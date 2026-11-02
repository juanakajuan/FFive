import SwiftUI

struct SettingsView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Picker("Weight Unit", selection: $unit) {
                    ForEach(WeightUnit.allCases) { Text("\($0.label) (\($0.rawValue))").tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Units")
            } footer: {
                Text("New prescriptions use this unit and its smallest jump: 5 lb, or 2.5 kg (2 kg for dumbbells). Loads you already logged keep their numbers and aren't converted.")
            }

            Section("About") {
                LabeledContent("Version", value: version)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
}
