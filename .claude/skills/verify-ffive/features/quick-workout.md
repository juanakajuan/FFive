# Quick workout

A lifter logs a free-form session outside any block. They add exercises from the catalog picker (or create a custom one with its muscle), log sets, and finish once no set is pending (each is logged or skipped). Finishing drops never-logged sets and exercises. The session lands in History, and in the Workout tab's stats row when no block is active.

## Sub-features

- `quick-start` starts a free-form workout named after the time of day (Morning, Afternoon, or Evening Workout). The Workout tab shows it headed `QUICK WORKOUT` with the subtitle `<name> · <timer>`.
- `quick-add` adds a catalog exercise through the searchable picker, opened with `Workout menu`, then `Add Exercise`. The new exercise gets one empty set, or last time's sets when it has history.
- `quick-custom` creates a custom exercise with `Create “<query>”` and a muscle. Not yet driven.
- `quick-log` edits `Set n weight` and `Set n reps` and ticks `Log set n`, which carries the Selected trait while logged.
- `quick-finish` finishes the workout with `Finish Workout`, pinned above the tab bar and shown only once the workout has an exercise, every exercise has a set, and every set is logged or skipped. Finishing updates the stats row (This Week, Time, All Time) and History.
- `quick-resume` returns to an open quick workout with `Workout menu`, then `Resume Quick Workout`, while a block day picked from `Schedule` is showing. Driven on the demo seed, which proves the UI only. Steps: `tap #workout.menu`, `tap #menu.quick-workout`, `wait text "QUICK WORKOUT"`, `tap #workout.schedule`, `tap button "circle.lefthalf.filled"`, `wait text "WEEK 2 DAY 1"`, `tap #workout.menu`, `tap #menu.quick-workout`, `absent text "WEEK 2 DAY 1"`.
- `quick-rename` renames the workout with `Workout menu`, then `Rename`. Not yet driven.
- `quick-discard` uses `Workout menu`, then `Discard Workout`, and confirms with `Discard Workout`. Not yet driven.

## How to get to it (user POV)

- Workout tab with no active block: the `Quick Workout` button on the plan card.
- Workout tab with an active block: `Workout menu`, then `Quick Workout`. It reads `Resume Quick Workout` while one is open.
- Workout tab with a finished block ("Mesocycle Complete"): the `Quick Workout` button under `End Mesocycle`.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data` (no block; This Week and All Time `0`, Time `0m`).
- Journey: `journeys/quick-workout.steps`.

- **Start.** Steps: `launch`, `wait #workout.quick timeout=20`, `tap #workout.quick`, `wait text "QUICK WORKOUT"`.
- **Add exercise.** Steps: `tap #workout.menu`, `tap #menu.add-exercise`, `wait nav "Add Exercise"`, `type #picker.search "Lateral"`, `tap #picker.row.lateral-raise`, `wait text "Lateral Raise"`.
- **Log.** Steps: `replace #set.weight.1 "25"`, `replace #set.reps.1 "12"`, `value #set.weight.1 "25"`, `value #set.reps.1 "12"`, `tap #keyboard.done`, `absent #workout.finish`, `tap #set.log.1`, `selected #set.log.1`, `wait #workout.finish`.
- **Finish.** Steps: `tap #workout.finish`, `wait text "All Time" timeout=10`, `store-expect SetEntry weight 25`, `store-expect SetEntry reps 12`, `store-expect SetEntry isDone 1`, `store-expect Workout endDate not-null`, `wait #workout.quick`. The tab is back on its empty state, and the `03-workout-after-finish` tree shows This Week and All Time at `1`.
- **History.** Steps: `tap #tab.more`, `tap #more.progress`, `tap #segment.history`, `tap button "~Workout,"`, `wait text "Lateral Raise"`.
- **Proof.** The journey's `store-expect` steps check the logged set and the finish. For the full row, run `ffive-verify store "select w.ZNAME, w.ZENDDATE is not null as finished, e.ZNAME, s.ZWEIGHT, s.ZREPS, s.ZISDONE from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is null"`. It returns `<time> Workout | 1 | Lateral Raise | 25.0 | 12 | 1`.

## Gotchas

- Picker rows are keyed by exercise name, as in `#picker.row.lateral-raise`. A label match is riskier. `~Lateral Raise` hits "Behind-the-Back Cable Lateral Raise" first.
- The workout name depends on the simulator clock, so match `~Workout,` in History. A bare `~Workout` matches the Workout tab button first.
- The stats row only renders with no active block. With a block, verify through More, Progress, then History instead.
- While a block is active, an open quick workout takes over the Workout tab until it is finished or discarded. A day picked from `Schedule` shows instead.
- A new exercise's set is `0` lb × `10` reps, and the zero weight shows the `lb` placeholder. Address fields by `#set.weight.<n>` and `#set.reps.<n>`, and check typed values with `value`.
- The `Workout menu` items do not appear in `tree` dumps, but tapping them by id works.
