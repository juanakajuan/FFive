import FFiveCore

enum DemoLaunch {
    private(set) static var route: DemoRoute?
    private static var taken: Set<DemoRoute> = []

    static func configure(_ mode: LaunchMode) {
        route = mode.demoRoute
    }

    static func take(_ candidate: DemoRoute) -> Bool {
        guard route == candidate else { return false }
        return taken.insert(candidate).inserted
    }

    static func isPending(_ candidate: DemoRoute) -> Bool {
        route == candidate && !taken.contains(candidate)
    }
}
