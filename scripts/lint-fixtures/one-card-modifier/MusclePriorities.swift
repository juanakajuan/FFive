import FFiveCore
import SwiftUI

struct MusclePriorityRow: View {
    let muscle: Muscle
    let priority: MusclePriority
    var isEditable = true
    let onChange: (MusclePriority) -> Void

    var body: some View {
        HStack {
            MuscleDotLabel(muscle: muscle)
            Spacer()
            if isEditable {
                Menu {
                    Picker(muscle.displayName, selection: Binding(get: { priority }, set: onChange)) {
                        ForEach(MusclePriority.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(priority.label)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .medium))
                    }
                    .font(Theme.detail)
                    .foregroundStyle(priority == .normal ? Theme.secondary : Theme.text)
                }
                .a11y(.musclePriority, key: muscle.rawValue)
                .accessibilityLabel("\(muscle.displayName) priority")
                .accessibilityValue(priority.label)
            } else {
                Text(priority.label).font(Theme.detail).foregroundStyle(Theme.secondary)
            }
        }
        .frame(minHeight: 32)
    }
}

struct MusclePrioritiesCard: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle Priorities").font(Theme.cardTitle).foregroundStyle(Theme.text)
            ForEach(meso.muscles) { muscle in
                MusclePriorityRow(muscle: muscle, priority: meso.priority(of: muscle), isEditable: meso.isActive) {
                    store.setPriority($0, of: muscle, in: meso)
                }
            }
            Text(MusclePriority.explanation + " A change applies from the next session the block builds.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

extension MusclePriority {
    static let explanation =
        "Emphasized muscles add sets faster. Maintained muscles start at maintenance volume and never add sets, which leaves recovery for the rest."
}
