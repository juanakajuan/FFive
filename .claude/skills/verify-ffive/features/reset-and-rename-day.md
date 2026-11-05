# Reset a workout and rename a day

`Reset Workout` in the workout menu clears every logged set of the open block day. Each set goes back to its prescription: unchecked, type Regular, weight and reps at the target, or empty when the set has no target. The exercise list, swaps, and added sets stay, and the day's muscle feedback is deleted. `Discard Workout` differs: it deletes the day and rebuilds it from the plan.

`Rename Day` renames the block day. The new name lands on the `MesoDay`, on every session of that day already built, and on later weeks built from it. The schedule grid header shows each day's name under `D<n>`. On a quick workout the same item reads `Rename` and renames only that workout.

## Sub-features

- `reset-menu` shows `Reset Workout` only on a block day with at least one logged set.
- `reset-confirm` asks in `#dialog.reset` before clearing.
- `rename-day` renames the day everywhere; a blank name is ignored.
- `grid-day-names` labels the grid header `Day <n>, <name>`.

## How to get to it (user POV)

- Workout tab, `Workout menu`, `Reset Workout` or `Rename Day`, on a block day.
- Workout tab, the calendar button, the grid header.

## Driving it with ffive-verify

Preconditions: `ffive-verify reset-data`. Journey: `journeys/reset-and-rename-day.steps`.

- **Reset.** Steps: log a set, `tap #workout.menu`, `tap #menu.reset`, `tap #dialog.reset`, `unselected #set.log.1`. Result: `ffive-verify store "select ZWEIGHT, ZREPS, ZISDONE from ZSETENTRY where ZISDONE = 1 or ZWEIGHT > 0"` is empty on week 1.
- **Rename.** Steps: `tap #menu.rename`, `wait alert "Rename Day"`, `replace field "Day name" "Push Day"`, `sleep 1`, `tap button "Save"`, `absent alert "Rename Day"`. Result: `store-expect MesoDay name "Push Day"` and `wait any "Day 1, Push Day"` in the schedule sheet.

## Gotchas

- Tapping `Save` right after `replace` can land while the keyboard settles and leave the alert open. Keep the `sleep 1` and the `absent alert` check.
