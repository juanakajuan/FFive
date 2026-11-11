# Copy a mesocycle

A lifter plans the next block as a copy of a past or current one. The builder's start screen lists every block under `Copy a Mesocycle`, each with `CURRENT` or `FINISHED <date>`. Tapping one opens `Copy <name>`: a week picker (`Week 1` to the last training week, no deload), a note saying whether loads carry over, and one card per day with its weekday, exercises, muscles, and, when loads carry, the sets each exercise starts from (`4 sets of 135 lb × 9`, or each set when they differ). `Use Week <n>` opens Customize filled with the block's name, length, priorities, days, weekdays and that week's exercises.

Loads carry when the block's last finished accumulation session is under 21 days old (`Mesocycle.carriesLoads`). Each copied exercise then starts week 1 from the sets of the chosen week: a logged set gives its weight and reps, an untouched set repeats its target (or the set before it when it had none), and skipped sets and myoreps are dropped. Swapping the exercise in Customize drops its carried sets. Rules and tests: `FFiveCore/Sources/FFiveCore/Planner/MesoCopy.swift`, `MesoCopyTests`.

## How to get to it (user POV)

- Any entry to the builder's start screen (Workout tab `Plan a Mesocycle`, Mesos `+`). The section shows only when a block exists.

## Driving it with ffive-verify

- Preconditions: `ffive-verify reset-data`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/copy-mesocycle.steps --name copy-mesocycle`. It plans `Full Body, 3 Days`, logs Squat 135 × 9, ends the block, copies it, checks the review for both weeks, starts `Copied Block`, and checks the first session's sets read 135 and 9 (`store-expect SetEntry targetWeight 135`) across a relaunch.
- Ids: `#builder.copy-source.<slug>` (row), `#builder.copy-week` (segmented picker; tap weeks as `button "Week 2"`), `#builder.copy-use`.

## Gotchas

- After `replace #builder.name`, `sleep 1` before `tap #builder.start`, or the tap only ends editing.
