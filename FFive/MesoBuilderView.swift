import SwiftUI
import SwiftData

struct MesoBuilderView: View {
    private enum Route: Hashable {
        case template(String)
        case blank
    }

    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !ExerciseCatalog.templates.isEmpty {
                    Section {
                        ForEach(ExerciseCatalog.templates) { template in
                            NavigationLink(value: Route.template(template.name)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name).font(.headline)
                                    Text(template.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(template.days.map(\.name).joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Start from a template")
                    } footer: {
                        Text("You can rename days and change any exercise on the next screen.")
                    }
                }
                Section {
                    NavigationLink(value: Route.blank) {
                        Label("Build from scratch", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationTitle("New Mesocycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .template(let name):
                    MesoEditorView(draft: MesoDraft(template: ExerciseCatalog.templates.first { $0.name == name })) { dismiss() }
                case .blank:
                    MesoEditorView(draft: MesoDraft(template: nil)) { dismiss() }
                }
            }
            .onAppear {
                if DemoLaunch.route == .builder, path.isEmpty, let first = ExerciseCatalog.templates.first {
                    path = [.template(first.name)]
                }
            }
        }
    }
}

struct MesoEditorView: View {
    @State var draft: MesoDraft
    var onStart: () -> Void

    @Environment(\.modelContext) private var context
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
            Section("Name") {
                TextField("Mesocycle name", text: $draft.name)
            }

            Section {
                Stepper(value: $draft.accumulationWeeks, in: 3...6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(draft.accumulationWeeks) training weeks")
                        Text("then 1 deload week").font(.caption).foregroundStyle(.secondary)
                    }
                }
                RIRSchedule(accumulationWeeks: draft.accumulationWeeks)
            } header: {
                Text("Length")
            } footer: {
                Text("Effort climbs each week as reps in reserve (RIR) count down toward zero. The deload then sheds fatigue so the next block starts fresh.")
            }

            ForEach($draft.days) { $day in
                Section {
                    TextField("Day name", text: $day.name)
                        .font(.headline)
                    ForEach(day.slots) { slot in
                        Button { picker = .swap(day: day.id, slot: slot) } label: {
                            HStack {
                                Text(slot.exercise).foregroundStyle(.primary)
                                Spacer()
                                MuscleChip(muscle: slot.muscle)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete { offsets in update(day.id) { $0.slots.remove(atOffsets: offsets) } }
                    .onMove { from, to in update(day.id) { $0.slots.move(fromOffsets: from, toOffset: to) } }
                    Button { picker = .add(day: day.id) } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Day \((draft.days.firstIndex { $0.id == day.id } ?? 0) + 1)")
                        Spacer()
                        if draft.days.count > 1 {
                            Button("Remove Day", role: .destructive) {
                                withAnimation { draft.days.removeAll { $0.id == day.id } }
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if day.slots.isEmpty {
                        Text("Add at least one exercise, or remove this day.")
                    }
                }
            }

            Section {
                Button {
                    withAnimation { draft.days.append(MesoDraft.Day(name: "Day \(draft.days.count + 1)", slots: [])) }
                } label: {
                    Label("Add Day", systemImage: "calendar.badge.plus")
                }
            } footer: {
                Text("Tap an exercise to swap it for another that trains the same muscle.")
            }
        }
        .navigationTitle("Customize")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .safeAreaInset(edge: .bottom) {
            Button(action: start) {
                Text("Start Mesocycle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .foregroundStyle(.black)
            .disabled(!draft.isStartable)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
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

    private func update(_ dayID: UUID, _ change: (inout MesoDraft.Day) -> Void) {
        guard let index = draft.days.firstIndex(where: { $0.id == dayID }) else { return }
        change(&draft.days[index])
    }

    private func start() {
        _ = MesoPlanner.start(draft, in: context)
        try? context.save()
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(phase.rir.map(String.init) ?? "—")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(phase == .deload ? Color.cyan : Color.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .animation(.snappy, value: accumulationWeeks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((0..<accumulationWeeks).map { "week \($0 + 1), \(Progression.phase(week: $0, accumulationWeeks: accumulationWeeks).rir ?? 0) RIR" }.joined(separator: ", ") + ", then deload")
    }
}
