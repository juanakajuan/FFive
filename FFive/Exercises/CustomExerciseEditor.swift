import FFiveCore
import SwiftUI

/// Creates a custom exercise, or with `editing` changes one. Calls `onSaved` with what was saved.
struct CustomExerciseEditor: View {
    var editing: CustomExercise?
    var onSaved: (CustomExerciseDraft) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @State private var draft: CustomExerciseDraft
    @State private var cue: String
    @State private var minReps: Int
    @State private var maxReps: Int
    @State private var nameTaken = false

    init(
        draft: CustomExerciseDraft, editing: CustomExercise? = nil,
        onSaved: @escaping (CustomExerciseDraft) -> Void = { _ in }
    ) {
        self.editing = editing
        self.onSaved = onSaved
        _draft = State(initialValue: draft)
        _cue = State(initialValue: draft.cue ?? "")
        _minReps = State(initialValue: draft.repRange.lowerBound)
        _maxReps = State(initialValue: draft.repRange.upperBound)
    }

    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("Name").foregroundStyle(Theme.secondary))
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                        .onChange(of: draft.name) { nameTaken = false }
                        .a11y(.editorName)
                    if nameTaken {
                        Text("Another exercise already has this name. It may be hidden.")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.danger)
                    }
                } header: {
                    header("Name")
                }
                Section {
                    Picker("Muscle", selection: $draft.muscle) {
                        ForEach(Muscle.allCases) { Text($0.displayName).tag($0) }
                    }
                    .a11y(.editorMuscle)
                    Picker("Equipment", selection: $draft.equipment) {
                        ForEach(Equipment.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .a11y(.editorEquipment)
                } header: {
                    header("Trains")
                } footer: {
                    Text("Muscle drives volume. Equipment sets how load steps up and whether body weight counts.")
                        .font(Theme.caption)
                }
                Section {
                    Stepper("Min \(minReps) reps", value: $minReps, in: 1...maxReps)
                    Stepper("Max \(maxReps) reps", value: $maxReps, in: minReps...50)
                } header: {
                    header("Rep range")
                }
                Section {
                    TextField(
                        "Cue", text: $cue, prompt: Text("Optional").foregroundStyle(Theme.secondary), axis: .vertical
                    )
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1...4)
                    .a11y(.editorCue)
                } header: {
                    header("Cue")
                }
            }
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .scrollContentBackground(.hidden)
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
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(Theme.tag)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
    }

    private func save() {
        var result = draft
        result.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.cue = cue
        result.repRange = minReps...maxReps
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
