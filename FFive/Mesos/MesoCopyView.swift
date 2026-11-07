import FFiveCore
import SwiftUI

/// Reviews one week of a past or current block before its copy opens in the editor.
struct MesoCopyView: View {
    let source: Mesocycle
    var onStart: () -> Void

    @Environment(Store.self) private var store
    @State private var week = 0

    var body: some View {
        let draft = source.copyDraft(week: week)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Source week", selection: $week) {
                    ForEach(source.copyableWeeks, id: \.self) { Text("Week \($0 + 1)").tag($0) }
                }
                .pickerStyle(.segmented)
                .a11y(.builderCopyWeek)
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 16)
                Text(loadsNote)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 10)
                ForEach(Array(draft.days.enumerated()), id: \.offset) { index, day in
                    dayCard(day, number: index + 1)
                }
            }
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle("Copy \(source.name)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                MesoEditorView(draft: draft, onStart: onStart)
            } label: {
                Text("Use Week \(week + 1)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.page)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.text, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .a11y(.builderCopyUse)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
    }

    private var loadsNote: String {
        guard let last = source.lastAccumulationDate else {
            return "Nothing was logged in this block, so week 1 plans its loads fresh."
        }
        let when = last.formatted(date: .abbreviated, time: .omitted)
        return source.carriesLoads()
            ? "Last trained \(when). Week 1 starts from the weights and reps logged this week."
            : "Last trained \(when), over 3 weeks ago. Week 1 plans its loads fresh."
    }

    private func dayCard(_ day: MesoDraft.Day, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Text(day.weekday?.name ?? "Day \(number)")
                    .font(Theme.columnHeader)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, 12)
            ForEach(Array(day.slots.enumerated()), id: \.offset) { _, slot in
                Rectangle().fill(Theme.hairline).frame(height: 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.exercise).font(Theme.body).foregroundStyle(Theme.text)
                    HStack(spacing: 8) {
                        MuscleDotLabel(muscle: slot.muscle)
                        if let targets = slot.startingTargets {
                            Text(setsText(targets)).font(Theme.caption).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 12)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 16)
    }

    private func setsText(_ targets: [SetTarget]) -> String {
        let unit = store.settings.weightUnit.rawValue
        let text = { (target: SetTarget) in
            "\(target.weight.map { "\(formatWeight($0)) \(unit)" } ?? "?") × \(target.reps.map(String.init) ?? "?")"
        }
        if let first = targets.first, targets.allSatisfy({ $0 == first }) {
            return "\(targets.count) \(targets.count == 1 ? "set" : "sets") of \(text(first))"
        }
        return targets.map(text).joined(separator: ", ")
    }
}

struct CopySourceRow: View {
    let meso: Mesocycle

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(status)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                Text(meso.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            CountPill(text: "\(meso.days.count)/week").brightness(0.07)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var status: String {
        guard let finished = meso.finishedDate else { return "CURRENT" }
        return "FINISHED \(finished.formatted(date: .abbreviated, time: .omitted).uppercased())"
    }
}
