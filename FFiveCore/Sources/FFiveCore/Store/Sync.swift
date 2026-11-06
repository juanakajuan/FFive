import CloudKit
import CoreData
import Foundation
import Observation

/// What Settings says about iCloud sync.
public enum SyncStatus: Equatable {
    /// The demo store lives in memory and never syncs.
    case off
    case checking
    case noAccount
    case unavailable
    case syncing
    /// Nil until the first sync this launch finishes.
    case upToDate(lastSync: Date?)
    case failed(SyncFailure)
}

public enum SyncFailure: Equatable {
    case storageFull
    case offline
    case other(String)

    init(_ error: any Error) {
        switch (error as? CKError)?.code {
        case .quotaExceeded: self = .storageFull
        case .networkUnavailable, .networkFailure: self = .offline
        default: self = .other(error.localizedDescription)
        }
    }
}

/// The facts sync status is made from: the iCloud account, and the import, export and setup events the store reports.
struct SyncState: Equatable {
    enum Account: Equatable {
        case unknown, available, noAccount, unavailable
    }

    var account = Account.unknown
    var running: Set<UUID> = []
    var lastSync: Date?
    var failure: SyncFailure?

    mutating func started(_ id: UUID) {
        running.insert(id)
    }

    mutating func finished(_ id: UUID, at date: Date, error: (any Error)?) {
        running.remove(id)
        if let error {
            failure = SyncFailure(error)
        } else {
            failure = nil
            lastSync = date
        }
    }

    var status: SyncStatus {
        switch account {
        case .unknown: return .checking
        case .noAccount: return .noAccount
        case .unavailable: return .unavailable
        case .available:
            if !running.isEmpty { return .syncing }
            if let failure { return .failed(failure) }
            return .upToDate(lastSync: lastSync)
        }
    }
}

@MainActor
@Observable
public final class SyncMonitor {
    private var state = SyncState()
    private let enabled: Bool
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    public var status: SyncStatus { enabled ? state.status : .off }

    /// A disabled monitor never touches CloudKit, which traps in a build without the iCloud entitlement.
    public init(enabled: Bool) {
        self.enabled = enabled
        guard enabled else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard
                    let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { return }
                MainActor.assumeIsolated { self?.record(event) }
            },
            center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshAccount() }
            },
        ]
        refreshAccount()
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        if let end = event.endDate {
            state.finished(event.identifier, at: end, error: event.succeeded ? nil : event.error)
        } else {
            state.started(event.identifier)
        }
    }

    private func refreshAccount() {
        Task {
            let account: SyncState.Account
            switch try? await CKContainer.default().accountStatus() {
            case .available: account = .available
            case .noAccount: account = .noAccount
            default: account = .unavailable
            }
            state.account = account
        }
    }
}
