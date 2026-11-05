import FFiveCore
import SwiftUI

struct ExercisesView: View {
    @Environment(Store.self) private var store

    @State private var search = ""
    @State private var muscle: Muscle?

    var body: some View {
        let listings = store.library(muscle: muscle, search: search)
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    SearchBox(text: $search)
                        .a11y(.exercisesSearch)
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
                            .a11y(.exercisesRow, key: listing.name)
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
    let store = Store(inMemory: true)
    return ExercisesView()
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}
