# Progress

Progress, pushed from the More tab, shows three panes. Volume is weekly sets per muscle against its landmarks, per block and week. Strength is the estimated 1RM per exercise, with a trend page. History lists finished workouts, each opening a read-only detail.

## Sub-features

- `progress-volume` shows the `Sets per Muscle · Week <n>` chart for the active block, with a week picker (`W1`… `DL`) and a block picker when there are several blocks.
- `progress-strength` lists exercises with e1RM (`<name>, <muscle>, <n> session(s), <e1RM> <unit>`) and opens an exercise trend page.
- `progress-history` shows stats tiles plus finished workouts, and opens a WorkoutDetail with its exercises and sets.
- `progress-empty` shows the "No mesocycle yet" empty state on the Volume pane with no block. Not yet driven.

## How to get to it (user POV)

- The `More` tab, the `Progress` row, then the segmented `Volume` / `Strength` / `History` control.
- History detail is also reachable from a finished cell on the schedule grid (the Workout tab's `Schedule` sheet, or the block's detail page on the Mesos tab).

## Driving it with ffive-verify

Preconditions:

- Demo baseline (`launch -seedDemo`).
- Journey: `journeys/progress.steps`.

- **Volume.** Steps: `tap #tab.more timeout=20`, `tap #more.progress`, `wait nav "Progress"`, `selected #segment.volume`, `wait text "Sets per Muscle*Week 2"`, `wait any "~Quads, 4 of"`, `tap #segment.w1`, `wait text "Sets per Muscle*Week 1"`.
- **Strength.** Steps: `tap #segment.strength`, `wait text "Estimated 1RM"`, `tap #strength.row.leg-press`, `wait nav "Leg Press"`.
- **History.** Steps: `tap button "Progress"` (back), `tap #segment.history`, `wait text "All Time"`, `tap #history.row.morning-workout`, `wait nav "Morning Workout"`, `wait text "Bench Press"`.
- **History delete.** Steps: `tap button "Progress"`, `swipe left #history.row.morning-workout`, `tap button "Delete"`, `wait #dialog.delete-workout`, `tap any "dismiss popup"` (a tap outside the dialog; iOS 26 shows it as a popover with no Cancel button) keeps the row; swipe again and `tap #dialog.delete-workout`, then `absent #history.row.morning-workout`.
- **Proof.** Keep shots `01-volume-w1`, `02-strength-trend`, and `03-history-detail`. For a change to how numbers are computed, compare the chart's accessibility label (`any "~<Muscle>, <done> of <planned> sets"`) with the planner's expectations in `FFiveCore/Tests/FFiveCoreTests/PlannerTests.swift`.

## Gotchas

- The pane control's segments are `#segment.volume`, `#segment.strength`, and `#segment.history`, and the selected one carries the selected trait. The week picker's segments are `#segment.w1` through `#segment.dl`.
- The back button on pushed pages is labeled with the previous title: `button "Progress"` from a trend page or detail, `button "More"` from Progress.
- Switching tabs resets More to its root. Re-enter with `tap #more.progress` after any tab switch.
- `-seedDemo -demoRoute progress` opens More and Progress directly. `-seedDemo -demoRoute strength` opens the richest trend page (Bench Press) on top of it. It is a shortcut, not proof of navigation.
- Demo dates are relative to now, so History's dates and the "This Week" tile change from day to day. Assert names and counts, not dates.
