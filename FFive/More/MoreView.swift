import FFiveCore
import SwiftUI

struct MoreView: View {
    private enum Destination: Hashable {
        case progress, learn, settings, changelog

        var a11y: A11y {
            switch self {
            case .progress: .moreProgress
            case .learn: .moreLearn
            case .settings: .moreSettings
            case .changelog: .moreChangelog
            }
        }
    }

    /// Demo launches into Progress land here; ProgressScreen then opens its own strength route.
    @State private var path = NavigationPath(
        DemoLaunch.take(.progress) || DemoLaunch.isPending(.strength) ? [Destination.progress] : [])

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Training") {
                        row("Progress", systemImage: "chart.bar.xaxis", to: .progress)
                        divider
                        row("Learn", systemImage: "book", to: .learn)
                    }
                    section("App") {
                        row("Settings", systemImage: "gearshape", to: .settings)
                        divider
                        row("Changelog", systemImage: "list.bullet.rectangle", to: .changelog)
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1).padding(.top, 24)
                    Text("App version: \(version)")
                        .font(Theme.caption.monospaced())
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 16)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.gutter)
            }
            .background(Theme.surface)
            .screenHeader("More")
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .progress: ProgressScreen()
                case .learn: LearnView()
                case .settings: SettingsView()
                case .changelog: ChangelogScreen()
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
    }

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: @escaping () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(text: title)
            GroupedCard(content: rows)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private func row(_ title: String, systemImage: String, to destination: Destination) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title).font(Theme.body)
                Spacer()
                RowChevron()
            }
            .foregroundStyle(Theme.text)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .a11y(destination.a11y)
    }
}

#Preview {
    MoreView()
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
