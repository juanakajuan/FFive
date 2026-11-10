import FFiveCore
import SwiftUI

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
                        .background(
                            selected ? Theme.raised : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        )
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

struct ChipPicker<Option: Hashable>: View {
    let title: String
    let options: [Option]
    var columns: Int
    let label: (Option) -> String
    var meaning: ((Option) -> String)? = nil
    let selection: Option?
    let onSelect: (Option?) -> Void

    @State private var showsHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title).font(Theme.detail).foregroundStyle(Theme.secondary)
                if meaning != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showsHelp.toggle() }
                    } label: {
                        Image(systemName: showsHelp ? "questionmark.circle.fill" : "questionmark.circle")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.infoText)
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        showsHelp
                            ? "Hide what \(title.lowercased()) answers mean" : "What \(title.lowercased()) answers mean"
                    )
                    .a11y(.chipHelp, key: title)
                }
            }
            if showsHelp, let meaning {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        let name = Text(label(option)).fontWeight(.semibold).foregroundStyle(Theme.text)
                        Text("\(name)  \(meaning(option))")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .transition(.opacity)
            }
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
                            .background(
                                selected ? Theme.infoFill : Theme.raised,
                                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            )
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

struct VolumeChart: View {
    let volumes: [MuscleVolume]

    var body: some View {
        let scale = Double(volumes.map { max($0.muscle.landmarks.mrv, $0.planned, $0.done) }.max() ?? 1)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(volumes) { VolumeRow(volume: $0, scale: scale) }
            HStack(spacing: 12) {
                swatch(Theme.infoText, "Done")
                swatch(Theme.infoFill, "Planned")
                swatch(Theme.success, "Productive")
                tick(Theme.text.opacity(0.7), "Minimum")
                tick(Theme.danger, "Maximum")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.secondary)
        }
    }

    private func tick(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 2, height: 10)
            Text(text)
        }
    }

    private func swatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

private struct VolumeRow: View {
    let volume: MuscleVolume
    let scale: Double

    var body: some View {
        let landmarks = volume.muscle.landmarks
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
                        Rectangle().fill(Theme.text.opacity(0.7)).frame(width: 2, height: 14)
                            .offset(x: x(landmarks.mev) - 1)
                        Rectangle().fill(Theme.danger).frame(width: 2, height: 14)
                            .offset(x: x(landmarks.mrv) - 1)
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
        .accessibilityLabel(
            "\(volume.muscle.displayName), \(volume.done) of \(volume.planned) sets done, minimum effective \(landmarks.mev), maximum recoverable \(landmarks.mrv)"
        )
    }
}

extension View {
    /// A sheet passes `Theme.page` to both `themedList` and `themedRow`.
    func themedList(background: Color = Theme.surface) -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(background)
    }

    /// One edge-to-edge row in a tab-root browse list (Mesos, Templates, Exercises): gutter inset, hairline below.
    func browseRow() -> some View {
        padding(.horizontal, Theme.gutter)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    func themedRow(vertical: CGFloat = 12, background: Color = Theme.surface) -> some View {
        alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .listRowBackground(background)
            .listRowSeparatorTint(Theme.hairline)
            .listRowInsets(EdgeInsets(top: vertical, leading: Theme.gutter, bottom: vertical, trailing: Theme.gutter))
    }
}

struct EquipmentScopeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(isOn ? "Showing your equipment" : "Showing all equipment")
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button(isOn ? "Show All" : "My Equipment") { isOn.toggle() }
                .font(Theme.body)
                .foregroundStyle(Theme.infoText)
                .a11y(.equipmentFilter)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 44)
    }
}

/// The app's one empty state: an icon over a title, a message, and the screen's next steps.
struct EmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    let message: String
    let actions: Actions

    init(
        _ title: String, systemImage: String, message: String, @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            // ContentUnavailableView offers its actions their ideal width, which shrinks wide buttons to their text.
            VStack(spacing: 12) { actions }
                .containerRelativeFrame(.horizontal) { width, _ in min(width - Theme.gutter * 4, 320) }
        }
    }
}

extension EmptyState where Actions == EmptyView {
    init(_ title: String, systemImage: String, message: String) {
        self.init(title, systemImage: systemImage, message: message) { EmptyView() }
    }
}

/// The trailing chevron on every row that opens a screen.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .accessibilityHidden(true)
    }
}

/// The section names for saved and built-in templates, shared by the Templates tab and the builder.
enum TemplateGroup {
    static let custom = "Your templates"
    static let builtIn = "FFive templates"
}
