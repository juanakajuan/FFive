import SwiftUI

/// The flat bar pinned to the top of the Workout tab, standing in for a navigation bar. Its fill runs up under
/// the status bar, and its bottom edge doubles as the session's progress line.
struct WorkoutHeader<Trailing: View>: View {
    let title: Text
    let subtitle: Text
    /// The share of the session's sets logged, from 0 to 1; nil draws only the hairline.
    var progress: Double?
    @ViewBuilder var trailing: () -> Trailing

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
            HStack(spacing: 20, content: trailing)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 16)
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

/// An outline glyph sized for header and card actions.
struct ActionIcon: View {
    let systemName: String
    var rotated = false

    static let verticalEllipsis = ActionIcon(systemName: "ellipsis", rotated: true)

    /// A calendar showing today's day of the month, where the system has those glyphs.
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
            .foregroundStyle(Theme.text)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}

/// Full-width buttons for the Workout tab's empty states.
struct WideButtonStyle: ButtonStyle {
    enum Kind { case filled, outlined }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        WideButtonLabel(kind: kind, isPressed: configuration.isPressed) { configuration.label }
    }
}

private struct WideButtonLabel<Label: View>: View {
    let kind: WideButtonStyle.Kind
    let isPressed: Bool
    @ViewBuilder var label: () -> Label
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label()
            .font(Theme.body.weight(.semibold))
            .foregroundStyle(kind == .filled ? Theme.page : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                kind == .filled ? Theme.text : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                if kind == .outlined {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.secondary, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.35)
    }
}

extension ButtonStyle where Self == WideButtonStyle {
    static var wideFilled: WideButtonStyle { WideButtonStyle(kind: .filled) }
    static var wideOutlined: WideButtonStyle { WideButtonStyle(kind: .outlined) }
}

/// A blue capsule that floats over the content beneath it: the workout's Finish button.
struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.accent, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == FloatingButtonStyle {
    static var floating: FloatingButtonStyle { FloatingButtonStyle() }
}
