import SwiftUI
import UIKit

/// The app's palette and type scale. Every screen draws from these tokens instead of system grouped colors.
enum Theme {
    /// Behind cards on the workout screen.
    static let page = Color(rgb: 0x131416)
    /// Cards, list screens, navigation bar, and tab bar.
    static let surface = Color(rgb: 0x252627)
    /// Filter bars, pills, and grouped cards that sit on `surface`.
    static let raised = Color(rgb: 0x2F2F32)
    /// Text fields and search fields.
    static let field = Color(rgb: 0x131416)
    static let text = Color(rgb: 0xF3F5F7)
    static let secondary = Color(rgb: 0xF3F5F7).opacity(0.55)
    static let hairline = Color(rgb: 0xF4F6F8).opacity(0.1)
    static let infoFill = Color(rgb: 0x3D4576)
    static let infoText = Color(rgb: 0x7D8FF2)
    static let noteFill = Color(rgb: 0x746539)
    static let success = Color(rgb: 0x2E8B62)
    static let danger = Color(rgb: 0xE5484D)

    static let cornerRadius: CGFloat = 4
    static let gutter: CGFloat = 16

    static let screenTitle = Font.system(size: 26, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .bold)
    static let body = Font.system(size: 16)
    static let detail = Font.system(size: 14)
    static let columnHeader = Font.system(size: 14, weight: .medium)
    static let tag = Font.system(size: 12, weight: .semibold)
    static let caption = Font.system(size: 12)

    /// The navigation bar appearance is UIKit-wide, so it is set once at launch.
    static func applyNavigationBarAppearance() {
        let text = UIColor(Theme.text)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Theme.surface)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.largeTitleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 26, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = nav
        // An opaque scroll-edge appearance hides large titles over scrolling content, so the edge state is
        // transparent over the same color.
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.backgroundColor = UIColor(Theme.surface)
        edge.titleTextAttributes = nav.titleTextAttributes
        edge.largeTitleTextAttributes = nav.largeTitleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = edge
        UINavigationBar.appearance().compactAppearance = nav
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

extension Muscle {
    /// Muscles share a color by region: pushing muscles, pulling muscles, legs, and calves with abs.
    var tint: Color {
        switch self {
        case .chest, .frontDelts, .sideDelts, .rearDelts, .triceps: Color(rgb: 0xE03EC3)
        case .back, .biceps, .traps, .forearms: Color(rgb: 0x24B8D9)
        case .quads, .hamstrings, .glutes: Color(rgb: 0x2FB890)
        case .calves, .abs: Color(rgb: 0x7C49F0)
        }
    }
}

/// The colored label above each exercise card.
struct MuscleTag: View {
    let muscle: Muscle

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .bold))
                .rotationEffect(.degrees(90))
                .foregroundStyle(muscle.tint)
            Text(muscle.displayName)
                .font(Theme.tag)
                .textCase(.uppercase)
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(muscle.tint.opacity(0.314), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .fixedSize()
    }
}

/// A dot and colored muscle name, as in exercise list rows.
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

/// A full-width card on the `page` background.
struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// A dark input box, used for set weight and reps.
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
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    func surfaceCard() -> some View { modifier(SurfaceCard()) }
    func themedField(height: CGFloat = 32) -> some View { modifier(ThemedField(height: height)) }
}

/// The square log toggle at the end of each set row.
struct LogCheckbox: View {
    let isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isOn ? Theme.success : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(isOn ? Theme.success : Theme.secondary, lineWidth: 2))
            .overlay {
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
    }
}

/// A tinted strip inside a card: blue for guidance, gold for a note the lifter saved.
struct Callout: View {
    enum Style { case info, note }

    let text: String
    var systemImage: String = "info.circle.fill"
    var style: Style = .info

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 15))
            Text(text).font(style == .info ? Theme.caption : Theme.detail)
            Spacer(minLength: 0)
        }
        .foregroundStyle(style == .info ? Theme.infoText : Theme.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style == .info ? Theme.infoFill : Theme.noteFill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// A small uppercase label such as CURRENT.
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
            .background(Theme.infoFill, in: RoundedRectangle(cornerRadius: 2))
            .fixedSize()
    }
}

/// A compact count such as "4/week".
struct CountPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.caption.weight(.medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }
}

/// The dark search box at the top of list screens.
struct SearchBox: View {
    var prompt = "Search"
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.secondary))
            .font(Theme.body)
            .foregroundStyle(Theme.text)
            .autocorrectionDisabled()
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .accessibilityLabel(prompt)
    }
}

/// The full-width band under the search box that opens filter choices.
struct FilterBar<MenuContent: View>: View {
    var label = "Filters"
    @ViewBuilder var menu: () -> MenuContent

    var body: some View {
        Menu(content: menu) {
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

/// A bordered group of rows, as on the More screen.
struct OutlinedGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// A screen section heading such as "Account".
struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
