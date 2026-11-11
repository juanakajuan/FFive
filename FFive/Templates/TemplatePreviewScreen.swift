import FFiveCore
import SwiftUI

/// A read-only look at a template's days, exercises and weekly muscle focus, with the way into the builder.
struct TemplatePreviewScreen: View {
    enum Subject: Hashable {
        case builtIn(ProgramTemplate)
        case custom(CustomTemplate)
    }

    let subject: Subject

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay = 0
    @State private var builder: MesoBuilderView.Route?
    @State private var renaming: TemplateRename?
    @State private var deleting: CustomTemplate?

    private var saved: CustomTemplate? {
        if case .custom(let saved) = subject { saved } else { nil }
    }

    /// Nil once a custom template is deleted, while the screen pops.
    private var template: ProgramTemplate? {
        switch subject {
        case .builtIn(let template): template
        case .custom(let saved): saved.isDeleted || saved.modelContext == nil ? nil : saved.template
        }
    }

    var body: some View {
        Group {
            if let template {
                content(template)
            } else {
                Theme.surface
            }
        }
        .background(Theme.surface)
        .navigationTitle(template?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let template {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Template Menu", systemImage: "ellipsis.circle") {
                        if let saved {
                            Button("Edit", systemImage: Symbol.edit) { builder = .editTemplate(saved) }
                                .a11y(.menuEditTemplate)
                        }
                        TemplateMenuItems(
                            template: template, saved: saved, builder: $builder, renaming: $renaming,
                            deleting: $deleting
                        )
                    }
                    .a11y(.templatePreviewMenu)
                }
            }
        }
        .sheet(item: $builder) { MesoBuilderView(startAt: $0) }
        .templateActions(renaming: $renaming, deleting: $deleting, store: store) { dismiss() }
    }

    private func content(_ template: ProgramTemplate) -> some View {
        let dayIndex = min(selectedDay, template.days.count - 1)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TemplateListRow(template: template, opensScreen: false)
                    .padding(.horizontal, Theme.gutter)
                if template.emphasis != nil {
                    Text(template.summary)
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, Theme.gutter)
                }
                SectionHeading(text: "Days")
                    .padding(.horizontal, Theme.gutter)
                DayTabs(days: template.days.map(\.name), selection: $selectedDay)
                if template.days.indices.contains(dayIndex) {
                    GroupedCard {
                        let slots = template.days[dayIndex].slots
                        ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.exercise).font(Theme.body).foregroundStyle(Theme.text)
                                MuscleDotLabel(muscle: slot.muscle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                            if index < slots.count - 1 {
                                Hairline()
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 10)
                }
                SectionHeading(text: "Muscle Focus")
                    .padding(.horizontal, Theme.gutter)
                MuscleFocusCard(counts: template.weeklyExercises)
            }
            .padding(.bottom, Theme.gutter)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Plan a Mesocycle") { builder = .template(template) }
                .buttonStyle(.primary)
                .a11y(.templatePreviewPlan)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .overlay(alignment: .top) { Hairline() }
        }
    }

}

/// One tab per day, scrolling sideways when the names run past the screen.
private struct DayTabs: View {
    let days: [String]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, name in
                    let selected = index == min(selection, days.count - 1)
                    Button {
                        selection = index
                    } label: {
                        Text(name)
                            .font(Theme.detail.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(selected ? Theme.text : Theme.secondary)
                            .padding(.horizontal, Theme.rowInset)
                            .frame(minHeight: 32)
                            .background(
                                selected ? Theme.raised : Theme.field,
                                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .a11y(.templatePreviewDay, index + 1)
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A bar per muscle, as long as its share of the week's exercises next to the most trained muscle.
private struct MuscleFocusCard: View {
    let counts: [(muscle: Muscle, count: Int)]

    var body: some View {
        let most = counts.map(\.count).max() ?? 1
        GroupedCard {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(counts, id: \.muscle) { entry in
                    HStack(spacing: 10) {
                        MuscleDotLabel(muscle: entry.muscle)
                            .font(Theme.detail)
                            .frame(width: 110, alignment: .leading)
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.field)
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .fill(entry.muscle.tint)
                                        .frame(width: geometry.size.width * CGFloat(entry.count) / CGFloat(most))
                                }
                            }
                        Text("\(entry.count)")
                            .font(Theme.caption.monospaced())
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 20, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(entry.muscle.displayName), \(entry.count) \(entry.count == 1 ? "exercise" : "exercises") a week"
                    )
                }
                Text("Exercises a week for each muscle. Set priorities in the builder once you plan.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, Theme.gutter)
    }
}
