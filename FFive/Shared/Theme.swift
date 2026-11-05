import FFiveCore
import SwiftUI
import UIKit

enum Theme {
    static let page = Color(rgb: 0x0A0A0B)
    static let surface = Color(rgb: 0x161718)
    static let raised = Color(rgb: 0x222326)
    static let field = Color(rgb: 0x0A0A0B)
    static let text = Color(rgb: 0xF3F5F7)
    static let secondary = Color(rgb: 0xF3F5F7).opacity(0.55)
    static let hairline = Color(rgb: 0xF4F6F8).opacity(0.1)
    static let infoFill = Color(rgb: 0x3D4576)
    static let infoText = Color(rgb: 0x7D8FF2)
    static let noteFill = Color(rgb: 0x746539)
    static let success = Color(rgb: 0x2E8B62)
    static let danger = Color(rgb: 0xE5484D)
    static let accent = Color(rgb: 0x2F6FEB)

    static let cornerRadius: CGFloat = 4
    static let gutter: CGFloat = 16

    static let screenTitle = Font.system(size: 26, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .bold)
    static let body = Font.system(size: 16)
    static let detail = Font.system(size: 14)
    static let columnHeader = Font.system(size: 14, weight: .medium)
    static let tag = Font.system(size: 12, weight: .semibold)
    static let caption = Font.system(size: 12)

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
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255)
    }
}

extension Muscle {
    var tint: Color {
        switch self {
        case .chest, .frontDelts, .sideDelts, .rearDelts, .triceps: Color(rgb: 0xFB4934)
        case .back, .biceps, .traps, .forearms: Color(rgb: 0x83A598)
        case .quads, .hamstrings, .glutes: Color(rgb: 0xB8BB26)
        case .calves, .abs: Color(rgb: 0xD3869B)
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

struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    func surfaceCard() -> some View { modifier(SurfaceCard()) }

    func surfaceCard(tag muscle: Muscle?) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceCard()
            if let muscle {
                MuscleTag(muscle: muscle)
                    .alignmentGuide(.top) { $0.height / 2 }
                    .padding(.leading, Theme.gutter)
            }
        }
    }
    func themedField(height: CGFloat = 32) -> some View { modifier(ThemedField(height: height)) }
}

struct LogCheckbox: View {
    let status: SetStatus

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3)
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
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
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
            .background(Theme.infoFill, in: RoundedRectangle(cornerRadius: 2))
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
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 3))
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
            .padding(.leading, 12)
            .padding(.trailing, 16)
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

struct OutlinedGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 1))
    }
}

struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
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
