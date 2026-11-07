import FFiveCore
import SwiftUI

extension Changelog {
    /// The changelog shipped in the app bundle, empty if it is missing or unreadable.
    static let bundled: Changelog = {
        guard let url = Bundle.main.url(forResource: "Changelog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let changelog = try? Changelog.decode(data)
        else { return Changelog(releases: []) }
        return changelog
    }()

    static var runningVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}

/// Every change the app shipped, grouped by release and day. Opened from More.
struct ChangelogScreen: View {
    var body: some View {
        ChangelogList(groups: Changelog.bundled.dayGroups, showsHeaders: true)
            .navigationTitle("Changelog")
    }
}

/// What changed since the lifter last opened the app, shown once after an update.
struct WhatsNewSheet: View {
    let groups: [Changelog.DayGroup]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // One day of changes needs no date heading; more than one reads better split by day.
            ChangelogList(groups: groups, showsHeaders: groups.count > 1)
                .navigationTitle("What's New")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .a11y(.sheetDone)
                    }
                }
        }
    }
}

private struct ChangelogList: View {
    let groups: [Changelog.DayGroup]
    let showsHeaders: Bool

    var body: some View {
        List {
            if groups.isEmpty {
                Text("No changes recorded yet.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    .themedRow()
            }
            ForEach(groups) { group in
                if showsHeaders {
                    DayHeading(group: group)
                        .themedRow(vertical: 8)
                        .padding(.top, 12)
                        .listRowSeparator(.hidden)
                }
                ForEach(group.entries, id: \.self) { EntryRow(entry: $0).themedRow() }
            }
        }
        .themedList()
        .a11y(.changelogList)
    }
}

private struct DayHeading: View {
    let group: Changelog.DayGroup

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var day: String {
        Self.parser.date(from: group.date)?.formatted(date: .abbreviated, time: .omitted) ?? group.date
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeading(text: day)
            Text("Version \(group.version)")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct EntryRow: View {
    let entry: Changelog.Entry

    private var color: Color {
        switch entry.kind {
        case .feature: Theme.accent
        case .improvement: Theme.success
        case .fix: Theme.danger
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(entry.kind.label.uppercased())
                .font(Theme.tag)
                .foregroundStyle(color)
                .frame(width: 70, alignment: .leading)
            Text(entry.text)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { ChangelogScreen() }
        .preferredColorScheme(.dark)
}
