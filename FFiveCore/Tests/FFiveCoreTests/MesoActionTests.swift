import XCTest

@testable import FFiveCore

@MainActor
final class MesoActionTests: XCTestCase {
    func testActiveBlockMenuOffersEnd() throws {
        let (store, meso) = try startedStore()
        let menu = withExtendedLifetime(store) { MesoAction.menu(for: meso) }
        XCTAssertEqual(menu, [.summary, .rename, .end, .delete])
    }

    func testFinishedBlockMenuLeavesOutEnd() throws {
        let (store, meso) = try startedStore()
        store.endMesocycle(meso)
        let menu = withExtendedLifetime(store) { MesoAction.menu(for: meso) }
        XCTAssertEqual(menu, [.summary, .rename, .delete])
    }
}
