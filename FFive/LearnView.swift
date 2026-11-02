import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The app picks your sets, reps, and weights from a few training ideas. Each short read explains one of them, so you know why a number changed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Learn.Category.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(Learn.articles.filter { $0.category == category }) { article in
                            NavigationLink {
                                Learn.ArticleView(article: article)
                            } label: {
                                Learn.ArticleRow(article: article)
                            }
                        }
                    }
                }
                Section {
                } footer: {
                    Text("Volume landmarks, the stimulus-to-fatigue ratio, and adjusting sets from session feedback come from Renaissance Periodization (Mike Israetel and colleagues). This app is not affiliated with RP.")
                }
            }
            .navigationTitle("Learn")
        }
    }
}

// MARK: - Article list and page

extension Learn {
    fileprivate static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    fileprivate struct ArticleRow: View {
        let article: Article

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: article.symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.headline)
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    fileprivate struct ArticleView: View {
        let article: Article

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(article.summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    TakeawaysCard(takeaways: article.takeaways)
                    ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(block: block)
                    }
                    EvidenceList(citations: article.evidence)
                }
                .padding()
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(article.title)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    fileprivate struct BlockView: View {
        let block: Block

        var body: some View {
            switch block {
            case .heading(let text):
                Text(text)
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
            case .paragraph(let text):
                Text(Learn.inline(text))
            case .bullets(let items):
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\u{2022}")
                                .foregroundStyle(.secondary)
                            Text(Learn.inline(item))
                        }
                    }
                }
            case .caveat(let text):
                VStack(alignment: .leading, spacing: 6) {
                    Label("A note on the evidence", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(Learn.inline(text))
                        .font(.callout)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .landmarksChart:
                LandmarksChart()
            case .rirCountdown:
                RIRCountdown()
            case .feedbackGrid:
                FeedbackGrid()
            case .loadSteps:
                LoadSteps()
            }
        }
    }

    fileprivate struct TakeawaysCard: View {
        let takeaways: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label("Key takeaways", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                ForEach(takeaways, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.tint)
                        Text(Learn.inline(item))
                            .font(.callout)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    fileprivate struct EvidenceList: View {
        let citations: [Citation]

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                Text("Evidence")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                ForEach(citations) { citation in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "\(citation.authors) (\(citation.year))")
                            .font(.footnote.weight(.semibold))
                        if let url = citation.url {
                            Link(destination: url) {
                                Text("\(citation.title) \(Image(systemName: "arrow.up.right.square"))")
                                    .multilineTextAlignment(.leading)
                            }
                            .font(.footnote)
                        } else {
                            Text(citation.title)
                                .font(.footnote)
                        }
                        Text(citation.source)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Visual aids

extension Learn {
    fileprivate enum LandmarkZone: CaseIterable, Identifiable {
        case belowMEV, towardMAV, mav, towardMRV

        var id: Self { self }

        var label: String {
            switch self {
            case .belowMEV: "Below MEV"
            case .towardMAV: "MEV to MAV"
            case .mav: "MAV"
            case .towardMRV: "MAV to MRV"
            }
        }

        var color: Color {
            switch self {
            case .belowMEV: Color.primary.opacity(0.22)
            case .towardMAV: Color.accentColor.opacity(0.55)
            case .mav: .green
            case .towardMRV: .orange
            }
        }

        func span(_ landmarks: VolumeLandmarks) -> (start: Int, end: Int) {
            switch self {
            case .belowMEV: (0, landmarks.mev)
            case .towardMAV: (landmarks.mev, landmarks.mav.lowerBound)
            case .mav: (landmarks.mav.lowerBound, landmarks.mav.upperBound)
            case .towardMRV: (landmarks.mav.upperBound, landmarks.mrv)
            }
        }
    }

    fileprivate struct LandmarksChart: View {
        private let scale = Muscle.allCases.map(\.landmarks.mrv).max() ?? 1

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 6) {
                    ForEach(LandmarkZone.allCases) { zone in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 14, height: 10)
                            Text(zone.label)
                        }
                    }
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.primary).frame(width: 2, height: 12).frame(width: 14)
                        Text("MV")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(Muscle.allCases) { muscle in
                    row(muscle)
                }

                Text(verbatim: "Hard sets per week. Every bar uses the same scale, 0 to \(scale) sets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .learnPanel()
        }

        private func row(_ muscle: Muscle) -> some View {
            let landmarks = muscle.landmarks
            return VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(muscle.displayName)
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Text(verbatim: "MV \(landmarks.mv)  MEV \(landmarks.mev)  MAV \(landmarks.mav.lowerBound)-\(landmarks.mav.upperBound)  MRV \(landmarks.mrv)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                LandmarkBar(landmarks: landmarks, scale: scale)
                    .frame(height: 10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(muscle.displayName). Maintenance \(landmarks.mv), minimum effective \(landmarks.mev), maximum adaptive \(landmarks.mav.lowerBound) to \(landmarks.mav.upperBound), maximum recoverable \(landmarks.mrv) sets per week."))
        }
    }

    fileprivate struct LandmarkBar: View {
        let landmarks: VolumeLandmarks
        let scale: Int

        var body: some View {
            GeometryReader { geometry in
                let unit = geometry.size.width / CGFloat(max(scale, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    ZStack(alignment: .leading) {
                        ForEach(LandmarkZone.allCases) { zone in
                            let span = zone.span(landmarks)
                            Rectangle()
                                .fill(zone.color)
                                .frame(width: CGFloat(max(0, span.end - span.start)) * unit)
                                .offset(x: CGFloat(span.start) * unit)
                        }
                    }
                    .frame(width: CGFloat(landmarks.mrv) * unit, alignment: .leading)
                    .clipShape(Capsule())
                    if landmarks.mv > 0 {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: geometry.size.height + 6)
                            .offset(x: CGFloat(landmarks.mv) * unit - 1)
                    }
                }
            }
        }
    }

    fileprivate struct RIRCountdown: View {
        @State private var weeks = 4

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Weeks before the deload")
                        .font(.subheadline.weight(.semibold))
                    Picker("Weeks before the deload", selection: $weeks) {
                        ForEach(Array(Learn.accumulationWeekOptions), id: \.self) { count in
                            Text(verbatim: "\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 6) {
                    ForEach(0..<weeks, id: \.self) { week in
                        let rir = Learn.rir(week: week, accumulationWeeks: weeks)
                        WeekChip(caption: "Wk \(week + 1)", value: "\(rir)", unit: "RIR",
                                 fill: Color.accentColor.opacity(0.25 + 0.2 * Double(3 - rir)),
                                 spoken: "Week \(week + 1), \(rir) reps in reserve")
                    }
                    WeekChip(caption: "Deload", value: "\u{00BD}", unit: "sets",
                             fill: Color.primary.opacity(0.1),
                             spoken: "Deload week, half the sets")
                }
                .animation(.snappy, value: weeks)

                Text(verbatim: summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .learnPanel()
        }

        private var summary: String {
            let countdown = (0..<weeks).map { String(Learn.rir(week: $0, accumulationWeeks: weeks)) }
            return "A \(weeks)-week block runs \(countdown.joined(separator: ", ")) RIR, then a deload week at half the sets."
        }
    }

    fileprivate struct WeekChip: View {
        let caption: String
        let value: String
        let unit: String
        let fill: Color
        let spoken: String

        var body: some View {
            VStack(spacing: 2) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
        }
    }

    fileprivate struct FeedbackGrid: View {
        @State private var pump: Pump = .moderate
        /// The rule only distinguishes moderate-or-worse pain, so one switch teaches it.
        @State private var jointPain = false
        private let rowLabelWidth: CGFloat = 76

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rows are soreness and columns are workload. Each cell is next week's change in sets for that muscle in that session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Grid sizes these columns from each label's one-line width and overflows a phone, so the rows are HStacks.
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Color.clear
                            .frame(width: rowLabelWidth, height: 1)
                        ForEach(Workload.allCases, id: \.self) { workload in
                            Text(workload.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Soreness.allCases, id: \.self) { soreness in
                        HStack(spacing: 4) {
                            Text(soreness.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: rowLabelWidth, alignment: .leading)
                            ForEach(Workload.allCases, id: \.self) { workload in
                                cell(soreness, workload)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pump")
                        .font(.subheadline.weight(.semibold))
                    Picker("Pump", selection: $pump) {
                        ForEach(Pump.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Moderate or worse joint pain", isOn: $jointPain)
                    .font(.subheadline.weight(.semibold))

                Text(adjusted ? "Outlined cells changed because of pump or joint pain." : "A moderate pump and little or no joint pain leave the table as it is.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .learnPanel()
            .animation(.snappy, value: pump)
            .animation(.snappy, value: jointPain)
        }

        private var adjusted: Bool {
            Soreness.allCases.contains { soreness in
                Workload.allCases.contains { workload in
                    change(soreness, workload) != Learn.FeedbackRule.baseChange(soreness, workload)
                }
            }
        }

        private func change(_ soreness: Soreness, _ workload: Workload) -> Int {
            Learn.FeedbackRule.setChange(soreness, workload, pump: pump, jointPain: jointPain ? .moderate : .none)
        }

        private func cell(_ soreness: Soreness, _ workload: Workload) -> some View {
            let value = change(soreness, workload)
            let changed = value != Learn.FeedbackRule.baseChange(soreness, workload)
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            return Text(verbatim: value > 0 ? "+\(value)" : "\(value)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(color(for: value), in: shape)
                .overlay { shape.strokeBorder(Color.primary.opacity(changed ? 0.85 : 0), lineWidth: 1.5) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(soreness.label), \(workload.label): \(spoken(value))"))
        }

        private func spoken(_ value: Int) -> String {
            switch value {
            case ..<0: "remove \(-value) \(-value == 1 ? "set" : "sets")"
            case 0: "no change"
            default: "add \(value) \(value == 1 ? "set" : "sets")"
            }
        }

        private func color(for value: Int) -> Color {
            switch value {
            case ..<0: Color.red.opacity(0.45)
            case 0: Color.primary.opacity(0.08)
            default: Color.green.opacity(0.2 + 0.18 * Double(value))
            }
        }
    }

    fileprivate struct LoadSteps: View {
        var body: some View {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Equipment")
                    Text(verbatim: "lb")
                    Text(verbatim: "kg")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    GridRow {
                        Text(equipment.displayName)
                        if equipment.increment(.lb) > 0 {
                            Text(verbatim: "+\(equipment.increment(.lb).formatted())")
                                .monospacedDigit()
                            Text(verbatim: "+\(equipment.increment(.kg).formatted())")
                                .monospacedDigit()
                        } else {
                            Text("Reps only")
                                .foregroundStyle(.secondary)
                                .gridCellColumns(2)
                        }
                    }
                }
            }
            .font(.subheadline)
            .learnPanel()
        }
    }
}

extension View {
    fileprivate func learnPanel() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
