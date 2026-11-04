import Foundation

public enum SessionStatus: Equatable {
    case upcoming
    case inProgress(Workout)
    case finished(Workout)
    case skipped

    public var isOpen: Bool {
        switch self {
        case .upcoming, .inProgress: true
        case .finished, .skipped: false
        }
    }
}
