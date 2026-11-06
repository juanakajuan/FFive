import FFiveCore
import SwiftUI

struct ExercisesView: View {
    @Environment(Store.self) private var store

    @State private var search = ""
    @State private var muscle: Muscle?
    @State private var equipment: Equipment?

    var body: some View {
        let listings = store.library(muscle: muscle, equipment: equipment, search: search)
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
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
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    SearchBox(text: $search)
                        .a11y(.exercisesSearch)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 12)
                    FilterBar(label: filterLabel) {
                        Picker("Muscle", selection: $muscle) {
                            Text("All").tag(Muscle?.none)
                            ForEach(Muscle.allCases) { Text($0.displayName).tag(Muscle?.some($0)) }
                        }
                        .pickerStyle(.menu)
                        Picker("Equipment", selection: $equipment) {
                            Text("All").tag(Equipment?.none)
                            ForEach(Equipment.allCases, id: \.self) { Text($0.displayName).tag(Equipment?.some($0)) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .background(Theme.surface)
            }
            .background(Theme.surface)
            .screenHeader("Exercises")
            .navigationDestination(for: ExerciseListing.self) { ExerciseDetailView(listing: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }

    private var filterLabel: String {
        let names = [muscle?.displayName, equipment?.displayName].compactMap { $0 }
        return names.isEmpty ? "Filters" : names.joined(separator: " \u{00B7} ")
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
