# Train a planned session

The Workout tab shows the block's next session inline. The lifter sees per-set targets (or "Calibrate" in week 1), logs weight and reps, and ticks each set's log checkbox. They rate pump, workload, and joint pain once a muscle's sets are done, and answer how a muscle recovered since it was last trained. Once every set is logged, `Finish Workout` appears pinned above the tab bar. It marks the grid cell done, and the tab moves on to the next day.

## Sub-features

- `session-open` shows the next open session of the block, headed `WEEK n DAY m` (`DELOAD DAY m` in the deload) with the subtitle `<day> • <block> • <n> RIR`. A day picked from the schedule grid shows instead.
- `session-targets` shows `Target <w> × <r>` from last week's logs, or `Calibrate · <range> reps at <n> RIR` in week 1, in the callout under the exercise name.
- `session-log` edits `Set n weight` and `Set n reps` and ticks `Log set n`, which carries the Selected trait while logged.
- `session-feedback` shows the "How did <muscle> feel today?" card once all of that muscle's sets are done, and records Pump, Workload, and Joint pain.
- `session-soreness` shows "How did your <muscle> recover?" for a muscle trained in an earlier session, and re-plans that muscle's targets on answer.
- `session-finish` finishes the session with `Finish Workout`, marks the cell finished, and shows the next day. The button exists only while every exercise has sets and all of them are logged. Deleting unlogged sets or removing unlogged exercises also brings it up.
- `session-pinned` keeps the `WEEK n DAY m` header (with `Schedule` and `Workout menu`) at the top and `Finish Workout` above the tab bar while the cards scroll.
- `session-tools` covers each card's `Technique cue`, `History`, and `Exercise menu` (Swap Exercise, Add Set, Remove Exercise), and each row's `Set n menu` (Add Set, Delete Set). Not yet driven.

## How to get to it (user POV)

- Workout tab: the block's next open session shows as soon as the tab opens.
- Workout tab, `Schedule` button: in the sheet's grid, tap a current-week `play.circle.fill`, `circle.lefthalf.filled`, or `circle` cell to show that day on the Workout tab.
- Mesos tab, the block's row: the detail page has the same grid. A current-week cell switches to the Workout tab on that day.
- Either grid: tap a finished `checkmark.circle.fill` cell to review it read-only (WorkoutDetail).

## Driving it with ffive-verify

Preconditions:

- On-disk: plan-mesocycle.steps ran on this store, so "Verify Block" shows Week 1 · Day 1. Journey: `journeys/train-session.steps`.
- Demo: `launch -seedDemo` (Week 2 · Day 1 in progress, quads logged). Journey: `journeys/train-session-seeded.steps`.

- **Open (on disk).** Relaunch onto the Workout tab. Steps: `launch`, `wait text "WEEK 1 DAY 1" timeout=20`, `wait text "Bench Press"`, `wait text "~Calibrate"`.
- **Log a set.** Enter 135 × 9 in set 1 and log it. Steps: `replace field "Set 1 weight" "135"`, `replace field "Set 1 reps" "9"`, `value field "Set 1 weight" "135"`, `value field "Set 1 reps" "9"`, `tap button "Done"`, `tap button "Log set 1"`, `selected button "Log set 1"`.
- **Finish gate.** After set 1 is logged, `absent button "Finish Workout"`. The journey then stops early the way a lifter would: `Set 2 menu`, `Delete Set` for Bench's unlogged sets, and `Exercise menu #1`, `Remove Exercise` for each other exercise. Finish stays absent until the last unlogged set is gone.
- **Finish.** Steps: `wait button "Finish Workout"`, `tap button "Finish Workout"`, `wait text "WEEK 1 DAY 2" timeout=10`. In the `Schedule` sheet, the W1 D1 cell becomes `checkmark.circle.fill`.
- **Proof (on disk).** Run `ffive-verify store "select w.ZWEEK, w.ZDAYINDEX, w.ZENDDATE is not null as finished, s.ZWEIGHT, s.ZREPS, s.ZISDONE from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is not null and s.ZISDONE = 1"`. It returns `0 | 0 | 1 | 135.0 | 9 | 1`.
- **Targets and feedback (demo).** The in-progress session is already on the Workout tab. Steps: `wait text "WEEK 2 DAY 1" timeout=20`, `wait text "Target 185 × 7"`, `wait text "How did quads feel today?"`, `scrollto button "Pretty good"`, `tap button "Great"`, `tap button "Pretty good"`, `scrollto text "~Next week's sets for quads"`, `tap button "None"`, `selected button "None"`, `wait image "checkmark.circle.fill"`. The feedback header shows its checkmark.
- **Soreness (demo).** Scroll to the chest question and answer it. Steps: `scrollto text "How did your chest recover?"`, `wait text "Target 150 × 8"`, `tap button "Healed just in time"`, `absent text "How did your chest recover?"`. The card disappears and Bench Press targets are re-planned.

## Gotchas

- An empty set field shows its placeholder: the unit for weight, `<n> RIR` for reps. A zero weight reads as empty. Assert typed values with `value field "Set n weight"`, not by matching the field's text.
- The session is a lazy stack, so cards below the fold are not in the tree. Scroll before asserting on them.
- `scrollto` swipes a long way and can leave its target under the tab bar. Scroll to the element just below a row before tapping it, as the seeded journey does for `Great` and `None`.
- Feedback chips carry the Selected trait. The header checkmark proves all three questions are answered.
- Feedback and soreness written in a `-seedDemo` run vanish on relaunch. Prove their persistence on the on-disk path, after week 1 is finished, when soreness questions appear.
- The decimal pad covers the lower part of the list and hides the tab bar. Tap `button "Done"` before tapping anything it might cover.
- `Finish Workout` is absent from the tree until every set is logged, so a `wait` or `tap` on it times out while any set is open.
- Remove Bench's other exercises while one Bench set is still unlogged. A fully logged Bench adds the chest feedback card, which pushes the next card's `Exercise menu` off screen.
- The tab builds a block day as soon as it shows it, so an open `ZWORKOUT` row is no proof that training started. Logging the day's first set resets its start time.
- The `Workout menu` items do not appear in `tree` dumps, but tapping them by label works.
