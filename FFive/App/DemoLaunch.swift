import FFiveCore

enum DemoLaunch {
    private(set) static var route: DemoRoute?
    private static var taken: Set<DemoRoute> = []

    static func configure(_ mode: LaunchMode) {
        route = mode.demoRoute
    }

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
