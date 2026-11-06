import Foundation
import SwiftData

@Model
public final class MesoDay {
    public var name: String = ""
    public var order: Int = 0
    public internal(set) var mesocycle: Mesocycle?
    @Relationship(deleteRule: .cascade, originalName: "slots", inverse: \DaySlot.day)
    var storedSlots: [DaySlot]?

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
