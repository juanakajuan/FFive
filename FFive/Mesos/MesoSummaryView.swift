import FFiveCore
import SwiftUI

struct MesoSummaryView: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store

    var body: some View {
        let summary = meso.summary
        ScrollView {
            VStack(spacing: Theme.gutter) {
                if summary.sets.isEmpty {
                    EmptyState(
                        "No sessions yet", systemImage: "chart.bar",
                        message: "Finish a session in this mesocycle to see its summary.")
                } else {
                    SetsByWeekCard(summary: summary)
                    StrengthChangeCard(changes: summary.strength, unit: store.settings.weightUnit)
                    FeedbackTrendCard(summary: summary)
                }
                if !meso.notes.isEmpty {
                    MesoNotesCard(meso: meso)
                }
            }
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.page)
        .navigationTitle("\(meso.name) Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MesoSummarySheet: View {
    let meso: Mesocycle

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MesoSummaryView(meso: meso)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .a11y(.sheetDone)
                    }
                }
        }
    }
}

private func weekLabel(_ week: Int, in summary: MesoSummary) -> String {
    week == summary.deloadWeek ? "DL" : "W\(week + 1)"
}

private struct SetsByWeekCard: View {
    let summary: MesoSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sets per Muscle").font(Theme.cardTitle).foregroundStyle(Theme.text)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 92, height: 1)
                    ForEach(0..<summary.weeks, id: \.self) { week in
                        Text(weekLabel(week, in: summary))
                            .font(Theme.tag)
                            .foregroundStyle(Theme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(summary.sets) { row in
                    HStack(spacing: 6) {
                        Text(row.muscle.displayName)
                            .font(Theme.detail)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .frame(width: 92, alignment: .leading)
                        ForEach(row.perWeek.indices, id: \.self) { week in
                            Text("\(row.perWeek[week])")
                                .font(Theme.detail.monospacedDigit())
                                .foregroundStyle(color(row.perWeek[week], row.muscle.landmarks))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(row.muscle.displayName), "
                            + row.perWeek.indices.map { "\(weekLabel($0, in: summary)) \(row.perWeek[$0]) sets" }
                            .joined(separator: ", "))
                }
            }
            Text("Green is inside the productive range, red is past what the muscle can usually recover from.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .scheduleCard()
    }

    private func color(_ sets: Int, _ landmarks: VolumeLandmarks) -> Color {
        if sets == 0 { return Theme.text.opacity(0.2) }
        if sets > landmarks.mrv { return Theme.danger }
        if landmarks.mav.contains(sets) { return Theme.success }
        return Theme.text
    }
}

private struct StrengthChangeCard: View {
    let changes: [MesoSummary.StrengthChange]
    let unit: WeightUnit

    private func trendColor(_ percent: Double) -> Color {
        if abs(percent) < 0.005 { return Theme.secondary }
        return percent > 0 ? Theme.success : Theme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Estimated 1RM").font(Theme.cardTitle).foregroundStyle(Theme.text)
                Spacer()
                Text("first → last (\(unit.rawValue))").font(Theme.caption).foregroundStyle(Theme.secondary)
            }
            if changes.isEmpty {
                Text("No hard sets logged yet.").font(Theme.detail).foregroundStyle(Theme.secondary)
            }
            ForEach(changes) { change in
                HStack(spacing: 8) {
                    Text(change.name)
                        .font(Theme.detail)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(formatWeight(change.first.rounded())) → \(formatWeight(change.last.rounded()))")
                        .font(Theme.detail.monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .fixedSize()
                    Text(change.percent.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())))
                        .font(Theme.detail.monospacedDigit().weight(.semibold))
                        .foregroundStyle(trendColor(change.percent))
                        .frame(width: 52, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Deload sets are left out, since they say nothing about strength.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .scheduleCard()
    }
}

private struct FeedbackTrendCard: View {
    let summary: MesoSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Feedback").font(Theme.cardTitle).foregroundStyle(Theme.text)
            if summary.feedback.isEmpty {
                Text("No feedback given yet.").font(Theme.detail).foregroundStyle(Theme.secondary)
            }
            ForEach(summary.feedback) { trend in
                VStack(alignment: .leading, spacing: 6) {
                    Text(trend.muscle.displayName).font(Theme.tag).foregroundStyle(Theme.text)
                    ForEach(trend.rows) { row in
                        HStack(spacing: 6) {
                            Text(row.metric.label)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondary)
                                .frame(width: 86, alignment: .leading)
                            ForEach(row.perWeek.indices, id: \.self) { week in
                                bar(row.perWeek[week])
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityText(trend.muscle, row))
                    }
                }
            }
            if !summary.feedback.isEmpty {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 86, height: 1)
                    ForEach(0..<summary.weeks, id: \.self) { week in
                        Text(weekLabel(week, in: summary))
                            .font(Theme.tag)
                            .foregroundStyle(Theme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                Text("Taller bars mean more. Soreness and workload usually climb until the deload.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .scheduleCard()
    }

    private func bar(_ value: Double?) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.raised)
            if let value {
                RoundedRectangle(cornerRadius: 2).fill(Theme.infoText).frame(height: 4 + 16 * value)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 20)
    }

    private func accessibilityText(_ muscle: Muscle, _ row: MesoSummary.FeedbackTrend.Row) -> String {
        let weeks = row.perWeek.indices.map { week in
            let value = row.perWeek[week].map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "none"
            return "\(weekLabel(week, in: summary)) \(value)"
        }
        return "\(muscle.displayName) \(row.metric.label), " + weeks.joined(separator: ", ")
    }
}

/// Pushes the summary rather than the detail screen, since both are keyed by the same meso.
struct MesoSummaryRoute: Hashable {
    let meso: Mesocycle
}
