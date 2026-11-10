import FFiveCore
import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(SyncMonitor.self) private var sync
    @Environment(AppRouter.self) private var router
    @State private var confirmDeleteAll = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        @Bindable var settings = store.settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(text: "Units")
                GroupedCard {
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
                .padding(.top, 8)

                SectionHeading(text: "Appearance")
                GroupedCard {
                    ForEach(Array(Appearance.allCases.enumerated()), id: \.element) { index, option in
                        if index > 0 { divider }
                        appearanceRow(option)
                    }
                }
                Text("System follows the iPhone's Light or Dark setting.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                SectionHeading(text: "Equipment")
                GroupedCard {
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
                .padding(.top, 8)

                SectionHeading(text: "Workout")
                GroupedCard {
                    Toggle("Auto-Match Weights", isOn: $settings.autoMatchWeights)
                        .tint(Theme.success)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .frame(minHeight: 44)
                        .a11y(.settingsAutoMatch)
                }
                Text(
                    "Changing a set's weight changes every later unlogged set of that exercise that had the same weight."
                )
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

                SectionHeading(text: "iCloud Sync")
                GroupedCard {
                    syncRow
                }
                Text(
                    "Workouts, mesocycles, templates, custom exercises and notes sync through your private iCloud account to every device signed in to the same Apple ID. The settings on this screen stay on this device."
                )
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

                SectionHeading(text: "Data")
                GroupedCard {
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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .a11y(.settingsExport)
                    divider
                    Button {
                        confirmDeleteAll = true
                    } label: {
                        HStack {
                            Text("Delete All Data").font(Theme.body).foregroundStyle(Theme.danger)
                            Spacer()
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .a11y(.settingsDeleteAll)
                }
                Text(
                    "Export saves every mesocycle, workout, set, feedback entry, custom exercise, template and pinned note to a JSON file. Delete All Data removes them from this iPhone and iCloud, and resets these settings."
                )
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

                SectionHeading(text: "About")
                GroupedCard {
                    LabeledContent("Version", value: version)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .frame(minHeight: 44)
                }
            }
            .padding([.horizontal, .bottom], Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("Settings")
        .sensoryFeedback(.selection, trigger: store.settings.weightUnit)
        .sensoryFeedback(.selection, trigger: store.settings.appearance)
        .confirmationDialog("Delete all data?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) { router.deleteAllData(store: store) }
                .a11y(.dialogDeleteAllData)
        } message: {
            Text(
                "Every mesocycle, workout, custom exercise, template and note is removed from this iPhone and from iCloud, and settings are reset. This can't be undone, so export your training data first if you want a copy."
            )
        }
    }

    private var syncRow: some View {
        let (title, detail, symbol, tint): (String, Text?, String, Color) =
            switch sync.status {
            case .off: ("Off", Text("Sample data stays on this device."), "icloud.slash", Theme.secondary)
            case .checking: ("Checking iCloud", nil, "icloud", Theme.secondary)
            case .noAccount:
                (
                    "Sign In to iCloud", Text("Sign in from the Settings app to back up and sync."), "icloud.slash",
                    Theme.secondary
                )
            case .unavailable:
                ("iCloud Unavailable", Text("Check iCloud in the Settings app."), "icloud.slash", Theme.secondary)
            case .syncing: ("Syncing", nil, "arrow.triangle.2.circlepath.icloud", Theme.infoText)
            case .upToDate(let date):
                ("On", date.map { Text("Synced \($0, style: .relative) ago") }, "checkmark.icloud", Theme.success)
            case .failed(.offline):
                ("Offline", Text("Changes sync when you're back online."), "icloud.slash", Theme.secondary)
            case .failed(.storageFull):
                (
                    "iCloud Storage Full", Text("Free up iCloud storage to keep syncing."), "exclamationmark.icloud",
                    Theme.danger
                )
            case .failed(.other(let message)): ("Sync Paused", Text(message), "exclamationmark.icloud", Theme.danger)
            }
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body).foregroundStyle(Theme.text)
                if let detail {
                    detail.font(Theme.detail).foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            if sync.status == .syncing || sync.status == .checking {
                ProgressView()
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .a11y(.settingsSync)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
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
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .a11y(.settingsUnit, key: option.rawValue)
    }

    private func appearanceRow(_ option: Appearance) -> some View {
        let selected = option == store.settings.appearance
        return Button {
            store.settings.appearance = option
        } label: {
            HStack {
                Text(option.label).font(Theme.body).foregroundStyle(Theme.text)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.infoText)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .a11y(.settingsAppearance, key: option.rawValue)
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
        .environment(AppRouter())
}
