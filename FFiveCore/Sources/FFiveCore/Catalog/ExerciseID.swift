import Foundation

/// Exercise identity. Folding at creation is what lets `bench press` and `Bench Press` share one history.
public struct ExerciseID: Hashable, Sendable {
    public let rawValue: String

    public init(folding name: String) {
        rawValue = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
