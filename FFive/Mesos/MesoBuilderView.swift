import FFiveCore
import SwiftData
import SwiftUI

struct MesoBuilderView: View {
    enum Route: Hashable {
        case template(ProgramTemplate)
        case blank
        case guided
        case copy(Mesocycle)
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
                    SectionHeading(text: "Copy a mesocycle")
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    TemplateGroup {
                        ForEach(mesos) { meso in
                            NavigationLink(value: Route.copy(meso)) { CopySourceRow(meso: meso) }
                                .buttonStyle(.plain)
                                .a11y(.builderCopySource, key: meso.name)
                            if meso.id != mesos.last?.id {
                                Rectangle().fill(Theme.hairline).frame(height: 1)
                            }
                        }
                    }
                }
                if !customTemplates.isEmpty {
                    SectionHeading(text: "Your templates")
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    TemplateGroup {
                        ForEach(customTemplates) { saved in
                            NavigationLink(value: Route.template(saved.template)) {
                                TemplateListRow(template: saved.template)
                            }
                            .buttonStyle(.plain)
                            .a11y(.builderCustomTemplate, key: saved.name)
                            if saved.id != customTemplates.last?.id {
                                Rectangle().fill(Theme.hairline).frame(height: 1)
                            }
                        }
                    }
                }
                SectionHeading(text: "Plan it for me")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                TemplateGroup {
                    NavigationLink(value: Route.guided) {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars").font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Guided plan").font(.system(size: 16, weight: .semibold))
                                Text("Pick your days a week and what to grow")
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(
                                Theme.secondary)
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .a11y(.builderGuided)
                }
                SectionHeading(text: "Start from a template")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                TemplateGroup {
                    ForEach(ExerciseCatalog.templates) { template in
                        NavigationLink(value: Route.template(template)) {
                            TemplateListRow(template: template)
                        }
                        .buttonStyle(.plain)
                        .a11y(.builderTemplate, key: template.name)
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                    NavigationLink(value: Route.blank) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.pencil").font(.system(size: 18))
                            Text("Build from scratch").font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(
                                Theme.secondary)
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .a11y(.builderBlank)
                }
                Text("You can rename days and change any exercise on the next screen.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 10)
            }
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("New Mesocycle")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func editor(_ route: Route) -> some View {
        switch route {
        case .template(let template): MesoEditorView(draft: MesoDraft(template: template)) { dismiss() }
        case .blank: MesoEditorView(draft: MesoDraft(template: nil)) { dismiss() }
        case .guided: MesoGuidedView { dismiss() }
        case .copy(let source): MesoCopyView(source: source) { dismiss() }
        }
    }
}

struct MesoEditorView: View {
    @State private var draft: MesoDraft
    private let original: MesoDraft
    var onStart: () -> Void

    init(draft: MesoDraft, onStart: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        original = draft
        self.onStart = onStart
    }

    @Environment(Store.self) private var store
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]
    @State private var picker: PickerRequest?
    @State private var templateName: String?
    @State private var confirmReset = false

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
            Section {
                TextField(
                    "Mesocycle name", text: $draft.name, prompt: Text("Mesocycle name").foregroundStyle(Theme.secondary)
                )
                .builderField()
                .builderRow()
                .a11y(.builderName)
            } header: {
                header("Name")
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
                .builderRow()
                RIRSchedule(accumulationWeeks: draft.accumulationWeeks)
                    .builderRow()
                footnote(
                    "Effort climbs each week as reps in reserve (RIR) count down toward zero. The deload then sheds fatigue so the next block starts fresh."
                )
            } header: {
                header("Length")
            }

            ForEach($draft.days) { $day in
                Section {
                    TextField("Day name", text: $day.name, prompt: Text("Day name").foregroundStyle(Theme.secondary))
                        .font(.system(size: 16, weight: .semibold))
                        .builderField()
                        .builderRow()
                    Picker("Weekday", selection: $day.weekday) {
                        Text("None").tag(Weekday?.none)
                        ForEach(Weekday.allCases) { Text($0.name).tag(Weekday?.some($0)) }
                    }
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                    .tint(Theme.secondary)
                    .a11y(.builderWeekday, (draft.days.firstIndex { $0.id == day.id } ?? 0) + 1)
                    .builderRow()
                    ForEach(day.slots) { slot in
                        Button {
                            picker = .swap(day: day.id, slot: slot)
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
                        .builderRow()
                    }
                    .onDelete { offsets in update(day.id) { $0.slots.remove(atOffsets: offsets) } }
                    .onMove { from, to in update(day.id) { $0.slots.move(fromOffsets: from, toOffset: to) } }
                    Button {
                        picker = .add(day: day.id)
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(Theme.body)
                            .foregroundStyle(Theme.infoText)
                    }
                    .builderRow()
                    Picker(
                        selection: Binding<Muscle?>(
                            get: { nil },
                            set: { muscle in
                                guard let muscle else { return }
                                update(day.id) { $0.slots.append(MesoDraft.Slot(muscle: muscle)) }
                            })
                    ) {
                        ForEach(Muscle.allCases) { Text($0.displayName).tag(Muscle?.some($0)) }
                    } label: {
                        Label("Add Muscle", systemImage: "plus.square.dashed")
                            .font(Theme.body)
                            .foregroundStyle(Theme.infoText)
                    }
                    .tint(Theme.secondary)
                    .a11y(.builderAddMuscle)
                    .builderRow()
                    if day.slots.isEmpty {
                        footnote("Add at least one exercise, or remove this day.")
                    }
                } header: {
                    HStack {
                        header("Day \((draft.days.firstIndex { $0.id == day.id } ?? 0) + 1)")
                        Spacer()
                        if draft.days.count > 1 {
                            Button("Remove Day", role: .destructive) {
                                withAnimation { draft.days.removeAll { $0.id == day.id } }
                            }
                            .font(Theme.detail)
                            .foregroundStyle(Theme.danger)
                        }
                    }
                }
            }

            Section {
                Button {
                    withAnimation { draft.days.append(MesoDraft.Day(name: "Day \(draft.days.count + 1)", slots: [])) }
                } label: {
                    Label("Add Day", systemImage: "calendar.badge.plus")
                        .font(Theme.body)
                        .foregroundStyle(Theme.infoText)
                }
                .builderRow()
                footnote(
                    "Tap an exercise to swap it for another that trains the same muscle. Add a muscle to choose its exercise later."
                )
            }

            if !draft.muscles.isEmpty {
                Section {
                    ForEach(draft.muscles) { muscle in
                        MusclePriorityRow(muscle: muscle, priority: draft.priorities[muscle] ?? .normal) {
                            draft.priorities[muscle] = $0
                        }
                        .builderRow()
                    }
                    footnote(MusclePriority.explanation)
                } header: {
                    header("Muscle Priorities")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.surface)
        .environment(\.defaultMinListRowHeight, 48)
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save as Template", systemImage: "square.and.arrow.down") { templateName = draft.name }
                    .disabled(!draft.isStartable)
                    .a11y(.builderSaveTemplate)
                EditButton()
                Menu("Options", systemImage: "ellipsis.circle") {
                    Button("Autofill Exercises", systemImage: "wand.and.stars", action: autofill)
                        .disabled(!draft.hasEmptySlot)
                        .a11y(.menuAutofill)
                    Button("Clear Exercises", systemImage: "eraser") { draft.clearExercises() }
                        .disabled(!draft.days.contains { $0.slots.contains { $0.exercise != nil } })
                        .a11y(.menuClearExercises)
                    Button("Reset", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
                        .a11y(.menuReset)
                }
                .a11y(.builderMenu)
            }
        }
        .confirmationDialog("Reset this mesocycle?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { draft = original }
                .a11y(.dialogReset)
        } message: {
            Text("Days, exercises and settings go back to how they were when you opened this screen.")
        }
        .alert(
            "Save as Template",
            isPresented: Binding(get: { templateName != nil }, set: { if !$0 { templateName = nil } })
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
                if let current = activeMesos.first {
                    Text("End \(current.name) before starting a new mesocycle.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                FilledActionButton(
                    title: "Start Mesocycle", isEnabled: draft.isStartable && activeMesos.isEmpty, action: start
                )
                .a11y(.builderStart)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
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

    private func header(_ text: String) -> some View {
        Text(text)
            .font(Theme.columnHeader)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            .listRowBackground(Theme.surface)
            .listRowSeparator(.hidden)
    }

    private func update(_ dayID: UUID, _ change: (inout MesoDraft.Day) -> Void) {
        guard let index = draft.days.firstIndex(where: { $0.id == dayID }) else { return }
        change(&draft.days[index])
    }

    private func autofill() {
        draft.autofill(
            from: store.library(muscle: nil, equipment: nil, search: ""), equipment: store.settings.equipment,
            lastPerformed: store.lastPerformed())
    }

    private func start() {
        guard (try? store.startMesocycle(draft)) != nil else { return }
        onStart()
    }
}

struct RIRSchedule: View {
    let accumulationWeeks: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0...accumulationWeeks, id: \.self) { week in
                let phase = Progression.phase(week: week, accumulationWeeks: accumulationWeeks)
                VStack(spacing: 2) {
                    Text(phase == .deload ? "DL" : "W\(week + 1)")
                        .font(Theme.tag)
                        .foregroundStyle(Theme.secondary)
                    Text(phase.rir.map(String.init) ?? "—")
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
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

struct FilledActionButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.page)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.text, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

extension View {
    fileprivate func builderRow() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
            .listRowInsets(EdgeInsets(top: 8, leading: Theme.gutter, bottom: 8, trailing: Theme.gutter))
    }

    fileprivate func builderField() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.hairline, lineWidth: 1))
    }
}
