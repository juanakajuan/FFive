import XCTest

final class DriverTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.juanix.FFive")
    private let environment = ProcessInfo.processInfo.environment
    private var out = URL(fileURLWithPath: NSTemporaryDirectory())
    private var launchedDemo = false
    /// Guards the state below, which the watchdog thread shares with the test.
    private let lock = NSLock()
    private var log: [String] = []
    private var currentStep = ""
    private var finished = false
    private var timedOut = false
    private var failureCaptured = false

    func testRunSteps() throws {
        let stepsPath = try XCTUnwrap(environment["FFIVE_STEPS"], "FFIVE_STEPS is not set")
        out = URL(fileURLWithPath: try XCTUnwrap(environment["FFIVE_OUT"], "FFIVE_OUT is not set"))
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        continueAfterFailure = false
        if let deadline = environment["FFIVE_DEADLINE"].flatMap(Double.init) {
            startWatchdog(at: Date(timeIntervalSince1970: deadline))
        }
        defer { lock.withLock { finished = true } }

        let lines = try String(contentsOfFile: stepsPath, encoding: .utf8).components(separatedBy: .newlines)
        for (number, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let step = "\(number + 1): \(line)"
            lock.withLock { currentStep = step }
            do {
                try run(Self.tokenize(line))
                append("ok   \(step)")
            } catch {
                record(XCTIssue(type: .assertionFailure, compactDescription: "\(error)"))
                return
            }
        }
    }

    override func record(_ issue: XCTIssue) {
        append("FAIL \(lock.withLock { currentStep }) -> \(issue.compactDescription)")
        captureFailure()
        super.record(issue)
    }

    /// Saves the tree and screen once per drive: an issue recorded while capturing, or a later one, keeps the first capture.
    private func captureFailure() {
        let first = lock.withLock {
            defer { failureCaptured = true }
            return !failureCaptured
        }
        guard first else { return }
        save(app.debugDescription, as: "failure.tree.txt")
        save(XCUIScreen.main.screenshot().pngRepresentation, as: "failure.png")
    }

    private func startWatchdog(at deadline: Date) {
        let pollingStepGrace: TimeInterval = 3
        Thread.detachNewThread { [self] in
            Thread.sleep(until: deadline)
            let step: String? = lock.withLock {
                guard !finished else { return nil }
                timedOut = true
                return currentStep
            }
            guard let step else { return }
            append("TIMEOUT during step \(step)")
            Thread.sleep(forTimeInterval: pollingStepGrace)
            guard !lock.withLock({ finished }) else { return }
            captureFailure()
        }
    }

    private func run(_ words: [String]) throws {
        guard let verb = words.first else { return }
        var args = Array(words.dropFirst())
        // cfprefsd writes the preferences plist seconds after the app sets a value, longer when values change in quick succession.
        let timeout = Self.option("timeout", in: &args).flatMap(Double.init) ?? (verb == "defaults-expect" ? 30 : 5)
        switch verb {
        case "launch":
            app.terminate()
            launchedDemo = args.contains("-seedDemo")
            app.launchArguments = args
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 15) else {
                throw StepError("app did not reach the foreground")
            }
        case "terminate":
            app.terminate()
        case "tap":
            tapSettled(try onScreen(args, timeout))
        case "longpress":
            try onScreen(args, timeout).press(forDuration: 1.2)
        case "drag":
            guard let split = args.firstIndex(of: "to") else { throw StepError("expected `drag <target> to <target>`") }
            let source = try onScreen(Array(args[..<split]), timeout)
            let destination = try onScreen(Array(args[(split + 1)...]), timeout)
            source.press(forDuration: 0.8, thenDragTo: destination)
        case "type":
            let text = try Self.pop(&args, "text")
            let field = try onScreen(args, timeout)
            field.tap()
            field.typeText(text)
        case "replace":
            let text = try Self.pop(&args, "text")
            let field = try onScreen(args, timeout)
            try focusTrailingEdge(field, timeout)
            let current = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4) + text)
        case "wait", "assert":
            _ = try onScreen(args, timeout)
        case "exists":
            _ = try element(args, timeout)
        case "absent":
            let found = try resolve(args)
            try poll(timeout) { found.exists ? "still present: \(args)" : nil }
        case "value":
            let expected = try Self.pop(&args, "expected value")
            let found = try onScreen(args, timeout)
            let actual = found.value as? String ?? ""
            guard actual == expected else { throw StepError("value is \"\(actual)\", expected \"\(expected)\"") }
        case "selected", "unselected":
            let found = try onScreen(args, timeout)
            guard found.isSelected == (verb == "selected") else {
                throw StepError("\(args) is \(found.isSelected ? "" : "not ")selected")
            }
        case "count":
            let expected = try Self.pop(&args, "expected count")
            let actual = try resolveAll(args).count
            guard String(actual) == expected else { throw StepError("count is \(actual), expected \(expected)") }
        case "scrollto":
            try scrollToMiddle(try resolve(args), args)
        case "key":
            guard args == ["return"] else { throw StepError("expected `key return`, got \(args)") }
            guard app.keyboards.firstMatch.exists else { throw StepError("key return: no keyboard on screen") }
            app.typeText(XCUIKeyboardKey.return.rawValue)
            try poll(timeout) { app.keyboards.firstMatch.exists ? "keyboard still up after return" : nil }
        case "swipe":
            switch args.first {
            case "up": app.swipeUp()
            case "down": app.swipeDown()
            case "left": app.swipeLeft()
            case "right": app.swipeRight()
            default: throw StepError("swipe needs up, down, left, or right")
            }
        case "store-expect":
            guard args.count == 3 else {
                throw StepError("expected `store-expect <Model> <field> <value>`, got \(args)")
            }
            guard !launchedDemo else {
                throw StepError(
                    "store-expect after `launch -seedDemo`: the demo store is in memory, so no on-disk store holds its data"
                )
            }
            guard let path = environment["FFIVE_STORE"] else { throw StepError("FFIVE_STORE is not set") }
            try poll(timeout) { try storeMismatch(path: path, model: args[0], field: args[1], value: args[2]) }
        case "defaults-expect":
            guard args.count == 2 else { throw StepError("expected `defaults-expect <key> <value>`, got \(args)") }
            try poll(timeout) { try defaultsMismatch(key: args[0], expected: args[1]) }
        case "shot":
            save(XCUIScreen.main.screenshot().pngRepresentation, as: "\(try Self.pop(&args, "name")).png")
        case "tree":
            save(app.debugDescription, as: "\(try Self.pop(&args, "name")).tree.txt")
        case "sleep":
            Thread.sleep(forTimeInterval: Double(args.first ?? "1") ?? 1)
        default:
            throw StepError("unknown step `\(verb)`")
        }
    }

    /// A tap on an alert button while the alert's field holds the keyboard only ends editing: the keyboard drops
    /// and the alert slides down, and the button never fires. When that happens, tap the button where it settled.
    private func tapSettled(_ target: XCUIElement) {
        let alertWithKeyboard = app.alerts.firstMatch.exists && app.keyboards.firstMatch.exists
        let before = target.frame
        target.tap()
        guard alertWithKeyboard else { return }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.5)
        guard target.exists, target.isHittable, target.frame != before else { return }
        target.tap()
    }

    /// Taps the field as near its trailing edge as still focuses it, so the cursor lands after the old text and
    /// deletes clear all of it. A centered tap can drop the cursor before the text, and the frame XCUITest
    /// reports includes the field's padding, where a tap focuses nothing.
    private func focusTrailingEdge(_ field: XCUIElement, _ timeout: Double) throws {
        var dx = 0.97
        try poll(timeout) {
            if field.value(forKey: "hasKeyboardFocus") as? Bool == true { return nil }
            field.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).tap()
            dx = max(dx - 0.1, 0.5)
            return "no keyboard focus after taps along the trailing edge"
        }
    }

    /// Drags the list a third of the screen at a time, with no fling, until the target sits in the middle half.
    /// XCUITest calls an element under the Workout tab's pinned header or above the tab bar hittable, but a
    /// tap there lands on the header or bar, so on-screen is not enough.
    private func scrollToMiddle(_ target: XCUIElement, _ args: [String]) throws {
        let height = app.windows.firstMatch.frame.height
        let band = (height * 0.25)...(height * 0.75)
        func centered() -> Bool { target.exists && target.isHittable && band.contains(target.frame.midY) }
        for _ in 0..<36 where !centered() {
            let before = target.exists ? target.frame : .null
            let up = !(target.exists && target.frame.midY < band.lowerBound)
            let (from, to) = up ? (0.7, 0.37) : (0.37, 0.7)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from)).press(
                forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
            if target.exists, target.frame == before { break }
        }
        guard target.exists && target.isHittable else { throw StepError("never scrolled into view: \(args)") }
    }

    private func resolveAll(_ args: [String]) throws -> XCUIElementQuery {
        if let id = args.first, id.hasPrefix("#") {
            return app.descendants(matching: .any).matching(identifier: String(id.dropFirst()))
        }
        guard args.count >= 2 else { throw StepError("expected `#<id>` or `<kind> \"<label>\"`, got \(args)") }
        let type: XCUIElement.ElementType =
            switch args[0] {
            case "button": .button
            case "text": .staticText
            case "field": .textField
            case "search": .searchField
            case "cell": .cell
            case "tab": .button
            case "switch": .switch
            case "image": .image
            case "nav": .navigationBar
            case "alert": .alert
            case "any": .any
            default: throw StepError("unknown element kind `\(args[0])`")
            }
        let scope: XCUIElementQuery =
            switch args[0] {
            case "tab": app.tabBars.descendants(matching: type)
            default: app.descendants(matching: type)
            }
        return scope.matching(labelPredicate(args[1]))
    }

    private static func index(_ args: [String]) -> Int? {
        args.dropFirst(2).first { $0.hasPrefix("#") }.flatMap { Int($0.dropFirst()) }
    }

    /// For existence checks: `#n` counts every match, on screen or not.
    private func resolve(_ args: [String]) throws -> XCUIElement {
        let query = try resolveAll(args)
        return Self.index(args).map { query.element(boundBy: $0) } ?? query.firstMatch
    }

    private func element(_ args: [String], _ timeout: Double) throws -> XCUIElement {
        let found = try resolve(args)
        try poll(timeout) { found.exists ? nil : "not found within \(timeout)s: \(args)" }
        return found
    }

    /// For actions and on-screen checks: `#n` counts only hittable matches. Screens under a sheet or
    /// full-screen cover stay in the tree, so counting every match would land on hidden elements.
    private func onScreen(_ args: [String], _ timeout: Double) throws -> XCUIElement {
        let query = try resolveAll(args)
        let wanted = Self.index(args) ?? 0
        var found: XCUIElement?
        try poll(timeout) {
            let visible = query.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            guard visible.count > wanted else { return "not on screen within \(timeout)s: \(args)" }
            found = visible[wanted]
            return nil
        }
        return try XCTUnwrap(found)
    }

    private func poll(_ timeout: Double, _ mismatch: () throws -> String?) throws {
        let deadline = Date.now.addingTimeInterval(timeout)
        while true {
            guard let reason = try mismatch() else { return }
            if lock.withLock({ timedOut }) { throw StepError("drive timed out (--timeout): \(reason)") }
            guard Date.now < deadline else { throw StepError(reason) }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    private func defaultsMismatch(key: String, expected: String) throws -> String? {
        guard let path = environment["FFIVE_DEFAULTS"] else { throw StepError("FFIVE_DEFAULTS is not set") }
        guard let data = FileManager.default.contents(atPath: path) else {
            return "no preferences written yet at \(path)"
        }
        let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
        guard let actual = dict[key] else {
            return "no key \(key); keys: \(dict.keys.sorted().joined(separator: ", "))"
        }
        return "\(actual)" == expected ? nil : "\(key) is \"\(actual)\", expected \"\(expected)\""
    }

    private func append(_ entry: String) {
        lock.withLock {
            log.append(entry)
            save(log.joined(separator: "\n") + "\n", as: "steps.log")
        }
    }

    private func save(_ text: String, as name: String) { save(Data(text.utf8), as: name) }

    private func save(_ data: Data, as name: String) {
        try? data.write(to: out.appendingPathComponent(name))
    }

    static func tokenize(_ line: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quoted = false
        var started = false
        for character in line {
            if character == "\"" {
                quoted.toggle()
                started = true
                continue
            }
            if character == " " && !quoted {
                if started { words.append(current) }
                current = ""
                started = false
                continue
            }
            current.append(character)
            started = true
        }
        if started { words.append(current) }
        return words
    }

    /// Removes and returns the last word (the payload of type/replace/value/count/shot/tree).
    static func pop(_ args: inout [String], _ what: String) throws -> String {
        guard let last = args.popLast() else { throw StepError("missing \(what)") }
        return last
    }

    /// Removes `timeout=<n>` style options.
    static func option(_ name: String, in args: inout [String]) -> String? {
        guard let index = args.firstIndex(where: { $0.hasPrefix("\(name)=") }) else { return nil }
        return String(args.remove(at: index).dropFirst(name.count + 1))
    }
}

struct StepError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
