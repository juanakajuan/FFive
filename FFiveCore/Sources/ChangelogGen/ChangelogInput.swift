import FFiveCore
import Foundation

enum ChangelogInput {
    /// Scopes that change how the app is built or checked, never what a lifter sees.
    static let toolingScopes: Set<String> = ["verify", "check", "lint", "ci", "scripts", "build", "deps"]

    static func parse(_ input: String) -> Changelog {
        var releases: [Changelog.Release] = []
        for line in input.split(separator: "\n") {
            let fields = line.split(separator: "\t", maxSplits: 2).map(String.init)
            guard fields.count == 3 else { continue }
            switch fields[0] {
            case "R":
                releases.append(.init(version: fields[1], date: fields[2], entries: []))
            case "C":
                guard !releases.isEmpty, let entry = entry(subject: fields[2], date: fields[1]) else { continue }
                releases[releases.count - 1].entries.append(entry)
            default:
                continue
            }
        }
        return Changelog(releases: releases.filter { !$0.entries.isEmpty })
    }

    /// `feat(scope): add a thing (#12)` becomes a New entry reading "Add a thing".
    static func entry(subject: String, date: String) -> Changelog.Entry? {
        guard let colon = subject.firstIndex(of: ":") else { return nil }
        var type = String(subject[..<colon]).trimmingCharacters(in: .whitespaces)
        if type.hasSuffix("!") { type.removeLast() }
        var scope: String?
        if let open = type.firstIndex(of: "("), type.hasSuffix(")") {
            scope = String(type[type.index(after: open)..<type.index(before: type.endIndex)])
            type = String(type[..<open])
        }
        let kind: Changelog.Entry.Kind
        switch type {
        case "feat": kind = .feature
        case "fix": kind = .fix
        case "perf": kind = .improvement
        default: return nil
        }
        if let scope, toolingScopes.contains(scope) { return nil }

        var text = subject[subject.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        while let range = text.range(of: #"\s*\(#\d+\)$"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        guard let first = text.first else { return nil }
        return .init(kind: kind, text: first.uppercased() + text.dropFirst(), date: date)
    }
}
