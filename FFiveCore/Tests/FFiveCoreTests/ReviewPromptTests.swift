import Foundation
import XCTest

@testable import FFiveCore

@MainActor
final class ReviewPromptTests: XCTestCase {
    let suite = "ReviewPromptTests-\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testAsksOnlyAfterAFinishedBlockAndOnlyOnce() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(finishedBlocks: 0, alreadyAsked: false), "no finished block yet")
        XCTAssertTrue(ReviewPrompt.shouldAsk(finishedBlocks: 1, alreadyAsked: false))
        XCTAssertFalse(ReviewPrompt.shouldAsk(finishedBlocks: 2, alreadyAsked: true), "it never asks twice")
    }

    func testStoreClaimsThePromptOnceAfterTheFirstBlockEndsAndRemembersIt() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = Store(inMemory: true, settings: Settings(defaults: defaults))
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)])]

        try store.startMesocycle(draft)
        XCTAssertFalse(store.takeReviewPrompt(), "a block still running does not ask")

        let first = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        store.endMesocycle(first)
        XCTAssertTrue(store.takeReviewPrompt(), "the first finished block asks")
        XCTAssertFalse(store.takeReviewPrompt(), "and only once")

        try store.startMesocycle(draft)
        store.endMesocycle(try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
        XCTAssertFalse(store.takeReviewPrompt(), "a later block does not ask again")
        XCTAssertFalse(
            Store(inMemory: true, settings: Settings(defaults: defaults)).takeReviewPrompt(),
            "the flag survives a relaunch")
        XCTAssertTrue(defaults.bool(forKey: "reviewRequested"))
    }
}
