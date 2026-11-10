import FFiveCore
import SwiftData
import SwiftUI

struct MesoScheduleGrid: View {
    let meso: Mesocycle
    var onOpen: (SessionKey) -> Void
    var onSkipped: (SessionKey) -> Void

    @Environment(Store.self) private var store

    var body: some View {
        let next = meso.nextUp
        let dayNames = meso.dayNames
        let weekdays = meso.weekdays
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(Theme.cardTitle).foregroundStyle(Theme.text)
            Grid(horizontalSpacing: 6, verticalSpacing: 8) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(meso.days.indices, id: \.self) { day in
                        VStack(spacing: 2) {
                            Text(weekdays[day]?.shortName.uppercased() ?? "D\(day + 1)").font(Theme.tag)
                            Text(dayNames[day])
                                .font(Theme.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(Theme.secondary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            (["Day \(day + 1)", weekdays[day]?.name, dayNames[day]] as [String?])
                                .compactMap { $0 }.joined(separator: ", "))
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
            Text(
                "Tap a day in the current week to train it, or a finished day to review it. Long-press a day to skip it."
            )
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
        }
        .surfaceCard()
    }

    @ViewBuilder
    private func cell(_ key: SessionKey, next: SessionKey?) -> some View {
        let status = meso.status(at: key)
        let isCurrentWeek = meso.isActive && key.week == next?.week
        switch status {
        case .finished(let workout):
            NavigationLink(value: workout) {
                cellIcon("checkmark.circle.fill", Theme.success)
            }
            .buttonStyle(.plain)
        case .skipped:
            if isCurrentWeek {
                Button {
                    onSkipped(key)
                } label: {
                    cellIcon("forward.circle", Theme.secondary)
                }
                .buttonStyle(.plain)
            } else {
                cellIcon("forward.circle", Theme.secondary)
            }
        case .upcoming, .inProgress:
            if isCurrentWeek {
                Button {
                    onOpen(key)
                } label: {
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
                        Button("Skip Day", systemImage: "forward") { withAnimation { store.skip(key, of: meso) } }
                            .a11y(.menuSkipDay)
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
}

/// Lengthens or shortens a running block one training week at a time. The deload and every week's RIR move with it.
struct MesoLengthCard: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store

    var body: some View {
        let weeks = meso.accumulationWeeks
        let range = Mesocycle.accumulationWeekRange
        VStack(alignment: .leading, spacing: 12) {
            Stepper(
                onIncrement: meso.canAddWeek ? { withAnimation { store.changeLength(of: meso, by: 1) } } : nil,
                onDecrement: meso.canRemoveWeek ? { withAnimation { store.changeLength(of: meso, by: -1) } } : nil
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(weeks) training weeks").font(Theme.cardTitle).foregroundStyle(Theme.text)
                    Text("then 1 deload week").font(Theme.caption).foregroundStyle(Theme.secondary)
                }
            }
            .a11y(.scheduleLength)
            RIRSchedule(accumulationWeeks: weeks)
            Text(footnote(weeks: weeks, range: range))
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .surfaceCard()
    }

    private func footnote(weeks: Int, range: ClosedRange<Int>) -> String {
        if weeks > range.lowerBound, !meso.canRemoveWeek {
            return "A week can't be removed once its last training week or the deload has logged sets."
        }
        if weeks < range.upperBound, !meso.canAddWeek {
            return "A week can't be added once the deload has logged sets."
        }
        return "Sessions not yet logged are rebuilt for their new RIR. Logged sessions keep theirs."
    }
}

struct WeekVolumeCard: View {
    let meso: Mesocycle
    let week: Int

    @Environment(Store.self) private var store

    var body: some View {
        let volumes = store.weeklyVolume(meso, week: week)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week's Sets").font(Theme.cardTitle).foregroundStyle(Theme.text)
                Spacer()
                Text("done / planned").font(Theme.caption).foregroundStyle(Theme.secondary)
            }
            VolumeChart(volumes: volumes)
            Text("The red tick is the most weekly sets that muscle can usually recover from.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .surfaceCard()
    }
}

extension View {
    func trainAfterAllDialog(
        _ key: Binding<SessionKey?>, of meso: Mesocycle, store: Store,
        onOpen: @escaping (SessionKey) -> Void
    ) -> some View {
        confirmationDialog(
            "Train this day after all?",
            isPresented: Binding(get: { key.wrappedValue != nil }, set: { if !$0 { key.wrappedValue = nil } }),
            titleVisibility: .visible, presenting: key.wrappedValue
        ) { key in
            Button("Train Day \(key.dayIndex + 1)") {
                store.unskip(key, of: meso)
                onOpen(key)
            }
            .a11y(.dialogTrainDay)
        }
    }
}
