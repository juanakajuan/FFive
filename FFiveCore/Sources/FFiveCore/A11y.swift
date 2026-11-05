import SwiftUI

public enum A11y: String, CaseIterable {
    case tabWorkout = "tab.workout"
    case tabMesos = "tab.mesos"
    case tabTemplates = "tab.templates"
    case tabExercises = "tab.exercises"
    case tabMore = "tab.more"
    case moreProgress = "more.progress"
    case moreLearn = "more.learn"
    case moreSettings = "more.settings"
    case workoutPlan = "workout.plan"
    case workoutQuick = "workout.quick"
    case workoutEnd = "workout.end"
    case workoutSchedule = "workout.schedule"
    case workoutMenu = "workout.menu"
    case workoutFinish = "workout.finish"
    case keyboardDone = "keyboard.done"
    case sheetDone = "sheet.done"
    case menuAddExercise = "menu.add-exercise"
    case menuReorder = "menu.reorder"
    case reorderSave = "reorder.save"
    case reorderCancel = "reorder.cancel"
    case menuSkipDay = "menu.skip-day"
    case menuQuickWorkout = "menu.quick-workout"
    case menuWorkoutNote = "menu.workout-note"
    case menuRename = "menu.rename"
    case menuBodyweight = "menu.bodyweight"
    case menuDiscard = "menu.discard"
    case menuReset = "menu.reset"
    case menuEndMesocycle = "menu.end-mesocycle"
    case menuView = "menu.view"
    case menuSwap = "menu.swap"
    case menuAddSet = "menu.add-set"
    case menuExerciseNote = "menu.exercise-note"
    case menuDeleteNote = "menu.delete-note"
    case menuRemoveExercise = "menu.remove-exercise"
    case menuDeleteSet = "menu.delete-set"
    case menuSkipSet = "menu.skip-set"
    case menuSkipRemaining = "menu.skip-remaining"
    case menuSetType = "menu.set-type"
    case menuJointPain = "menu.joint-pain"
    case dialogEndMesocycle = "dialog.end-mesocycle"
    case dialogDiscard = "dialog.discard"
    case dialogReset = "dialog.reset"
    case dialogTrainDay = "dialog.train-day"
    case exerciseMenu = "exercise.menu"
    case exerciseCue = "exercise.cue"
    case exerciseHistory = "exercise.history"
    case exercisePin = "exercise.pin"
    case setMenu = "set.menu"
    case setWeight = "set.weight"
    case setReps = "set.reps"
    case setLog = "set.log"
    case noteText = "note.text"
    case noteSave = "note.save"
    case noteCancel = "note.cancel"
    case pickerSearch = "picker.search"
    case pickerRow = "picker.row"
    case pickerCancel = "picker.cancel"
    case exercisesSearch = "exercises.search"
    case exercisesRow = "exercises.row"
    case builderTemplate = "builder.template"
    case builderBlank = "builder.blank"
    case builderName = "builder.name"
    case builderStart = "builder.start"
    case builderCancel = "builder.cancel"
    case mesosNew = "mesos.new"
    case mesosPlan = "mesos.plan"
    case mesosRow = "mesos.row"
    case mesosMenu = "mesos.menu"
    case segment = "segment"
    case chip = "chip"
    case strengthRow = "strength.row"
    case historyRow = "history.row"
    case settingsUnit = "settings.unit"

    static let indexed: Set<A11y> = [
        .setWeight, .setReps, .setMenu, .setLog, .exerciseMenu, .exerciseCue, .exerciseHistory, .exercisePin,
    ]
    static let keyed: Set<A11y> = [
        .pickerRow, .exercisesRow, .builderTemplate, .mesosRow, .mesosMenu, .segment, .chip, .strengthRow, .historyRow,
        .settingsUnit,
    ]

    func indexed(_ index: Int) -> String { "\(rawValue).\(index)" }
    func keyed(_ key: String) -> String { "\(rawValue).\(A11y.slug(key))" }

    /// Lowercase, every run of characters outside a-z and 0-9 becomes one hyphen, no leading or trailing hyphen.
    static func slug(_ text: String) -> String {
        var out = ""
        var pendingHyphen = false
        for scalar in text.lowercased().unicodeScalars {
            let isAlnum = (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9")
            if isAlnum {
                if pendingHyphen && !out.isEmpty { out.append("-") }
                pendingHyphen = false
                out.unicodeScalars.append(scalar)
            } else {
                pendingHyphen = true
            }
        }
        return out
    }
}

extension View {
    public func a11y(_ id: A11y) -> some View { accessibilityIdentifier(id.rawValue) }
    public func a11y(_ id: A11y, _ index: Int) -> some View { accessibilityIdentifier(id.indexed(index)) }
    public func a11y(_ id: A11y, key: String) -> some View { accessibilityIdentifier(id.keyed(key)) }
}
