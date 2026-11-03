import SwiftUI

/// The card at the top of the Workout tab, standing in for a navigation bar.
struct WorkoutHeader<Trailing: View>: View {
    let title: Text
    let subtitle: Text
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .textCase(.uppercase)
                subtitle
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 16, content: trailing)
                .padding(.top, 2)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard()
    }
}

/// An outline glyph sized for header and card actions.
struct ActionIcon: View {
    let systemName: String
    var rotated = false

    static let verticalEllipsis = ActionIcon(systemName: "ellipsis", rotated: true)

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20))
            .rotationEffect(.degrees(rotated ? 90 : 0))
            .foregroundStyle(Theme.text)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}

/// Full-width buttons at the bottom of the workout stream and in its empty states.
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
            .background(kind == .filled ? Theme.text : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
