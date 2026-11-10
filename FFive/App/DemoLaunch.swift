import FFiveCore

enum DemoLaunch {
    private(set) static var route: DemoRoute?
    private(set) static var isDemo = false
    private static var taken = false

    static func configure(_ mode: LaunchMode) {
        route = mode.demoRoute
        isDemo = mode.isDemo
    }

    static func take(_ candidate: DemoRoute) -> Bool {
        guard isPending(candidate) else { return false }
        taken = true
        return true
    }

    static func isPending(_ candidate: DemoRoute) -> Bool {
        route == candidate && !taken
    }
}
