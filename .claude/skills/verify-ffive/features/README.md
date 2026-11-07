# FFive verification map

This directory is the maintained source for verifying FFive's user-facing behavior. Read this index before driving the app, then use the matching feature file as the recipe. Each recipe has a runnable step file in `../journeys/`.

## Baseline preconditions

- `ffive-verify` means `.claude/skills/verify-ffive/scripts/ffive-verify`, run from the repo root.
- `ffive-verify launch` printed `READY`, and `ffive-verify doctor` prints `HEALTHY` with an install stamp that matches the source.
- **Demo baseline** (read-only journeys): every drive starts with `launch -seedDemo`. The block "Full Body, 3 Days" is at Week 2 of 5. Week 1 is finished, Week 2 · Day 1 is in progress with Squat logged, and Week 2 · Day 3 is skipped. The Workout tab opens on `WEEK 2 DAY 1`. "Morning Workout" and "Evening Workout" are free-form history.
- **On-disk baseline** (write journeys): `ffive-verify reset-data`, then a bare `launch`. The Workout tab shows `Plan a Mesocycle` and `Quick Workout`.
- The on-disk journeys form one chain on a single store: `reset-data` → quick-workout → plan-mesocycle → train-session → skip-day → unskip-day → skip-mesos-detail. Each one's `Before:` header names the state it needs. notes, set-type, bodyweight, coaching-tips, reorder-exercises, swap-exercise, reset-and-rename-day, muscle-priorities, end-mesocycle, delete-mesocycle, rename-mesocycle, meso-notes, meso-length, weekday-labels, and copy-mesocycle each start from their own `reset-data`.
- Never drive a simulator that `ffive-verify launch` did not create in this checkout.

## Driving conventions

- The tabs are Workout, Mesos, Templates, Exercises, and More. The tab bar is a row of plain buttons with the ids `#tab.workout`, `#tab.mesos`, `#tab.templates`, `#tab.exercises`, and `#tab.more`. The `tab` kind matches nothing. Settings, Progress, and Learn are pushed from More.
- Only the selected tab is rendered, and a tab starts over at its root each time it is reopened. Re-enter pushed pages after every tab switch.
- Address every control by its `#id` from `FFiveCore/Sources/FFiveCore/A11y.swift`. An indexed id ends in the 1-based set number or card position (`#set.weight.1`, `#exercise.menu.2`). A keyed id ends in the slug of a name (`#picker.row.lateral-raise`). `drive` rejects an unknown id before it touches the simulator.
- Assert screen text by its visible text, with no separator characters in the step. Leave out `·`, `•`, `×`, a spaced `-`, and `/`. Put a `*` where the separator sits, as in `wait text "Sets per muscle*Week 2"`, so one step still checks both halves of the same text.
- A few controls have no id and keep a label. They are the schedule grid cells (SF Symbol identifiers such as `forward.circle`), the builder's `Increment` and `Decrement`, the back buttons, and History rows of quick workouts, whose names depend on the clock.
- Wait for the new screen's `nav` title or a state-specific label after every navigation, not a fixed `sleep`. The Workout tab has no navigation bar. Wait for its header text (`WEEK n DAY m`, `DELOAD DAY m`, or `QUICK WORKOUT`).
- While the keyboard is up the tab bar is hidden. Tap `#keyboard.done` before tapping a tab.
- Put durable writes on the on-disk path. `-seedDemo` is in-memory and resets on every `launch`, but it shares the real UserDefaults, so restore `weightUnit` to `lb`.

## Proof and skip reporting

- Capture the user action and the resulting state: `shot` before and after, plus an assertion on the new state.
- Writes need a second, read-only view. Inside the journey, `store-expect` and `defaults-expect` check the write. Outside it, run `ffive-verify store "<sql>"` or `ffive-verify defaults` and save the output next to the run with `tee`. Add a relaunch for persistence.
- Record the feature ID and entry point with every artifact (`--name <feature-id>`).
- Report an unreachable path with the failing step from `steps.log` and the unmet precondition. Do not report a skipped entry point as verified through another one.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then has exactly four H2 sections in this order.

1. `Sub-features` lists short IDs, one line per behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with ffive-verify` starts with `Preconditions:`. Its labeled bullets pair each user action with the exact steps and the observable result.
4. `Gotchas` lists traps that can waste or invalidate a run.

## Features

- [Plan a mesocycle](./plan-mesocycle.md): pick a template, customize name and length, start the block, and see it on the Mesos tab (on disk).
- [Copy a mesocycle](./copy-mesocycle.md): plan a block as a copy of a past one, pick a source week, review its days, and start with its logged loads (on disk).
- [Custom templates](./custom-templates.md): save a builder draft or a block as a template, find it on the Templates tab and in the builder, rename and delete it (on disk).
- [Muscle priorities](./muscle-priorities.md): mark muscles Emphasize, Normal, or Maintain in the builder or on the block's detail page; maintained muscles start at MV (on disk).
- [Train a planned session](./train-session.md): the block's session shows on the Workout tab; log or skip sets against targets, give feedback and soreness, and finish (on disk and demo).
- [Skip a day](./skip-day.md): skip from the workout menu or the schedule grid, then train it after all (on disk).
- [Delete a mesocycle](./delete-mesocycle.md): delete a block from its Mesos row menu or its detail page, behind a confirmation that counts its logged workouts; they leave History and Progress (on disk).
- [End a mesocycle](./end-mesocycle.md): end the active block from the workout menu; the session reaches History, the block shows finished, and the store holds its finished date (on disk).
- [Mesocycle summary and rename](./meso-summary.md): sets per muscle per week, e1RM change, and feedback trends, pushed from a block or shown on end, and renaming a block (demo and on disk).
- [Quick workout](./quick-workout.md): a free-form session with exercises from the picker (on disk).
- [Reset and rename a day](./reset-and-rename-day.md): clear a block day's logged sets back to the plan, and rename the day from the workout menu (on disk).
- [Reorder exercises](./reorder-exercises.md): drag a session's exercises into a new order, for this session or later weeks too (on disk and demo).
- [Set type](./set-type.md): mark a set Regular, Myorep, or Myorep match from its menu; the type shows on the row and in history (on disk).
- [Bodyweight](./bodyweight.md): set body weight from the workout menu, log added load or assistance on bodyweight lifts, and see e1RM, volume, and labels count body weight (on disk).
- [Block length](./meso-length.md): add or remove a training week from the Workout tab's schedule sheet while the block runs (on disk).
- [Mesocycle notes](./meso-notes.md): a list of notes on the active block, added and deleted from the workout menu or the block's detail page, and shown in its summary (on disk).
- [Weekday labels](./weekday-labels.md): label block days Monday through Sunday in the builder, relabel one from the workout menu for this session or every week, shown in the header and schedule grid (on disk).
- [Notes](./notes.md): a per-workout exercise note, pinning it to carry forward, editing, unpinning, and deleting it, and a day note (on disk).
- [Exercise history](./exercise-history.md): the history button on an exercise card lists every finished session of it, grouped by meso, and opens each one (demo).
- [Last performed](./last-performed.md): exercise picker rows and the exercise detail page show the date of the newest finished session (demo).
- [Suggest an exercise](./suggest-exercise.md): the picker's Suggest button cycles fitting exercises for the muscle, done-before first, and changes nothing until Add (demo).
- [Muscle slots in the builder](./muscle-slots.md): a builder day holds muscle-only slots that block Start; the editor menu autofills, clears and resets them (on disk).
- [Exercise detail from the picker](./picker-detail.md): a picker row's info button opens that exercise's detail on top of the picker; back keeps the search (demo).
- [Progress](./progress.md): volume against landmarks, the strength trend, and history, pushed from More (demo).
- [Coaching tips](./coaching-tips.md): a starting-load tip on a calibration set and a rest tip after a log, each linking to its Learn article and staying closed once dismissed (on disk plus UserDefaults).
- [Settings](./settings.md): weight unit, auto-match weights, iCloud sync status, and app version, pushed from More (demo plus UserDefaults).

Not mapped yet: the Templates tab's search and filter, the Exercises tab, a block's detail page on the Mesos tab (beyond its schedule grid and priorities), Learn, swapping or removing exercises, renaming a quick workout, and discarding a workout.
