import XCTest

@testable import FFiveCore

final class TemplateVariantTests: XCTestCase {
    private let lowerBody: Set<Muscle> = [.quads, .hamstrings, .glutes]

    private func slots(_ template: ProgramTemplate, in muscles: Set<Muscle>) -> Int {
        template.days.flatMap(\.slots).filter { muscles.contains($0.muscle) }.count
    }

    func testEveryWomensTemplateOutweighsItsNamesakeInGlutesAndLowerBody() {
        let womens = ExerciseCatalog.templates.filter { $0.variant == .women }
        XCTAssertGreaterThanOrEqual(womens.count, 5, "a women's variant for each whole-body schedule")
        for template in womens {
            let baseName = String(template.name.dropFirst("Women's ".count))
            guard let base = ExerciseCatalog.templates.first(where: { $0.name == baseName }) else {
                XCTFail("\(template.name) has no standard namesake")
                continue
            }
            XCTAssertEqual(base.variant, .standard)
            XCTAssertEqual(template.emphasis, base.emphasis, "\(template.name) keeps its namesake's emphasis")
            XCTAssertEqual(template.days.count, base.days.count, "\(template.name) keeps its namesake's schedule")
            XCTAssertGreaterThan(
                slots(template, in: [.glutes]), slots(base, in: [.glutes]), "\(template.name) adds glute volume")
            XCTAssertGreaterThan(
                slots(template, in: lowerBody), slots(base, in: lowerBody), "\(template.name) adds lower-body volume")
        }
    }

    func testCustomTemplatesAreStandardAndNotBuiltIn() {
        let custom = ProgramTemplate(name: "Mine", emphasis: nil, summary: "", days: [])
        XCTAssertFalse(custom.isBuiltIn)
        XCTAssertEqual(custom.variant, .standard)
        XCTAssertTrue(ExerciseCatalog.templates.allSatisfy(\.isBuiltIn))
    }

    func testSourceFilterSplitsBuiltInFromCustom() {
        let builtIn = ExerciseCatalog.templates[0]
        let custom = ProgramTemplate(name: "Mine", emphasis: nil, summary: "", days: builtIn.days)
        var filter = TemplateFilter()
        XCTAssertTrue(filter.matches(builtIn) && filter.matches(custom), "no filter shows both")

        filter.source = .builtIn
        XCTAssertTrue(filter.matches(builtIn))
        XCTAssertFalse(filter.matches(custom))
        XCTAssertTrue(filter.shows(.builtIn))
        XCTAssertFalse(filter.shows(.custom), "the custom section hides")

        filter.source = .custom
        XCTAssertFalse(filter.matches(builtIn))
        XCTAssertTrue(filter.matches(custom))
        XCTAssertFalse(filter.shows(.builtIn))
    }

    func testVariantFilterPicksOneVariantAndDropsCustom() {
        let standard = ExerciseCatalog.templates.first { $0.variant == .standard }!
        let womens = ExerciseCatalog.templates.first { $0.variant == .women }!
        let custom = ProgramTemplate(name: "Mine", emphasis: nil, summary: "", days: [])
        var filter = TemplateFilter()

        filter.variant = .women
        XCTAssertEqual([standard, womens, custom].map(filter.matches), [false, true, false])
        filter.variant = .standard
        XCTAssertEqual(
            [standard, womens, custom].map(filter.matches), [true, false, false],
            "a custom template has no variant, so any variant filter drops it")
    }

    func testFiltersCombine() {
        var filter = TemplateFilter()
        filter.daysPerWeek = 4
        filter.variant = .women
        filter.search = " upper "
        XCTAssertEqual(ExerciseCatalog.templates.filter(filter.matches).map(\.name), ["Women's Upper/Lower, 4 Days"])
    }

    func testLabelNamesEveryActiveFilter() {
        var filter = TemplateFilter()
        XCTAssertEqual(filter.label, "Filters")
        filter.daysPerWeek = 3
        filter.emphasis = .wholeBody
        filter.source = .builtIn
        filter.variant = .women
        XCTAssertEqual(filter.label, "3/week · Whole Body · Built-in · Women's")
        filter.search = "full"
        XCTAssertEqual(filter.label, "3/week · Whole Body · Built-in · Women's", "search is not a filter")
    }
}
