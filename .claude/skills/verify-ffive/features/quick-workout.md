# Quick workout

A lifter logs a free-form session outside any block. They add exercises from the catalog picker (or create a custom one with its muscle), log sets, and finish once every set is logged. The session lands in History, and in the Workout tab's stats row when no block is active.

## Sub-features

- `quick-start` starts a free-form workout named after the time of day (Morning, Afternoon, or Evening Workout). The Workout tab shows it headed `QUICK WORKOUT` with the subtitle `<name> • <timer>`.
- `quick-add` adds a catalog exercise through the searchable picker, opened with `Workout menu`, then `Add Exercise`. The new exercise gets one empty set, or last time's sets when it has history.
- `quick-custom` creates a custom exercise with `Create “<query>”` and a muscle. Not yet driven.
- `quick-log` edits `Set n weight` and `Set n reps` and ticks `Log set n`, which carries the Selected trait while logged.
- `quick-finish` finishes the workout with `Finish Workout`, pinned above the tab bar and shown only once the workout has an exercise, every exercise has a set, and every set is logged. Finishing updates the stats row (This Week, Time, All Time) and History.
- `quick-resume` returns to an open quick workout with `Workout menu`, then `Resume Quick Workout`, while a block day picked from `Schedule` is showing. Driven on the demo seed, which proves the UI only: `Workout menu`, `Quick Workout`, `wait text "QUICK WORKOUT"`, `tap button "Schedule"`, `tap button "circle.lefthalf.filled"`, `wait text "WEEK 2 DAY 1"`, `Workout menu`, `Resume Quick Workout`, `absent text "WEEK 2 DAY 1"`.
- `quick-rename` renames the workout with `Workout menu`, then `Rename`. Not yet driven.
- `quick-discard` uses `Workout menu`, then `Discard Workout`, and confirms with `Discard Workout`. Not yet driven.

## How to get to it (user POV)

- Workout tab with no active block: the `Quick Workout` button on the plan card.
- Workout tab with an active block: `Workout menu`, then `Quick Workout`. It reads `Resume Quick Workout` while one is open.
- Workout tab with a finished block ("Block complete"): the `Quick Workout` button under `End Mesocycle`.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data` (no block; This Week and All Time `0`, Time `0m`).
- Journey: `journeys/quick-workout.steps`.

- **Start.** Steps: `launch`, `wait button "Quick Workout" timeout=20`, `tap button "Quick Workout"`, `wait text "QUICK WORKOUT"`.
- **Add exercise.** Steps: `tap button "Workout menu"`, `tap button "Add Exercise"`, `wait nav "Add Exercise"`, `type search "Search or create exercise" "Lateral"`, `tap button "Lateral Raise, Dumbbell"`, `wait text "Lateral Raise"`.
- **Log.** Steps: `replace field "Set 1 weight" "25"`, `replace field "Set 1 reps" "12"`, `value field "Set 1 weight" "25"`, `value field "Set 1 reps" "12"`, `tap button "Done"`, `absent button "Finish Workout"`, `tap button "Log set 1"`, `selected button "Log set 1"`, `wait button "Finish Workout"`.
- **Finish.** Steps: `tap button "Finish Workout"`, `wait text "All Time" timeout=10`, `wait button "Quick Workout"`. The tab is back on its empty state, and the `03-workout-after-finish` tree shows This Week and All Time at `1`.
- **History.** Steps: `tap button "More"`, `tap button "Progress"`, `tap button "History"`, `tap button "~Workout,"`, `wait text "Lateral Raise"`.
- **Proof.** Run `ffive-verify store "select w.ZNAME, w.ZENDDATE is not null as finished, e.ZNAME, s.ZWEIGHT, s.ZREPS, s.ZISDONE from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is null"`. It returns `<time> Workout | 1 | Lateral Raise | 25.0 | 12 | 1`.

## Gotchas

- `~Lateral Raise` matches "Behind-the-Back Cable Lateral Raise" first. Use the full row label `<name>, <equipment>`.
- The workout name depends on the simulator clock, so match `~Workout,` in History. A bare `~Workout` matches the Workout tab button first.
- The stats row only renders with no active block. With a block, verify through More, Progress, then History instead.
- While a block is active, an open quick workout takes over the Workout tab until it is finished or discarded. A day picked from `Schedule` shows instead.
- A new exercise's set is `0` lb × `10` reps, and the zero weight shows the `lb` placeholder. Address fields by their `Set n` labels and check typed values with `value field`.
- The `Workout menu` items do not appear in `tree` dumps, but tapping them by label works.
