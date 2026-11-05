import FFiveCore
import Foundation

/// The Learn tab's articles as data. Foundation only, so a script can compile it with Domain.swift
/// to check word counts and the feedback rule without SwiftUI.
enum Learn {
    enum Category: String, CaseIterable, Identifiable {
        case system = "The system"
        case gym = "In the gym"
        case recovery = "Recovery"
        var id: Self { self }
    }

    struct Citation: Identifiable {
        let authors: String
        let year: Int
        let title: String
        let source: String
        let doi: String?
        var id: String { title }
        var url: URL? { doi.flatMap { URL(string: "https://doi.org/\($0)") } }
    }

    /// Text blocks hold inline Markdown. The cases without text are visual aids drawn from Domain.swift.
    enum Block {
        case heading(String)
        case paragraph(String)
        case bullets([String])
        case caveat(String)
        case landmarksChart
        case rirCountdown
        case feedbackGrid
        case loadSteps
    }

    struct Article: Identifiable {
        let id: String
        let category: Category
        let title: String
        let symbol: String
        let summary: String
        let takeaways: [String]
        let blocks: [Block]
        let evidence: [Citation]

        var prose: [String] {
            takeaways
                + blocks.flatMap { block -> [String] in
                    switch block {
                    case .heading(let text), .paragraph(let text), .caveat(let text): [text]
                    case .bullets(let items): items
                    case .landmarksChart, .rirCountdown, .feedbackGrid, .loadSteps: []
                    }
                }
        }
    }

    // MARK: - Rules shown in the visual aids

    static let accumulationWeekOptions = 3...6

    static func rir(week: Int, accumulationWeeks: Int) -> Int {
        Progression.phase(week: week, accumulationWeeks: accumulationWeeks).rir ?? 0
    }

    enum FeedbackRule {
        static func baseChange(_ soreness: Soreness, _ workload: Workload) -> Int {
            Progression.setDelta(
                MuscleFeedback(soreness: soreness, pump: .moderate, workload: workload, jointPain: JointPain.none))
        }

        static func setChange(_ soreness: Soreness, _ workload: Workload, pump: Pump, jointPain: JointPain) -> Int {
            Progression.setDelta(
                MuscleFeedback(soreness: soreness, pump: pump, workload: workload, jointPain: jointPain))
        }
    }
}

// MARK: - Evidence

extension Learn.Citation {
    static let israetel2021 = Self(
        authors: "Israetel M, Hoffmann J, Davis M, Feather J", year: 2021,
        title: "Scientific Principles of Hypertrophy Training",
        source: "Renaissance Periodization (book)", doi: nil)

    static let schoenfeld2017Volume = Self(
        authors: "Schoenfeld BJ, Ogborn D, Krieger JW", year: 2017,
        title:
            "Dose-response relationship between weekly resistance training volume and increases in muscle mass: A systematic review and meta-analysis",
        source: "Journal of Sports Sciences, 35(11), 1073-1082", doi: "10.1080/02640414.2016.1210197")

    static let pelland2026 = Self(
        authors: "Pelland JC, Remmert JF, Robinson ZP, Hinson SR, Zourdos MC", year: 2026,
        title:
            "The Resistance Training Dose Response: Meta-Regressions Exploring the Effects of Weekly Volume and Frequency on Muscle Hypertrophy and Strength Gains",
        source: "Sports Medicine, 56(2), 481-505", doi: "10.1007/s40279-025-02344-w")

    static let robinson2024 = Self(
        authors: "Robinson ZP, Pelland JC, Remmert JF, Refalo MC, Jukic I, Steele J, Zourdos MC", year: 2024,
        title:
            "Exploring the Dose-Response Relationship Between Estimated Resistance Training Proximity to Failure, Strength Gain, and Muscle Hypertrophy: A Series of Meta-Regressions",
        source: "Sports Medicine, 54(9), 2209-2231", doi: "10.1007/s40279-024-02069-2")

    static let plotkin2022 = Self(
        authors:
            "Plotkin D, Coleman M, Van Every D, Maldonado J, Oberlin D, Israetel M, Feather J, Alto A, Vigotsky AD, Schoenfeld BJ",
        year: 2022,
        title:
            "Progressive overload without progressing load? The effects of load or repetition progression on muscular adaptations",
        source: "PeerJ, 10, e14142", doi: "10.7717/peerj.14142")

    static let zourdos2016 = Self(
        authors: "Zourdos MC, Klemp A, Dolan C, et al.", year: 2016,
        title: "Novel Resistance Training-Specific Rating of Perceived Exertion Scale Measuring Repetitions in Reserve",
        source: "Journal of Strength and Conditioning Research, 30(1), 267-275", doi: "10.1519/JSC.0000000000001049")

    static let helms2016 = Self(
        authors: "Helms ER, Cronin J, Storey A, Zourdos MC", year: 2016,
        title:
            "Application of the Repetitions in Reserve-Based Rating of Perceived Exertion Scale for Resistance Training",
        source: "Strength and Conditioning Journal, 38(4), 42-49", doi: "10.1519/SSC.0000000000000218")

    static let refalo2023 = Self(
        authors: "Refalo MC, Helms ER, Trexler ET, Hamilton DL, Fyfe JJ", year: 2023,
        title:
            "Influence of Resistance Training Proximity-to-Failure on Skeletal Muscle Hypertrophy: A Systematic Review with Meta-analysis",
        source: "Sports Medicine, 53(3), 649-665", doi: "10.1007/s40279-022-01784-y")

    static let halperin2022 = Self(
        authors: "Halperin I, Malleron T, Har-Nir I, Androulakis-Korakakis P, Wolf M, Fisher J, Steele J", year: 2022,
        title:
            "Accuracy in Predicting Repetitions to Task Failure in Resistance Exercise: A Scoping Review and Exploratory Meta-analysis",
        source: "Sports Medicine, 52(2), 377-390", doi: "10.1007/s40279-021-01559-x")

    static let maeo2023 = Self(
        authors: "Maeo S, Wu Y, Huang M, et al.", year: 2023,
        title:
            "Triceps brachii hypertrophy is substantially greater after elbow extension training performed in the overhead versus neutral arm position",
        source: "European Journal of Sport Science, 23(7), 1240-1250", doi: "10.1080/17461391.2022.2100279")

    static let maeo2021 = Self(
        authors: "Maeo S, Huang M, Wu Y, et al.", year: 2021,
        title:
            "Greater Hamstrings Muscle Hypertrophy but Similar Damage Protection after Training at Long versus Short Muscle Lengths",
        source: "Medicine and Science in Sports and Exercise, 53(4), 825-837", doi: "10.1249/MSS.0000000000002523")

    static let schoenfeld2021 = Self(
        authors: "Schoenfeld BJ, Grgic J, Van Every DW, Plotkin DL", year: 2021,
        title:
            "Loading Recommendations for Muscle Strength, Hypertrophy, and Local Endurance: A Re-Examination of the Repetition Continuum",
        source: "Sports, 9(2), 32", doi: "10.3390/sports9020032")

    static let schoenfeld2017Load = Self(
        authors: "Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW", year: 2017,
        title:
            "Strength and Hypertrophy Adaptations Between Low- vs. High-Load Resistance Training: A Systematic Review and Meta-analysis",
        source: "Journal of Strength and Conditioning Research, 31(12), 3508-3523", doi: "10.1519/JSC.0000000000002200")

    static let wolf2023 = Self(
        authors: "Wolf M, Androulakis-Korakakis P, Fisher J, Schoenfeld B, Steele J", year: 2023,
        title: "Partial Vs Full Range of Motion Resistance Training: A Systematic Review and Meta-Analysis",
        source: "International Journal of Strength and Conditioning, 3(1)", doi: "10.47206/ijsc.v3i1.182")

    static let schoenfeldGrgic2020 = Self(
        authors: "Schoenfeld BJ, Grgic J", year: 2020,
        title:
            "Effects of range of motion on muscle development during resistance training interventions: A systematic review",
        source: "SAGE Open Medicine, 8", doi: "10.1177/2050312120901559")

    static let pedrosa2022 = Self(
        authors: "Pedrosa GF, Lima FV, Schoenfeld BJ, et al.", year: 2022,
        title:
            "Partial range of motion training elicits favorable improvements in muscular adaptations when carried out at long muscle lengths",
        source: "European Journal of Sport Science, 22(8), 1250-1260", doi: "10.1080/17461391.2021.1927199")

    static let schoenfeld2015 = Self(
        authors: "Schoenfeld BJ, Ogborn DI, Krieger JW", year: 2015,
        title:
            "Effect of repetition duration during resistance training on muscle hypertrophy: a systematic review and meta-analysis",
        source: "Sports Medicine, 45(4), 577-585", doi: "10.1007/s40279-015-0304-0")

    static let schoenfeldContreras2013 = Self(
        authors: "Schoenfeld BJ, Contreras B", year: 2013,
        title: "Is Postexercise Muscle Soreness a Valid Indicator of Muscular Adaptations?",
        source: "Strength and Conditioning Journal, 35(5), 16-21", doi: "10.1519/SSC.0b013e3182a61820")

    static let damas2016 = Self(
        authors: "Damas F, Phillips SM, Libardi CA, et al.", year: 2016,
        title:
            "Resistance training-induced changes in integrated myofibrillar protein synthesis are related to hypertrophy only after attenuation of muscle damage",
        source: "The Journal of Physiology, 594(18), 5209-5222", doi: "10.1113/JP272472")

    static let bell2023 = Self(
        authors: "Bell L, Strafford BW, Coleman M, Androulakis Korakakis P, Nolan D", year: 2023,
        title:
            "Integrating Deloading into Strength and Physique Sports Training Programmes: An International Delphi Consensus Approach",
        source: "Sports Medicine - Open, 9, 87", doi: "10.1186/s40798-023-00633-0")

    static let coleman2024 = Self(
        authors: "Coleman M, Burke R, Augustin F, et al.", year: 2024,
        title:
            "Gaining more from doing less? The effects of a one-week deload period during supervised resistance training on muscular adaptations",
        source: "PeerJ, 12, e16777", doi: "10.7717/peerj.16777")

    static let schoenfeld2016Frequency = Self(
        authors: "Schoenfeld BJ, Ogborn D, Krieger JW", year: 2016,
        title:
            "Effects of Resistance Training Frequency on Measures of Muscle Hypertrophy: A Systematic Review and Meta-Analysis",
        source: "Sports Medicine, 46(11), 1689-1697", doi: "10.1007/s40279-016-0543-8")

    static let schoenfeld2019Frequency = Self(
        authors: "Schoenfeld BJ, Grgic J, Krieger J", year: 2019,
        title:
            "How many times per week should a muscle be trained to maximize muscle hypertrophy? A systematic review and meta-analysis of studies examining the effects of resistance training frequency",
        source: "Journal of Sports Sciences, 37(11), 1286-1295", doi: "10.1080/02640414.2018.1555906")
}

// MARK: - Articles

extension Learn {
    static let articles: [Article] = [
        Article(
            id: "landmarks", category: .system,
            title: "Volume landmarks", symbol: "chart.bar.xaxis",
            summary: "How many hard sets each muscle needs per week, and how many it can recover from.",
            takeaways: [
                "Volume is the number of hard sets a muscle gets each week. More sets build more muscle, up to the point where you stop recovering.",
                "MEV is where growth starts, MAV is where most people grow best, and MRV is the most you can recover from.",
                "The numbers here are starting estimates. Your feedback after each session finds your own.",
            ],
            blocks: [
                .heading("Counting sets"),
                .paragraph(
                    "The app measures volume in hard sets per muscle per week. A hard set ends within about 3 reps of failure, and warm-up sets do not count. The app counts sets instead of total weight lifted, because hard sets across a wide range of reps build about the same amount of muscle (see Rep ranges)."
                ),
                .paragraph(
                    "Across studies, more weekly sets lead to more growth. Schoenfeld, Ogborn and Krieger (2017) pooled 15 studies and found that growth rose step by step with weekly sets. Pelland and colleagues (2026) analyzed 67 studies and saw the same rise, with each extra set adding a little less than the one before."
                ),
                .heading("Four landmarks"),
                .paragraph(
                    "Mike Israetel and his colleagues at Renaissance Periodization (RP) named four points on that curve. The app uses their names."
                ),
                .bullets([
                    "**MV, maintenance volume.** About enough sets to keep the muscle you have. Useful in a busy stretch or while dieting.",
                    "**MEV, minimum effective volume.** The fewest weekly sets that still produce growth. Each block starts near here.",
                    "**MAV, maximum adaptive volume.** The range where most people grow best. It is a band, not a single number.",
                    "**MRV, maximum recoverable volume.** The most sets you can do and still recover. Past it, performance drops and growth stalls.",
                ]),
                .heading("Starting estimates"),
                .landmarksChart,
                .paragraph(
                    "A zero means other lifts already cover that landmark, so the muscle needs no direct sets to reach it. For example, presses train the front delts, and squats and hinges train the glutes."
                ),
                .heading("Why they are only a start"),
                .paragraph(
                    "These numbers are averages for intermediate lifters. Your own landmarks depend on genetics, training history, sleep, food, and stress, and they shift over time. You do not need to guess them. The app starts each block near MEV, adds sets when your feedback says you recovered, and holds or cuts sets when you did not. A muscle's weekly total never goes above the MRV shown here."
                ),
                .caveat(
                    "These landmark values are coaching estimates, not measurements from a study. Research supports the general shape, in which more sets give more growth with shrinking returns. It does not give exact numbers for each muscle."
                ),
            ],
            evidence: [.schoenfeld2017Volume, .pelland2026, .israetel2021]
        ),

        Article(
            id: "mesocycle", category: .system,
            title: "Mesocycles", symbol: "calendar",
            summary: "Why training runs in blocks that get harder each week and then back off.",
            takeaways: [
                "A mesocycle, or block, is 3 to 6 weeks of building work followed by one easy deload week.",
                "Sets start near MEV and rise with your feedback. Reps in reserve fall each week, so the last week ends at failure.",
                "The deload clears fatigue, and the next block starts near MEV again.",
            ],
            blocks: [
                .heading("The shape of a block"),
                .paragraph(
                    "The app plans training in mesocycles, also called blocks. A block has 3 to 6 accumulation weeks and then one deload week. During accumulation two things rise together. Each muscle gets more sets as your feedback allows, and each set ends closer to failure."
                ),
                .paragraph(
                    "This layout follows the way RP builds hypertrophy programs. Starting easy leaves room to add work. Ending hard pushes training as far as you can recover from. Fatigue builds along the way, so the hard part stays short."
                ),
                .heading("The RIR countdown"),
                .paragraph(
                    "Every accumulation week has a target for reps in reserve (RIR), the number of reps you could still do when you end a set. The target counts down to 0 in the final week. Pick a block length to see the plan."
                ),
                .rirCountdown,
                .paragraph(
                    "The rule takes the number of accumulation weeks left after the current one and caps it at 3. A 4-week block runs 3, 2, 1, 0. A 3-week block starts at 2. A 6-week block holds 3 RIR for three weeks, because the app never sets a target more than 3 reps from failure."
                ),
                .heading("How sets climb"),
                .paragraph(
                    "In week 1 each muscle gets about its MEV, split across the sessions and exercises that train it, with at least 2 sets per exercise. Week 1 also asks for reps in the lower half of each exercise's range. If the app has no earlier numbers for an exercise, you pick a weight that leaves the target RIR. All of this leaves room to add reps and sets later."
                ),
                .paragraph(
                    "After each session the app reads your feedback and adds, holds, or removes sets for the next week (see Session feedback). By the final week most muscles usually sit inside their MAV, and some get close to their MRV."
                ),
                .heading("Then a deload"),
                .paragraph(
                    "Early weeks feel easy on purpose. The last week should feel like real work. The deload week that follows cuts sets in half so fatigue can clear (see Deloads). Then a new block starts near MEV again. If you got stronger, the same RIR targets land on heavier weights or more reps than before."
                ),
                .caveat(
                    "The block length and the countdown come from coaching practice, mostly RP's. Studies show that growth tends to improve as sets end closer to failure (Robinson et al., 2024). No study has tested this exact weekly countdown against other plans."
                ),
            ],
            evidence: [.israetel2021, .robinson2024]
        ),

        Article(
            id: "overload", category: .system,
            title: "Progressive overload", symbol: "arrow.up.right.circle",
            summary: "Add reps first, then weight. How the app sets each week's targets.",
            takeaways: [
                "Each week the app keeps your weight and adds the reps that the lower RIR target frees up.",
                "When reps pass the top of an exercise's range, the weight goes up by the smallest step and the reps reset.",
                "If a set falls 2 or more reps short, next week repeats the same target.",
            ],
            blocks: [
                .heading("Why do more"),
                .paragraph(
                    "As you get stronger, the same weight for the same reps leaves more reps in reserve, so each set does less for the muscle. Progressive overload means asking for a little more over time so that sets stay hard. More reps at the same weight counts, and so does more weight."
                ),
                .paragraph(
                    "Plotkin and colleagues (2022) had trained lifters add either load or reps for 8 weeks. Both groups grew about the same amount of muscle. The app uses both, reps first and then load."
                ),
                .heading("Reps first"),
                .paragraph(
                    "The app starts from what you logged last week. It keeps the weight and adds the reps that the lower RIR target frees up. If you logged 10 reps at 2 RIR, the target at 1 RIR is 11 reps with the same weight. In weeks where the RIR target stays the same, the new target matches what you did, so beating last week's target raises this week's."
                ),
                .heading("Then weight"),
                .paragraph(
                    "Every exercise has a rep range, such as 8 to 12. When the new target would pass the top of that range, the app adds the smallest weight step for that equipment."
                ),
                .loadSteps,
                .paragraph(
                    "Then it works out reps for the heavier weight. It estimates your one-rep max with the Epley formula, counting your reps in reserve as reps you could have done, and solves for the reps that leave the new RIR target. The result stays inside the exercise's range. If the estimate is off, the next week corrects it, because every week starts from what you logged. Bodyweight exercises have no weight step, so they keep adding reps."
                ),
                .heading("When a set falls short"),
                .paragraph(
                    "Bad days happen. If a set comes in 2 or more reps below its target, the app repeats that target next week instead of raising it. A miss of 1 rep counts as normal day-to-day noise, so the app keeps progressing from the reps you did. If you skip a set, its target carries over unchanged."
                ),
                .paragraph(
                    "If many sets for one muscle keep falling short, say so in the workload and soreness questions. That is how the app learns to cut sets."
                ),
                .caveat(
                    "Adding reps and then load, often called double progression, is common coaching practice. The evidence supports progressing by either reps or load (Plotkin et al., 2022). The point where the app switches from one to the other is a design choice, not a tested rule."
                ),
            ],
            evidence: [.plotkin2022]
        ),

        Article(
            id: "rir", category: .gym,
            title: "Reps in reserve", symbol: "speedometer",
            summary: "How hard each set should be, and how to judge it.",
            takeaways: [
                "RIR is how many more good reps you could have done when you ended the set.",
                "Working sets stay between 3 RIR and 0 RIR. The app asks for 0 only in the last week of a block.",
                "Most people have about one more rep left than they think. Guesses are more accurate close to failure, with heavier weights, and in later sets.",
            ],
            blocks: [
                .heading("What it means"),
                .paragraph(
                    "Reps in reserve (RIR) rates how hard a set was. When you end a set, ask how many more reps you could have done with the same form. If the answer is two, that set was at 2 RIR. At 0 RIR you could not have done another rep."
                ),
                .paragraph(
                    "Zourdos and colleagues (2016) linked RIR to the familiar 1 to 10 effort scale, where a 10 means 0 RIR and a 9 means 1 RIR. Helms and colleagues (2016) described how to use it to set loads one set at a time. The app uses RIR because it adjusts to the day. A 2 RIR target asks for the same effort whether you slept well or badly, even if you get fewer reps on a bad day."
                ),
                .heading("How close to failure"),
                .paragraph(
                    "Growth does not require failure on every set. Refalo and colleagues (2023) found no clear extra growth from going all the way to failure compared with stopping a little short. Robinson and colleagues (2024) found that growth tends to improve as sets end closer to failure, while strength gains look similar across a wide range of RIR."
                ),
                .paragraph(
                    "The app follows both findings. Every working set lands between 3 and 0 RIR, so every set is hard. A target of 0 appears only in the last week of a block, when a deload is a week away."
                ),
                .rirCountdown,
                .heading("Judging it better"),
                .paragraph(
                    "Halperin and colleagues (2022) pooled 12 studies of lifters predicting their reps to failure. On average people guessed about one rep too few, so they had more left than they thought. Training experience made little difference. Guesses were more accurate close to failure, with heavier loads, and in later sets."
                ),
                .bullets([
                    "Now and then, take the last set of a machine or cable exercise to true failure. Compare the reps you got with the reps you expected.",
                    "Count only reps with the same form as the first rep. A rep that needs a bounce or a body swing does not count.",
                    "Reps slow down as you near failure. A clear slowdown means you are close.",
                ]),
            ],
            evidence: [.zourdos2016, .helms2016, .refalo2023, .robinson2024, .halperin2022]
        ),

        Article(
            id: "exercises", category: .gym,
            title: "Choosing exercises", symbol: "scalemass",
            summary: "Stimulus-to-fatigue ratio, and what makes one exercise better than another.",
            takeaways: [
                "A good exercise trains the target muscle hard without much extra fatigue. RP calls this the stimulus-to-fatigue ratio (SFR).",
                "Stable machines and cables, a strong stretch, and pain-free joints usually mean a better ratio.",
                "Keep the same exercises for a whole block so your progress is easy to read.",
            ],
            blocks: [
                .heading("Stimulus and fatigue"),
                .paragraph(
                    "Every set does two things. It gives the target muscle a reason to grow, and it adds fatigue to that muscle, your joints, and your body as a whole. RP calls the balance between the two the stimulus-to-fatigue ratio, or SFR. An exercise with a high SFR gives a lot of growth stimulus for the fatigue it costs."
                ),
                .paragraph(
                    "This matters because recovery has a limit, and your MRV is that limit for each muscle. An exercise that spends recovery on fatigue that does not build the target muscle leaves fewer sets for the work that does."
                ),
                .heading("What raises SFR"),
                .bullets([
                    "**Stability.** When a machine, bench, or pad holds you in place, more effort goes to the target muscle and less to balance.",
                    "**Load in the stretch.** Exercises that work the muscle hard while it is long tend to grow it well (see Technique for growth).",
                    "**Joint comfort.** An exercise that hurts a joint costs recovery and limits how hard you can push. Swap it.",
                    "**Feeling the muscle.** A strong pump and a clear sense that the target muscle did the work are rough signs of a good fit.",
                    "**Low whole-body cost.** Heavy deadlifts and squats tire you far beyond the muscles they target. They have a place, but each set costs a lot.",
                ]),
                .heading("An example"),
                .paragraph(
                    "Maeo and colleagues (2023) had 21 adults train one arm with overhead cable triceps extensions and the other with cable pushdowns, using the same sets and reps. After 12 weeks the long head of the triceps grew about 1.5 times as much in the overhead arm, even though that arm lifted lighter loads. More growth for less load on the elbow is a better ratio."
                ),
                .heading("Choosing your lifts"),
                .paragraph(
                    "Each exercise in the app shows a one-line cue about technique or SFR. When you set up a block, prefer exercises you feel in the target muscle and can do without joint pain. Keep them for the whole block, so that gains in reps and weight reflect real progress and not a new movement. Between blocks, swap any lift whose feedback kept showing joint pain or a weak pump."
                ),
                .caveat(
                    "SFR is a coaching idea from RP, not something a study can measure directly. Research backs parts of it, such as the benefit of training muscles at long lengths (Maeo et al., 2021). The rest comes from coaching experience."
                ),
            ],
            evidence: [.israetel2021, .maeo2023, .maeo2021]
        ),

        Article(
            id: "reps", category: .gym,
            title: "Rep ranges", symbol: "number.circle",
            summary: "Why light and heavy sets both build muscle, and how the app picks a range.",
            takeaways: [
                "Light and heavy sets build similar muscle when both end close to failure.",
                "Heavy sets build more max strength. Light sets take more reps and more burning to reach the same effort.",
                "Each exercise has its own range, chosen so you can judge RIR and add reps in small steps.",
            ],
            blocks: [
                .heading("An old rule"),
                .paragraph(
                    "A common gym rule says heavy weights build strength, moderate weights build size, and light weights build endurance. Schoenfeld and colleagues (2021) re-examined this rule, often called the repetition continuum. They concluded that muscle growth happens across a wide range of loads, as long as the sets are hard."
                ),
                .paragraph(
                    "An earlier meta-analysis from the same group (Schoenfeld et al., 2017) compared light loads, 60% of max or less, with heavier loads in 21 studies where every set went to failure. Muscle growth was similar. Gains in one-rep max favored the heavy loads."
                ),
                .heading("Why ranges still matter"),
                .paragraph("If many rep counts build muscle, the choice comes down to practical trade-offs."),
                .bullets([
                    "**Very low reps** need heavy weights. Each rep loads the joints more, and one missed rep is a large share of the set.",
                    "**Very high reps** bring burning and heavy breathing that can end a set before the muscle is near failure. RIR is also harder to judge with light loads (Halperin et al., 2022).",
                    "**Moderate reps** let you judge RIR well and add reps in small steps.",
                ]),
                .paragraph(
                    "So each exercise in the app has a range that suits it. Big compound lifts like squats and bench presses sit around 5 to 10 reps. Isolation lifts like curls and lateral raises sit around 10 to 20. A 5 lb jump on a 20 lb dumbbell is a 25% increase, so these lifts need more room to add reps before the weight goes up."
                ),
                .heading("Mixing it up"),
                .paragraph(
                    "A week with some heavier work and some lighter work builds strength and size together. Within one exercise, keep the same range for the whole block so that progress is easy to see."
                ),
            ],
            evidence: [.schoenfeld2021, .schoenfeld2017Load, .halperin2022]
        ),

        Article(
            id: "technique", category: .gym,
            title: "Technique for growth", symbol: "figure.strengthtraining.traditional",
            summary: "Full range of motion, the stretched position, and controlled lowering.",
            takeaways: [
                "Use the full range of motion you can control, and do not cut reps short at the stretched end.",
                "When full reps run out, partial reps in the stretched half are the better kind of partial. Log only the full reps.",
                "Lower the weight under control. A slow count is not needed.",
            ],
            blocks: [
                .heading("Full range of motion"),
                .paragraph(
                    "In most studies, reps through a full range of motion build as much muscle as partial reps, or more. A 2023 meta-analysis by Wolf and colleagues found small advantages for full range across strength and size. The case is strongest for lower-body muscles. Studies on upper-body muscles are fewer and less consistent (Schoenfeld and Grgic, 2020)."
                ),
                .heading("The stretched position"),
                .paragraph(
                    "Where in the range a muscle works hardest seems to matter. Several studies found more growth when the muscle was loaded hard while long, or stretched."
                ),
                .bullets([
                    "Seated leg curls, which stretch the hamstrings at the hip, grew them more than lying leg curls (Maeo et al., 2021).",
                    "Overhead triceps extensions grew the triceps more than pushdowns (Maeo et al., 2023).",
                    "Knee extensions done only in the bent-knee half of the range grew parts of the quads more than full reps did (Pedrosa et al., 2022).",
                ]),
                .paragraph(
                    "Each of these studies had fewer than 50 people, so treat the effect as likely, not settled. In practice, pick exercises that load the stretched position, like the ones the app's cues point out, and control the bottom of each rep."
                ),
                .heading("Lengthened partials"),
                .paragraph(
                    "Near the end of a hard set you may run out of full reps. One option is a few extra partial reps in the stretched half of the movement. Wolf and colleagues saw a possible edge for partials at long muscle lengths, with wide uncertainty. If you add them, log only the full reps so the app's progression stays accurate."
                ),
                .heading("Controlled lowering"),
                .paragraph(
                    "Lower the weight under control instead of letting it drop. Control keeps the muscle loaded through the stretch and makes reps comparable from week to week. You do not need a slow count. Schoenfeld and colleagues (2015) found similar growth for reps lasting from half a second to 8 seconds. Very slow reps, over 10 seconds, looked worse, though few studies tested them."
                ),
            ],
            evidence: [.wolf2023, .schoenfeldGrgic2020, .maeo2021, .maeo2023, .pedrosa2022, .schoenfeld2015]
        ),

        Article(
            id: "feedback", category: .recovery,
            title: "Session feedback", symbol: "slider.horizontal.3",
            summary: "The four questions the app asks, and how each answer changes next week's sets.",
            takeaways: [
                "You rate pump, workload, and joint pain after training a muscle, and soreness at the start of its next session.",
                "Soreness and workload pick a set change from a table. Pump nudges it, and joint pain can stop it from adding sets.",
                "The table is a rule of thumb modeled on RP's approach, not a tested formula.",
            ],
            blocks: [
                .heading("The four questions"),
                .bullets([
                    "**Soreness.** Did the muscle never get sore, heal a while ago, heal just in time, or is it still sore?",
                    "**Pump.** How full and tight the muscle felt during and right after its sets.",
                    "**Workload.** How hard that muscle's sets felt, from easy to too much.",
                    "**Joint pain.** Any pain in the joints the exercises loaded. You can also report it mid-session from an exercise's menu.",
                ]),
                .paragraph(
                    "Soreness usually peaks a day or more after training, so the app cannot ask about it right away. It asks at the start of the next session that trains the muscle and writes the answer back to the session that caused it."
                ),
                .heading("From answers to sets"),
                .paragraph(
                    "Soreness tells the app whether the muscle recovered in time. Workload tells it how much the session took. Together they pick the change in sets for that muscle in that session next week. Use the controls under the table to see what pump and joint pain do."
                ),
                .feedbackGrid,
                .bullets([
                    "A low pump adds 1 set when the change is already positive. The muscle recovered but got little out of the session.",
                    "A great pump removes 1 set when the change is +2 or more, so a session that already worked grows more slowly.",
                    "The change stays between -1 and +3 sets per session.",
                    "Moderate or worse joint pain caps the change at 0. The app does not add sets to a movement that hurts.",
                    "New sets go to the exercise with the fewest sets, and cuts come from the one with the most. No exercise drops below 1 set, and no muscle goes above its weekly MRV.",
                    "If soreness or workload is missing, that muscle's sets stay the same.",
                ]),
                .heading("Reading soreness"),
                .paragraph(
                    "Soreness is a recovery signal, not a growth signal. Being very sore does not mean a session worked better (Schoenfeld and Contreras, 2013). Early in a training program, much of the response to a session goes to repairing damage rather than building new muscle (Damas et al., 2016). The app uses soreness for one question only. Did the muscle heal before you trained it again?"
                ),
                .caveat(
                    "This table is a heuristic modeled on how RP adjusts volume from feedback. The numbers are coaching judgment, and no study has tested them. The rule is cautious and runs every week, so a step in the wrong direction gets corrected the next week."
                ),
            ],
            evidence: [.israetel2021, .schoenfeldContreras2013, .damas2016]
        ),

        Article(
            id: "deload", category: .recovery,
            title: "Deloads", symbol: "bed.double",
            summary: "Why every block ends with an easy week, and what changes during it.",
            takeaways: [
                "A deload is a planned easy week that lets fatigue clear before the next block.",
                "The app halves your sets, rounded up, and goes back to week 1 weights and reps.",
                "Research on deloads is thin. In one trial a full week off did not slow muscle growth, though strength gains were a bit smaller.",
            ],
            blocks: [
                .heading("Why back off"),
                .paragraph(
                    "By the end of a block you are doing more sets than you started with, and every set ends at or near failure. Fatigue has built up. Weights feel heavier than they should, joints ache more, and motivation dips. Another hard week would usually make these worse."
                ),
                .paragraph(
                    "A deload lowers training stress for a short time. A 2023 consensus study of strength and physique coaches (Bell et al.) defined it as a planned period of lower training stress that reduces fatigue, helps recovery, and prepares you for the training that follows."
                ),
                .heading("What the app does"),
                .paragraph(
                    "The deload comes right after the last accumulation week. Each exercise gets half the sets you did in that last week, rounded up, using the weights and reps from week 1. Week 1 targets left 2 to 3 reps in reserve, and you are likely stronger now, so deload sets should feel easy."
                ),
                .paragraph(
                    "Keep the week easy even if you feel good by midweek. Feeling good means fatigue is clearing, which is the goal. Adding work back in would cut the deload short."
                ),
                .heading("What the evidence says"),
                .paragraph(
                    "Deloads are common in practice and rarely studied. Coleman and colleagues (2024) had trained lifters either stop lifting for one week in the middle of a 9-week program or keep training. Muscle growth was the same in both groups. The group that kept training gained a bit more strength."
                ),
                .paragraph(
                    "That study removed training completely, which differs from the app's lighter week, so it does not settle the question. The app uses a deload because it lets each block start fresh near MEV, the way RP programs are built. It is a reasonable default, not a proven requirement."
                ),
            ],
            evidence: [.bell2023, .coleman2024, .israetel2021]
        ),

        Article(
            id: "frequency", category: .recovery,
            title: "Training frequency", symbol: "repeat",
            summary: "How often to train each muscle, and why the programs hit most muscles twice a week.",
            takeaways: [
                "For a fixed number of weekly sets, how many days you spread them over matters little for growth.",
                "Training a muscle at least twice a week makes it easier to do enough good sets.",
                "Your soreness answers show whether a muscle recovers between sessions, and the app adjusts sets to match.",
            ],
            blocks: [
                .heading("What the studies show"),
                .paragraph(
                    "In 2016, Schoenfeld, Ogborn and Krieger pooled the studies then available and found that training a muscle twice a week grew more muscle than once a week. A 2019 update by Schoenfeld, Grgic and Krieger included more studies. When weekly sets were the same, how often people trained made no meaningful difference. Pelland and colleagues (2026) found the same for muscle growth, while strength did improve with more frequent training."
                ),
                .heading("Why the programs spread sets out"),
                .paragraph(
                    "Frequency still matters in a practical way. Twenty sets for one muscle in one session makes a long workout, and the last sets are done tired. Ten sets on each of two days is easier to do well. That is why every program in the app trains most muscles at least twice a week."
                ),
                .heading("Frequency and recovery"),
                .paragraph(
                    "The soreness question checks whether a muscle recovers between sessions. If it keeps healing early, it can take more sets, and the app adds them. If it is still sore every time you train it, the app cuts sets. If that keeps happening across blocks, a program that trains the muscle less often may suit you better."
                ),
                .heading("Picking a schedule"),
                .bullets([
                    "Choose a number of training days you can keep for a whole block. A missed session loses all of its sets, so a smaller plan you keep does more than a bigger plan you skip.",
                    "Two or three sessions per muscle each week fits most schedules and most volume levels.",
                    "As a muscle's weekly sets climb toward its MRV, more sessions keep each one shorter.",
                ]),
            ],
            evidence: [.schoenfeld2016Frequency, .schoenfeld2019Frequency, .pelland2026]
        ),
    ]
}
