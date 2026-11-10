import SwiftUI

extension Binding {
    /// True while the optional holds a value. Setting it to false clears the value,
    /// which is how an alert or dialog dismisses itself.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}
