import SwiftUI

// The controls #184 found silent: a settings toggle, a menu picker, and filter-menu toggles.
struct SettingsAndFiltersView: View {
    @State private var autoMatch = false
    @State private var selectedMeso = 0
    @State private var showHidden = false
    @State private var muscle: Int? = nil

    var body: some View {
        VStack {
            Toggle("Auto-Match Weights", isOn: $autoMatch)
                .tint(Theme.success)
                .groupRow()
            Picker("Mesocycle", selection: $selectedMeso) {
                ForEach(0..<3) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Theme.text)
            FilterBar(label: "Filters") {
                Picker("Muscle", selection: $muscle) {
                    Text("All").tag(Int?.none)
                }
                .pickerStyle(.menu)
                Toggle("Show Hidden", isOn: $showHidden)
            }
            .sensoryFeedback(.selection, trigger: muscle)
        }
    }
}
