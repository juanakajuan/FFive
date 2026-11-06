import Foundation

enum DemoRoute: String {
    case train, builder, session, progress, strength
}

enum DemoLaunch {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-seedDemo")
    static let route: DemoRoute? = isEnabled
        ? UserDefaults.standard.string(forKey: "demoRoute").flatMap(DemoRoute.init(rawValue:))
        : nil

    private static var taken: Set<DemoRoute> = []

    static func take(_ candidate: DemoRoute) -> Bool {
        guard route == candidate else { return false }
        return taken.insert(candidate).inserted
    }

    static func isPending(_ candidate: DemoRoute) -> Bool {
        route == candidate && !taken.contains(candidate)
    }
}
