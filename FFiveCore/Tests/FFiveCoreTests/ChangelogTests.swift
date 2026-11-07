import Foundation
import XCTest

@testable import ChangelogGen
@testable import FFiveCore

final class ChangelogTests: XCTestCase {
    private let changelog = Changelog(releases: [
        .init(
            version: "1.10", date: "2026-11-09",
            entries: [
                .init(kind: .feature, text: "C", date: "2026-11-09"),
                .init(kind: .fix, text: "B", date: "2026-11-08"),
                .init(kind: .feature, text: "D", date: "2026-11-09"),
            ]),
        .init(version: "1.9", date: "2026-11-07", entries: [.init(kind: .feature, text: "A", date: "2026-11-07")]),
        .init(version: "1.8", date: "2026-11-01", entries: [.init(kind: .fix, text: "Z", date: "2026-11-01")]),
    ])

    func testVersionsCompareByNumber() {
        XCTAssertEqual(Changelog.compare("1.10", "1.9"), .orderedDescending)
        XCTAssertEqual(Changelog.compare("1.0", "1"), .orderedSame)
        XCTAssertEqual(Changelog.compare("1.4", "1.4.1"), .orderedAscending)
    }

    func testChangesGroupByReleaseThenDayNewestFirst() {
        let groups = changelog.dayGroups
        XCTAssertEqual(groups.map(\.id), ["1.10 2026-11-09", "1.10 2026-11-08", "1.9 2026-11-07", "1.8 2026-11-01"])
        XCTAssertEqual(groups[0].entries.map(\.text), ["C", "D"], "a day keeps its changes in release order")
    }

    func testAnUpdateShowsEveryReleaseSinceTheLastSeenOne() {
        let shown = changelog.unseen(lastSeen: "1.8", current: "1.10", hasHistory: true)
        XCTAssertEqual(Set(shown.map(\.version)), ["1.10", "1.9"], "skipping a version still shows its changes")
        XCTAssertEqual(changelog.unseen(lastSeen: "1.10", current: "1.10", hasHistory: true), [])
        XCTAssertEqual(
            changelog.unseen(lastSeen: "1.8", current: "1.9", hasHistory: true).map(\.version), ["1.9"],
            "a release newer than the running build stays hidden")
    }

    func testOnlyALifterWithHistorySeesWhatsNewBeforeAVersionWasRecorded() {
        XCTAssertEqual(changelog.unseen(lastSeen: nil, current: "1.9", hasHistory: false), [], "a fresh install")
        XCTAssertEqual(
            changelog.unseen(lastSeen: nil, current: "1.9", hasHistory: true).map(\.version), ["1.9"],
            "an update from a build without the changelog shows just this release")
    }

    func testCommitSubjectsBecomeLifterFacingEntries() {
        let entry = ChangelogInput.entry(subject: "feat: suggest an exercise in the picker (#86) (#113)", date: "d")
        XCTAssertEqual(entry, .init(kind: .feature, text: "Suggest an exercise in the picker", date: "d"))
        XCTAssertEqual(ChangelogInput.entry(subject: "fix(ui)!: close the gap", date: "d")?.kind, .fix)
        XCTAssertEqual(ChangelogInput.entry(subject: "perf: faster planner", date: "d")?.kind, .improvement)
        XCTAssertNil(ChangelogInput.entry(subject: "chore: bump version to 1.4", date: "d"))
        XCTAssertNil(ChangelogInput.entry(subject: "refactor: split Store", date: "d"))
        XCTAssertNil(ChangelogInput.entry(subject: "feat(verify): park idle simulators", date: "d"))
        XCTAssertNil(ChangelogInput.entry(subject: "Add Learn tab", date: "d"))
    }

    func testTheStreamFromTheScriptBuildsReleasesAndDropsEmptyOnes() {
        let changelog = ChangelogInput.parse(
            """
            R\t1.5\t2026-11-08
            C\t2026-11-08\tfeat: a: with colon
            C\t2026-11-07\tchore: tidy
            R\t1.4\t2026-11-07
            C\t2026-11-07\tchore: bump version to 1.4
            """)
        XCTAssertEqual(
            changelog,
            Changelog(releases: [
                .init(
                    version: "1.5", date: "2026-11-08",
                    entries: [.init(kind: .feature, text: "A: with colon", date: "2026-11-08")])
            ]))
    }

    func testTheShippedChangelogDecodesNewestFirst() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("FFive/Changelog.json")
        let shipped = try Changelog.decode(Data(contentsOf: url))
        XCTAssertFalse(shipped.releases.isEmpty)
        let versions = shipped.releases.map(\.version)
        XCTAssertEqual(versions, versions.sorted { Changelog.compare($0, $1) == .orderedDescending })
    }
}
