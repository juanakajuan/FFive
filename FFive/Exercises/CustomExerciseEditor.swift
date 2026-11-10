import FFiveCore
import SwiftUI

/// Creates a custom exercise, or with `editing` changes one. Calls `onSaved` with what was saved.
struct CustomExerciseEditor: View {
    let editing: CustomExercise?
    let onSaved: (CustomExerciseDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    private let original: CustomExerciseDraft
    @State private var draft: CustomExerciseDraft
    @State private var cue: String
    @State private var minReps: Int
    @State private var maxReps: Int
    @State private var nameTaken = false

    init(
        draft: CustomExerciseDraft, editing: CustomExercise? = nil,
        onSaved: @escaping (CustomExerciseDraft) -> Void
    ) {
        self.editing = editing
        self.onSaved = onSaved
        var original = draft
        original.cue = draft.cue ?? ""
        self.original = original
        _draft = State(initialValue: draft)
        _cue = State(initialValue: draft.cue ?? "")
        _minReps = State(initialValue: draft.repRange.lowerBound)
        _maxReps = State(initialValue: draft.repRange.upperBound)
    }

    private var edited: CustomExerciseDraft {
        var result = draft
        result.cue = cue
        result.repRange = minReps...maxReps
        return result
    }

    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeading(text: "Name")
                    TextField("Name", text: $draft.name, prompt: Text("Name").foregroundStyle(Theme.secondary))
                        .formField()
                        .onChange(of: draft.name) { nameTaken = false }
                        .a11y(.editorName)
                    if nameTaken {
                        Text("Another exercise already has this name. It may be hidden.")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.danger)
                            .padding(.top, 8)
                    }

                    SectionHeading(text: "Trains")
                    GroupedCard {
                        pickerRow("Muscle") {
                            Picker("Muscle", selection: $draft.muscle) {
                                ForEach(Muscle.allCases) { Text($0.displayName).tag($0) }
                            }
                            .a11y(.editorMuscle)
                        }
                        Hairline()
                        pickerRow("Equipment") {
                            Picker("Equipment", selection: $draft.equipment) {
                                ForEach(Equipment.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .a11y(.editorEquipment)
                        }
                    }
                    footnote("Muscle drives volume. Equipment sets how load steps up and whether body weight counts.")

                    SectionHeading(text: "Rep range")
                    GroupedCard {
                        Stepper("Min \(minReps) reps", value: $minReps, in: 1...maxReps)
                            .groupRow()
                        Hairline()
                        Stepper("Max \(maxReps) reps", value: $maxReps, in: minReps...50)
                            .groupRow()
                    }

                    SectionHeading(text: "Cue")
                    TextField(
                        "Cue", text: $cue, prompt: Text("Optional").foregroundStyle(Theme.secondary), axis: .vertical
                    )
                    .lineLimit(1...4)
                    .formField()
                    .a11y(.editorCue)
                }
                .padding([.horizontal, .bottom], Theme.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.page)
            .navigationTitle(editing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.editorCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .a11y(.editorSave)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(edited != original)
    }

    private func pickerRow(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            picker()
                .labelsHidden()
                .tint(Theme.secondary)
        }
        .groupRow()
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.detail)
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    private func save() {
        var result = edited
        result.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.saveCustomExercise(result, editing: editing)
        } catch {
            nameTaken = true
            return
        }
        dismiss()
        onSaved(result)
    }
}

extension View {
    /// One row in a `GroupedCard`, as on Settings.
    fileprivate func groupRow() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.text)
            .frame(minHeight: 44)
    }
}
