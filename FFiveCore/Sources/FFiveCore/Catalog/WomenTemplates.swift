extension ExerciseCatalog {
    /// Women's versions of the whole-body templates: each keeps its namesake's schedule and moves upper-body
    /// volume to the lower body, glutes most.
    static let womenTemplates: [ProgramTemplate] = [
        ProgramTemplate(
            name: "Women's Full Body, 2 Days",
            emphasis: .wholeBody,
            summary: "Suits women with two training days who want the whole body hit twice a week, glutes most.",
            days: [
                day(
                    "Full Body A",
                    [
                        "Squat", "Hip Thrust", "Lat Pulldown", "Seated Leg Curl", "Dumbbell Shoulder Press",
                        "Hip Abduction Machine",
                    ]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Bulgarian Split Squat", "Incline Dumbbell Press", "Seated Cable Row",
                        "Cable Kickback", "Lateral Raise",
                    ]),
            ],
            variant: .women
        ),
        ProgramTemplate(
            name: "Women's Full Body, 3 Days",
            emphasis: .wholeBody,
            summary:
                "Suits women with three training days who want a glute lift every session and the upper body twice.",
            days: [
                day(
                    "Full Body A",
                    ["Squat", "Hip Thrust", "Lat Pulldown", "Seated Leg Curl", "Lateral Raise", "Cable Crunch"]),
                day(
                    "Full Body B",
                    [
                        "Romanian Deadlift", "Bulgarian Split Squat", "Incline Dumbbell Press",
                        "Chest-Supported Dumbbell Row", "Hip Abduction Machine", "Cable Curl",
                    ]),
                day(
                    "Full Body C",
                    [
                        "Leg Press", "Smith Hip Thrust", "Seated Cable Row", "Cable Kickback", "Tricep Pushdown",
                        "Cable Lateral Raise",
                    ]),
            ],
            variant: .women
        ),
        ProgramTemplate(
            name: "Women's Upper/Lower, 4 Days",
            emphasis: .wholeBody,
            summary: "Suits women with four days who want two glute-led lower days and two lighter upper days.",
            days: [
                day(
                    "Upper A",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Seated Cable Row", "Lateral Raise", "Cable Curl",
                        "Tricep Pushdown",
                    ]),
                day(
                    "Lower A",
                    [
                        "Hip Thrust", "Squat", "Romanian Deadlift", "Seated Leg Curl", "Hip Abduction Machine",
                        "Cable Crunch",
                    ]),
                day(
                    "Upper B",
                    [
                        "Dumbbell Shoulder Press", "Chest-Supported Dumbbell Row", "Machine Chest Press",
                        "Cable Lateral Raise", "Face Pull", "Hanging Leg Raise",
                    ]),
                day(
                    "Lower B",
                    [
                        "Bulgarian Split Squat", "Smith Hip Thrust", "Leg Press", "Lying Leg Curl", "Cable Kickback",
                        "Calf Raise",
                    ]),
            ],
            variant: .women
        ),
        ProgramTemplate(
            name: "Women's Upper/Lower + Full Body, 5 Days",
            emphasis: .wholeBody,
            summary: "Suits women with five days who want three lower days, one of them for glutes and hamstrings.",
            days: [
                day(
                    "Lower A",
                    [
                        "Squat", "Hip Thrust", "Romanian Deadlift", "Leg Extension", "Hip Abduction Machine",
                        "Calf Raise",
                    ]),
                day(
                    "Upper A",
                    [
                        "Incline Dumbbell Press", "Lat Pulldown", "Seated Cable Row", "Lateral Raise", "Cable Curl",
                        "Tricep Pushdown",
                    ]),
                day(
                    "Glutes & Hamstrings",
                    [
                        "Smith Hip Thrust", "Bulgarian Split Squat", "Seated Leg Curl", "Cable Kickback",
                        "Back Extension", "Cable Crunch",
                    ]),
                day(
                    "Upper B",
                    [
                        "Dumbbell Shoulder Press", "Chest-Supported Dumbbell Row", "Machine Chest Press",
                        "Cable Lateral Raise", "Face Pull", "Overhead Cable Extension",
                    ]),
                day(
                    "Lower B",
                    [
                        "Hack Squat", "Dumbbell Romanian Deadlift", "Cable Pull-Through", "Lying Leg Curl", "Lunge",
                        "Hanging Leg Raise",
                    ]),
            ],
            variant: .women
        ),
        ProgramTemplate(
            name: "Women's Push/Pull/Legs, 6 Days",
            emphasis: .wholeBody,
            summary: "Suits women who recover well and can train six days, with a glute finisher on every upper day.",
            days: [
                day(
                    "Push A",
                    [
                        "Incline Dumbbell Press", "Dumbbell Shoulder Press", "Lateral Raise", "Tricep Pushdown",
                        "Hip Abduction Machine",
                    ]),
                day("Pull A", ["Lat Pulldown", "Seated Cable Row", "Face Pull", "Cable Curl", "Cable Kickback"]),
                day(
                    "Legs A",
                    ["Hip Thrust", "Squat", "Romanian Deadlift", "Seated Leg Curl", "Calf Raise", "Cable Crunch"]),
                day(
                    "Push B",
                    [
                        "Machine Chest Press", "Machine Shoulder Press", "Cable Lateral Raise",
                        "Overhead Cable Extension", "Back Extension",
                    ]),
                day(
                    "Pull B",
                    [
                        "Chest-Supported Dumbbell Row", "Close-Grip Lat Pulldown", "Reverse Pec Deck",
                        "Incline Dumbbell Curl", "Hip Abduction Machine",
                    ]),
                day(
                    "Legs B",
                    [
                        "Bulgarian Split Squat", "Smith Hip Thrust", "Leg Press", "Lying Leg Curl", "Cable Kickback",
                        "Hanging Leg Raise",
                    ]),
            ],
            variant: .women
        ),
    ]
}
