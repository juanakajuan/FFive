import FFiveCore
import SwiftData
import SwiftUI

struct MesoBuilderView: View {
    enum Route: Hashable {
        case template(ProgramTemplate)
        case blank
        case guided
        case copy(Mesocycle)
        /// Edits a custom template's days in place instead of starting a block.
        case editTemplate(CustomTemplate)
    }

    var startAt: Route?

    @Environment(\.dismiss) private var dismiss
    @Query(CustomTemplate.all) private var customTemplates: [CustomTemplate]
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesos: [Mesocycle]
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let startAt {
                    editor(startAt)
                } else {
                    templateList
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.builderCancel)
                }
            }
            .navigationDestination(for: Route.self, destination: editor)
            .onAppear {
                if startAt == nil, DemoLaunch.route == .builder, path.isEmpty,
                    let first = ExerciseCatalog.defaultTemplate
                {
                    path = [.template(first)]
                }
            }
        }
    }

    private var templateList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !mesos.isEmpty {
                    GroupedSection("Copy a Mesocycle") {
                        ForEach(mesos) { meso in
                            NavigationLink(value: Route.copy(meso)) { CopySourceRow(meso: meso) }
                                .buttonStyle(.plain)
                                .a11y(.builderCopySource, key: meso.name)
                            if meso.id != mesos.last?.id {
                                Hairline()
                            }
                        }
                    }
                }
                if !customTemplates.isEmpty {
                    GroupedSection(TemplateGroup.custom) {
                        ForEach(customTemplates) { saved in
                            NavigationLink(value: Route.template(saved.template)) {
                                TemplateListRow(template: saved.template)
                            }
                            .buttonStyle(.plain)
                            .a11y(.builderCustomTemplate, key: saved.name)
                            if saved.id != customTemplates.last?.id {
                                Hairline()
                            }
                        }
                    }
                }
                GroupedSection("Plan It for Me") {
                    linkRow(
                        "Guided Plan", systemImage: "wand.and.stars", detail: "Pick your days a week and what to grow",
                        to: .guided
                    )
                    .a11y(.builderGuided)
                }
                GroupedSection(TemplateGroup.builtIn) {
                    ForEach(ExerciseCatalog.templates) { template in
                        NavigationLink(value: Route.template(template)) {
                            TemplateListRow(template: template)
                        }
                        .buttonStyle(.plain)
                        .a11y(.builderTemplate, key: template.name)
                        Hairline()
                    }
                    linkRow("Build from Scratch", systemImage: "square.dashed", to: .blank)
                        .a11y(.builderBlank)
                }
                Text("You can rename days and change any exercise on the next screen.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 10)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("New Mesocycle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func linkRow(_ title: String, systemImage: String, detail: String? = nil, to route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.rowTitle)
                    if let detail {
                        Text(detail)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                Spacer()
                RowChevron()
            }
            .foregroundStyle(Theme.text)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func editor(_ route: Route) -> some View {
        switch route {
        case .template(let template): MesoEditorView(draft: MesoDraft(template: template)) { dismiss() }
        case .blank: MesoEditorView(draft: MesoDraft(template: nil)) { dismiss() }
        case .guided: MesoGuidedView { dismiss() }
        case .copy(let source): MesoCopyView(source: source) { dismiss() }
        case .editTemplate(let saved):
            MesoEditorView(draft: MesoDraft(template: saved.template), editing: saved) { dismiss() }
        }
    }
}

struct MesoEditorView: View {
    @State private var draft: MesoDraft
    private let original: MesoDraft
    /// The custom template this screen saves back to. Editing a template hides what only a block keeps:
    /// name, length, schedule, weekdays and priorities.
    private let editing: CustomTemplate?
    var onStart: () -> Void

    init(draft: MesoDraft, editing: CustomTemplate? = nil, onStart: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        original = draft
        self.editing = editing
        self.onStart = onStart
    }

    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]
    @State private var picker: PickerRequest?
    @State private var templateName: String?
    @State private var confirmReset = false
    @State private var managingDays = false
    @State private var editMode: EditMode = .inactive

    private enum PickerRequest: Identifiable {
        case add(day: UUID)
        case swap(day: UUID, slot: MesoDraft.Slot)

        var id: String {
            switch self {
            case .add(let day): "add-\(day)"
            case .swap(_, let slot): "swap-\(slot.id)"
            }
        }
    }

    var body: some View {
        List {
            if editing == nil {
                blockSettings
            }

            ForEach(Array($draft.days.enumerated()), id: \.element.id) { index, day in
                daySection(day, number: index + 1)
            }

            Section {
                Button {
                    withAnimation(.snappy) {
                        draft.days.append(MesoDraft.Day(name: "Day \(draft.days.count + 1)", slots: []))
                    }
                } label: {
                    Label("Add Day", systemImage: "calendar.badge.plus")
                        .font(Theme.body)
                        .foregroundStyle(Theme.infoText)
                }
                .themedRow(vertical: 8)
                footnote(
                    "Tap an exercise to swap it for another that trains the same muscle. Add a muscle to choose its exercise later."
                )
            }

            if editing == nil, !draft.muscles.isEmpty {
                musclePriorities
            }
        }
        .themedList()
        .environment(\.defaultMinListRowHeight, 48)
        .navigationTitle(editing == nil ? "Customize" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if editMode.isEditing {
                    Button("Done") { withAnimation(.snappy) { editMode = .inactive } }
                        .fontWeight(.semibold)
                        .a11y(.builderDoneEditing)
                } else {
                    Menu {
                        if editing == nil {
                            Button("Save as Template", systemImage: "square.and.arrow.down") {
                                templateName = draft.name
                            }
                            .disabled(!draft.isStartable)
                            .a11y(.builderSaveTemplate)
                        }
                        Button("Edit Exercises", systemImage: "arrow.up.arrow.down") {
                            withAnimation(.snappy) { editMode = .active }
                        }
                        .a11y(.menuEditExercises)
                        Button("Manage Days", systemImage: "list.number") { managingDays = true }
                            .a11y(.menuManageDays)
                        Button("Autofill Exercises", systemImage: "wand.and.stars", action: autofill)
                            .disabled(!draft.hasEmptySlot)
                            .a11y(.menuAutofill)
                        Button("Clear Exercises", systemImage: "eraser") { draft.clearExercises() }
                            .disabled(!draft.days.contains { $0.slots.contains { $0.exercise != nil } })
                            .a11y(.menuClearExercises)
                        Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmReset = true
                        }
                        .a11y(.menuReset)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(editing == nil ? "Mesocycle Menu" : "Template Menu")
                    .a11y(.builderMenu)
                }
            }
        }
        .confirmationDialog(
            editing == nil ? "Reset this mesocycle?" : "Reset this template?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button(editing == nil ? "Reset Mesocycle" : "Reset Template", role: .destructive) { draft = original }
                .a11y(.dialogReset)
        } message: {
            Text(
                editing == nil
                    ? "Days, exercises and settings go back to how they were when you opened this screen."
                    : "Days and exercises go back to how they were when you opened this screen."
            )
        }
        .alert(
            "Save as Template",
            isPresented: $templateName.isPresent()
        ) {
            TextField("Template name", text: Binding(get: { templateName ?? "" }, set: { templateName = $0 }))
            Button("Save") {
                if let templateName { store.saveTemplate(from: draft, named: templateName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves these days and exercises so you can start from them again.")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if draft.hasEmptySlot {
                    Text("Choose an exercise for every muscle, or autofill them from the menu.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                if let editing {
                    Button("Save Template") {
                        store.updateTemplate(editing, from: draft)
                        onStart()
                    }
                    .buttonStyle(.primary)
                    .disabled(!draft.isStartable)
                    .a11y(.builderUpdateTemplate)
                } else {
                    if let current = activeMesos.first {
                        Text("End \(current.name) before starting a new mesocycle.")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                    Button("Start Mesocycle", action: start)
                        .buttonStyle(.primary)
                        .disabled(!draft.isStartable || !activeMesos.isEmpty)
                        .a11y(.builderStart)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .overlay(alignment: .top) { Hairline() }
        }
        .interactiveDismissDisabled(draft != original)
        .sheet(isPresented: $managingDays) { ManageDaysView(draft: $draft) }
        .sheet(item: $picker) { request in
            switch request {
            case .add(let dayID):
                ExercisePickerView { name, muscle in
                    update(dayID) { $0.slots.append(MesoDraft.Slot(exercise: name, muscle: muscle)) }
                }
            case .swap(let dayID, let slot):
                ExercisePickerView(
                    title: slot.exercise.map { "Swap \($0)" } ?? "Choose \(slot.muscle.displayName)",
                    muscle: slot.muscle
                ) { name, muscle in
                    update(dayID) { day in
                        guard let index = day.slots.firstIndex(where: { $0.id == slot.id }) else { return }
                        day.slots[index].exercise = name
                        day.slots[index].muscle = muscle
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var blockSettings: some View {
        Section {
            TextField(
                "Mesocycle name", text: $draft.name,
                prompt: Text("Mesocycle name").foregroundStyle(Theme.secondary)
            )
            .formField()
            .themedRow(vertical: 8)
            .a11y(.builderName)
        } header: {
            SectionHeading(text: "Name")
                .themedRow(vertical: 0)
        }

        Section {
            Stepper(value: $draft.accumulationWeeks, in: Mesocycle.accumulationWeekRange) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(draft.accumulationWeeks) training weeks")
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                    Text("then 1 deload week").font(Theme.caption).foregroundStyle(Theme.secondary)
                }
            }
            .themedRow(vertical: 8)
            RIRSchedule(accumulationWeeks: draft.accumulationWeeks)
                .themedRow(vertical: 8)
            footnote(
                "Effort climbs each week as reps in reserve (RIR) count down toward zero. The deload then sheds fatigue so the next mesocycle starts fresh."
            )
        } header: {
            SectionHeading(text: "Length")
                .themedRow(vertical: 0)
        }

        Section {
            Picker(
                "Starts on",
                selection: Binding(
                    get: { draft.startWeekday }, set: { $0.map { draft.schedule(startingOn: $0) } })
            ) {
                if draft.startWeekday == nil { Text("Choose").tag(Weekday?.none) }
                ForEach(Weekday.allCases) { Text($0.name).tag(Weekday?.some($0)) }
            }
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .tint(Theme.secondary)
            .sensoryFeedback(.selection, trigger: draft.startWeekday)
            .a11y(.builderStartWeekday)
            .themedRow(vertical: 8)
            footnote(
                "Each day gets a weekday that spreads rest through the week. Change any of them below."
            )
        } header: {
            SectionHeading(text: "Schedule")
                .themedRow(vertical: 0)
        }
    }

    private func daySection(_ day: Binding<MesoDraft.Day>, number: Int) -> some View {
        let id = day.wrappedValue.id
        let slots = day.wrappedValue.slots
        return Section {
            TextField("Day name", text: day.name, prompt: Text("Day name").foregroundStyle(Theme.secondary))
                .font(Theme.rowTitle)
                .formField()
                .themedRow(vertical: 8)
            if editing == nil {
                Picker("Weekday", selection: day.weekday) {
                    Text("None").tag(Weekday?.none)
                    ForEach(Weekday.allCases) { Text($0.name).tag(Weekday?.some($0)) }
                }
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .tint(Theme.secondary)
                .sensoryFeedback(.selection, trigger: day.wrappedValue.weekday)
                .a11y(.builderWeekday, number)
                .themedRow(vertical: 8)
            }
            ForEach(slots) { slot in
                Button {
                    picker = .swap(day: id, slot: slot)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(slot.exercise ?? "Choose an exercise")
                                .font(Theme.body)
                                .foregroundStyle(slot.exercise == nil ? Theme.infoText : Theme.text)
                            MuscleDotLabel(muscle: slot.muscle)
                        }
                        Spacer()
                        Image(systemName: slot.exercise == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .themedRow(vertical: 8)
            }
            .onDelete { offsets in update(id) { $0.slots.remove(atOffsets: offsets) } }
            .onMove { from, to in update(id) { $0.slots.move(fromOffsets: from, toOffset: to) } }
            Button {
                picker = .add(day: id)
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(Theme.body)
                    .foregroundStyle(Theme.infoText)
            }
            .themedRow(vertical: 8)
            Picker(
                selection: Binding<Muscle?>(
                    get: { nil },
                    set: { muscle in
                        guard let muscle else { return }
                        update(id) { $0.slots.append(MesoDraft.Slot(muscle: muscle)) }
                    })
            ) {
                ForEach(Muscle.allCases) { Text($0.displayName).tag(Muscle?.some($0)) }
            } label: {
                Label("Add Muscle", systemImage: "plus.square.dashed")
                    .font(Theme.body)
                    .foregroundStyle(Theme.infoText)
            }
            .tint(Theme.secondary)
            .sensoryFeedback(.selection, trigger: slots.count) { old, new in new > old }
            .a11y(.builderAddMuscle)
            .themedRow(vertical: 8)
            if slots.isEmpty {
                footnote("Add at least one exercise, or remove this day.")
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(text: "Day \(number)")
                Spacer()
                if draft.days.count > 1 {
                    Button("Remove Day", role: .destructive) {
                        withAnimation(.snappy) { draft.days.removeAll { $0.id == id } }
                    }
                    .font(Theme.detail)
                    .foregroundStyle(Theme.danger)
                }
            }
            .themedRow(vertical: 0)
        }
    }

    private var musclePriorities: some View {
        Section {
            ForEach(draft.muscles) { muscle in
                MusclePriorityRow(muscle: muscle, priority: draft.priorities[muscle] ?? .normal) {
                    draft.priorities[muscle] = $0
                }
                .themedRow(vertical: 8)
            }
            footnote(MusclePriority.explanation)
        } header: {
            SectionHeading(text: "Muscle Priorities")
                .themedRow(vertical: 0)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            .themedRow()
            .listRowSeparator(.hidden)
    }

    private func update(_ dayID: UUID, _ change: (inout MesoDraft.Day) -> Void) {
        guard let index = draft.days.firstIndex(where: { $0.id == dayID }) else { return }
        withAnimation(.snappy) { change(&draft.days[index]) }
    }

    private func autofill() {
        draft.autofill(
            from: store.library(muscle: nil, equipment: nil, search: ""), equipment: store.settings.equipment,
            lastPerformed: store.lastPerformed())
    }

    private func start() {
        guard router.start(draft, store: store) else { return }
        onStart()
    }
}

/// Lists the draft's days to drag into the order the block trains them, rename or remove.
/// A day's weekday label moves with it.
struct ManageDaysView: View {
    @Binding var draft: MesoDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array($draft.days.enumerated()), id: \.element.id) { offset, day in
                    let index = offset + 1
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(
                            "Day name", text: day.name, prompt: Text("Day name").foregroundStyle(Theme.secondary)
                        )
                        .formField()
                        .a11y(.manageDaysName, index)
                        HStack(alignment: .firstTextBaseline) {
                            Text(details(day.wrappedValue, index: index))
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondary)
                            Spacer()
                            if draft.days.count > 1 {
                                Button("Remove Day", role: .destructive) {
                                    withAnimation(.snappy) { draft.days.remove(atOffsets: [offset]) }
                                }
                                .buttonStyle(.borderless)
                                .font(Theme.detail)
                                .foregroundStyle(Theme.danger)
                                .a11y(.manageDaysRemove, index)
                            }
                        }
                    }
                    .themedRow(vertical: 8)
                }
                .onMove { draft.moveDays(fromOffsets: $0, toOffset: $1) }
                Text("Drag a day to change the order the mesocycle trains it in. Its weekday moves with it.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                    .themedRow(vertical: 8)
                    .listRowSeparator(.hidden)
            }
            .themedList(background: Theme.page)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Manage Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .a11y(.manageDaysDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func details(_ day: MesoDraft.Day, index: Int) -> String {
        let exercises = day.slots.count == 1 ? "1 exercise" : "\(day.slots.count) exercises"
        return ["Day \(index)", day.weekday?.name, exercises].compactMap { $0 }.joined(separator: " · ")
    }
}

struct RIRSchedule: View {
    let accumulationWeeks: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0...accumulationWeeks, id: \.self) { week in
                let phase = Progression.phase(week: week, accumulationWeeks: accumulationWeeks)
                VStack(spacing: 2) {
                    Text(phase.shortLabel(week: week))
                        .font(Theme.tag)
                        .foregroundStyle(Theme.secondary)
                    Text(phase.rir.map(String.init) ?? "—")
                        .font(Theme.rowTitle.monospacedDigit())
                        .foregroundStyle(phase == .deload ? Theme.infoText : Theme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .animation(.snappy, value: accumulationWeeks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            (0..<accumulationWeeks).map {
                "week \($0 + 1), \(Progression.phase(week: $0, accumulationWeeks: accumulationWeeks).rir ?? 0) RIR"
            }.joined(separator: ", ") + ", then deload")
    }
}
