import SwiftUI

struct ExercisePickerView: View {
    var onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ForEach(ExerciseLibrary.groups, id: \.name) { group in
                        Section(group.name) {
                            ForEach(group.exercises, id: \.self, content: row)
                        }
                    }
                } else {
                    if !ExerciseLibrary.all.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) {
                        Button { pick(query) } label: {
                            Label("Add \"\(query)\"", systemImage: "plus.circle.fill")
                        }
                    }
                    ForEach(ExerciseLibrary.all.filter { $0.localizedCaseInsensitiveContains(query) },
                            id: \.self, content: row)
                }
            }
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search or create exercise")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ name: String) -> some View {
        Button { pick(name) } label: {
            Text(name).foregroundStyle(.primary)
        }
    }

    private func pick(_ name: String) {
        onPick(name)
        dismiss()
    }
}
