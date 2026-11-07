import CoreData
import Foundation
import OSLog
import SwiftData

/// The CloudKit record fields the store mirrors to, derived from the SwiftData models.
/// `cloudkit/schema-fields.txt` holds the same list, and `scripts/cloudkit-schema.sh` checks a
/// CloudKit environment against that file before a release.
enum CloudKitSchema {
    static let containerID = "iCloud.com.juanix.FFive"

    /// One `RecordType.field` line per field, sorted. Core Data mirrors each entity to a `CD_` record
    /// type, each attribute and to-one relationship to a `CD_` field, and to-many relationships to nothing.
    static var fields: [String] {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: AppStore.models)
        else { return [] }
        return model.entities.flatMap { entity -> [String] in
            let type = "CD_\(entity.name ?? "")"
            let attributes = entity.attributesByName.keys
            let toOne = entity.relationshipsByName.filter { !$0.value.isToMany }.keys
            return (["entityName"] + attributes + toOne).map { "\(type).CD_\($0)" }
        }
        .sorted()
    }

    /// Debug builds push the schema to the Development environment whenever the models change, so a
    /// field reaches CloudKit before any feature has to write it. Production only takes fields that
    /// Development has, deployed from the CloudKit Console.
    static func pushToDevelopmentIfChanged(storeURL: URL) {
        #if DEBUG
            let log = Logger(subsystem: "com.juanix.FFive", category: "CloudKitSchema")
            let fingerprint = fields.joined(separator: "\n")
            let marker = storeURL.appendingPathExtension("cloudkit-schema")
            guard (try? String(contentsOf: marker, encoding: .utf8)) != fingerprint else { return }
            do {
                try push(storeURL: storeURL)
                try fingerprint.write(to: marker, atomically: true, encoding: .utf8)
                log.info("Pushed the CloudKit schema to Development")
            } catch {
                log.error("Could not push the CloudKit schema to Development: \(error)")
            }
        #endif
    }

    private static func push(storeURL: URL) throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: AppStore.models)
        else { return }
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
        description.shouldAddStoreAsynchronously = false
        let container = NSPersistentCloudKitContainer(name: "FFive", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        defer {
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        try container.initializeCloudKitSchema()
    }
}
