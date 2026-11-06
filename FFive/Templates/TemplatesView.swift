import FFiveCore
import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]

    @State private var search = ""
    @State private var daysPerWeek: Int?
    @State private var emphasis: TemplateEmphasis?
    @State private var builder: MesoBuilderView.Route?

    private static let dayCounts = Set(ExerciseCatalog.templates.map(\.days.count)).sorted()
    private static let emphases = TemplateEmphasis.allCases.filter { emphasis in
        ExerciseCatalog.templates.contains { $0.emphasis == emphasis }
    }

    private var filterLabel: String {
        let active = [daysPerWeek.map { "\($0)/week" }, emphasis?.displayName].compactMap { $0 }
        return active.isEmpty ? "Filters" : active.joined(separator: " · ")
    }

    private var templates: [ProgramTemplate] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return ExerciseCatalog.templates
            .filter { daysPerWeek == nil || $0.days.count == daysPerWeek }
            .filter { emphasis == nil || $0.emphasis == emphasis }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        let templates = templates
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeading(text: "FFive templates")
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    if templates.isEmpty {
                        Text("No templates match.")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, Theme.gutter)
                    } else {
                        TemplateGroup {
                            ForEach(templates) { template in
                                Button {
                                    builder = .template(template.name)
                                } label: {
                                    TemplateListRow(template: template)
                                }
                                .buttonStyle(.plain)
                                if template.id != templates.last?.id {
                                    Rectangle().fill(Theme.hairline).frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, Theme.gutter)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    SearchBox(text: $search)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 12)
                    FilterBar(label: filterLabel) {
                        Picker("Days per week", selection: $daysPerWeek) {
                            Text("All").tag(Int?.none)
                            ForEach(Self.dayCounts, id: \.self) { Text("\($0)/week").tag(Int?.some($0)) }
                        }
                        Picker("Emphasis", selection: $emphasis) {
                            Text("All").tag(TemplateEmphasis?.none)
                            ForEach(Self.emphases) { Text($0.displayName).tag(TemplateEmphasis?.some($0)) }
                        }
                    }
                }
                .background(Theme.surface)
            }
            .background(Theme.surface)
            .screenHeader("Templates") {
                HeaderAddButton(label: "New Mesocycle") { builder = .blank }
                    .disabled(!activeMesos.isEmpty)
                    .a11y(.mesosNew)
            }
            .sheet(item: $builder) { MesoBuilderView(startAt: $0) }
        }
    }
}

struct TemplateGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 12)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, Theme.gutter)
    }
}

struct TemplateListRow: View {
    let template: ProgramTemplate

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(template.emphasis.displayName.uppercased())
                        .font(.system(size: 11.5, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.secondary)
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            CountPill(text: "\(template.days.count)/week")
                // The pill shares the card's raised fill, so lift it to stay visible.
                .brightness(0.07)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

extension MesoBuilderView.Route: Identifiable {
    var id: Self { self }
}

#Preview {
    TemplatesView()
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
