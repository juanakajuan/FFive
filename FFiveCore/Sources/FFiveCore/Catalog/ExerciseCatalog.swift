import Foundation

public enum ExerciseCatalog {
    public static let all: [ExerciseInfo] = [
        x(
            "Bench Press", .chest, .barbell, 5...10,
            "Shoulder blades pinned, touch low on the chest, and press without bouncing."),
        x(
            "Incline Bench Press", .chest, .barbell, 6...10,
            "A low incline of about 30 degrees keeps the chest working instead of the front delts."),
        x(
            "Dumbbell Press", .chest, .dumbbell, 8...12,
            "Let the dumbbells sink a little below the chest for a deeper stretch than a barbell allows."),
        x(
            "Incline Dumbbell Press", .chest, .dumbbell, 8...12,
            "Lower slowly to a full stretch at the bottom, then drive up and slightly in."),
        x(
            "Machine Chest Press", .chest, .machine, 8...15,
            "The fixed path lets you push close to failure with little fatigue from balancing."),
        x(
            "Push-Up", .chest, .bodyweight, 10...20,
            "Keep a rigid plank and lower until the chest nearly touches the floor."),
        x(
            "Dip", .chest, .bodyweight, 8...15,
            "Lean the torso forward and sink until the chest stretches, without forcing the shoulders."),
        x(
            "Cable Fly", .chest, .cable, 10...20,
            "Keep a soft bend in the elbows and reach wide at the start for a strong stretch."),
        x(
            "Pec Deck", .chest, .machine, 10...20,
            "Set the seat so the handles start behind you, then squeeze through to the middle."),
        x(
            "Dumbbell Fly", .chest, .dumbbell, 10...15,
            "The load is heaviest at the bottom, so lower under control and stop at a deep stretch."),
        x(
            "Low-to-High Cable Fly", .chest, .cable, 12...20,
            "Sweep up toward chin height to bias the upper chest with almost no joint stress."),

        x("Pull-Up", .back, .bodyweight, 6...12, "Start from a dead hang and pull the elbows down toward the hips."),
        x(
            "Chin-Up", .back, .bodyweight, 6...12,
            "An underhand grip lets the lats move more weight through a long range."),
        x(
            "Lat Pulldown", .back, .cable, 8...15,
            "Lock the thighs under the pad and let the arms rise fully before each rep."),
        x(
            "Close-Grip Lat Pulldown", .back, .cable, 10...15,
            "A neutral close grip keeps the elbows tight to the body for a deep lat stretch."),
        x(
            "Single-Arm Lat Pulldown", .back, .cable, 10...15,
            "Working one side at a time lets you reach higher at the top and feel the lat lengthen."),
        x(
            "Straight-Arm Pulldown", .back, .cable, 12...20,
            "Keep the arms long and sweep the bar to the thighs so the lats do the work alone."),
        x(
            "Barbell Row", .back, .barbell, 6...10,
            "Brace hard, hold the torso angle, and row the bar to the lower ribs without heaving."),
        x(
            "Dumbbell Row", .back, .dumbbell, 8...12,
            "Let the dumbbell hang to a full stretch, then row it toward the hip."),
        x(
            "Chest-Supported Dumbbell Row", .back, .dumbbell, 8...12,
            "The bench removes the lower back from the lift, so the upper back takes all the fatigue."),
        x(
            "Seated Cable Row", .back, .cable, 8...15,
            "Reach forward to stretch, then pull to the stomach while staying tall."),
        x(
            "Machine Row", .back, .machine, 8...15,
            "A stable machine lets you take sets close to failure with little setup cost."),
        x("T-Bar Row", .back, .machine, 8...12, "Keep the chest on the pad and pull the elbows back past the torso."),

        x(
            "Squat", .quads, .barbell, 5...10,
            "Sit straight down between the heels and hit full depth at a steady speed."),
        x(
            "Front Squat", .quads, .barbell, 6...10,
            "The front rack keeps the torso upright, which loads the quads more than the hips."),
        x(
            "Hack Squat", .quads, .machine, 8...12,
            "Feet low on the platform and knees forward to give the quads the deepest bend."),
        x(
            "Pendulum Squat", .quads, .machine, 8...12,
            "The arc stays easy on the back while the quads work through a full range."),
        x(
            "Smith Squat", .quads, .smith, 8...12,
            "Place the feet slightly forward and sink deep; the fixed bar removes balance demands."),
        x(
            "Leg Press", .quads, .machine, 8...15,
            "Lower until the hips are about to curl off the pad, and keep the lower back flat."),
        x(
            "Lunge", .quads, .dumbbell, 8...12,
            "Take a moderate step and let the front knee travel forward to keep the work on the quads."),
        x(
            "Bulgarian Split Squat", .quads, .dumbbell, 8...12,
            "Rear foot on a bench, sink the back knee low, and push through the whole front foot."),
        x(
            "Goblet Squat", .quads, .dumbbell, 10...15,
            "Holding the weight in front keeps you upright and makes depth easy to find."),
        x(
            "Leg Extension", .quads, .machine, 10...20,
            "Lean back slightly to lengthen the quads and pause briefly at the top."),
        x(
            "Sissy Squat", .quads, .bodyweight, 10...20,
            "Hold a support, let the knees travel far forward, and lean back to stretch the quads."),

        x(
            "Romanian Deadlift", .hamstrings, .barbell, 6...10,
            "Push the hips back with soft knees and stop once the hamstrings are fully stretched."),
        x(
            "Stiff-Legged Deadlift", .hamstrings, .barbell, 6...10,
            "Straighter knees put more stretch on the hamstrings, so use a lighter load than a deadlift."),
        x(
            "Dumbbell Romanian Deadlift", .hamstrings, .dumbbell, 8...12,
            "Slide the dumbbells down the thighs and keep the back flat as the hips travel back."),
        x(
            "Good Morning", .hamstrings, .barbell, 6...10,
            "Hinge slowly with the bar on the back until the hamstrings stop the descent."),
        x(
            "Leg Curl", .hamstrings, .machine, 10...15,
            "Control the return and let the legs straighten fully before the next rep."),
        x(
            "Seated Leg Curl", .hamstrings, .machine, 10...15,
            "Sitting with the hips bent stretches the hamstrings more, which makes this a top pick."),
        x(
            "Lying Leg Curl", .hamstrings, .machine, 10...15,
            "Keep the hips pressed into the pad so the hamstrings, not the lower back, finish the rep."),
        x(
            "Nordic Curl", .hamstrings, .bodyweight, 5...10,
            "Lower yourself as slowly as you can; the eccentric is where this one works."),
        x(
            "Glute-Ham Raise", .hamstrings, .bodyweight, 6...12,
            "Bend at the knees to pull the torso up, keeping a straight line from knee to shoulder."),

        x(
            "Hip Thrust", .glutes, .barbell, 8...12,
            "Tuck the chin, drive through the heels, and pause with the hips fully extended."),
        x(
            "Smith Hip Thrust", .glutes, .smith, 8...12,
            "The fixed bar removes balancing, so all the effort goes into extending the hips."),
        x(
            "Deadlift", .glutes, .barbell, 5...8,
            "Wedge in tight before the bar leaves the floor; high fatigue cost, so keep volume modest."),
        x(
            "Cable Pull-Through", .glutes, .cable, 10...15,
            "Hinge back against the cable's pull, then squeeze the hips forward to stand tall."),
        x(
            "Back Extension", .glutes, .bodyweight, 10...20,
            "Round slightly at the top and drive with the hips to bias the glutes over the lower back."),
        x(
            "Hip Abduction Machine", .glutes, .machine, 12...20,
            "Lean forward a little and push the knees out under control to load the upper glutes."),
        x(
            "Cable Kickback", .glutes, .cable, 12...20,
            "Brace on the frame and kick back and slightly out without arching the lower back."),

        x(
            "Lateral Raise", .sideDelts, .dumbbell, 12...20,
            "Lead with the elbows and raise out to the sides, stopping near shoulder height."),
        x(
            "Seated Dumbbell Lateral Raise", .sideDelts, .dumbbell, 12...20,
            "Sitting takes the legs out, so the delts cannot cheat the weight up."),
        x(
            "Lean-Away Lateral Raise", .sideDelts, .dumbbell, 12...20,
            "Lean away from a post so the delt is loaded even at the bottom of the rep."),
        x(
            "Incline Side-Lying Lateral Raise", .sideDelts, .dumbbell, 12...20,
            "Lying on an incline bench keeps tension on the delt through the stretched position."),
        x(
            "Cable Lateral Raise", .sideDelts, .cable, 12...20,
            "The cable keeps tension at the bottom, where dumbbells go slack."),
        x(
            "Behind-the-Back Cable Lateral Raise", .sideDelts, .cable, 12...20,
            "Running the cable behind you starts the delt in a longer, more stretched position."),
        x(
            "Cable Y-Raise", .sideDelts, .cable, 12...20,
            "Raise the handles up and out in a Y and stop before the traps take over."),
        x(
            "Machine Lateral Raise", .sideDelts, .machine, 12...20,
            "Line the shoulder up with the pivot and push with the elbows, not the hands."),
        x(
            "Cable Upright Row", .sideDelts, .cable, 10...15,
            "Use a wide grip and pull the elbows out to shoulder height, no higher."),

        x(
            "Face Pull", .rearDelts, .cable, 12...20,
            "Pull the rope toward the eyes with elbows high and spread the hands apart at the end."),
        x(
            "Rear Delt Fly", .rearDelts, .dumbbell, 12...20,
            "Hinge over, keep the arms nearly straight, and sweep wide with no torso swing."),
        x(
            "Reverse Pec Deck", .rearDelts, .machine, 12...20,
            "Face the pad and move the arms in a wide arc without squeezing the shoulder blades."),
        x(
            "Cable Rear Delt Fly", .rearDelts, .cable, 12...20,
            "Cross the cables and pull them apart at shoulder height for tension through the full range."),
        x(
            "Wide-Grip Rear Delt Row", .rearDelts, .cable, 10...15,
            "Row with the elbows flared wide so the rear delts lead instead of the lats."),

        x(
            "Overhead Press", .frontDelts, .barbell, 5...10,
            "Squeeze the glutes, press the bar straight up, and move the head through at the top."),
        x(
            "Dumbbell Shoulder Press", .frontDelts, .dumbbell, 8...12,
            "Lower the dumbbells to ear level for a full range without straining the shoulders."),
        x(
            "Machine Shoulder Press", .frontDelts, .machine, 8...12,
            "A stable path lets you train hard with little fatigue from bracing."),
        x(
            "Smith Shoulder Press", .frontDelts, .smith, 8...12,
            "Sit with the bar just in front of the face and lower it to chin height."),
        x(
            "Arnold Press", .frontDelts, .dumbbell, 8...12,
            "Rotate the palms out as you press for a longer range at the front of the shoulder."),
        x(
            "Front Raise", .frontDelts, .dumbbell, 10...15,
            "Raise to eye level without swinging; pressing often covers this muscle already."),

        x(
            "Barbell Curl", .biceps, .barbell, 8...12,
            "Pin the elbows at your sides and lower the bar all the way down each rep."),
        x(
            "EZ-Bar Curl", .biceps, .barbell, 8...12,
            "The angled grip is easier on the wrists, so you can load the biceps heavier."),
        x(
            "Dumbbell Curl", .biceps, .dumbbell, 8...15,
            "Turn the palms up as you curl and lower slowly to a straight arm."),
        x(
            "Hammer Curl", .biceps, .dumbbell, 8...15,
            "A neutral grip brings in the brachialis and forearm, so it adds arm size beyond the biceps."),
        x(
            "Incline Dumbbell Curl", .biceps, .dumbbell, 10...15,
            "Arms hang behind the body on the incline, which stretches the biceps at the bottom."),
        x(
            "Preacher Curl", .biceps, .barbell, 8...12,
            "Keep the upper arm flat on the pad and control the bottom, where the load peaks."),
        x(
            "Machine Preacher Curl", .biceps, .machine, 10...15,
            "The machine keeps tension steady, so you can push close to failure safely."),
        x(
            "Spider Curl", .biceps, .dumbbell, 10...15,
            "Lie chest down on an incline and curl straight up for hard work at the top."),
        x(
            "Cable Curl", .biceps, .cable, 10...15,
            "Constant cable tension keeps the biceps working at both ends of the rep."),
        x(
            "Behind-the-Body Cable Curl", .biceps, .cable, 10...15,
            "Face away from the cable so the arm starts behind you in a long, stretched position."),

        x(
            "Close-Grip Bench Press", .triceps, .barbell, 6...10,
            "Grip about shoulder width and keep the elbows tucked to shift work to the triceps."),
        x(
            "JM Press", .triceps, .barbell, 8...12,
            "Lower the bar toward the chin by bending the elbows forward, then extend back up."),
        x(
            "Skull Crusher", .triceps, .barbell, 8...12,
            "Lower the bar behind the head, not to the forehead, for a deeper triceps stretch."),
        x(
            "Tricep Pushdown", .triceps, .cable, 10...15,
            "Pin the elbows at your sides and lock the arms out fully at the bottom."),
        x("Rope Pushdown", .triceps, .cable, 10...15, "Split the rope apart at the bottom for a full lockout."),
        x(
            "Overhead Cable Extension", .triceps, .cable, 10...15,
            "Arms overhead stretch the long head, which tends to grow well from this angle."),
        x(
            "Dumbbell Overhead Extension", .triceps, .dumbbell, 10...15,
            "Lower the dumbbell deep behind the head and keep the elbows pointed forward."),
        x(
            "Machine Dip", .triceps, .machine, 8...12,
            "Stay upright and press down to lockout; the machine removes the shoulder strain of dips."),
        x(
            "Close-Grip Push-Up", .triceps, .bodyweight, 10...20,
            "Hands under the shoulders and elbows tight to load the triceps with no equipment."),

        x(
            "Calf Raise", .calves, .machine, 10...20,
            "Pause at the bottom in a full stretch before rising; the stretch drives growth here."),
        x(
            "Seated Calf Raise", .calves, .machine, 12...20,
            "Bent knees shift the work to the soleus, so pair it with a straight-leg raise."),
        x(
            "Leg Press Calf Raise", .calves, .machine, 10...20,
            "Keep the knees straight and let the heels drop as far as the sled allows."),
        x(
            "Smith Calf Raise", .calves, .smith, 10...20,
            "Stand on a raised plate so the heels can sink well below the toes."),
        x(
            "Single-Leg Calf Raise", .calves, .dumbbell, 10...20,
            "One leg at a time on a step gives a big range with only a light dumbbell."),

        x(
            "Barbell Shrug", .traps, .barbell, 10...15,
            "Lift the shoulders straight up toward the ears and hold the top for a second."),
        x(
            "Dumbbell Shrug", .traps, .dumbbell, 10...20,
            "Dumbbells at your sides let the shoulders travel straight up without the bar in the way."),
        x(
            "Cable Shrug", .traps, .cable, 12...20,
            "The cable keeps tension at the bottom, so let the shoulders drop fully each rep."),
        x("Smith Shrug", .traps, .smith, 10...15, "The fixed bar lets you load heavy and focus only on the shrug."),

        x(
            "Wrist Curl", .forearms, .barbell, 12...20,
            "Rest the forearms on the thighs and let the bar roll to the fingertips before curling."),
        x(
            "Reverse Wrist Curl", .forearms, .dumbbell, 12...20,
            "Palms down with a light weight, lifting the back of the hand toward the ceiling."),
        x(
            "Cable Wrist Curl", .forearms, .cable, 12...20,
            "The cable keeps the forearm flexors loaded through the full range."),
        x(
            "Reverse Curl", .forearms, .barbell, 10...15,
            "An overhand grip makes the forearm muscles do most of the curling."),

        x(
            "Cable Crunch", .abs, .cable, 10...20,
            "Round the spine to bring the ribs toward the hips, keeping the hips still."),
        x(
            "Machine Crunch", .abs, .machine, 10...20,
            "Curl the torso down by flexing the spine, not by pulling with the arms."),
        x(
            "Hanging Leg Raise", .abs, .bodyweight, 10...20,
            "Curl the pelvis up at the top so the abs, not the hip flexors, finish the rep."),
        x(
            "Reverse Crunch", .abs, .bodyweight, 10...20,
            "Roll the hips off the floor slowly and lower them with control."),
        x(
            "Decline Sit-Up", .abs, .bodyweight, 10...20,
            "Curl up one vertebra at a time and hold a weight once bodyweight gets easy."),
        x(
            "Ab Wheel", .abs, .bodyweight, 8...15,
            "Keep the hips tucked and roll only as far as you can without the lower back sagging."),
        x(
            "Plank", .abs, .bodyweight, 20...60,
            "Log seconds held as reps; squeeze the glutes and brace as if bracing for a punch."),
    ]

    public static let templates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Full Body, 3 Days",
            summary: "Suits beginners or anyone with three training days who wants each muscle hit twice a week.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Bench Press", "Pull-Up", "Seated Leg Curl", "Incline Dumbbell Curl", "Lateral Raise"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Incline Dumbbell Press", "Chest-Supported Dumbbell Row",
                        "Overhead Cable Extension", "Cable Curl", "Cable Lateral Raise",
                    ]),
                day(
                    "Full Body C",
                    [
                        "Leg Press", "Machine Chest Press", "Seated Cable Row", "Rope Pushdown", "Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper/Lower, 4 Days",
            summary:
                "Suits intermediates with four days who want every muscle trained twice a week with room to add sets.",
            days: [
                day(
                    "Upper A",
                    ["Bench Press", "Pull-Up", "Seated Cable Row", "Lateral Raise", "EZ-Bar Curl", "Skull Crusher"]),
                day(
                    "Lower A",
                    [
                        "Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Chest-Supported Dumbbell Row", "Cable Lateral Raise", "Face Pull",
                        "Incline Dumbbell Curl", "Overhead Cable Extension",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Bulgarian Split Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper/Lower + Arms & Delts, 5 Days",
            summary:
                "Suits lifters with five days who want extra arm and side delt volume on top of an upper/lower base.",
            days: [
                day(
                    "Upper A",
                    [
                        "Bench Press", "Barbell Row", "Incline Dumbbell Press", "Lat Pulldown", "Lateral Raise",
                        "Hammer Curl",
                    ]),
                day(
                    "Lower A",
                    [
                        "Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Arms & Delts",
                    [
                        "Skull Crusher", "EZ-Bar Curl", "Cable Lateral Raise", "Overhead Cable Extension",
                        "Incline Dumbbell Curl", "Reverse Pec Deck",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Bench Press", "Pull-Up", "Chest-Supported Dumbbell Row", "Cable Fly",
                        "Machine Lateral Raise", "Tricep Pushdown",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Bulgarian Split Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Push/Pull/Legs, 6 Days",
            summary:
                "Suits experienced lifters who recover well and can train six days with shorter, focused sessions.",
            days: [
                day(
                    "Push A",
                    ["Bench Press", "Incline Dumbbell Press", "Lateral Raise", "Skull Crusher", "Rope Pushdown"]),
                day("Pull A", ["Pull-Up", "Barbell Row", "Barbell Shrug", "Face Pull", "Barbell Curl", "Hammer Curl"]),
                day(
                    "Legs A",
                    [
                        "Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Push B", ["Dip", "Overhead Press", "Pec Deck", "Cable Lateral Raise", "Overhead Cable Extension"]),
                day(
                    "Pull B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "Reverse Pec Deck", "Incline Dumbbell Curl",
                        "Cable Curl", "Wrist Curl",
                    ]),
                day(
                    "Legs B",
                    [
                        "Hack Squat", "Bulgarian Split Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
    ]

    static let byID: [ExerciseID: ExerciseInfo] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func info(_ id: ExerciseID) -> ExerciseInfo? {
        byID[id]
    }

    static func resolve(_ name: String) -> TemplateSlot? {
        info(ExerciseID(folding: name)).map { TemplateSlot(muscle: $0.muscle, exercise: name) }
    }

    private static func x(
        _ name: String, _ muscle: Muscle, _ equipment: Equipment, _ reps: ClosedRange<Int>, _ cue: String
    ) -> ExerciseInfo {
        ExerciseInfo(name: name, muscle: muscle, equipment: equipment, repRange: reps, cue: cue)
    }

    private static func day(_ name: String, _ exercises: [String]) -> TemplateDay {
        TemplateDay(name: name, exerciseNames: exercises, slots: exercises.compactMap(resolve))
    }
}
