import FFiveCore
import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Environment(Store.self) private var store
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]
    @Query(CustomTemplate.all) private var customTemplates: [CustomTemplate]

    @State private var search = ""
    @State private var daysPerWeek: Int?
    @State private var builder: MesoBuilderView.Route?
    @State private var renaming: CustomTemplate?
    @State private var renameDraft = ""
    @State private var deleting: CustomTemplate?

    private func matches(_ template: ProgramTemplate) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        return (daysPerWeek == nil || template.days.count == daysPerWeek)
            && (query.isEmpty || template.name.localizedCaseInsensitiveContains(query))
    }

    var body: some View {
        let builtIn = ExerciseCatalog.templates.filter(matches)
        let custom = customTemplates.filter { matches($0.template) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading("Custom templates")
                    if customTemplates.isEmpty {
                        emptyNote("Save a mesocycle or a builder draft as a template and it shows up here.")
                    } else if custom.isEmpty {
                        emptyNote("No custom templates match.")
                    } else {
                        TemplateGroup {
                            ForEach(custom) { saved in
                                customRow(saved)
                                if saved.id != custom.last?.id {
                                    Rectangle().fill(Theme.hairline).frame(height: 1)
                                }
                            }
                        }
                    }
                    heading("FFive templates")
                    if builtIn.isEmpty {
                        emptyNote("No templates match.")
                    } else {
                        TemplateGroup {
                            ForEach(builtIn) { template in
                                Button {
                                    builder = .template(template)
                                } label: {
                                    TemplateListRow(template: template)
                                }
                                .buttonStyle(.plain)
                                if template.id != builtIn.last?.id {
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
                    FilterBar(label: daysPerWeek.map { "\($0)/week" } ?? "Filters") {
                        Picker("Days per week", selection: $daysPerWeek) {
                            Text("All").tag(Int?.none)
                            ForEach([3, 4, 5, 6], id: \.self) { Text("\($0)/week").tag(Int?.some($0)) }
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
            Button {
                builder = .template(template)
            } label: {
                TemplateListRow(template: template, isCustom: true)
            }
            .buttonStyle(.plain)
            .a11y(.templatesCustom, key: saved.name)

            Menu {
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

    private func heading(_ text: String) -> some View {
        SectionHeading(text: text)
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(Theme.detail)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, Theme.gutter)
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
    var isCustom = false

    /// Built-in names read "Split, N Days", so the part before the comma names the split.
    private var split: String {
        isCustom ? "CUSTOM" : String(template.name.split(separator: ",").first ?? Substring(template.name)).uppercased()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isCustom ? "person" : "target")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(split)
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
    let store = Store(inMemory: true)
    return TemplatesView()
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}
