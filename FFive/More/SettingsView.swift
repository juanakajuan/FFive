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

                SectionHeading(text: "Data")
                    .padding(.top, 20)
                OutlinedGroup {
                    ShareLink(
                        item: TrainingExportFile(store: store),
                        preview: SharePreview(TrainingExportFile.fileName(on: .now))
                    ) {
                        HStack {
                            Text("Export Training Data").font(Theme.body).foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.infoText)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .a11y(.settingsExport)
                }
                Text(
                    "Saves every mesocycle, workout, set, feedback entry, custom exercise, template and pinned note to a JSON file."
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

/// Builds the JSON only when the share sheet asks for it, so opening Settings costs nothing.
private struct TrainingExportFile: Transferable {
    let store: Store

    static func fileName(on date: Date) -> String {
        "FFive Export \(date.formatted(.iso8601.year().month().day())).json"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try await file.store.exportJSON()
            let url = URL.temporaryDirectory.appending(path: fileName(on: .now))
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .preferredColorScheme(.dark)
        .environment(Store(inMemory: true))
}
