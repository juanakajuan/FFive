import SwiftUI
import FFiveCore

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
                .frame(height: 18)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(Theme.tag)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// This week's sessions and time, and every session, on the Workout tab and in Progress.
struct StatsRow: View {
    let stats: WeekStats

    var body: some View {
        HStack(spacing: 8) {
            StatTile(title: "This Week", value: "\(stats.thisWeek)", icon: "flame")
            StatTile(title: "Time", value: formatDuration(stats.time), icon: "clock")
            StatTile(title: "All Time", value: "\(stats.allTime)", icon: "trophy")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct MuscleChip: View {
    let muscle: Muscle

    var body: some View {
        MuscleTag(muscle: muscle)
    }
}

/// The week's phase in `StatusBadge` style: blue for an accumulation week's RIR, gold for the deload.
struct PhaseBadge: View {
    let phase: WeekPhase

    var body: some View {
        Text(phase.badgeText)
            .font(Theme.caption)
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(phase == .deload ? Theme.noteFill : Theme.infoFill, in: RoundedRectangle(cornerRadius: 2))
            .fixedSize()
    }
}

extension WeekPhase {
    var badgeText: String {
        switch self {
        case .accumulation(let rir): "\(rir) RIR"
        case .deload: "Deload"
        }
    }
}

/// Equal-width buttons that pick exactly one option, in place of the system segmented control.
struct SegmentedButtons<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(Theme.detail.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(selected ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(selected ? Theme.raised : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .a11y(.segment, key: label(option))
            }
        }
        .padding(2)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A row of tappable options that reads as one question. Tapping the selected option clears it.
struct ChipPicker<Option: Hashable>: View {
    let title: String
    let options: [Option]
    var columns: Int
    let label: (Option) -> String
    let selection: Option?
    let onSelect: (Option?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.detail).foregroundStyle(Theme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = option == selection
                    Button {
                        onSelect(selected ? nil : option)
                    } label: {
                        Text(label(option))
                            .font(Theme.detail.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selected ? Theme.infoFill : Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(selected ? Theme.infoText : Color.clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .a11y(.chip, key: label(option))
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// One muscle's weekly sets against its landmarks. The track ends at MRV, the tick marks MEV,
/// and the green rule underneath spans the productive range, so no two fills ever overlap.
struct VolumeBar: View {
    let volume: MuscleVolume

    var body: some View {
        let landmarks = volume.muscle.landmarks
        let scale = Double(max(landmarks.mrv, volume.planned, volume.done))
        HStack(spacing: 10) {
            Text(volume.muscle.displayName)
                .font(Theme.detail)
                .foregroundStyle(Theme.text)
                .frame(width: 92, alignment: .leading)
            GeometryReader { proxy in
                let x = { (sets: Int) in proxy.size.width * Double(sets) / scale }
                VStack(alignment: .leading, spacing: 3) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.raised)
                        RoundedRectangle(cornerRadius: 2).fill(Theme.infoFill).frame(width: x(volume.planned))
                        RoundedRectangle(cornerRadius: 2).fill(Theme.infoText).frame(width: x(volume.done))
                        Rectangle().fill(Theme.text.opacity(0.7)).frame(width: 2, height: 14).offset(x: x(landmarks.mev) - 1)
                    }
                    .frame(height: 10)
                    Capsule()
                        .fill(Theme.success)
                        .frame(width: x(landmarks.mav.upperBound) - x(landmarks.mav.lowerBound), height: 3)
                        .offset(x: x(landmarks.mav.lowerBound))
                }
            }
            .frame(height: 16)
            Text("\(volume.done)/\(volume.planned)")
                .font(Theme.caption.monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(volume.muscle.displayName), \(volume.done) of \(volume.planned) sets done, minimum effective \(landmarks.mev), maximum recoverable \(landmarks.mrv)")
    }
}

struct VolumeLegend: View {
    var includesMaximum = false

    var body: some View {
        HStack(spacing: 12) {
            item(Theme.infoText, "Done")
            item(Theme.infoFill, "Planned")
            item(Theme.success, "Productive")
            tick(Theme.text.opacity(0.7), "Minimum")
            if includesMaximum { tick(Theme.danger, "Maximum") }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.secondary)
    }

    private func tick(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 2, height: 10)
            Text(text)
        }
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

extension View {
    /// A plain list on `surface`, without the system grouped look.
    func themedList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
    }

    /// A list row on `surface` with 16pt gutters and a hairline separator.
    func themedRow(vertical: CGFloat = 12) -> some View {
        alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
            .listRowInsets(EdgeInsets(top: vertical, leading: Theme.gutter, bottom: vertical, trailing: Theme.gutter))
    }
}
