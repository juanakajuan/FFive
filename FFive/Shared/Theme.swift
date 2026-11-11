import FFiveCore
import SwiftUI
import UIKit

enum Theme {
    static let page = Color(light: 0xEDEEF0, dark: 0x0A0A0B)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161718)
    static let raised = Color(light: 0xE5E6E9, dark: 0x222326)
    static let field = Color(light: 0xF1F2F4, dark: 0x0A0A0B)
    static let text = Color(light: 0x111214, dark: 0xF3F5F7)
    static let secondary = Color(light: 0x111214, dark: 0xF3F5F7, lightAlpha: 0.62, darkAlpha: 0.55)
    static let hairline = Color(light: 0x111214, dark: 0xF4F6F8, lightAlpha: 0.14, darkAlpha: 0.1)
    static let infoFill = Color(light: 0xDCE1FA, dark: 0x3D4576)
    static let infoText = Color(light: 0x3346B8, dark: 0x7D8FF2)
    static let noteFill = Color(light: 0xF1E3B5, dark: 0x746539)
    static let success = Color(light: 0x237A54, dark: 0x2E8B62)
    static let danger = Color(light: 0xC62F33, dark: 0xE5484D)
    static let accent = Color(light: 0x2F6FEB, dark: 0x2F6FEB)
    /// The unlit body in a muscle icon, which sits on a tinted tag.
    static let figure = Color(light: 0x111214, dark: 0x0A0A0B, lightAlpha: 0.22, darkAlpha: 0.6)
    /// Text and glyphs drawn on an accent, danger or success fill.
    static let onAccent = Color.white
    /// An empty cell or an empty bar in a chart.
    static let faint = Theme.text.opacity(0.2)

    /// A control that can't be used, or a set or exercise that is locked or skipped.
    static let dimmed: Double = 0.4
    static let pressed: Double = 0.7

    static let cornerRadius: CGFloat = 4
    static let gutter: CGFloat = 16
    /// The inset inside a raised box or a field: grouped cards, stat tiles, panels, text inputs.
    static let rowInset: CGFloat = 12

    static let screenTitle = Font.system(size: 26, weight: .bold)
    static let heroTitle = Font.system(size: 22, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .bold)
    /// The title of a tappable row or a button.
    static let rowTitle = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 16)
    static let detail = Font.system(size: 14)
    static let columnHeader = Font.system(size: 14, weight: .medium)
    static let tag = Font.system(size: 12, weight: .semibold)
    static let caption = Font.system(size: 12)

    static func applyNavigationBarAppearance() {
        let text = UIColor(Theme.text)
        let surface = UIColor(Theme.surface)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = surface
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.largeTitleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 26, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = nav
        // An opaque scroll-edge appearance hides large titles over scrolling content, so the edge state is
        // transparent over the same color.
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.backgroundColor = surface
        edge.titleTextAttributes = nav.titleTextAttributes
        edge.largeTitleTextAttributes = nav.largeTitleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = edge
        UINavigationBar.appearance().compactAppearance = nav
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        let light = UIColor(rgb: light, alpha: lightAlpha)
        let dark = UIColor(rgb: dark, alpha: darkAlpha)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .light ? light : dark })
    }
}

extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

extension Muscle {
    var tint: Color {
        switch self {
        case .chest, .frontDelts, .sideDelts, .rearDelts, .triceps: Color(light: 0xB8231A, dark: 0xFB4934)
        case .back, .biceps, .traps, .forearms: Color(light: 0x2F6B5E, dark: 0x83A598)
        case .quads, .hamstrings, .glutes: Color(light: 0x5E6B0C, dark: 0xB8BB26)
        case .calves, .abs: Color(light: 0x9B3F6A, dark: 0xD3869B)
        }
    }
}

struct MuscleTag: View {
    let muscle: Muscle

    var body: some View {
        HStack(spacing: 6) {
            MuscleIcon(muscle: muscle)
            Text(muscle.displayName)
                .font(Theme.tag)
                .textCase(.uppercase)
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background {
            // Opaque, so a tag hanging over a card's edge hides the edge behind it.
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(muscle.tint.opacity(0.314)))
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(muscle.tint.opacity(0.6), lineWidth: 1))
        .fixedSize()
    }
}

struct MuscleDotLabel: View {
    let muscle: Muscle

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(muscle.tint).frame(width: 7, height: 7)
            Text(muscle.displayName).foregroundStyle(muscle.tint)
        }
        .font(Theme.caption.weight(.medium))
    }
}

/// How a card insets its content.
enum CardInset {
    /// The gutter on every side.
    case gutter
    /// The gutter on top and a short bottom only, for a card of rows that set their own horizontal inset
    /// so hairlines and set rows can run edge to edge.
    case rows
}

/// The one card: every card on every screen draws through this modifier.
struct SurfaceCard: ViewModifier {
    var inset: CardInset

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, inset == .gutter ? Theme.gutter : 0)
            .padding(.top, Theme.gutter)
            .padding(.bottom, inset == .gutter ? Theme.gutter : 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// The one divider: a 1 pt hairline the width of its container.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

struct ThemedField: ViewModifier {
    var height: CGFloat = 32

    func body(content: Content) -> some View {
        content
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 4)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    func surfaceCard(_ inset: CardInset = .gutter) -> some View { modifier(SurfaceCard(inset: inset)) }

    func surfaceCard(_ inset: CardInset = .gutter, tag muscle: Muscle?) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceCard(inset)
            if let muscle {
                MuscleTag(muscle: muscle)
                    .alignmentGuide(.top) { $0.height / 2 }
                    .padding(.leading, Theme.gutter)
            }
        }
    }
    func themedField(height: CGFloat = 32) -> some View { modifier(ThemedField(height: height)) }

    /// A leading-aligned text field in a form: a name, a cue.
    func formField() -> some View {
        font(Theme.body)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.rowInset)
            .padding(.vertical, 8)
            .frame(minHeight: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.hairline, lineWidth: 1))
    }
}

struct LogCheckbox: View {
    let status: SetStatus

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius)
        shape
            .fill(status == .done ? Theme.success : Color.clear)
            .overlay {
                switch status {
                case .pending: shape.stroke(Theme.secondary, lineWidth: 2)
                case .done: shape.stroke(Theme.success, lineWidth: 2)
                case .skipped: shape.stroke(Theme.secondary, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                }
            }
            .overlay {
                switch status {
                case .pending: EmptyView()
                case .done:
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(
                        Theme.onAccent)
                case .skipped:
                    Image(systemName: "forward.end.fill").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .frame(width: 24, height: 24)
    }
}

struct Callout: View {
    enum Style {
        case info, note, pinned

        var fill: Color {
            switch self {
            case .info: Theme.infoFill
            case .note: Theme.raised
            case .pinned: Theme.noteFill
            }
        }
    }

    let text: String
    var systemImage: String = "info.circle.fill"
    var style: Style = .info

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 15)).accessibilityHidden(true)
            Text(text).font(style == .info ? Theme.caption : Theme.detail)
            Spacer(minLength: 0)
        }
        .foregroundStyle(style == .info ? Theme.infoText : Theme.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.fill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

struct StatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.caption)
            .textCase(.uppercase)
            .tracking(0.3)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Theme.infoFill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .fixedSize()
    }
}

struct CountPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.caption.weight(.medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .fixedSize()
    }
}

struct SearchBox: View {
    var prompt = "Search"
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.secondary))
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .autocorrectionDisabled()
            .padding(.horizontal, Theme.rowInset)
            .frame(height: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .accessibilityLabel(prompt)
    }
}

struct FilterBar<MenuContent: View>: View {
    var label = "Filters"
    let menu: MenuContent

    init(label: String = "Filters", @ViewBuilder menu: () -> MenuContent) {
        self.label = label
        self.menu = menu()
    }

    var body: some View {
        Menu {
            menu
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(label)
                Spacer()
            }
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 7)
            .background(Theme.raised)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.surface).frame(height: 1) }
        }
    }
}

/// The one grouped box for settings-style menus. It owns the inner `rowInset`, so rows add no horizontal
/// padding; callers own the outer gutter. Tab-root browse lists use edge-to-edge rows instead.
struct GroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, Theme.rowInset)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// The one section heading. It owns its spacing, so callers add only horizontal padding.
/// In a `List`, give its row `themedRow(vertical: 0)`.
struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.cardTitle)
            .foregroundStyle(Theme.text)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A section heading over a grouped card, for a screen built from a `ScrollView`.
struct GroupedSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(text: title)
            GroupedCard { content }
        }
    }
}

struct ScreenHeader<Trailing: View>: ViewModifier {
    let title: String
    let trailing: Trailing

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Text(title)
                        .font(Theme.screenTitle)
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    trailing
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.surface)
            }
    }
}

struct HeaderAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

extension View {
    func screenHeader(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        modifier(ScreenHeader(title: title, trailing: trailing()))
    }

    func screenHeader(_ title: String) -> some View {
        modifier(ScreenHeader(title: title, trailing: EmptyView()))
    }
}
