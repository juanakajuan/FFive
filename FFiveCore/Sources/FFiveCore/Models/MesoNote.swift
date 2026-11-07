import Foundation

/// A note on a whole block, kept in the order it was written.
public struct MesoNote: Hashable, Codable, Identifiable {
    public static let maxLength = 500

    public let id: UUID
    public let text: String
    public let date: Date

    /// Nil for blank text. Text longer than `maxLength` is cut to it.
    init?(text: String, date: Date = .now) {
        guard let trimmed = text.noteText else { return nil }
        id = UUID()
        self.text = String(trimmed.prefix(Self.maxLength))
        self.date = date
    }
}
