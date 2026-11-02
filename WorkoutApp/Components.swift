import SwiftUI

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct MuscleChip: View {
    let muscle: Muscle

    var body: some View {
        Text(muscle.displayName)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .fixedSize()
    }
}

struct PhaseBadge: View {
    let phase: WeekPhase

    var body: some View {
        Text(phase.badgeText)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(phase == .deload ? Color.cyan : Color.accentColor)
            .background((phase == .deload ? Color.cyan : Color.accentColor).opacity(0.18), in: Capsule())
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
            Text(title).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = option == selection
                    Button {
                        onSelect(selected ? nil : option)
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(selected ? Color.black : Color.primary)
                            .background(selected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.borderless)
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
                .font(.subheadline)
                .frame(width: 92, alignment: .leading)
            GeometryReader { proxy in
                let x = { (sets: Int) in proxy.size.width * Double(sets) / scale }
                VStack(alignment: .leading, spacing: 3) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule().fill(Color.accentColor.opacity(0.35)).frame(width: x(volume.planned))
                        Capsule().fill(Color.accentColor).frame(width: x(volume.done))
                        Rectangle().fill(Color.primary.opacity(0.7)).frame(width: 2, height: 14).offset(x: x(landmarks.mev) - 1)
                    }
                    .frame(height: 10)
                    Capsule()
                        .fill(Color.green)
                        .frame(width: x(landmarks.mav.upperBound) - x(landmarks.mav.lowerBound), height: 3)
                        .offset(x: x(landmarks.mav.lowerBound))
                }
            }
            .frame(height: 16)
            Text("\(volume.done)/\(volume.planned)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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
            item(Color.accentColor, "Done")
            item(Color.accentColor.opacity(0.35), "Planned")
            item(Color.green, "Productive")
            tick(Color.primary.opacity(0.7), "Minimum")
            if includesMaximum { tick(Color.red, "Maximum") }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
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
