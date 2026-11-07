import SwiftData

extension Store {
    /// Deletes every record of every model and resets settings, leaving the app as a fresh install finds it.
    /// Each record is deleted on its own, not in a batch, so the CloudKit mirror sends a delete for each one and the
    /// iCloud copy goes too. The built-in catalog and templates are code, not records, so they stay.
    public func deleteAllData() {
        for model in AppStore.models { deleteEvery(model) }
        settings.reset()
        commit()
    }

    private func deleteEvery<Model: PersistentModel>(_: Model.Type) {
        for record in (try? context.fetch(FetchDescriptor<Model>())) ?? [] { context.delete(record) }
    }
}
