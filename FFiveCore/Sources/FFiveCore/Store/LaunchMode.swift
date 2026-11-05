import Foundation

/// Screens a demo launch can open straight into, chosen with `-demoRoute <name>`.
public enum DemoRoute: String {
    case train, builder, session, progress, strength
}

public enum LaunchMode: Equatable {
    /// The lifter's own store on disk.
    case lifter
    /// `-seedDemo`: an in-memory store filled by `DemoSeed`, opened on `route` when one is named.
    case demo(route: DemoRoute?)

    public init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-seedDemo") else {
            self = .lifter
            return
        }
        let route = arguments.firstIndex(of: "-demoRoute")
            .flatMap { arguments.dropFirst($0 + 1).first }
            .flatMap(DemoRoute.init(rawValue:))
        self = .demo(route: route)
    }

    public var isDemo: Bool { self != .lifter }

    public var demoRoute: DemoRoute? {
        if case .demo(let route) = self { route } else { nil }
    }
}
