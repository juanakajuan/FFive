import FFiveCore
import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        @Bindable var settings = store.settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(text: "Units")
                OutlinedGroup {
                    ForEach(Array(WeightUnit.allCases.enumerated()), id: \.element) { index, option in
                        if index > 0 { divider }
                        unitRow(option)
                    }
                }
                Text(
                    "New prescriptions use this unit and its smallest jump: 5 lb, or 2.5 kg (2 kg for dumbbells). Loads you already logged keep their numbers and aren't converted."
                )
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)

                SectionHeading(text: "Equipment")
                    .padding(.top, 20)
                OutlinedGroup {
                    ForEach(Array(Equipment.allCases.enumerated()), id: \.element) { index, option in
                        if index > 0 { divider }
                        equipmentRow(option)
                    }
                }
                Text(
                    "The Exercises tab and the exercise picker show only exercises for the equipment you have. Custom exercises always show."
                )
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)

                SectionHeading(text: "Workout")
                    .padding(.top, 20)
                OutlinedGroup {
                    Toggle("Auto-Match Weights", isOn: $settings.autoMatchWeights)
                        .tint(Theme.success)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .a11y(.settingsAutoMatch)
                }
                Text(
                    "Changing a set's weight changes every later unlogged set of that exercise that had the same weight."
                )
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
        .sensoryFeedback(.selection, trigger: store.settings.weightUnit)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 12)
    }

    private func unitRow(_ option: WeightUnit) -> some View {
        let selected = option == store.settings.weightUnit
        let title = "\(option.label) (\(option.rawValue))"
        return Button {
            store.settings.weightUnit = option
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
        .a11y(.settingsUnit, key: option.rawValue)
    }

    private func equipmentRow(_ option: Equipment) -> some View {
        let selected = store.settings.equipment.contains(option)
        return Button {
            store.settings.toggle(option)
        } label: {
            HStack {
                Text(option.displayName).font(Theme.body).foregroundStyle(Theme.text)
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
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .a11y(.settingsEquipment, key: option.rawValue)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
        .environment(Store(inMemory: true))
}
