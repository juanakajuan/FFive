import SwiftUI

struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let unit: WeightUnit
    let rir: Int?
    var onCompleted: () -> Void
    var onAdd: () -> Void
    var onDelete: () -> Void

    @Environment(Store.self) private var store

    private enum Field { case weight, reps }
    @FocusState private var focus: Field?
    @State private var followers: [SetEntry] = []

    /// Zero reads as "not entered yet", so the field shows its placeholder instead of a 0.
    private var weight: Binding<Double?> {
        Binding(
            get: { set.weight == 0 ? nil : set.weight },
            set: { store.setWeight($0 ?? 0, of: set, carryingTo: followers) })
    }

    private var isBodyweight: Bool { self.set.exercise?.isBodyweight ?? false }

    private var reps: Binding<Int?> {
        Binding(get: { set.reps == 0 ? nil : set.reps }, set: { set.reps = $0 ?? 0 })
    }

    private var setType: Binding<SetType> {
        Binding(get: { set.type }, set: { store.setType($0, of: set) })
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add Set", systemImage: "plus", action: onAdd)
                    .a11y(.menuAddSet)
                switch set.status {
                case .pending:
                    Button("Skip Set", systemImage: "forward.end") { store.skip(set, skipped: true) }
                        .a11y(.menuSkipSet)
                case .skipped:
                    Button("Unskip Set", systemImage: "arrow.uturn.backward") { store.skip(set, skipped: false) }
                        .a11y(.menuSkipSet)
                case .done:
                    EmptyView()
                }
                Picker("Set Type", selection: setType) {
                    ForEach(SetType.allCases) { Text($0.title).tag($0) }
                }
                .a11y(.menuSetType)
                Button("Delete Set", systemImage: "trash", role: .destructive, action: onDelete)
                    .a11y(.menuDeleteSet)
            } label: {
                ActionIcon.verticalEllipsis.frame(width: SetColumns.menu, height: 44)
            }
            .accessibilityLabel(set.type.tag == nil ? "Set \(number) menu" : "Set \(number) menu, \(set.type.title)")
            .a11y(.setMenu, number)

            TextField(
                "Set \(number) weight", value: weight, format: .number,
                prompt: Text(isBodyweight ? "BW" : unit.rawValue).foregroundStyle(Theme.secondary)
            )
            .keyboardType(isBodyweight ? .numbersAndPunctuation : .decimalPad)
            .focused($focus, equals: .weight)
            .onChange(of: focus) { _, new in
                followers = new == .weight ? store.weightFollowers(of: set) : []
            }
            .themedField()
            .contentShape(Rectangle())
            .onTapGesture { focus = .weight }
            .accessibilityLabel("Set \(number) weight")
            .a11y(.setWeight, number)
            .frame(width: SetColumns.field)
            .padding(.leading, 12)
            .opacity(set.status == .skipped ? 0.4 : 1)

            TextField(
                "Set \(number) reps", value: reps, format: .number,
                prompt: Text(rir.map { "\($0) RIR" } ?? "reps").foregroundStyle(Theme.secondary)
            )
            .keyboardType(.numberPad)
            .focused($focus, equals: .reps)
            .themedField()
            .contentShape(Rectangle())
            .onTapGesture { focus = .reps }
            .accessibilityLabel("Set \(number) reps")
            .a11y(.setReps, number)
            .frame(width: SetColumns.field)
            .padding(.leading, 16)
            .opacity(set.status == .skipped ? 0.4 : 1)

            if let tag = set.type.tag {
                Text(tag)
                    .font(Theme.caption.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, 8)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Button {
                store.log(set, done: !set.isDone)
                if set.isDone { onCompleted() }
            } label: {
                LogCheckbox(status: set.status)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log set \(number)")
            .a11y(.setLog, number)
            .accessibilityValue(set.status == .skipped ? "Skipped" : "")
            .accessibilityAddTraits(set.isDone ? .isSelected : [])
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 52)
    }
}
