import Foundation

/// Screens a `-seedDemo` launch can open straight into, chosen with `-demoRoute <name>`.
enum DemoRoute: String {
    case train, builder, session, progress, strength
}

enum DemoLaunch {
    /// Demo launches run on an in-memory store and never touch the lifter's real data.
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-seedDemo")
    static let route: DemoRoute? = isEnabled
        ? UserDefaults.standard.string(forKey: "demoRoute").flatMap(DemoRoute.init(rawValue:))
        : nil

    private static var taken: Set<DemoRoute> = []

    /// True once, the first time a screen asks for the route it owns.
    static func take(_ candidate: DemoRoute) -> Bool {
        guard route == candidate else { return false }
        return taken.insert(candidate).inserted
    }

    /// True while the route is still waiting for its screen, without claiming it.
    static func isPending(_ candidate: DemoRoute) -> Bool {
        route == candidate && !taken.contains(candidate)
    }
}
