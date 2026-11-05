import SwiftUI
import SwiftData
import FFiveCore

struct ExercisePickerView: View {
    var title = "Add Exercise"
    var muscle: Muscle?
    var onPick: (String, Muscle) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var logged: [Exercise]
    @State private var search = ""

    private struct Entry: Identifiable {
        let name: String
        let muscle: Muscle
        let detail: String
        var id: String { name.lowercased() }
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private var entries: [Entry] {
        var result = ExerciseCatalog.all.map { Entry(name: $0.name, muscle: $0.muscle, detail: $0.equipment.displayName) }
        var seen = Set(result.map(\.id))
        for exercise in logged {
            guard let muscle = exercise.muscleRaw.flatMap(Muscle.init(rawValue:)),
                  seen.insert(exercise.name.lowercased()).inserted else { continue }
            result.append(Entry(name: exercise.name, muscle: muscle, detail: "Custom"))
        }
        return result
            .filter { muscle == nil || $0.muscle == muscle }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        let entries = entries
        NavigationStack {
            VStack(spacing: 0) {
                SearchBox(prompt: "Search or create exercise", text: $search)
                    .accessibilityAddTraits(.isSearchField)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 12)
                List {
                    if !query.isEmpty && !entries.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) {
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
                }
            }
        }
    }

    private func row(_ entry: Entry) -> some View {
        Button { pick(entry.name, entry.muscle) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 4) {
                        MuscleDotLabel(muscle: entry.muscle)
                        Text("\u{2022} \(entry.detail)")
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
        .accessibilityLabel("\(entry.name), \(entry.detail)")
        .accessibilityValue(entry.muscle.displayName)
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
