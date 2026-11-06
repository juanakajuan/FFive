import FFiveCore
import SwiftUI

struct LearnView: View {
    var body: some View {
        List {
            Text(
                "The app picks your sets, reps, and weights from a few training ideas. Each short read explains one of them, so you know why a number changed."
            )
            .font(Theme.detail)
            .foregroundStyle(Theme.secondary)
            .themedRow()
            .listRowSeparator(.hidden)
            ForEach(Learn.Category.allCases) { category in
                SectionHeading(text: category.rawValue)
                    .accessibilityAddTraits(.isHeader)
                    .themedRow(vertical: 8)
                    .padding(.top, 12)
                    .listRowSeparator(.hidden)
                ForEach(Learn.articles.filter { $0.category == category }) { article in
                    NavigationLink {
                        Learn.ArticleView(article: article)
                    } label: {
                        Learn.ArticleRow(article: article)
                    }
                    .themedRow()
                }
            }
            Text(
                "Volume landmarks, the stimulus-to-fatigue ratio, and adjusting sets from session feedback come from Renaissance Periodization (Mike Israetel and colleagues). This app is not affiliated with RP."
            )
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            .themedRow(vertical: 20)
            .listRowSeparator(.hidden)
        }
        .themedList()
        .navigationTitle("Learn")
    }
}

#Preview {
    NavigationStack { LearnView() }
        .preferredColorScheme(.dark)
}

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
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.text)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(Theme.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Text(article.summary)
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    fileprivate struct ArticleView: View {
        let article: Article

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(article.summary)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.secondary)
                    TakeawaysCard(takeaways: article.takeaways)
                    ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(block: block)
                    }
                    EvidenceList(citations: article.evidence)
                }
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .tint(Theme.infoText)
                .padding(Theme.gutter)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.surface)
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
                    .font(Theme.cardTitle)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
            case .paragraph(let text):
                Text(Learn.inline(text))
            case .bullets(let items):
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\u{2022}")
                                .foregroundStyle(Theme.secondary)
                            Text(Learn.inline(item))
                        }
                    }
                }
            case .caveat(let text):
                VStack(alignment: .leading, spacing: 6) {
                    Label("A note on the evidence", systemImage: "info.circle")
                        .font(Theme.detail.weight(.semibold))
                    Text(Learn.inline(text))
                        .font(Theme.detail)
                }
                .foregroundStyle(Theme.text)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.noteFill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
                Label("Key takeaways", systemImage: "lightbulb")
                    .font(Theme.body.weight(.semibold))
                    .foregroundStyle(Theme.infoText)
                ForEach(takeaways, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.infoText)
                        Text(Learn.inline(item))
                            .font(Theme.detail)
                            .foregroundStyle(Theme.text)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.infoFill.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    fileprivate struct EvidenceList: View {
        let citations: [Citation]

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Rectangle().fill(Theme.hairline).frame(height: 1)
                Text("Evidence")
                    .font(Theme.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                ForEach(citations) { citation in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "\(citation.authors) (\(citation.year))")
                            .font(Theme.detail.weight(.semibold))
                        if let url = citation.url {
                            Link(destination: url) {
                                Text("\(citation.title) \(Image(systemName: "arrow.up.right.square"))")
                                    .multilineTextAlignment(.leading)
                            }
                            .font(Theme.detail)
                        } else {
                            Text(citation.title)
                                .font(Theme.detail)
                        }
                        Text(citation.source)
                            .font(Theme.caption)
                            .italic()
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
            .padding(.top, 12)
        }
    }
}

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
            case .belowMEV: Theme.text.opacity(0.22)
            case .towardMAV: Theme.infoText.opacity(0.6)
            case .mav: Theme.success
            case .towardMRV: Theme.danger.opacity(0.75)
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
                LazyVGrid(
                    columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                    alignment: .leading, spacing: 6
                ) {
                    ForEach(LandmarkZone.allCases) { zone in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(zone.color).frame(width: 14, height: 10)
                            Text(zone.label)
                        }
                    }
                    HStack(spacing: 6) {
                        Rectangle().fill(Theme.text).frame(width: 2, height: 12).frame(width: 14)
                        Text("MV")
                    }
                }
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)

                ForEach(Muscle.allCases) { muscle in
                    row(muscle)
                }

                Text(verbatim: "Hard sets per week. Every bar uses the same scale, 0 to \(scale) sets.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            .learnPanel()
        }

        private func row(_ muscle: Muscle) -> some View {
            let landmarks = muscle.landmarks
            return VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(muscle.displayName)
                        .font(Theme.detail.weight(.medium))
                    Spacer(minLength: 8)
                    Text(
                        verbatim:
                            "MV \(landmarks.mv)  MEV \(landmarks.mev)  MAV \(landmarks.mav.lowerBound)-\(landmarks.mav.upperBound)  MRV \(landmarks.mrv)"
                    )
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                LandmarkBar(landmarks: landmarks, scale: scale)
                    .frame(height: 10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(
                    verbatim:
                        "\(muscle.displayName). Maintenance \(landmarks.mv), minimum effective \(landmarks.mev), maximum adaptive \(landmarks.mav.lowerBound) to \(landmarks.mav.upperBound), maximum recoverable \(landmarks.mrv) sets per week."
                ))
        }
    }

    fileprivate struct LandmarkBar: View {
        let landmarks: VolumeLandmarks
        let scale: Int

        var body: some View {
            GeometryReader { geometry in
                let unit = geometry.size.width / CGFloat(max(scale, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.raised)
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
                            .fill(Theme.text)
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
                        .font(Theme.detail.weight(.semibold))
                    SegmentedButtons(options: Array(Learn.accumulationWeekOptions), selection: $weeks) { "\($0)" }
                }

                HStack(spacing: 6) {
                    ForEach(0..<weeks, id: \.self) { week in
                        let rir = Learn.rir(week: week, accumulationWeeks: weeks)
                        WeekChip(
                            caption: "Wk \(week + 1)", value: "\(rir)", unit: "RIR",
                            fill: Theme.infoText.opacity(0.2 + 0.18 * Double(3 - rir)),
                            spoken: "Week \(week + 1), \(rir) reps in reserve")
                    }
                    WeekChip(
                        caption: "Deload", value: "\u{00BD}", unit: "sets",
                        fill: Theme.field,
                        spoken: "Deload week, half the sets")
                }
                .animation(.snappy, value: weeks)

                Text(verbatim: summary)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            .learnPanel()
        }

        private var summary: String {
            let countdown = (0..<weeks).map { String(Learn.rir(week: $0, accumulationWeeks: weeks)) }
            return
                "A \(weeks)-week block runs \(countdown.joined(separator: ", ")) RIR, then a deload week at half the sets."
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
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
                Text(
                    "Rows are soreness and columns are workload. Each cell is next week's change in sets for that muscle in that session."
                )
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)

                // Grid sizes these columns from each label's one-line width and overflows a phone, so the rows are HStacks.
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Color.clear
                            .frame(width: rowLabelWidth, height: 1)
                        ForEach(Workload.allCases, id: \.self) { workload in
                            Text(workload.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Soreness.allCases, id: \.self) { soreness in
                        HStack(spacing: 4) {
                            Text(soreness.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                                .frame(width: rowLabelWidth, alignment: .leading)
                            ForEach(Workload.allCases, id: \.self) { workload in
                                cell(soreness, workload)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pump")
                        .font(Theme.detail.weight(.semibold))
                    SegmentedButtons(options: Pump.allCases, selection: $pump, label: \.label)
                }

                Toggle("Moderate or worse joint pain", isOn: $jointPain)
                    .font(Theme.detail.weight(.semibold))
                    .tint(Theme.success)

                Text(
                    adjusted
                        ? "Outlined cells changed because of pump or joint pain."
                        : "A moderate pump and little or no joint pain leave the table as it is."
                )
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
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
            let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius)
            return Text(verbatim: value > 0 ? "+\(value)" : "\(value)")
                .font(Theme.body.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(color(for: value), in: shape)
                .overlay { shape.strokeBorder(Theme.text.opacity(changed ? 0.85 : 0), lineWidth: 1.5) }
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
            case ..<0: Theme.danger.opacity(0.45)
            case 0: Theme.field
            default: Theme.success.opacity(0.3 + 0.2 * Double(value))
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
                .font(Theme.columnHeader)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondary)
                Rectangle().fill(Theme.hairline).frame(height: 1)
                    .gridCellUnsizedAxes(.horizontal)
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    GridRow {
                        Text(equipment.displayName)
                        step(equipment.increment(.lb))
                        step(equipment.increment(.kg))
                    }
                }
            }
            .font(Theme.detail)
            .learnPanel()
        }

        private func step(_ increment: Double) -> some View {
            Text(verbatim: increment == 0 ? "Reps" : "+\(increment.formatted())")
                .monospacedDigit()
        }
    }
}

extension View {
    fileprivate func learnPanel() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
