import CloudKit
import Foundation
import SwiftData
import XCTest

@testable import FFiveCore

final class CloudKitSchemaTests: XCTestCase {
    func testSchemaOpensWithCloudKitMirroring() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "cloudkit-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let configuration = ModelConfiguration(
            schema: AppStore.schema, url: url, cloudKitDatabase: .private("iCloud.com.juanix.FFive"))
        XCTAssertNoThrow(
            try ModelContainer(for: AppStore.schema, configurations: configuration),
            "CloudKit refuses a non-optional relationship or an attribute with no default")
    }

    func testStatusFollowsAccountThenEvents() {
        var state = SyncState()
        XCTAssertEqual(state.status, .checking)

        state.account = .noAccount
        XCTAssertEqual(state.status, .noAccount)

        state.account = .available
        XCTAssertEqual(state.status, .upToDate(lastSync: nil), "no sync has finished yet this launch")

        let setup = UUID()
        let export = UUID()
        state.started(setup)
        state.started(export)
        XCTAssertEqual(state.status, .syncing)

        let done = Date(timeIntervalSince1970: 1_000)
        state.finished(setup, at: done, error: nil)
        XCTAssertEqual(state.status, .syncing, "syncing until every running event ends")

        state.finished(export, at: done, error: CKError(.quotaExceeded))
        XCTAssertEqual(state.status, .failed(.storageFull))

        let retry = UUID()
        state.started(retry)
        state.finished(retry, at: done + 60, error: nil)
        XCTAssertEqual(state.status, .upToDate(lastSync: done + 60), "a later success clears the failure")
    }

    func testNetworkErrorsReadAsOffline() {
        XCTAssertEqual(SyncFailure(CKError(.networkUnavailable)), .offline)
        XCTAssertEqual(SyncFailure(CKError(.networkFailure)), .offline)
    }
}
