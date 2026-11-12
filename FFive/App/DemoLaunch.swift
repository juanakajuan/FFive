import FFiveCore

enum DemoLaunch {
    static let mode = LaunchMode()
    private static var taken = false

    static var route: DemoRoute? { mode.demoRoute }
    static var isDemo: Bool { mode.isDemo }

    static func take(_ candidate: DemoRoute) -> Bool {
        guard isPending(candidate) else { return false }
        taken = true
        return true
    }

    static func isPending(_ candidate: DemoRoute) -> Bool {
        route == candidate && !taken
    }
}
