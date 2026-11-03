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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: "Units")
                OutlinedGroup {
                    ForEach(Array(WeightUnit.allCases.enumerated()), id: \.element) { index, option in
                        if index > 0 { divider }
                        unitRow(option)
                    }
                }
                Text("New prescriptions use this unit and its smallest jump: 5 lb, or 2.5 kg (2 kg for dumbbells). Loads you already logged keep their numbers and aren't converted.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SectionHeading(text: "About")
                    .padding(.top, 20)
                OutlinedGroup {
                    LabeledContent("Version", value: version)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                }
            }
            .padding(Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("Settings")
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 12)
    }

    private func unitRow(_ option: WeightUnit) -> some View {
        let selected = option == unit
        let title = "\(option.label) (\(option.rawValue))"
        return Button {
            unit = option
        } label: {
            HStack {
                Text(title).font(Theme.body).foregroundStyle(Theme.text)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.infoText)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: unit)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
}
