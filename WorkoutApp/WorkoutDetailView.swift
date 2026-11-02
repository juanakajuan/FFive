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
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .padding(.top, 8)
            }

            ForEach(workout.sortedExercises) { exercise in
                Section(exercise.name) {
                    let sets = exercise.sortedSets.filter(\.isDone)
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(set.weight.formatted()) \(unit.rawValue) × \(set.reps)")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
