import Foundation

/// Screens a demo launch can open straight into, chosen with `-demoRoute <name>`.
public enum DemoRoute: String {
    case train, builder, session, progress, strength
}

public struct LaunchMode: Equatable {
    public enum Source: Equatable {
        /// The lifter's own store on disk.
        case lifter
        /// `-seedDemo`: an in-memory store filled by `DemoSeed`, opened on `route` when one is named.
        case demo(route: DemoRoute?)
    }

    public let source: Source
    /// `-disableAnimations`: the verify driver launches with it so taps land on settled screens.
    public let animationsDisabled: Bool

    public init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        animationsDisabled = arguments.contains("-disableAnimations")
        guard arguments.contains("-seedDemo") else {
            source = .lifter
            return
        }
        let route = arguments.firstIndex(of: "-demoRoute")
            .flatMap { arguments.dropFirst($0 + 1).first }
            .flatMap(DemoRoute.init(rawValue:))
        source = .demo(route: route)
    }

    public var isDemo: Bool { source != .lifter }

    public var demoRoute: DemoRoute? {
        if case .demo(let route) = source { route } else { nil }
    }
}
