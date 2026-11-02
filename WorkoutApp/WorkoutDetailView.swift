import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatTile(title: "Duration", value: formatDuration(workout.duration), icon: "clock.fill")
                    StatTile(title: "Sets", value: "\(workout.completedSets)", icon: "checkmark.circle.fill")
                    StatTile(title: "Volume (\(unit.rawValue))",
                             value: Int(workout.totalVolume).formatted(),
                             icon: "scalemass.fill")
                }
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    if let meso = workout.mesocycle, let week = workout.week, let phase = workout.phase {
                        Text("\(meso.name) · \(phase == .deload ? "Deload week" : "Week \(week + 1), \(phase.badgeText)")")
                    }
                }
                .padding(.top, 8)
            }

            ForEach(workout.sortedExercises.filter { $0.sets.contains(where: \.isDone) }) { exercise in
                Section(exercise.name) {
                    let sets = exercise.sortedSets.filter(\.isDone)
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(formatWeight(set.weight)) \(unit.rawValue) × \(set.reps)")
                                .monospacedDigit()
                        }
                    }
                }
            }

            let feedback = workout.feedback.compactMap { record in record.muscle.map { ($0, record.value) } }
                .sorted { $0.0.displayName < $1.0.displayName }
            if !feedback.isEmpty {
                Section("How it felt") {
                    ForEach(feedback, id: \.0) { muscle, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(muscle.displayName).font(.subheadline.bold())
                            Text([value.pump.map { "Pump: \($0.label)" },
                                  value.workload.map { "Workload: \($0.label)" },
                                  value.jointPain.map { "Joints: \($0.label)" },
                                  value.soreness.map { "Afterwards: \($0.label)" }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
