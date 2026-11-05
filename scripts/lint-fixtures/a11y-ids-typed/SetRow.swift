import SwiftUI

struct SetRow: View {
    @Binding var weight: String

    var body: some View {
        TextField("Weight", text: $weight)
            .accessibilityIdentifier("set.weight.1")
    }
}
