import SwiftUI
import SwiftData
import FFiveCore

/// One exercise in the library: a catalog entry, or a custom one the lifter has logged.
struct ExerciseListing: Hashable, Identifiable {
    let id: ExerciseID
    let name: String
    let muscle: Muscle
    let info: ExerciseInfo?

    var equipment: String { info?.equipment.displayName ?? "Custom" }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ExercisesView: View {
    @Query private var logged: [Exercise]

    @State private var search = ""
    @State private var muscle: Muscle?

    /// Catalog exercises plus custom ones the lifter has logged with a muscle, as in the exercise picker.
    private var listings: [ExerciseListing] {
        var result = ExerciseCatalog.all.map { ExerciseListing(id: $0.id, name: $0.name, muscle: $0.muscle, info: $0) }
        var seen = Set(result.map(\.id))
        for exercise in logged {
            guard let muscle = exercise.muscle, seen.insert(exercise.key).inserted else { continue }
            result.append(ExerciseListing(id: exercise.key, name: exercise.name, muscle: muscle, info: nil))
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        return result
            .filter { muscle == nil || $0.muscle == muscle }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let listings = listings
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    SearchBox(text: $search)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 12)
                    FilterBar(label: muscle?.displayName ?? "Filters") {
                        Picker("Muscle", selection: $muscle) {
                            Text("All").tag(Muscle?.none)
                            ForEach(Muscle.allCases) { Text($0.displayName).tag(Muscle?.some($0)) }
                        }
                    }
                    if listings.isEmpty {
                        Text("No exercises match.")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                            .padding(Theme.gutter * 2)
                    }
                    ForEach(listings) { listing in
                        NavigationLink(value: listing) { row(listing) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .background(Theme.surface)
            .screenHeader("Exercises")
            .navigationDestination(for: ExerciseListing.self) { ExerciseDetailView(listing: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }

    private func row(_ listing: ExerciseListing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                HStack(spacing: 4) {
                    MuscleDotLabel(muscle: listing.muscle)
                    Text("•")
                    Text(listing.equipment)
                }
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 73)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

#Preview {
    ExercisesView()
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
