import Foundation
import SwiftData

@Model
public final class MesoDay {
    public var name: String = ""
    public var order: Int = 0
    var weekdayRaw: String?
    public internal(set) var mesocycle: Mesocycle?
    @Relationship(deleteRule: .cascade, originalName: "slots", inverse: \DaySlot.day)
    var storedSlots: [DaySlot]?

    public var slots: [DaySlot] {
        get { storedSlots ?? [] }
        set { storedSlots = newValue }
    }

    init(name: String, order: Int, weekday: Weekday? = nil) {
        self.name = name
        self.order = order
        self.weekdayRaw = weekday?.rawValue
    }

    public internal(set) var weekday: Weekday? {
        get { weekdayRaw.flatMap(Weekday.init(rawValue:)) }
        set { weekdayRaw = newValue?.rawValue }
    }

    var sortedSlots: [DaySlot] { slots.sorted { $0.order < $1.order } }
}
