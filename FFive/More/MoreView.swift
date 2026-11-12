import FFiveCore
import SwiftUI

struct MoreView: View {
    private enum Destination: Hashable {
        case progress, learn, plateCalculator, settings, changelog

        var a11y: A11y {
            switch self {
            case .progress: .moreProgress
            case .learn: .moreLearn
            case .plateCalculator: .morePlateCalculator
            case .settings: .moreSettings
            case .changelog: .moreChangelog
            }
        }
    }

    /// Demo launches into Progress land here; ProgressScreen then opens its own strength route.
    @State private var path = NavigationPath(
        DemoLaunch.take(.progress) || DemoLaunch.isPending(.strength) ? [Destination.progress] : [])

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GroupedSection("Training") {
                        row("Progress", systemImage: Symbol.progress, to: .progress)
                        Hairline()
                        row("Learn", systemImage: "book", to: .learn)
                        Hairline()
                        row("Plate Calculator", systemImage: "scalemass", to: .plateCalculator)
                    }
                    GroupedSection("App") {
                        row("Settings", systemImage: "gearshape", to: .settings)
                        Hairline()
                        row("Changelog", systemImage: "list.bullet.rectangle", to: .changelog)
                    }
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
                case .plateCalculator: PlateCalculatorScreen()
                case .settings: SettingsView()
                case .changelog: ChangelogScreen()
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        }
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
