import Foundation
import SwiftData

@Model
public final class MesoDay {
    public var name: String = ""
    public var order: Int = 0
    public internal(set) var mesocycle: Mesocycle?
    @Relationship(deleteRule: .cascade, originalName: "slots", inverse: \DaySlot.day)
    var storedSlots: [DaySlot]?
    /// A workout note pinned to this day, shown on each of its sessions until it is unpinned.
    public internal(set) var pinnedNote: String?

    public var slots: [DaySlot] {
        get { storedSlots ?? [] }
        set { storedSlots = newValue }
    }

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSlots: [DaySlot] { slots.sorted { $0.order < $1.order } }
}
