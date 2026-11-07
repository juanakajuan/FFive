import Foundation

/// What changed in each shipped version, newest release first. `scripts/changelog.sh` writes it from the
/// git history at release time; the app ships it as `Changelog.json`.
public struct Changelog: Codable, Equatable {
    public var releases: [Release]

    public init(releases: [Release]) { self.releases = releases }

    public struct Release: Codable, Equatable {
        public var version: String
        /// The day the release was cut, as `yyyy-MM-dd`.
        public var date: String
        public var entries: [Entry]

        public init(version: String, date: String, entries: [Entry]) {
            self.version = version
            self.date = date
            self.entries = entries
        }
    }

    public struct Entry: Codable, Equatable, Hashable {
        public enum Kind: String, Codable, CaseIterable {
            case feature, improvement, fix

            public var label: String {
                switch self {
                case .feature: "New"
                case .improvement: "Improved"
                case .fix: "Fixed"
                }
            }
        }

        public var kind: Kind
        public var text: String
        /// The day the change landed, as `yyyy-MM-dd`.
        public var date: String

        public init(kind: Kind, text: String, date: String) {
            self.kind = kind
            self.text = text
            self.date = date
        }
    }

    /// The changes of one release that landed on one day.
    public struct DayGroup: Equatable, Identifiable {
        public let version: String
        public let date: String
        public let entries: [Entry]

        public var id: String { "\(version) \(date)" }
    }

    public static func decode(_ data: Data) throws -> Changelog {
        try JSONDecoder().decode(Changelog.self, from: data)
    }

    /// Every change, one group per release and day, newest first.
    public var dayGroups: [DayGroup] { Self.dayGroups(releases) }

    static func dayGroups(_ releases: [Release]) -> [DayGroup] {
        releases.flatMap { release in
            Dictionary(grouping: release.entries, by: \.date)
                .sorted { $0.key > $1.key }
                .map { DayGroup(version: release.version, date: $0.key, entries: $0.value) }
        }
    }

    /// The groups to show once after an update, empty when there is nothing new to tell.
    ///
    /// - Parameters:
    ///   - lastSeen: the version whose changes the lifter last saw, nil before this build recorded one.
    ///   - current: the running version.
    ///   - hasHistory: whether the lifter trained before. With no `lastSeen`, a lifter with history updated
    ///     from a build that predates the changelog and sees this release; a fresh install sees nothing.
    public func unseen(lastSeen: String?, current: String, hasHistory: Bool) -> [DayGroup] {
        let shown: [Release]
        if let lastSeen {
            shown = releases.filter {
                Self.compare($0.version, lastSeen) == .orderedDescending
                    && Self.compare($0.version, current) != .orderedDescending
            }
        } else {
            shown = hasHistory ? releases.filter { Self.compare($0.version, current) == .orderedSame } : []
        }
        return Self.dayGroups(shown)
    }

    /// Orders dotted versions by number, so 1.10 follows 1.9 and 1.0 equals 1.
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
