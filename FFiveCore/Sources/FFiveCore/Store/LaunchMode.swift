import Foundation

public enum DemoRoute: String {
    case train, builder, session, progress, strength
}

public struct LaunchMode: Equatable {
    enum Source: Equatable {
        case lifter
        case demo(route: DemoRoute?)
    }

    let source: Source
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
