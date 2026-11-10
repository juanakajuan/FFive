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
    @State private var performedOnly = false
    @State private var suggested: ExerciseListing?
    @State private var detail: ExerciseListing?

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let settings = store.settings
        let all = store.library(muscle: muscle, equipment: nil, search: search, performedOnly: performedOnly)
        let entries = all.filter { !equipmentOnly || $0.fits(settings.equipment) }
        let groups = Dictionary(grouping: entries, by: \.muscle)
        let queryID = ExerciseID(folding: query)
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
                Button {
                    performedOnly.toggle()
                } label: {
                    HStack {
                        Text("Only exercises I\u{2019}ve performed")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Image(systemName: performedOnly ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(performedOnly ? Theme.infoText : Theme.secondary)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(performedOnly ? .isSelected : [])
                .padding(.bottom, 4)
                .a11y(.pickerPerformedOnly)
                if let suggested {
                    suggestionCard(suggested, lastPerformed: lastPerformed[suggested.id])
                }
                List {
                    if entries.isEmpty && !all.isEmpty {
                        Text("Only exercises for equipment you don\u{2019}t have match.")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                            .themedRow(vertical: 8)
                            .listRowSeparator(.hidden)
                    }
                    if !query.isEmpty && store.listing(queryID) == nil {
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
                    ForEach(Muscle.allCases) { group in
                        if let rows = groups[group] {
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
                    if performedOnly {
                        EmptyState(
                            "No exercises performed yet",
                            systemImage: "clock.arrow.circlepath",
                            message: "Exercises show here once you log a set of them in a finished workout.")
                    } else {
                        EmptyState(
                            "Search to add an exercise",
                            systemImage: "magnifyingglass",
                            message: "Type a name to create your own exercise.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.pickerCancel)
                }
                if let muscle {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Suggest", systemImage: "sparkles") {
                            suggested = ExerciseListing.suggestion(
                                after: suggested?.id,
                                in: store.library(muscle: muscle, equipment: nil, search: ""),
                                muscle: muscle, equipment: settings.equipment, lastPerformed: lastPerformed)
                        }
                        .a11y(.pickerSuggest)
                    }
                }
            }
            .navigationDestination(item: $detail) { ExerciseDetailView(listing: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: $creating) {
                CustomExerciseEditor(draft: CustomExerciseDraft(name: query, muscle: muscle ?? .chest)) { saved in
                    pick(saved.name, saved.muscle)
                }
            }
        }
    }

    private func row(_ entry: ExerciseListing, lastPerformed: Date?) -> some View {
        HStack(spacing: 4) {
            pickButton(entry, lastPerformed: lastPerformed)
            Button {
                searchFocused = false
                detail = entry
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.infoText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entry.name) details")
            .a11y(.pickerDetail, key: entry.name)
        }
    }

    private func pickButton(_ entry: ExerciseListing, lastPerformed: Date?) -> some View {
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

    private func suggestionCard(_ entry: ExerciseListing, lastPerformed: Date?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested")
                    .font(Theme.tag)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.infoText)
                Text(entry.name)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Text(
                    [entry.equipment, lastPerformed.map { "last performed \($0.formatted(.lastPerformed))" }]
                        .compactMap(\.self).joined(separator: " \u{2022} ")
                )
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button {
                pick(entry.name, entry.muscle)
            } label: {
                Text("Add")
                    .font(Theme.columnHeader)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(entry.name)")
            .a11y(.pickerSuggestionAdd)
        }
        .padding(Theme.rowInset)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
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

    /// The day of a session in an exercise's history, such as "Tue, Mar 3, 2026".
    static var sessionDay: Date.FormatStyle { .dateTime.weekday(.abbreviated).month(.abbreviated).day().year() }
}
