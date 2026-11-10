import FFiveCore
import SwiftUI

/// Asks how many days a week the user trains and how each muscle should be trained, then opens the plan that
/// fits in the editor with every slot waiting for an exercise.
struct MesoGuidedView: View {
    var onStart: () -> Void

    @State private var daysPerWeek = 4
    @State private var priorities = Dictionary(
        uniqueKeysWithValues: Muscle.allCases.map { ($0, MusclePriority.guidedDefault(for: $0)) })

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(text: "Days per week")
                Picker("Days per week", selection: $daysPerWeek) {
                    ForEach(Array(MesoDraft.guidedDaysPerWeek), id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .a11y(.builderGuidedDays)
                SectionHeading(text: "Muscles")
                ForEach(Muscle.allCases) { muscle in
                    MusclePriorityRow(muscle: muscle, priority: priorities[muscle] ?? .normal) {
                        priorities[muscle] = $0
                    }
                    if muscle != Muscle.allCases.last {
                        Hairline()
                    }
                }
                Text(
                    "Emphasized muscles train up to 3 times a week, normal ones twice and maintained ones once. "
                        + MusclePriority.explanation
                )
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
                .padding(.top, 10)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("Guided Plan")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                MesoEditorView(draft: MesoDraft(daysPerWeek: daysPerWeek, priorities: priorities), onStart: onStart)
            } label: {
                Text("Build Plan")
            }
            .buttonStyle(.primary)
            .a11y(.builderGuidedBuild)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .overlay(alignment: .top) { Hairline() }
        }
    }
}
