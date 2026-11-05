import Foundation
import SwiftData

@Model
public final class MesoDay {
    public var name: String = ""
    public var order: Int = 0
    public internal(set) var mesocycle: Mesocycle?
    @Relationship(deleteRule: .cascade, inverse: \DaySlot.day)
    public var slots: [DaySlot] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSlots: [DaySlot] { slots.sorted { $0.order < $1.order } }
}
