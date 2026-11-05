import XCTest

@testable import FFiveCore

final class LaunchModeTests: XCTestCase {
    func testPlainLaunchIsTheLifter() {
        XCTAssertEqual(LaunchMode(arguments: ["FFive"]).source, .lifter)
        XCTAssertEqual(
            LaunchMode(arguments: ["FFive", "-demoRoute", "progress"]).source, .lifter,
            "a route without -seedDemo opens nothing")
        XCTAssertFalse(LaunchMode(arguments: ["FFive"]).isDemo)
    }

    func testSeedDemoParsesItsRoute() {
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-seedDemo"]).source, .demo(route: nil))
        XCTAssertEqual(
            LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute", "progress"]).source, .demo(route: .progress))
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-demoRoute", "strength", "-seedDemo"]).demoRoute, .strength)
        XCTAssertEqual(
            LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute", "nowhere"]).source, .demo(route: nil),
            "an unknown route is ignored")
        XCTAssertEqual(
            LaunchMode(arguments: ["FFive", "-seedDemo", "-demoRoute"]).source, .demo(route: nil),
            "a route flag with no value is ignored")
        XCTAssertTrue(LaunchMode(arguments: ["FFive", "-seedDemo"]).isDemo)
    }

    func testDisableAnimationsFlag() {
        XCTAssertFalse(LaunchMode(arguments: ["FFive"]).animationsDisabled)
        XCTAssertFalse(LaunchMode(arguments: ["FFive", "-seedDemo"]).animationsDisabled)
        XCTAssertTrue(LaunchMode(arguments: ["FFive", "-disableAnimations"]).animationsDisabled)
        XCTAssertTrue(LaunchMode(arguments: ["FFive", "-seedDemo", "-disableAnimations"]).animationsDisabled)
        XCTAssertEqual(LaunchMode(arguments: ["FFive", "-disableAnimations"]).source, .lifter)
    }
}
