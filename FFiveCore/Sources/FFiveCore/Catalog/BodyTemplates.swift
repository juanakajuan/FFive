extension ExerciseCatalog {
    static let wholeBodyTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Full Body, 2 Days",
            emphasis: .wholeBody,
            summary: "Suits anyone with only two training days who wants the whole body hit twice a week.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Bench Press", "Pull-Up", "Seated Leg Curl", "Lateral Raise", "Cable Curl"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Incline Dumbbell Press", "Seated Cable Row", "Leg Extension",
                        "Overhead Cable Extension", "Calf Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Full Body, 3 Days",
            emphasis: .wholeBody,
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
            emphasis: .wholeBody,
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
            name: "Upper/Lower + Full Body, 5 Days",
            emphasis: .wholeBody,
            summary:
                "Suits intermediates with five days who want an upper/lower base plus one full body day for extra volume.",
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
                    "Full Body",
                    [
                        "Hack Squat", "Incline Dumbbell Press", "Lat Pulldown", "Hip Thrust", "Cable Lateral Raise",
                        "Cable Crunch",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Bench Press", "Chest-Supported Dumbbell Row", "Machine Shoulder Press", "Face Pull",
                        "Incline Dumbbell Curl", "Overhead Cable Extension",
                    ]),
                day(
                    "Lower B",
                    [
                        "Leg Press", "Stiff-Legged Deadlift", "Bulgarian Split Squat", "Seated Leg Curl",
                        "Seated Calf Raise", "Back Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Push/Pull/Legs, 6 Days",
            emphasis: .wholeBody,
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

    static let upperBodyTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Upper Body Focus, 2 Days",
            emphasis: .upperBody,
            summary:
                "Suits lifters with two days who want most of each session on chest, back and shoulders with one leg lift.",
            days: [
                day(
                    "Full Body A",
                    ["Bench Press", "Pull-Up", "Overhead Press", "Squat", "Lateral Raise", "Skull Crusher"]),
                day(
                    "Full Body B",
                    [
                        "Incline Dumbbell Press", "Seated Cable Row", "Romanian Deadlift", "Cable Lateral Raise",
                        "Face Pull", "EZ-Bar Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper Body Focus, 3 Days",
            emphasis: .upperBody,
            summary: "Suits lifters with three days who want two upper days and one solid leg day.",
            days: [
                day(
                    "Upper A",
                    [
                        "Bench Press", "Pull-Up", "Overhead Press", "Seated Cable Row", "Lateral Raise",
                        "Skull Crusher",
                    ]),
                day(
                    "Lower",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Chest-Supported Dumbbell Row", "Cable Lateral Raise",
                        "EZ-Bar Curl", "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper Body Focus, 4 Days",
            emphasis: .upperBody,
            summary: "Suits lifters with four days who want a bigger chest, back and shoulders with one solid leg day.",
            days: [
                day(
                    "Upper A",
                    [
                        "Bench Press", "Pull-Up", "Incline Dumbbell Press", "Seated Cable Row", "Lateral Raise",
                        "Skull Crusher",
                    ]),
                day(
                    "Lower",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Upper B",
                    [
                        "Overhead Press", "Lat Pulldown", "Dip", "Chest-Supported Dumbbell Row", "Cable Lateral Raise",
                        "EZ-Bar Curl",
                    ]),
                day(
                    "Upper C",
                    [
                        "Incline Bench Press", "Barbell Row", "Pec Deck", "Reverse Pec Deck", "Hammer Curl",
                        "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper Body Focus, 5 Days",
            emphasis: .upperBody,
            summary:
                "Suits lifters with five days who want push, pull and upper days plus a shoulders and arms day, with one leg day.",
            days: [
                day(
                    "Push",
                    ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Rope Pushdown"]),
                day("Pull", ["Pull-Up", "Barbell Row", "Seated Cable Row", "Face Pull", "Barbell Curl"]),
                day(
                    "Legs",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Upper",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Dip", "Chest-Supported Dumbbell Row",
                        "Cable Lateral Raise", "Hammer Curl",
                    ]),
                day(
                    "Shoulders & Arms",
                    [
                        "Machine Shoulder Press", "Seated Dumbbell Lateral Raise", "Reverse Pec Deck", "Skull Crusher",
                        "Incline Dumbbell Curl", "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper Body Focus, 6 Days",
            emphasis: .upperBody,
            summary:
                "Suits experienced lifters with six days who want upper body growth with a single dedicated leg day.",
            days: [
                day(
                    "Push A",
                    ["Bench Press", "Incline Dumbbell Press", "Overhead Press", "Lateral Raise", "Rope Pushdown"]),
                day("Pull A", ["Pull-Up", "Barbell Row", "Seated Cable Row", "Face Pull", "Barbell Curl"]),
                day(
                    "Legs",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Push B",
                    [
                        "Dip", "Incline Bench Press", "Machine Shoulder Press", "Cable Fly", "Cable Lateral Raise",
                        "Overhead Cable Extension",
                    ]),
                day(
                    "Pull B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "Reverse Pec Deck", "Barbell Shrug",
                        "Incline Dumbbell Curl", "Hammer Curl",
                    ]),
                day(
                    "Shoulders & Arms",
                    [
                        "Seated Dumbbell Lateral Raise", "Skull Crusher", "EZ-Bar Curl", "Dumbbell Overhead Extension",
                        "Cable Curl", "Rear Delt Fly",
                    ]),
            ]
        ),
    ]

    static let lowerBodyTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Lower Body Focus, 2 Days",
            emphasis: .lowerBody,
            summary: "Suits lifters with two days who want each session led by legs with a short upper block.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Bench Press", "Pull-Up", "Calf Raise"]),
                day(
                    "Full Body B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Incline Dumbbell Press", "Seated Cable Row",
                        "Seated Calf Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Lower Body Focus, 3 Days",
            emphasis: .lowerBody,
            summary: "Suits lifters with three days who want two lower days and one upper day.",
            days: [
                day(
                    "Lower A",
                    [
                        "Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Upper",
                    ["Bench Press", "Pull-Up", "Overhead Press", "Seated Cable Row", "EZ-Bar Curl", "Rope Pushdown"]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Lower Body Focus, 4 Days",
            emphasis: .lowerBody,
            summary: "Suits lifters with four days who want bigger legs with three lower days and one upper day.",
            days: [
                day(
                    "Lower A",
                    [
                        "Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Upper",
                    ["Bench Press", "Pull-Up", "Overhead Press", "Seated Cable Row", "EZ-Bar Curl", "Rope Pushdown"]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
                day(
                    "Lower C",
                    [
                        "Leg Press", "Stiff-Legged Deadlift", "Leg Extension", "Cable Pull-Through",
                        "Leg Press Calf Raise", "Back Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Lower Body Focus, 5 Days",
            emphasis: .lowerBody,
            summary:
                "Suits lifters with five days who want three lower days split by quads and hips, plus two upper days.",
            days: [
                day(
                    "Quads",
                    [
                        "Squat", "Hack Squat", "Leg Extension", "Bulgarian Split Squat", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Upper A",
                    ["Bench Press", "Pull-Up", "Overhead Press", "Seated Cable Row", "Lateral Raise", "Rope Pushdown"]),
                day(
                    "Hamstrings & Glutes",
                    [
                        "Romanian Deadlift", "Hip Thrust", "Lying Leg Curl", "Cable Pull-Through", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Chest-Supported Dumbbell Row", "Cable Lateral Raise",
                        "EZ-Bar Curl", "Overhead Cable Extension",
                    ]),
                day(
                    "Legs",
                    [
                        "Leg Press", "Stiff-Legged Deadlift", "Lunge", "Seated Leg Curl", "Hip Abduction Machine",
                        "Leg Press Calf Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Lower Body Focus, 6 Days",
            emphasis: .lowerBody,
            summary:
                "Suits experienced lifters with six days who want bigger legs and glutes with a light upper body schedule.",
            days: [
                day(
                    "Quads",
                    [
                        "Squat", "Hack Squat", "Leg Extension", "Bulgarian Split Squat", "Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Push",
                    ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Rope Pushdown"]),
                day(
                    "Hamstrings & Glutes",
                    [
                        "Romanian Deadlift", "Hip Thrust", "Lying Leg Curl", "Cable Pull-Through", "Seated Leg Curl",
                        "Seated Calf Raise",
                    ]),
                day(
                    "Pull",
                    ["Pull-Up", "Seated Cable Row", "Chest-Supported Dumbbell Row", "Face Pull", "Barbell Curl"]),
                day(
                    "Legs",
                    [
                        "Leg Press", "Stiff-Legged Deadlift", "Lunge", "Hip Abduction Machine", "Leg Extension",
                        "Leg Press Calf Raise",
                    ]),
                day(
                    "Arms & Delts",
                    [
                        "Cable Lateral Raise", "Skull Crusher", "EZ-Bar Curl", "Overhead Cable Extension",
                        "Hammer Curl", "Reverse Pec Deck",
                    ]),
            ]
        ),
    ]

    /// Short sessions of about 25 minutes. The barbell-only and dumbbell-only ones fit a home or hotel setup.
    static let timeSaverTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Time-Saver Full Body, 2 Days",
            emphasis: .timeSaver,
            summary: "Suits busy lifters with two short days who can spare about 25 minutes a session.",
            days: [
                day("Full Body A", ["Squat", "Bench Press", "Pull-Up", "Lateral Raise"]),
                day("Full Body B", ["Romanian Deadlift", "Overhead Press", "Seated Cable Row", "Tricep Pushdown"]),
            ]
        ),
        ProgramTemplate(
            name: "Barbell-Only Full Body, 2 Days",
            emphasis: .timeSaver,
            summary: "Suits lifters with just a barbell, plates and a bench, training two short days a week.",
            days: [
                day("Full Body A", ["Squat", "Bench Press", "Barbell Row", "Barbell Curl"]),
                day("Full Body B", ["Romanian Deadlift", "Overhead Press", "Barbell Row", "Skull Crusher"]),
            ]
        ),
        ProgramTemplate(
            name: "Dumbbell-Only Full Body, 2 Days",
            emphasis: .timeSaver,
            summary: "Suits lifters with just dumbbells and a bench, training two short days a week.",
            days: [
                day("Full Body A", ["Goblet Squat", "Dumbbell Press", "Dumbbell Row", "Lateral Raise"]),
                day(
                    "Full Body B",
                    [
                        "Dumbbell Romanian Deadlift", "Dumbbell Shoulder Press", "Chest-Supported Dumbbell Row",
                        "Dumbbell Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Time-Saver Full Body, 3 Days",
            emphasis: .timeSaver,
            summary: "Suits busy lifters with three short days who can spare about 25 minutes a session.",
            days: [
                day("Full Body A", ["Squat", "Dumbbell Press", "Chest-Supported Dumbbell Row", "Rope Pushdown"]),
                day("Full Body B", ["Romanian Deadlift", "Machine Shoulder Press", "Lat Pulldown", "EZ-Bar Curl"]),
                day("Full Body C", ["Leg Press", "Incline Dumbbell Press", "Seated Cable Row", "Cable Lateral Raise"]),
            ]
        ),
        ProgramTemplate(
            name: "Barbell-Only Full Body, 3 Days",
            emphasis: .timeSaver,
            summary: "Suits lifters with just a barbell, plates and a bench, training three short days a week.",
            days: [
                day("Full Body A", ["Squat", "Bench Press", "Barbell Row", "EZ-Bar Curl"]),
                day("Full Body B", ["Deadlift", "Overhead Press", "Barbell Row", "Skull Crusher"]),
                day("Full Body C", ["Front Squat", "Incline Bench Press", "Romanian Deadlift", "Barbell Shrug"]),
            ]
        ),
        ProgramTemplate(
            name: "Dumbbell-Only Full Body, 3 Days",
            emphasis: .timeSaver,
            summary: "Suits lifters with just dumbbells and a bench, training three short days a week.",
            days: [
                day("Full Body A", ["Goblet Squat", "Dumbbell Press", "Dumbbell Row", "Lateral Raise"]),
                day(
                    "Full Body B",
                    [
                        "Dumbbell Romanian Deadlift", "Dumbbell Shoulder Press", "Chest-Supported Dumbbell Row",
                        "Hammer Curl",
                    ]),
                day(
                    "Full Body C",
                    ["Bulgarian Split Squat", "Incline Dumbbell Press", "Dumbbell Row", "Dumbbell Overhead Extension"]),
            ]
        ),
        ProgramTemplate(
            name: "Time-Saver Upper/Lower, 4 Days",
            emphasis: .timeSaver,
            summary: "Suits busy lifters with four short days who can spare about 25 minutes a session.",
            days: [
                day("Upper A", ["Bench Press", "Pull-Up", "Lateral Raise", "Tricep Pushdown"]),
                day("Lower A", ["Squat", "Lying Leg Curl", "Calf Raise"]),
                day("Upper B", ["Incline Dumbbell Press", "Seated Cable Row", "Face Pull", "Hammer Curl"]),
                day("Lower B", ["Romanian Deadlift", "Leg Press", "Hip Thrust", "Seated Calf Raise"]),
            ]
        ),
    ]
}
