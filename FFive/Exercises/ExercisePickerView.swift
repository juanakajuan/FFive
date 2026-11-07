import FFiveCore
import SwiftUI

struct ExercisePickerView: View {
    var title = "Add Exercise"
    var muscle: Muscle?
    var onPick: (String, Muscle) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @State private var search = ""
    @State private var creating = false
    @FocusState private var searchFocused: Bool
    @State private var equipmentOnly = true

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let settings = store.settings
        let all = store.library(muscle: muscle, equipment: nil, search: search)
        let entries = all.filter { !equipmentOnly || !settings.filtersEquipment || $0.fits(settings.equipment) }
        let lastPerformed = store.lastPerformed()
        NavigationStack {
            VStack(spacing: 0) {
                SearchBox(prompt: "Search or create exercise", text: $search)
                    .focused($searchFocused)
                    .accessibilityAddTraits(.isSearchField)
                    .a11y(.pickerSearch)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, settings.filtersEquipment ? 0 : 12)
                if settings.filtersEquipment {
                    EquipmentScopeToggle(isOn: $equipmentOnly)
                        .padding(.bottom, 4)
                }
                List {
                    if entries.isEmpty && !all.isEmpty {
                        Text("Only exercises for equipment you don\u{2019}t have match.")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                            .themedRow(vertical: 8)
                            .listRowSeparator(.hidden)
                    }
                    if !query.isEmpty && !all.contains(where: { $0.id == ExerciseID(folding: query) }) {
                        createRow
                            .themedRow()
                        Text(
                            "Custom exercises need a muscle, equipment and a rep range so volume and progression can count them."
                        )
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                        .themedRow(vertical: 8)
                        .listRowSeparator(.hidden)
                    }
                    ForEach(muscle.map { [$0] } ?? Muscle.allCases) { group in
                        let rows = entries.filter { $0.muscle == group }
                        if !rows.isEmpty {
                            Section {
                                ForEach(rows) { entry in
                                    row(entry, lastPerformed: lastPerformed[entry.id]).themedRow()
                                }
                            } header: {
                                Text(group.displayName)
                                    .font(Theme.tag)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.secondary)
                                    .padding(.horizontal, Theme.gutter)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.raised)
                                    .listRowInsets(EdgeInsets())
                            }
                        }
                    }
                }
                .themedList()
                .scrollDismissesKeyboard(.immediately)
            }
            .background(Theme.surface)
            .overlay {
                if entries.isEmpty && query.isEmpty {
                    ContentUnavailableView(
                        "Search to add an exercise",
                        systemImage: "magnifyingglass",
                        description: Text("Type a name to create your own exercise."))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.pickerCancel)
                }
            }
            .sheet(isPresented: $creating) {
                CustomExerciseEditor(draft: CustomExerciseDraft(name: query, muscle: muscle ?? .chest)) { saved in
                    pick(saved.name, saved.muscle)
                }
            }
        }
    }

    private func row(_ entry: ExerciseListing, lastPerformed: Date?) -> some View {
        Button {
            pick(entry.name, entry.muscle)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 4) {
                        MuscleDotLabel(muscle: entry.muscle)
                        Text("\u{2022} \(entry.equipment)")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                    if let lastPerformed {
                        Text("Last performed \(lastPerformed.formatted(.lastPerformed))")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.name), \(entry.equipment)")
        .accessibilityValue(
            [entry.muscle.displayName, lastPerformed.map { "last performed \($0.formatted(.lastPerformed))" }]
                .compactMap(\.self).joined(separator: ", ")
        )
        .a11y(.pickerRow, key: entry.name)
    }

    private var createRow: some View {
        Button {
            searchFocused = false
            creating = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.infoText)
                Text("Create \u{201C}\(query)\u{201D}")
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ name: String, _ muscle: Muscle) {
        onPick(name, muscle)
        dismiss()
    }
}

extension FormatStyle where Self == Date.FormatStyle {
    /// The day an exercise was last done, such as "Mar 3, 2026".
    static var lastPerformed: Date.FormatStyle { .dateTime.month(.abbreviated).day().year() }
}
