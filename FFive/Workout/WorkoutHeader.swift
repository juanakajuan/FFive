import SwiftUI

struct WorkoutHeader<Trailing: View>: View {
    let title: Text
    let subtitle: Text
    var progress: Double?
    let trailing: Trailing

    init(title: Text, subtitle: Text, progress: Double? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(Theme.screenTitle)
                    .foregroundStyle(Theme.text)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                subtitle
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 20) { trailing }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { ProgressLine(progress: progress) }
    }
}

private struct ProgressLine: View {
    let progress: Double?

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Theme.success)
                .frame(width: proxy.size.width * min(max(progress ?? 0, 0), 1))
        }
        .frame(height: 2)
        .background(Theme.hairline)
        .animation(.snappy, value: progress)
        .accessibilityElement()
        .accessibilityLabel("Workout progress")
        .accessibilityValue(Text((progress ?? 0).formatted(.percent.precision(.fractionLength(0)))))
        .accessibilityHidden(progress == nil)
    }
}

struct ActionIcon: View {
    let systemName: String
    var rotated = false
    var tint = Theme.text

    static let verticalEllipsis = ActionIcon(systemName: "ellipsis", rotated: true)

    /// The ⓘ detail icon, tinted like every other ⓘ and text link.
    static func info(filled: Bool) -> ActionIcon {
        ActionIcon(systemName: filled ? "info.circle.fill" : "info.circle", tint: Theme.infoText)
    }

    static var calendar: ActionIcon {
        if #available(iOS 26, *) {
            return ActionIcon(systemName: "\(Calendar.current.component(.day, from: .now)).calendar")
        }
        return ActionIcon(systemName: "calendar")
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22))
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}

struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rowTitle)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.accent, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? Theme.pressed : 1)
    }
}

extension ButtonStyle where Self == FloatingButtonStyle {
    static var floating: FloatingButtonStyle { FloatingButtonStyle() }
}
