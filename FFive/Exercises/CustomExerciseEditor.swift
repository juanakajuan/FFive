import FFiveCore
import SwiftUI

/// Creates a custom exercise, or with `editing` changes one. Calls `onSaved` with what was saved.
struct CustomExerciseEditor: View {
    let editing: CustomExercise?
    let onSaved: (ExerciseListing) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    private let original: CustomExerciseDraft
    @State private var draft: CustomExerciseDraft
    @State private var nameTaken = false

    init(
        draft: CustomExerciseDraft, editing: CustomExercise? = nil,
        onSaved: @escaping (ExerciseListing) -> Void
    ) {
        self.editing = editing
        self.onSaved = onSaved
        original = draft
        _draft = State(initialValue: draft)
    }

    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
                    Text("Muscle drives volume. Equipment sets how load steps up and whether body weight counts.")
                        .footnote()

                    SectionHeading(text: "Rep range")
                    GroupedCard {
                        Stepper("Min \(draft.minReps) reps", value: $draft.minReps, in: 1...draft.maxReps)
                            .groupRow()
                        Hairline()
                        Stepper("Max \(draft.maxReps) reps", value: $draft.maxReps, in: draft.minReps...50)
                            .groupRow()
                    }

                    SectionHeading(text: "Cue")
                    TextField(
                        "Cue", text: $draft.cue, prompt: Text("Optional").foregroundStyle(Theme.secondary),
                        axis: .vertical
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
        .interactiveDismissDisabled(draft != original)
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

    private func save() {
        do {
            let saved = try store.saveCustomExercise(draft, editing: editing)
            dismiss()
            onSaved(saved)
        } catch {
            nameTaken = true
        }
    }
}
