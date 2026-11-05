import SwiftUI
import SwiftData
import FFiveCore

struct MesoBuilderView: View {
    enum Route: Hashable {
        case template(String)
        case blank
    }

    /// Opens straight into the editor, as when the Templates tab picks a template.
    var startAt: Route?

    @Environment(\.dismiss) private var dismiss
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
                if startAt == nil, DemoLaunch.route == .builder, path.isEmpty, let first = ExerciseCatalog.templates.first {
                    path = [.template(first.name)]
                }
            }
        }
    }

    private var templateList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(text: "Start from a template")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                TemplateGroup {
                    ForEach(ExerciseCatalog.templates) { template in
                        NavigationLink(value: Route.template(template.name)) {
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
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.secondary)
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

    private func editor(_ route: Route) -> some View {
        let template: ProgramTemplate? = switch route {
        case .template(let name): ExerciseCatalog.templates.first { $0.name == name }
        case .blank: nil
        }
        return MesoEditorView(draft: MesoDraft(template: template)) { dismiss() }
    }
}

struct MesoEditorView: View {
    @State var draft: MesoDraft
    var onStart: () -> Void

    @Environment(Store.self) private var store
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]
    @State private var picker: PickerRequest?

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
                TextField("Mesocycle name", text: $draft.name, prompt: Text("Mesocycle name").foregroundStyle(Theme.secondary))
                    .builderField()
                    .builderRow()
                    .a11y(.builderName)
            } header: {
                header("Name")
            }

            Section {
                Stepper(value: $draft.accumulationWeeks, in: 3...6) {
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
                footnote("Effort climbs each week as reps in reserve (RIR) count down toward zero. The deload then sheds fatigue so the next block starts fresh.")
            } header: {
                header("Length")
            }

            ForEach($draft.days) { $day in
                Section {
                    TextField("Day name", text: $day.name, prompt: Text("Day name").foregroundStyle(Theme.secondary))
                        .font(.system(size: 16, weight: .semibold))
                        .builderField()
                        .builderRow()
                    ForEach(day.slots) { slot in
                        Button { picker = .swap(day: day.id, slot: slot) } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(slot.exercise)
                                        .font(Theme.body)
                                        .foregroundStyle(Theme.text)
                                    MuscleDotLabel(muscle: slot.muscle)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
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
                    Button { picker = .add(day: day.id) } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(Theme.body)
                            .foregroundStyle(Theme.infoText)
                    }
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
                footnote("Tap an exercise to swap it for another that trains the same muscle.")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.surface)
        .environment(\.defaultMinListRowHeight, 48)
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let current = activeMesos.first {
                    Text("End \(current.name) before starting a new mesocycle.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                FilledActionButton(title: "Start Mesocycle", isEnabled: draft.isStartable && activeMesos.isEmpty, action: start)
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
                ExercisePickerView(title: "Swap \(slot.exercise)", muscle: slot.muscle) { name, muscle in
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

    private func start() {
        guard (try? store.startMesocycle(draft)) != nil else { return }
        onStart()
    }
}

/// The week-by-week effort targets for a block length, updated live as the length changes.
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
        .accessibilityLabel((0..<accumulationWeeks).map { "week \($0 + 1), \(Progression.phase(week: $0, accumulationWeeks: accumulationWeeks).rir ?? 0) RIR" }.joined(separator: ", ") + ", then deload")
    }
}

/// The full-width filled button for a screen's main action.
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

private extension View {
    func builderRow() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
            .listRowInsets(EdgeInsets(top: 8, leading: Theme.gutter, bottom: 8, trailing: Theme.gutter))
    }

    /// A dark, left-aligned text box for names.
    func builderField() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.hairline, lineWidth: 1))
    }
}
