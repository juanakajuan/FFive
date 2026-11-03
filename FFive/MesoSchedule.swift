import SwiftUI
import SwiftData

/// The block's week-by-day grid. Current-week days open or skip; finished days push their workout.
struct MesoScheduleGrid: View {
    let meso: Mesocycle
    var onOpen: (SessionKey) -> Void

    @Environment(\.modelContext) private var context
    @State private var trainAfterAll: SessionKey?

    var body: some View {
        let next = meso.nextUp
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(Theme.cardTitle).foregroundStyle(Theme.text)
            Grid(horizontalSpacing: 6, verticalSpacing: 8) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(meso.days.indices, id: \.self) { day in
                        Text("D\(day + 1)")
                            .font(Theme.tag)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                ForEach(0..<meso.totalWeeks, id: \.self) { week in
                    GridRow {
                        Text(week == meso.accumulationWeeks ? "DL" : "W\(week + 1)")
                            .font(Theme.tag)
                            .foregroundStyle(week == next?.week ? Theme.text : Theme.secondary)
                            .frame(width: 28, alignment: .leading)
                        ForEach(meso.days.indices, id: \.self) { day in
                            cell(SessionKey(week: week, dayIndex: day), next: next)
                        }
                    }
                }
            }
            Text("Tap a day in the current week to train it, or a finished day to review it. Long-press a day to skip it.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .scheduleCard()
        .confirmationDialog("Train this day after all?",
                            isPresented: Binding(get: { trainAfterAll != nil }, set: { if !$0 { trainAfterAll = nil } }),
                            titleVisibility: .visible, presenting: trainAfterAll) { key in
            Button("Train Day \(key.dayIndex + 1)") {
                meso.unskip(key)
                onOpen(key)
            }
        }
    }

    @ViewBuilder
    private func cell(_ key: SessionKey, next: SessionKey?) -> some View {
        let status = meso.status(at: key)
        let isCurrentWeek = key.week == next?.week
        switch status {
        case .finished(let workout):
            NavigationLink(value: workout) {
                cellIcon("checkmark.circle.fill", Theme.success)
            }
            .buttonStyle(.plain)
        case .skipped:
            if isCurrentWeek {
                Button { trainAfterAll = key } label: { cellIcon("forward.circle", Theme.secondary) }
                    .buttonStyle(.plain)
            } else {
                cellIcon("forward.circle", Theme.secondary)
            }
        case .upcoming, .inProgress:
            if isCurrentWeek {
                Button { onOpen(key) } label: {
                    if case .inProgress = status {
                        cellIcon("circle.lefthalf.filled", Theme.infoText)
                    } else if key == next {
                        cellIcon("play.circle.fill", Theme.infoText)
                    } else {
                        cellIcon("circle", Theme.secondary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if meso.canSkip(key) {
                        Button("Skip Day", systemImage: "forward") { skip(key) }
                    }
                }
            } else {
                cellIcon("circle", Theme.text.opacity(0.2))
            }
        }
    }

    private func cellIcon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 24))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
    }

    private func skip(_ key: SessionKey) {
        withAnimation { meso.skip(key, in: context) }
        try? context.save()
    }
}

/// One week's sets per muscle against the volume landmarks.
struct WeekVolumeCard: View {
    let meso: Mesocycle
    let week: Int
    let unit: WeightUnit

    @Environment(\.modelContext) private var context

    var body: some View {
        let volumes = MesoPlanner.weeklyVolume(meso, week: week, unit: unit, context: context)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week's Sets").font(Theme.cardTitle).foregroundStyle(Theme.text)
                Spacer()
                Text("done / planned").font(Theme.caption).foregroundStyle(Theme.secondary)
            }
            ForEach(volumes) { VolumeBar(volume: $0) }
            VolumeLegend()
            Text("Each bar ends at the most weekly sets that muscle can usually recover from.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .scheduleCard()
    }
}

private extension View {
    /// Full-width card on the page background, matching the Workout tab's cards.
    func scheduleCard() -> some View {
        padding(Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
