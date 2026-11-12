import XCTest

@testable import FFiveCore

final class PlateMathTests: XCTestCase {
    private func load(_ target: Double, bar: Double = 45, unit: WeightUnit = .lb) -> PlateLoad {
        PlateLoad.closest(to: target, bar: bar, plates: unit.plates)
    }

    func testTwoFortyFivesLoad225() {
        let result = load(225)
        XCTAssertEqual(result.perSide, [45, 45])
        XCTAssertTrue(result.isExact)
        XCTAssertEqual(result.total, 225)
    }

    func testKilogramsLoadHeaviestFirst() {
        let result = load(102.5, bar: 20, unit: .kg)
        XCTAssertEqual(result.perSide, [25, 15, 1.25])
        XCTAssertTrue(result.isExact)
    }

    func testOnePlateLoad135() {
        XCTAssertEqual(load(135).perSide, [45])
    }

    func testTargetBelowBarLoadsBarAlone() {
        let result = load(30)
        XCTAssertEqual(result.perSide, [])
        XCTAssertEqual(result.total, 45)
        XCTAssertEqual(result.offBy, 15)
        XCTAssertFalse(result.isExact)
    }

    func testTargetEqualToBarIsExactWithNoPlates() {
        let result = load(45)
        XCTAssertEqual(result.perSide, [])
        XCTAssertTrue(result.isExact)
        XCTAssertEqual(result.offBy, 0)
    }

    func testUnloadableTargetShowsClosestAndHowFarOff() {
        let result = load(226)
        XCTAssertEqual(result.total, 225)
        XCTAssertEqual(result.offBy, -1)
        XCTAssertFalse(result.isExact)
    }

    func testTieTakesTheLighterLoad() {
        let result = load(227.5)
        XCTAssertEqual(result.total, 225)
        XCTAssertEqual(result.offBy, -2.5)
    }

    func testJustPastTheTieTakesTheHeavierLoad() {
        XCTAssertEqual(load(227.6).total, 230)
    }

    func testBarlessMachineLoadsTheWholeWeightOnTheSides() {
        let result = load(100, bar: 0)
        XCTAssertEqual(result.perSide, [45, 5])
        XCTAssertEqual(result.total, 100)
    }

    func testLighterBarsLoadTheRest() {
        XCTAssertEqual(load(135, bar: 35).perSide, [45, 5])
        XCTAssertEqual(load(60, bar: 15, unit: .kg).perSide, [20, 2.5])
    }

    func testKilogramHalfPlatesReachQuarterKilogramSteps() {
        let result = load(52.5, bar: 20, unit: .kg)
        XCTAssertEqual(result.perSide, [15, 1.25])
        XCTAssertTrue(result.isExact)
    }

    func testDecimalTargetsDoNotDriftFromFloatError() {
        let result = load(62.5, bar: 20, unit: .kg)
        XCTAssertEqual(result.perSide, [20, 1.25])
        XCTAssertTrue(result.isExact)
        XCTAssertEqual(result.offBy, 0)
        XCTAssertTrue(load(0.1 + 0.2 + 44.7).isExact)
    }

    func testNoPlatesLoadsTheBarAlone() {
        let result = PlateLoad.closest(to: 100, bar: 45, plates: [])
        XCTAssertEqual(result.perSide, [])
        XCTAssertEqual(result.offBy, -55)
    }

    func testEachUnitHasItsOwnPlatesAndBar() {
        XCTAssertEqual(WeightUnit.lb.plates, [45, 35, 25, 10, 5, 2.5])
        XCTAssertEqual(WeightUnit.kg.plates, [25, 20, 15, 10, 5, 2.5, 1.25])
        XCTAssertEqual(WeightUnit.lb.defaultBarWeight, 45)
        XCTAssertEqual(WeightUnit.kg.defaultBarWeight, 20)
    }

    func testPlateFormatKeepsTheQuarterDigits() {
        XCTAssertEqual(formatPlate(1.25), "1.25")
        XCTAssertEqual(formatPlate(45), "45")
        XCTAssertEqual(formatPlate(2.5), "2.5")
    }
}
