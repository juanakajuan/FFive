import FFiveCore
import SwiftUI

struct ExercisesView: View {
    @Environment(Store.self) private var store

    @State private var search = ""
    @State private var muscle: Muscle?
    @State private var equipment: Equipment?
    @State private var showHidden = false
    @State private var performedOnly = false
    @State private var equipmentOnly = true
    @State private var creating = false
    @State private var path = NavigationPath()

    var body: some View {
        let settings = store.settings
        let all = store.library(
            muscle: muscle, equipment: equipment, search: search, includeHidden: showHidden,
            performedOnly: performedOnly)
        let listings = all.filter { !equipmentOnly || !settings.filtersEquipment || $0.fits(settings.equipment) }
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(listings) { listing in
                        NavigationLink(value: listing) { row(listing) }
                            .buttonStyle(.plain)
                            .a11y(.exercisesRow, key: listing.name)
                    }
                }
            }
            .overlay {
                if listings.isEmpty {
                    EmptyState(
                        "No matching exercises", systemImage: "magnifyingglass",
                        message: all.isEmpty
                            ? "Try another name or clear a filter."
                            : "Only exercises for equipment you don\u{2019}t have match. Tap Show All to see every exercise."
                    )
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    SearchBox(text: $search)
                        .a11y(.exercisesSearch)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 12)
                    if settings.filtersEquipment {
                        EquipmentScopeToggle(isOn: $equipmentOnly)
                    }
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
                        Toggle("Show hidden", isOn: $showHidden)
                            .a11y(.exercisesShowHidden)
                        Toggle("Only exercises I\u{2019}ve performed", isOn: $performedOnly)
                            .a11y(.exercisesPerformedOnly)
                    }
                }
                .background(Theme.surface)
            }
            .background(Theme.surface)
            .screenHeader("Exercises") {
                HeaderAddButton(label: "New Exercise") { creating = true }
                    .a11y(.exercisesNew)
            }
            .navigationDestination(for: ExerciseListing.self) { ExerciseDetailView(listing: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: $creating) {
                CustomExerciseEditor(
                    draft: CustomExerciseDraft(name: search, muscle: muscle ?? .chest, equipment: equipment ?? .machine)
                ) { saved in
                    showSaved(saved.name)
                }
            }
        }
    }

    private func showSaved(_ name: String) {
        let match = store.library(muscle: nil, equipment: nil, search: name, includeHidden: true)
            .first { $0.isCustom && $0.name == name }
        if let match { path.append(match) }
    }

    private var filterLabel: String {
        let names = [
            muscle?.displayName, equipment?.displayName, showHidden ? "Hidden" : nil,
            performedOnly ? "Performed" : nil,
        ].compactMap { $0 }
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
                    if listing.isHidden {
                        Text("•")
                        Text("Hidden")
                    }
                }
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            RowChevron()
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
