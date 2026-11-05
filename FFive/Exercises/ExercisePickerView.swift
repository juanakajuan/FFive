import SwiftUI
import FFiveCore

struct ExercisePickerView: View {
    var title = "Add Exercise"
    /// Limits the list to one muscle, as when swapping an exercise for another that trains the same thing.
    var muscle: Muscle?
    var onPick: (String, Muscle) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let entries = store.library(muscle: muscle, search: search)
        NavigationStack {
            VStack(spacing: 0) {
                SearchBox(prompt: "Search or create exercise", text: $search)
                    .accessibilityAddTraits(.isSearchField)
                    .a11y(.pickerSearch)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 12)
                List {
                    if !query.isEmpty && !entries.contains(where: { $0.id == ExerciseID(folding: query) }) {
                        createRow
                            .themedRow()
                        Text("Custom exercises need the muscle they train so volume and progression can count them.")
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
                                    row(entry).themedRow()
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
                    ContentUnavailableView("Search to add an exercise",
                                           systemImage: "magnifyingglass",
                                           description: Text("Type a name to create your own, then choose the muscle it trains."))
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
        }
    }

    private func row(_ entry: ExerciseListing) -> some View {
        Button { pick(entry.name, entry.muscle) } label: {
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
        .accessibilityValue(entry.muscle.displayName)
        .a11y(.pickerRow, key: entry.name)
    }

    @ViewBuilder
    private var createRow: some View {
        let label = HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.infoText)
            Text("Create \u{201C}\(query)\u{201D}")
                .font(Theme.body)
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        if let muscle {
            Button { pick(query, muscle) } label: { label }
                .buttonStyle(.plain)
        } else {
            Menu {
                Section("Which muscle does it train?") {
                    ForEach(Muscle.allCases) { muscle in
                        Button(muscle.displayName) { pick(query, muscle) }
                    }
                }
            } label: {
                label
            }
        }
    }

    private func pick(_ name: String, _ muscle: Muscle) {
        onPick(name, muscle)
        dismiss()
    }
}
