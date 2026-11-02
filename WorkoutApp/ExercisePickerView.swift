import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    var title = "Add Exercise"
    /// Limits the list to one muscle, as when swapping an exercise for another that trains the same thing.
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

    /// Catalog exercises plus custom ones the lifter has logged with a muscle.
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
            List {
                if !query.isEmpty && !entries.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) {
                    Section {
                        createRow
                    } footer: {
                        Text("Custom exercises need the muscle they train so volume and progression can count them.")
                    }
                }
                ForEach(muscle.map { [$0] } ?? Muscle.allCases) { group in
                    let rows = entries.filter { $0.muscle == group }
                    if !rows.isEmpty {
                        Section(group.displayName) {
                            ForEach(rows) { entry in
                                Button { pick(entry.name, entry.muscle) } label: {
                                    HStack {
                                        Text(entry.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .tint(.primary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty && query.isEmpty {
                    ContentUnavailableView("Search to add an exercise",
                                           systemImage: "magnifyingglass",
                                           description: Text("Type a name to create your own, then choose the muscle it trains."))
                }
            }
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search or create exercise")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var createRow: some View {
        let label = Label("Create \u{201C}\(query)\u{201D}", systemImage: "plus.circle.fill")
        if let muscle {
            Button { pick(query, muscle) } label: { label }
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
