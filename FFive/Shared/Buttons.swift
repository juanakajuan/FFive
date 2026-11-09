import SwiftUI

/// The full-width action buttons. Primary is filled, secondary is outlined and turns red for a destructive role.
struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    static let height: CGFloat = 48

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonLabel(
            kind: kind, isDestructive: configuration.role == .destructive, isPressed: configuration.isPressed
        ) { configuration.label }
    }
}

private struct ActionButtonLabel<Label: View>: View {
    let kind: ActionButtonStyle.Kind
    let isDestructive: Bool
    let isPressed: Bool
    let label: Label
    @Environment(\.isEnabled) private var isEnabled

    init(kind: ActionButtonStyle.Kind, isDestructive: Bool, isPressed: Bool, @ViewBuilder label: () -> Label) {
        self.kind = kind
        self.isDestructive = isDestructive
        self.isPressed = isPressed
        self.label = label()
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.page
        case .secondary: isDestructive ? Theme.danger : Theme.text
        }
    }

    var body: some View {
        label
            .font(Theme.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: ActionButtonStyle.height)
            .background(
                kind == .primary ? Theme.text : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.secondary, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? (isPressed ? 0.7 : 1) : 0.35)
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    static var primary: ActionButtonStyle { ActionButtonStyle(kind: .primary) }
    static var secondary: ActionButtonStyle { ActionButtonStyle(kind: .secondary) }
}
