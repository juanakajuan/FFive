import FFiveCore
import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Environment(Store.self) private var store
    @Query(CustomTemplate.all) private var customTemplates: [CustomTemplate]

    @State private var search = ""
    @State private var daysPerWeek: Int?
    @State private var emphasis: TemplateEmphasis?
    @State private var builder: MesoBuilderView.Route?
    @State private var renaming: CustomTemplate?
    @State private var renameDraft = ""
    @State private var deleting: CustomTemplate?

    private static let dayCounts = Set(ExerciseCatalog.templates.map(\.days.count)).sorted()
    private static let emphases = TemplateEmphasis.allCases.filter { emphasis in
        ExerciseCatalog.templates.contains { $0.emphasis == emphasis }
    }

    private var filterLabel: String {
        let active = [daysPerWeek.map { "\($0)/week" }, emphasis?.displayName].compactMap { $0 }
        return active.isEmpty ? "Filters" : active.joined(separator: " · ")
    }

    /// A custom template has no emphasis, so it drops out while an emphasis filter is on.
    private func matches(_ template: ProgramTemplate) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        return (daysPerWeek == nil || template.days.count == daysPerWeek)
            && (emphasis == nil || template.emphasis == emphasis)
            && (query.isEmpty || template.name.localizedCaseInsensitiveContains(query))
    }

    var body: some View {
        let builtIn = ExerciseCatalog.templates.filter(matches)
        let custom = customTemplates.filter { matches($0.template) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeading(text: TemplateGroup.custom)
                        .padding(.horizontal, Theme.gutter)
                    if customTemplates.isEmpty {
                        emptyNote("Save a mesocycle or a builder draft as a template and it shows up here.")
                    } else if custom.isEmpty {
                        emptyNote("None of your templates match.")
                    } else {
                        ForEach(custom) { saved in
                            customRow(saved).browseRow()
                        }
                    }
                    SectionHeading(text: TemplateGroup.builtIn)
                        .padding(.horizontal, Theme.gutter)
                    if builtIn.isEmpty {
                        emptyNote("No templates match.")
                    } else {
                        ForEach(builtIn) { template in
                            NavigationLink(value: TemplatePreviewScreen.Subject.builtIn(template)) {
                                TemplateListRow(template: template)
                            }
                            .buttonStyle(.plain)
                            .a11y(.templatesTemplate, key: template.name)
                            .browseRow()
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
                        .pickerStyle(.menu)
                        Picker("Emphasis", selection: $emphasis) {
                            Text("All").tag(TemplateEmphasis?.none)
                            ForEach(Self.emphases) { Text($0.displayName).tag(TemplateEmphasis?.some($0)) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .background(Theme.surface)
            }
            .background(Theme.surface)
            .screenHeader("Templates") {
                HeaderAddButton(label: "New Template") { builder = .blank }
                    .a11y(.templatesNew)
            }
            .navigationDestination(for: TemplatePreviewScreen.Subject.self) { TemplatePreviewScreen(subject: $0) }
            .sheet(item: $builder) { MesoBuilderView(startAt: $0) }
            .alert(
                "Rename Template",
                isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
            ) {
                TextField("Template name", text: $renameDraft)
                Button("Save") {
                    if let renaming { store.rename(renaming, to: renameDraft) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete this template?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible, presenting: deleting
            ) { saved in
                Button("Delete Template", role: .destructive) { store.delete(saved) }
                    .a11y(.dialogDeleteTemplate)
            } message: { saved in
                Text("\(saved.name) is removed from your templates. Mesocycles started from it keep their plan.")
            }
        }
    }

    private func customRow(_ saved: CustomTemplate) -> some View {
        let template = saved.template
        return HStack(spacing: 12) {
            NavigationLink(value: TemplatePreviewScreen.Subject.custom(saved)) {
                TemplateListRow(template: template)
            }
            .buttonStyle(.plain)
            .a11y(.templatesCustom, key: saved.name)

            Menu {
                Button("Copy", systemImage: "doc.on.doc") { builder = .editTemplate(store.copyTemplate(template)) }
                    .a11y(.menuCopyTemplate)
                Button("Rename", systemImage: "pencil") {
                    renameDraft = saved.name
                    renaming = saved
                }
                .a11y(.menuRenameTemplate)
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = saved }
                    .a11y(.menuDeleteTemplate)
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.text)
                    .frame(width: 24, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(saved.name) menu")
            .a11y(.templatesMenu, key: saved.name)
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(Theme.detail)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, Theme.gutter)
    }
}

struct TemplateListRow: View {
    let template: ProgramTemplate
    /// False where the row is a header rather than a link.
    var opensScreen = true

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if template.emphasis != nil {
                        Image("Logo")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .accessibilityHidden(true)
                    }
                    Image(systemName: template.emphasis == nil ? "person" : "target")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(template.emphasis?.displayName.uppercased() ?? "CUSTOM")
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
            if opensScreen { RowChevron() }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

extension MesoBuilderView.Route: Identifiable {
    var id: Self { self }
}

#Preview {
    let store = Store(inMemory: true)
    return TemplatesView()
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}
