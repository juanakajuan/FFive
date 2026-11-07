extension ExerciseCatalog {
    /// Each of these trains the abs on at least two days a week.
    static let glutesAndAbsTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Glute Focus Full Body, 2 Days",
            emphasis: .glutesAndAbs,
            summary: "Suits lifters with two days who want glutes and abs first while still training the whole body.",
            days: [
                day(
                    "Full Body A",
                    ["Hip Thrust", "Squat", "Seated Leg Curl", "Bench Press", "Pull-Up", "Cable Crunch"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Bulgarian Split Squat", "Hip Abduction Machine", "Incline Dumbbell Press",
                        "Seated Cable Row", "Hanging Leg Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Glute Focus Full Body, 3 Days",
            emphasis: .glutesAndAbs,
            summary: "Suits lifters with three days who want glute growth first while still training the whole body.",
            days: [
                day(
                    "Full Body A",
                    ["Hip Thrust", "Squat", "Seated Leg Curl", "Bench Press", "Pull-Up", "Cable Kickback"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Bulgarian Split Squat", "Hip Abduction Machine", "Incline Dumbbell Press",
                        "Seated Cable Row", "Hanging Leg Raise",
                    ]),
                day(
                    "Full Body C",
                    [
                        "Smith Hip Thrust", "Hack Squat", "Cable Pull-Through", "Machine Shoulder Press",
                        "Lat Pulldown", "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Glute Focus, 4 Days",
            emphasis: .glutesAndAbs,
            summary:
                "Suits lifters with four days who want glutes and abs trained twice a week alongside two upper days.",
            days: [
                day(
                    "Glutes A",
                    [
                        "Hip Thrust", "Squat", "Romanian Deadlift", "Hip Abduction Machine", "Calf Raise",
                        "Cable Crunch",
                    ]),
                day(
                    "Upper A",
                    ["Bench Press", "Pull-Up", "Seated Cable Row", "Lateral Raise", "Cable Curl", "Rope Pushdown"]),
                day(
                    "Glutes B",
                    [
                        "Smith Hip Thrust", "Bulgarian Split Squat", "Seated Leg Curl", "Cable Kickback",
                        "Back Extension", "Hanging Leg Raise",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Machine Shoulder Press",
                        "Chest-Supported Dumbbell Row", "Hammer Curl", "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Glute Focus, 5 Days",
            emphasis: .glutesAndAbs,
            summary:
                "Suits lifters with five days who want glutes trained three times a week alongside two upper days.",
            days: [
                day(
                    "Glutes A",
                    [
                        "Hip Thrust", "Romanian Deadlift", "Bulgarian Split Squat", "Hip Abduction Machine",
                        "Seated Leg Curl", "Calf Raise",
                    ]),
                day(
                    "Upper A",
                    ["Bench Press", "Pull-Up", "Seated Cable Row", "Lateral Raise", "Cable Curl", "Rope Pushdown"]),
                day(
                    "Glutes B",
                    ["Squat", "Smith Hip Thrust", "Lunge", "Cable Kickback", "Lying Leg Curl", "Hanging Leg Raise"]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Machine Shoulder Press",
                        "Chest-Supported Dumbbell Row", "Hammer Curl", "Overhead Cable Extension",
                    ]),
                day(
                    "Glutes C",
                    [
                        "Deadlift", "Hack Squat", "Back Extension", "Hip Abduction Machine", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Glute Focus, 6 Days",
            emphasis: .glutesAndAbs,
            summary:
                "Suits experienced lifters with six days who want glutes and abs three times a week with push, pull and upper days.",
            days: [
                day(
                    "Glutes A",
                    [
                        "Hip Thrust", "Squat", "Seated Leg Curl", "Hip Abduction Machine", "Calf Raise",
                        "Cable Crunch",
                    ]),
                day(
                    "Push",
                    [
                        "Bench Press", "Incline Dumbbell Press", "Machine Shoulder Press", "Lateral Raise",
                        "Rope Pushdown",
                    ]),
                day(
                    "Glutes B",
                    [
                        "Romanian Deadlift", "Bulgarian Split Squat", "Cable Kickback", "Back Extension",
                        "Seated Calf Raise", "Hanging Leg Raise",
                    ]),
                day(
                    "Pull", ["Pull-Up", "Seated Cable Row", "Chest-Supported Dumbbell Row", "Face Pull", "Cable Curl"]),
                day(
                    "Glutes C",
                    [
                        "Smith Hip Thrust", "Hack Squat", "Cable Pull-Through", "Lying Leg Curl",
                        "Hip Abduction Machine", "Ab Wheel",
                    ]),
                day(
                    "Upper",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Cable Lateral Raise", "Hammer Curl",
                        "Overhead Cable Extension", "Decline Sit-Up",
                    ]),
            ]
        ),
    ]

    static let chestAndTricepsTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Chest & Triceps Focus, 2 Days",
            emphasis: .chestAndTriceps,
            summary:
                "Suits lifters with two days who want each session led by chest and triceps with the rest kept on track.",
            days: [
                day(
                    "Full Body A",
                    ["Bench Press", "Incline Dumbbell Press", "Squat", "Pull-Up", "Skull Crusher", "Rope Pushdown"]),
                day(
                    "Full Body B",
                    [
                        "Incline Bench Press", "Dip", "Romanian Deadlift", "Seated Cable Row", "Cable Fly",
                        "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Triceps Focus, 3 Days",
            emphasis: .chestAndTriceps,
            summary: "Suits lifters with three days who want two chest and triceps days around one legs and back day.",
            days: [
                day(
                    "Chest & Triceps A",
                    [
                        "Bench Press", "Incline Dumbbell Press", "Cable Fly", "Skull Crusher", "Rope Pushdown",
                        "Lateral Raise",
                    ]),
                day(
                    "Legs & Back",
                    ["Squat", "Romanian Deadlift", "Pull-Up", "Seated Cable Row", "Lying Leg Curl", "Barbell Curl"]),
                day(
                    "Chest & Triceps B",
                    [
                        "Incline Bench Press", "Dip", "Pec Deck", "Overhead Cable Extension", "Tricep Pushdown",
                        "Cable Lateral Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Triceps Focus, 4 Days",
            emphasis: .chestAndTriceps,
            summary:
                "Suits lifters with four days who want an upper/lower split with chest and triceps leading each upper day.",
            days: [
                day(
                    "Upper A",
                    ["Bench Press", "Incline Dumbbell Press", "Pull-Up", "Cable Fly", "Skull Crusher", "Rope Pushdown"]),
                day(
                    "Lower A",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Upper B",
                    [
                        "Incline Bench Press", "Dip", "Seated Cable Row", "Pec Deck", "Lateral Raise",
                        "Overhead Cable Extension",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Hanging Leg Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Triceps Focus, 5 Days",
            emphasis: .chestAndTriceps,
            summary:
                "Suits lifters with five days who want a bigger chest and triceps with the rest of the body kept on track.",
            days: [
                day(
                    "Chest & Triceps A",
                    [
                        "Bench Press", "Incline Dumbbell Press", "Cable Fly", "Skull Crusher", "Rope Pushdown",
                        "Lateral Raise",
                    ]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day(
                    "Back & Biceps",
                    ["Pull-Up", "Chest-Supported Dumbbell Row", "Face Pull", "Barbell Curl", "Hammer Curl"]),
                day(
                    "Chest & Triceps B",
                    [
                        "Incline Bench Press", "Dumbbell Press", "Pec Deck", "Dip", "Overhead Cable Extension",
                        "Tricep Pushdown",
                    ]),
                day(
                    "Legs B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Triceps Focus, 6 Days",
            emphasis: .chestAndTriceps,
            summary:
                "Suits experienced lifters with six days who want chest and triceps three times a week with two leg days.",
            days: [
                day(
                    "Chest & Triceps A",
                    ["Bench Press", "Incline Dumbbell Press", "Cable Fly", "Skull Crusher", "Rope Pushdown"]),
                day("Pull", ["Pull-Up", "Seated Cable Row", "Face Pull", "Barbell Curl", "Hammer Curl"]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day(
                    "Chest & Triceps B",
                    ["Incline Bench Press", "Dip", "Pec Deck", "Overhead Cable Extension", "Lateral Raise"]),
                day(
                    "Legs B",
                    ["Hack Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise", "Cable Crunch"]),
                day(
                    "Upper",
                    [
                        "Machine Chest Press", "Low-to-High Cable Fly", "Lat Pulldown", "Cable Lateral Raise",
                        "JM Press", "Tricep Pushdown",
                    ]),
            ]
        ),
    ]

    static let backAndBicepsTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Back & Biceps Focus, 2 Days",
            emphasis: .backAndBiceps,
            summary:
                "Suits lifters with two days who want each session led by back and biceps with the rest kept on track.",
            days: [
                day(
                    "Full Body A",
                    ["Pull-Up", "Barbell Row", "Squat", "Bench Press", "Barbell Curl", "Incline Dumbbell Curl"]),
                day(
                    "Full Body B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "Romanian Deadlift", "Incline Dumbbell Press",
                        "Hammer Curl", "Cable Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Back & Biceps Focus, 3 Days",
            emphasis: .backAndBiceps,
            summary: "Suits lifters with three days who want two back and biceps days around one legs and push day.",
            days: [
                day(
                    "Back & Biceps A",
                    [
                        "Pull-Up", "Barbell Row", "Close-Grip Lat Pulldown", "Straight-Arm Pulldown", "Barbell Curl",
                        "Incline Dumbbell Curl",
                    ]),
                day(
                    "Legs & Push",
                    ["Squat", "Romanian Deadlift", "Bench Press", "Lying Leg Curl", "Lateral Raise", "Rope Pushdown"]),
                day(
                    "Back & Biceps B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "T-Bar Row", "Face Pull", "Hammer Curl",
                        "Cable Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Back & Biceps Focus, 4 Days",
            emphasis: .backAndBiceps,
            summary:
                "Suits lifters with four days who want an upper/lower split with back and biceps leading each upper day.",
            days: [
                day(
                    "Upper A",
                    [
                        "Pull-Up", "Barbell Row", "Bench Press", "Straight-Arm Pulldown", "Barbell Curl",
                        "Incline Dumbbell Curl",
                    ]),
                day(
                    "Lower A",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Upper B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "Incline Dumbbell Press", "Face Pull",
                        "Hammer Curl", "Cable Curl",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Hanging Leg Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Back & Biceps Focus, 5 Days",
            emphasis: .backAndBiceps,
            summary:
                "Suits lifters with five days who want a wider back and bigger biceps with the rest of the body kept on track.",
            days: [
                day(
                    "Back & Biceps A",
                    [
                        "Pull-Up", "Barbell Row", "Close-Grip Lat Pulldown", "Straight-Arm Pulldown", "Barbell Curl",
                        "Incline Dumbbell Curl",
                    ]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day("Push", ["Bench Press", "Pec Deck", "Lateral Raise", "Overhead Cable Extension", "Rope Pushdown"]),
                day(
                    "Back & Biceps B",
                    [
                        "Lat Pulldown", "Chest-Supported Dumbbell Row", "T-Bar Row", "Face Pull", "Hammer Curl",
                        "Cable Curl",
                    ]),
                day(
                    "Legs B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Cable Crunch",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Back & Biceps Focus, 6 Days",
            emphasis: .backAndBiceps,
            summary:
                "Suits experienced lifters with six days who want back and biceps three times a week with two leg days.",
            days: [
                day(
                    "Back & Biceps A",
                    ["Pull-Up", "Barbell Row", "Close-Grip Lat Pulldown", "Barbell Curl", "Incline Dumbbell Curl"]),
                day("Push", ["Bench Press", "Overhead Press", "Pec Deck", "Lateral Raise", "Rope Pushdown"]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day(
                    "Back & Biceps B",
                    ["Lat Pulldown", "Chest-Supported Dumbbell Row", "T-Bar Row", "Hammer Curl", "Cable Curl"]),
                day(
                    "Legs B",
                    ["Hack Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise", "Cable Crunch"]),
                day(
                    "Back & Arms",
                    [
                        "Single-Arm Lat Pulldown", "Seated Cable Row", "Straight-Arm Pulldown", "Face Pull",
                        "Preacher Curl", "Overhead Cable Extension",
                    ]),
            ]
        ),
    ]

    static let chestAndBackTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Chest & Back Focus, 2 Days",
            emphasis: .chestAndBack,
            summary: "Suits lifters with two days who want each session led by paired chest and back lifts.",
            days: [
                day(
                    "Full Body A",
                    ["Bench Press", "Pull-Up", "Incline Dumbbell Press", "Barbell Row", "Squat", "Lateral Raise"]),
                day(
                    "Full Body B",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Dip", "Chest-Supported Dumbbell Row",
                        "Romanian Deadlift", "Seated Leg Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Back Focus, 3 Days",
            emphasis: .chestAndBack,
            summary: "Suits lifters with three days who want two chest and back days around one leg day.",
            days: [
                day(
                    "Chest & Back A",
                    [
                        "Bench Press", "Pull-Up", "Incline Dumbbell Press", "Barbell Row", "Lateral Raise",
                        "Skull Crusher",
                    ]),
                day(
                    "Legs",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Chest & Back B",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Cable Fly", "Chest-Supported Dumbbell Row",
                        "Face Pull", "EZ-Bar Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Back Focus, 4 Days",
            emphasis: .chestAndBack,
            summary:
                "Suits lifters with four days who want an upper/lower split where each upper day pairs chest and back.",
            days: [
                day(
                    "Chest & Back A",
                    [
                        "Bench Press", "Pull-Up", "Incline Dumbbell Press", "Barbell Row", "Lateral Raise",
                        "Skull Crusher",
                    ]),
                day(
                    "Lower A",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Chest & Back B",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Cable Fly", "Chest-Supported Dumbbell Row",
                        "Face Pull", "EZ-Bar Curl",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Hanging Leg Raise",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Back Focus, 5 Days",
            emphasis: .chestAndBack,
            summary: "Suits lifters with five days who want chest and back three times a week with two leg days.",
            days: [
                day(
                    "Chest & Back A",
                    [
                        "Bench Press", "Pull-Up", "Incline Dumbbell Press", "Barbell Row", "Lateral Raise",
                        "Skull Crusher",
                    ]),
                day(
                    "Lower A",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Chest & Back B",
                    [
                        "Incline Bench Press", "Lat Pulldown", "Cable Fly", "Chest-Supported Dumbbell Row",
                        "Face Pull", "EZ-Bar Curl",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Hip Thrust", "Seated Leg Curl", "Bulgarian Split Squat", "Seated Calf Raise",
                        "Hanging Leg Raise",
                    ]),
                day(
                    "Chest & Back C",
                    [
                        "Machine Chest Press", "Seated Cable Row", "Pec Deck", "Straight-Arm Pulldown",
                        "Cable Lateral Raise", "Hammer Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Chest & Back Focus, 6 Days",
            emphasis: .chestAndBack,
            summary:
                "Suits experienced lifters with six days who want chest and back three times a week plus a shoulders and arms day.",
            days: [
                day(
                    "Chest & Back A",
                    ["Bench Press", "Pull-Up", "Incline Dumbbell Press", "Barbell Row", "Lateral Raise"]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day(
                    "Shoulders & Arms",
                    ["Overhead Press", "Cable Lateral Raise", "Reverse Pec Deck", "Skull Crusher", "EZ-Bar Curl"]),
                day(
                    "Chest & Back B",
                    ["Incline Bench Press", "Lat Pulldown", "Cable Fly", "Chest-Supported Dumbbell Row", "Face Pull"]),
                day(
                    "Legs B",
                    ["Hack Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise", "Cable Crunch"]),
                day(
                    "Chest & Back C",
                    [
                        "Machine Chest Press", "Seated Cable Row", "Pec Deck", "Straight-Arm Pulldown", "Hammer Curl",
                        "Rope Pushdown",
                    ]),
            ]
        ),
    ]

    static let armsAndShouldersTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Arms & Delts Focus, 2 Days",
            emphasis: .armsAndShoulders,
            summary: "Suits lifters with two days who want extra arm and delt work in each full body session.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Bench Press", "Pull-Up", "Lateral Raise", "EZ-Bar Curl", "Skull Crusher"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Overhead Press", "Seated Cable Row", "Cable Lateral Raise",
                        "Incline Dumbbell Curl", "Overhead Cable Extension",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Arms & Delts Focus, 3 Days",
            emphasis: .armsAndShoulders,
            summary:
                "Suits lifters with three days who want a dedicated arms and delts day between two full body days.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Bench Press", "Pull-Up", "Lateral Raise", "EZ-Bar Curl", "Skull Crusher"]),
                day(
                    "Arms & Delts",
                    [
                        "Overhead Cable Extension", "Incline Dumbbell Curl", "Cable Lateral Raise", "Rope Pushdown",
                        "Hammer Curl", "Reverse Pec Deck",
                    ]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Overhead Press", "Seated Cable Row", "Leg Press", "Machine Lateral Raise",
                        "Cable Curl",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Arms & Delts Focus, 4 Days",
            emphasis: .armsAndShoulders,
            summary: "Suits lifters with four days who want two upper days, an arms and delts day and one leg day.",
            days: [
                day(
                    "Upper A",
                    ["Bench Press", "Pull-Up", "Overhead Press", "Lateral Raise", "EZ-Bar Curl", "Skull Crusher"]),
                day(
                    "Lower",
                    ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Arms & Delts",
                    [
                        "Overhead Cable Extension", "Incline Dumbbell Curl", "Cable Lateral Raise", "Rope Pushdown",
                        "Cable Curl", "Reverse Pec Deck",
                    ]),
                day(
                    "Upper B",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Machine Shoulder Press", "Machine Lateral Raise",
                        "Hammer Curl", "JM Press",
                    ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper/Lower + Arms & Delts, 5 Days",
            emphasis: .armsAndShoulders,
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
            name: "Arms & Delts Focus, 6 Days",
            emphasis: .armsAndShoulders,
            summary:
                "Suits experienced lifters with six days who want two arms and delts days on top of push, pull and two leg days.",
            days: [
                day(
                    "Push",
                    ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Skull Crusher"]),
                day("Pull", ["Pull-Up", "Barbell Row", "Face Pull", "Barbell Curl", "Hammer Curl"]),
                day("Legs A", ["Squat", "Romanian Deadlift", "Leg Extension", "Lying Leg Curl", "Calf Raise"]),
                day(
                    "Arms & Delts A",
                    [
                        "Cable Lateral Raise", "EZ-Bar Curl", "Overhead Cable Extension", "Incline Dumbbell Curl",
                        "Rope Pushdown", "Reverse Pec Deck",
                    ]),
                day(
                    "Legs B",
                    ["Hack Squat", "Hip Thrust", "Seated Leg Curl", "Seated Calf Raise", "Cable Crunch"]),
                day(
                    "Arms & Delts B",
                    [
                        "Machine Shoulder Press", "Machine Lateral Raise", "Preacher Curl", "JM Press", "Cable Curl",
                        "Rear Delt Fly",
                    ]),
            ]
        ),
    ]
}
