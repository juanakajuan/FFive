public enum SetType: String, CaseIterable, Identifiable {
    case regular
    case myorep
    case myorepMatch

    public var id: Self { self }

    public var title: String {
        switch self {
        case .regular: "Regular"
        case .myorep: "Myorep"
        case .myorepMatch: "Myorep match"
        }
    }

    public var tag: String? {
        switch self {
        case .regular: nil
        case .myorep: "MYO"
        case .myorepMatch: "MATCH"
        }
    }

    var countsTowardProgression: Bool { self == .regular }
}
