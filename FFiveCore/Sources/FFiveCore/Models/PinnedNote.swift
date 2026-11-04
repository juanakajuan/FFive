import Foundation
import SwiftData

@Model
public final class PinnedNote {
    public var name: String = ""
    public var text: String = ""

    init(name: String, text: String) {
        self.name = name
        self.text = text
    }

    private static func all(named name: String, in context: ModelContext) -> [PinnedNote] {
        (try? context.fetch(FetchDescriptor<PinnedNote>(predicate: #Predicate { $0.name == name }))) ?? []
    }

    static func find(named name: String, in context: ModelContext) -> PinnedNote? {
        all(named: name, in: context).first
    }

    static func delete(for name: String, in context: ModelContext) {
        all(named: name, in: context).forEach(context.delete)
    }

    static func set(_ text: String, for name: String, in context: ModelContext) {
        guard let text = text.noteText else { return delete(for: name, in: context) }
        let existing = all(named: name, in: context)
        if let first = existing.first {
            first.text = text
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(PinnedNote(name: name, text: text))
        }
    }
}

extension String {
    var noteText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
