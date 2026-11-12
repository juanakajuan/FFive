import FFiveCore
import SwiftUI

/// A starting load for the plate calculator sheet. Each tap is a new value so the sheet reopens fresh.
struct PlateTarget: Identifiable {
    let id = UUID()
    let weight: Double?
}

struct PlateCalculatorSheet: View {
    let startingWeight: Double?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PlateCalculatorScreen(startingWeight: startingWeight)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .a11y(.sheetDone)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PlateCalculatorScreen: View {
    @Environment(Store.self) private var store
    @State private var target: Double?

    init(startingWeight: Double? = nil) {
        _target = State(initialValue: startingWeight.flatMap { $0 > 0 ? $0 : nil })
    }

    private var unit: WeightUnit { store.settings.weightUnit }

    private var bar: Binding<Double?> {
        Binding(
            get: { store.settings.barWeight(for: unit) },
            set: { store.settings.setBarWeight($0 ?? 0, for: unit) })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.gutter) {
                inputs
                if let target, target > 0 {
                    result(PlateLoad.closest(to: target, bar: store.settings.barWeight(for: unit), plates: unit.plates))
                } else {
                    Text("Enter a weight to see the plates for each side.")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.gutter)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.page)
        .navigationTitle("Plate Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputs: some View {
        VStack(spacing: 0) {
            field("Target", value: $target, a11y: .plateTarget)
                .padding(.bottom, 12)
            Hairline()
            field("Bar", value: bar, a11y: .plateBar)
                .padding(.top, 12)
        }
        .surfaceCard()
    }

    private func field(_ title: String, value: Binding<Double?>, a11y: A11y) -> some View {
        HStack(spacing: 12) {
            Text(title).font(Theme.body).foregroundStyle(Theme.text)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .themedField(height: 40)
                .frame(width: 110)
                .accessibilityLabel("\(title) weight")
                .a11y(a11y)
            Text(unit.rawValue)
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func result(_ load: PlateLoad) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per side").font(Theme.columnHeader).foregroundStyle(Theme.secondary)
            PlateStack(plates: load.perSide, unit: unit)
            Text(load.perSide.isEmpty ? "Bar only" : load.perSide.map(formatPlate).joined(separator: " · "))
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.text)
                .a11y(.plateResult)
            Hairline()
            Text("Bar \(formatPlate(load.bar)) \(unit.rawValue)")
                .font(Theme.body)
                .foregroundStyle(Theme.text)
            if !load.isExact {
                Text(offBy(load))
                    .font(Theme.detail)
                    .foregroundStyle(Theme.infoText)
                    .a11y(.plateOffBy)
            }
        }
        .surfaceCard()
    }

    private func offBy(_ load: PlateLoad) -> String {
        let amount = "\(formatPlate(abs(load.offBy))) \(unit.rawValue) \(load.offBy < 0 ? "under" : "over")"
        return "Closest you can load: \(formatPlate(load.total)) \(unit.rawValue) (\(amount))"
    }
}

/// One side of the bar as plates, heaviest at the collar, each as tall as its weight.
private struct PlateStack: View {
    let plates: [Double]
    let unit: WeightUnit

    private var heaviest: Double { unit.plates.first ?? 1 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                Rectangle().fill(Theme.secondary).frame(width: 20, height: 6)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    Text(formatPlate(plate))
                        .font(Theme.tag)
                        .foregroundStyle(Theme.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: 34, height: 30 + 50 * plate / heaviest)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
            }
            .frame(minHeight: 80)
        }
        .accessibilityHidden(true)
    }
}
