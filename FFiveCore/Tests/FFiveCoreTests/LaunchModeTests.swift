import XCTest
@testable import FFiveCore

final class LaunchModeTests: XCTestCase {
    func testPlainLaunchIsTheLifter() {
        XCTAssertEqual(LaunchMode(arguments: ["FFive"]), .lifter)
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-demoRoute", "progress"]), .lifter, "a route without -seedDemo opens nothing")
        XCTAssertFalse(LaunchMode(arguments: ["FFive"]).isDemo)
    }

    func testSeedDemoParsesItsRoute() {
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-seedDemo"]), .demo(route: nil))
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute", "progress"]), .demo(route: .progress))
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-demoRoute", "strength", "-seedDemo"]).demoRoute, .strength)
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute", "nowhere"]), .demo(route: nil), "an unknown route is ignored")
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute"]), .demo(route: nil), "a route flag with no value is ignored")
        XCTAssertTrue(LaunchMode(arguments: ["FFive", "-seedDemo"]).isDemo)
    }
}
