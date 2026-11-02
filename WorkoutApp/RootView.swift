import SwiftUI

struct RootView: View {
    private enum Tab { case train, progress, learn }

    @State private var tab: Tab = [.progress, .strength].contains(DemoLaunch.route) ? .progress : .train

    var body: some View {
        TabView(selection: $tab) {
            TrainView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
                .tag(Tab.train)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(Tab.progress)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(Tab.learn)
        }
    }
}
