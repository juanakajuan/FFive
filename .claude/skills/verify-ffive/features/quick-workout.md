# Quick workout

A lifter logs a free-form session outside any block. They add exercises from the catalog picker (or create a custom one with its muscle), log sets, and finish. The session lands in history and in the Train tab stats when no block is active.

## Sub-features

- `quick-start` starts a free-form workout named after the time of day (Morning, Afternoon, or Evening Workout).
- `quick-add` adds a catalog exercise through the searchable picker. The new exercise gets one empty set, or last time's sets when it has history.
- `quick-custom` creates a custom exercise with `Create “<query>”` and a muscle. Not yet driven.
- `quick-log` edits weight and reps and marks sets done (`<n> set(s) done` header).
- `quick-finish` finishes the workout, which updates the stats tiles and History.
- `quick-resume` closes the workout and later continues it with `Resume Quick Workout`.
- `quick-discard` uses `Discard Workout`, then `Discard`. Not yet driven.

## How to get to it (user POV)

- Train tab with no active block: the `Quick Workout` button under the plan card.
- Train tab with an active block: the bolt `Quick Workout` toolbar button.
- Either button reads `Resume Quick Workout` while one is open.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data` (no block, stats all `0`).
- Journey: `journeys/quick-workout.steps`.

- **Start.** Steps: `tap button "Quick Workout"`, `wait nav "Workout"`.
- **Add exercise.** Steps: `tap button "Add Exercise"`, `wait nav "Add Exercise"`, `type search "Search or create exercise" "Lateral"`, `tap button "Lateral Raise, Dumbbell"`, `wait text "Lateral Raise"`.
- **Log.** Steps: `replace field "0" #0 "25"`, `replace field "0" #1 "12"`, `value field "0" #0 "25"`, `value field "0" #1 "12"`, `tap button "Done"`, `tap button "circle"`, `wait text "1 set done"`.
- **Finish.** Steps: `tap button "Finish"`, `wait text "All Time"`, `count text "1" "2"`. This Week and All Time both read 1.
- **History.** Steps: `tap tab "Progress"`, `tap button "History"`, `tap button "~Workout"`, `wait text "Lateral Raise"`.
- **Proof.** Run `ffive-verify store "select w.ZNAME, w.ZENDDATE is not null as finished, e.ZNAME, s.ZWEIGHT, s.ZREPS, s.ZISDONE from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is null"`. It returns `<time> Workout | 1 | Lateral Raise | 25.0 | 12 | 1`.

## Gotchas

- `~Lateral Raise` matches "Behind-the-Back Cable Lateral Raise" first. Use the full row label `<name>, <equipment>`.
- The workout name depends on the simulator clock, so match `~Workout`, not a fixed name.
- The stats row only renders with no active block. With a block, verify through Progress → History instead.
- A new exercise's empty set is `0` lb × `10` reps, but the reps field's placeholder is also `0`. Address fields by `field "0" #n`, never by their current value.
