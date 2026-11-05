import SQLite3
import XCTest

/// Runs a step file against the installed FFive app (`com.juanix.FFive`).
/// `ffive-verify drive` passes the file as FFIVE_STEPS and the evidence folder as FFIVE_OUT, the app's
/// store and preferences paths as FFIVE_STORE and FFIVE_DEFAULTS, and the watchdog delay as FFIVE_TREE_AT.
/// The step language is documented in the skill's SKILL.md.
final class DriverTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.juanix.FFive")
    private let environment = ProcessInfo.processInfo.environment
    private var out = URL(fileURLWithPath: NSTemporaryDirectory())
    private var log: [String] = []
    private var currentStep = ""
    private var finished = false

    func testRunSteps() throws {
        let stepsPath = try XCTUnwrap(environment["FFIVE_STEPS"], "FFIVE_STEPS is not set")
        out = URL(fileURLWithPath: try XCTUnwrap(environment["FFIVE_OUT"], "FFIVE_OUT is not set"))
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        continueAfterFailure = false
        if let seconds = environment["FFIVE_TREE_AT"].flatMap(Double.init) { startWatchdog(after: seconds) }
        defer { finished = true }

        let lines = try String(contentsOfFile: stepsPath, encoding: .utf8).components(separatedBy: .newlines)
        for (number, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            currentStep = "\(number + 1): \(line)"
            do {
                try run(Self.tokenize(line))
                record("ok   \(number + 1): \(line)")
            } catch {
                // XCTFail stops the test, so everything worth keeping is written before it.
                record("FAIL \(number + 1): \(line) -> \(error)")
                save(app.debugDescription, as: "failure.tree.txt")
                save(XCUIScreen.main.screenshot().pngRepresentation, as: "failure.png")
                XCTFail("step \(number + 1) `\(line)` failed: \(error)")
                return
            }
        }
    }

    private func startWatchdog(after seconds: Double) {
        Thread.detachNewThread { [self] in
            Thread.sleep(forTimeInterval: seconds)
            guard !finished else { return }
            record("TIMEOUT after \(Int(seconds))s during step \(currentStep)")
            save(app.debugDescription, as: "failure.tree.txt")
            save(XCUIScreen.main.screenshot().pngRepresentation, as: "failure.png")
        }
    }

    // MARK: Steps

    private func run(_ words: [String]) throws {
        guard let verb = words.first else { return }
        var args = Array(words.dropFirst())
        let timeout = Self.option("timeout", in: &args).flatMap(Double.init) ?? 5
        switch verb {
        case "launch":
            app.terminate()
            app.launchArguments = args
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 15) else { throw StepError("app did not reach the foreground") }
        case "terminate":
            app.terminate()
        case "tap":
            try onScreen(args, timeout).tap()
        case "longpress":
            try onScreen(args, timeout).press(forDuration: 1.2)
        case "type":
            let text = try Self.pop(&args, "text")
            let field = try onScreen(args, timeout)
            field.tap()
            field.typeText(text)
        case "replace":
            let text = try Self.pop(&args, "text")
            let field = try onScreen(args, timeout)
            // A centered tap can drop the cursor before the old text; tap the trailing edge so deletes clear it.
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            let current = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4) + text)
        case "wait", "assert":
            _ = try onScreen(args, timeout)
        case "exists":
            _ = try element(args, timeout)
        case "absent":
            let query = try resolve(args)
            let gone = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: gone, object: query)
            guard XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed else { throw StepError("still present: \(args)") }
        case "value":
            let expected = try Self.pop(&args, "expected value")
            let found = try onScreen(args, timeout)
            let actual = found.value as? String ?? ""
            guard actual == expected else { throw StepError("value is \"\(actual)\", expected \"\(expected)\"") }
        case "selected", "unselected":
            let found = try onScreen(args, timeout)
            guard found.isSelected == (verb == "selected") else { throw StepError("\(args) is \(found.isSelected ? "" : "not ")selected") }
        case "count":
            let expected = try Self.pop(&args, "expected count")
            let actual = try resolveAll(args).count
            guard String(actual) == expected else { throw StepError("count is \(actual), expected \(expected)") }
        case "scrollto":
            let query = try resolve(args)
            for _ in 0..<12 where !(query.exists && query.isHittable) { app.swipeUp() }
            guard query.exists && query.isHittable else { throw StepError("never scrolled into view: \(args)") }
        case "swipe":
            switch args.first {
            case "up": app.swipeUp()
            case "down": app.swipeDown()
            case "left": app.swipeLeft()
            case "right": app.swipeRight()
            default: throw StepError("swipe needs up, down, left, or right")
            }
        case "store-expect":
            guard args.count == 3 else { throw StepError("expected `store-expect <Model> <field> <value>`, got \(args)") }
            try poll(timeout) { try storeMismatch(model: args[0], field: args[1], value: args[2]) }
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

    // MARK: Queries

    /// `#<id>` matches an accessibility identifier exactly. Otherwise `<kind> "<label>" [#n]`, where kind is
    /// button, text, field, search, cell, tab, switch, image, nav, alert, or any, and the label matches the
    /// accessibility label, identifier, or placeholder exactly; prefix it with `~` to match a substring.
    private func resolveAll(_ args: [String]) throws -> XCUIElementQuery {
        if let id = args.first, id.hasPrefix("#") {
            return app.descendants(matching: .any).matching(identifier: String(id.dropFirst()))
        }
        guard args.count >= 2 else { throw StepError("expected `#<id>` or `<kind> \"<label>\"`, got \(args)") }
        let type: XCUIElement.ElementType = switch args[0] {
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
        let scope: XCUIElementQuery = switch args[0] {
        case "tab": app.tabBars.descendants(matching: type)
        default: app.descendants(matching: type)
        }
        let label = args[1]
        let predicate = label.hasPrefix("~")
            ? NSPredicate(format: "label CONTAINS %@ OR identifier CONTAINS %@ OR placeholderValue CONTAINS %@",
                          String(label.dropFirst()), String(label.dropFirst()), String(label.dropFirst()))
            : NSPredicate(format: "label == %@ OR identifier == %@ OR placeholderValue == %@", label, label, label)
        return scope.matching(predicate)
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
        guard found.waitForExistence(timeout: timeout) else { throw StepError("not found within \(timeout)s: \(args)") }
        return found
    }

    /// For actions and on-screen checks: `#n` counts only hittable matches. Screens under a sheet or
    /// full-screen cover stay in the tree, so counting every match would land on hidden elements.
    private func onScreen(_ args: [String], _ timeout: Double) throws -> XCUIElement {
        let query = try resolveAll(args)
        let wanted = Self.index(args) ?? 0
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            let visible = query.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if visible.count > wanted { return visible[wanted] }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date.now < deadline
        throw StepError("not on screen within \(timeout)s: \(args)")
    }

    // MARK: Store and preferences

    /// Retries `mismatch` every 0.25 s until it returns nil or the timeout passes, then fails with its last reason.
    private func poll(_ timeout: Double, _ mismatch: () throws -> String?) throws {
        let deadline = Date.now.addingTimeInterval(timeout)
        while true {
            guard let reason = try mismatch() else { return }
            guard Date.now < deadline else { throw StepError(reason) }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    private func storeMismatch(model: String, field: String, value: String) throws -> String? {
        guard let path = environment["FFIVE_STORE"] else { throw StepError("FFIVE_STORE is not set") }
        guard FileManager.default.fileExists(atPath: path) else {
            return "no on-disk store at \(path); -seedDemo launches are in memory"
        }
        let table = "Z" + model.uppercased(), column = "Z" + field.uppercased()
        let (condition, bound): (String, Store.Value?) = switch value {
        case "null": ("is null", nil)
        case "not-null": ("is not null", nil)
        default: Double(value).map { ("= ?", .number($0)) } ?? ("= ?", .text(value))
        }
        let store = try Store(path: path)
        defer { store.close() }
        let tables = try store.strings("select name from sqlite_master where type = 'table' and name like 'Z%' and name not like 'Z\\_%' escape '\\' order by name")
        guard tables.contains(table) else { throw StepError("no table \(table); tables: \(tables.joined(separator: ", "))") }
        let columns = try store.strings("select name from pragma_table_info('\(table)')")
        guard columns.contains(column) else { throw StepError("no column \(column) in \(table); columns: \(columns.joined(separator: ", "))") }
        if try store.strings("select count(*) from \(table) where \(column) \(condition)", binding: bound).first != "0" { return nil }
        let values = try store.strings("select distinct \(column) from \(table) limit 10")
        return "no \(model) row has \(field) \(condition.replacingOccurrences(of: "?", with: value)); values: \(values.joined(separator: ", "))"
    }

    private func defaultsMismatch(key: String, expected: String) throws -> String? {
        guard let path = environment["FFIVE_DEFAULTS"] else { throw StepError("FFIVE_DEFAULTS is not set") }
        guard let data = FileManager.default.contents(atPath: path) else { return "no preferences written yet at \(path)" }
        let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
        guard let actual = dict[key] else { return "no key \(key); keys: \(dict.keys.sorted().joined(separator: ", "))" }
        return "\(actual)" == expected ? nil : "\(key) is \"\(actual)\", expected \"\(expected)\""
    }

    // MARK: Plumbing

    private func record(_ entry: String) {
        log.append(entry)
        save(log.joined(separator: "\n") + "\n", as: "steps.log")
    }

    private func save(_ text: String, as name: String) { save(Data(text.utf8), as: name) }

    private func save(_ data: Data, as name: String) {
        try? data.write(to: out.appendingPathComponent(name))
    }

    /// Splits on spaces, keeping "double quoted" runs together.
    static func tokenize(_ line: String) -> [String] {
        var words: [String] = [], current = "", quoted = false, started = false
        for character in line {
            if character == "\"" { quoted.toggle(); started = true; continue }
            if character == " " && !quoted {
                if started { words.append(current) }
                current = ""; started = false
                continue
            }
            current.append(character); started = true
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

/// A read-only SQLite handle on the app's SwiftData store.
private struct Store {
    enum Value {
        case number(Double)
        case text(String)
    }

    private let db: OpaquePointer

    init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle else {
            throw StepError("cannot open store at \(path): \(handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no handle")")
        }
        db = handle
    }

    func close() { sqlite3_close(db) }

    /// The first column of every row as text, `null` for SQL null.
    func strings(_ sql: String, binding value: Value? = nil) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StepError("\(String(cString: sqlite3_errmsg(db))) in `\(sql)`")
        }
        defer { sqlite3_finalize(statement) }
        switch value {
        case .number(let number): sqlite3_bind_double(statement, 1, number)
        case .text(let text): sqlite3_bind_text(statement, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        case nil: break
        }
        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "null")
        }
        return rows
    }
}

struct StepError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
