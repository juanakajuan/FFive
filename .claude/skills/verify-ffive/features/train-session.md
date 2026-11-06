# Train a planned session

The Workout tab shows the block's next session inline. The lifter sees per-set targets (or "Calibrate" in week 1), logs weight and reps, and ticks each set's log checkbox. They rate pump, workload, and joint pain once a muscle's last card has no pending set, and answer how a muscle recovered since it was last trained. Once no set is pending (each is logged or skipped), `Finish Workout` appears pinned above the tab bar. It marks the grid cell done, and the tab moves on to the next day.

## Sub-features

- `session-open` shows the next open session of the block, headed `WEEK n DAY m` (`DELOAD DAY m` in the deload) with the subtitle `<day> · <block> · <n> RIR` (`· Deload` in the deload). A day picked from the schedule grid shows instead.
- `session-targets` shows `Target <w> × <r>` from last week's logs, or `Calibrate · <range> reps at <n> RIR` while a set has no target weight (week 1), in the callout under the exercise name.
- `session-log` edits `Set n weight` and `Set n reps` and ticks `Log set n`, which carries the Selected trait while logged.
- `session-feedback` shows the "How did <muscle> feel today?" card under the muscle's last card once that card has no pending set (logged or skipped), and records Pump, Workload, and Joint pain. Tapping a selected chip clears it.
- `joint-pain-menu` reports joint pain mid-session from `#exercise.menu.<n>`, then `#menu.joint-pain` and a level by label (`button "A lot"`). It writes the muscle's feedback record for this session, so the end-of-muscle card opens with that chip selected. Block sessions only; quick workouts have no entry. Journey: `journeys/joint-pain.steps`, after `plan-mesocycle.steps` on a fresh store; it checks `store-expect MuscleFeedbackRecord jointPainRaw 3`, relaunches, and asserts `selected #chip.a-lot`.
- `session-soreness` shows "How did your <muscle> recover?" above the muscle's first card when the block's latest earlier finished session logged that muscle and recorded feedback for it with no soreness yet. With no feedback given last time, no question shows. The answer may re-plan targets (see Soreness below).
- `session-skip-sets` skips one pending set from `Set n menu` (`Skip Set`, then `Unskip Set` to undo) or every pending set of a card from `Exercise menu` (`Skip Remaining Sets`). A skipped row dims its fields and its log checkbox reads `Skipped` as its value. Logging a skipped set replaces the skip. A logged set offers no `Skip Set`.
- `session-finish` finishes the session with `Finish Workout`, marks the cell finished, and shows the next day. The button exists only while every exercise has sets and none of them is still pending (each is logged or skipped). Deleting unlogged sets or removing unlogged exercises also brings it up.
- `session-pinned` keeps the `WEEK n DAY m` header (with `Schedule` and `Workout menu`) at the top and `Finish Workout` above the tab bar while the cards scroll.
- `session-tools` covers each card's `Technique cue`, `History`, and `Exercise menu` (Swap Exercise on block days until a set is logged, Add Set, Skip Remaining Sets, Joint Pain, Add/Edit Note, Delete Note, Remove Exercise), and each row's `Set n menu` (Add Set, Skip/Unskip Set, Set Type, Delete Set). Delete Set and Remove Exercise are driven by `train-session.steps`; Swap Exercise, Technique cue, and History are not yet driven.

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
- **Log a set.** Enter 135 × 9 in set 1 and log it. Steps: `replace #set.weight.1 "135"`, `replace #set.reps.1 "9"`, `value #set.weight.1 "135"`, `value #set.reps.1 "9"`, `tap #keyboard.done`, `tap #set.log.1`, `selected #set.log.1`.
- **Finish gate.** After set 1 is logged, `absent #workout.finish`. The journey then stops early the way a lifter would. It taps `#set.menu.2`, then `#menu.delete-set`, for Bench's unlogged sets, and `#exercise.menu.2`, then `#menu.remove-exercise`, for each other exercise. Card ids follow card position, so the second card is `#exercise.menu.2` after every removal. Finish stays absent until the last unlogged set is gone.
- **Finish.** Steps: `wait #workout.finish`, `tap #workout.finish`, `wait text "WEEK 1 DAY 2" timeout=10`, `store-expect SetEntry weight 135`, `store-expect SetEntry reps 9`. In the `Schedule` sheet, the W1 D1 cell becomes `checkmark.circle.fill`.
- **Proof (on disk).** The journey's `store-expect` steps check the logged weight and reps. For the full row, run `ffive-verify store "select w.ZWEEK, w.ZDAYINDEX, w.ZENDDATE is not null as finished, s.ZWEIGHT, s.ZREPS, s.ZISDONE from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is not null and s.ZISDONE = 1"`. It returns `0 | 0 | 1 | 135.0 | 9 | 1`.
- **Skip sets (on disk).** After plan-mesocycle, `journeys/skip-sets.steps` logs set 1, skips set 2 (`#set.menu.2`, `#menu.skip-set`, `value #set.log.2 "Skipped"`, `store-expect SetEntry isSkipped 1`), undoes and redoes the skip, then taps `#exercise.menu.<n>`, `#menu.skip-remaining` for all six cards. `Finish Workout` stays absent until the last card is skipped, and set 2 still reads `Skipped` after a relaunch. For the rows, run `ffive-verify store "select ZISDONE, ZISSKIPPED, count(*) from ZSETENTRY group by 1,2"`.
- **Targets and feedback (demo).** The in-progress session is already on the Workout tab. Steps: `wait text "WEEK 2 DAY 1" timeout=20`, `wait text "Target 185 * 7"`, `wait text "How did quads feel today?"`, `scrollto #chip.great`, `tap #chip.great`, `scrollto #chip.pretty-good`, `tap #chip.pretty-good`, `scrollto #chip.none`, `tap #chip.none`, `selected #chip.none`, `exists image "checkmark.circle.fill"`. The feedback header shows its checkmark; by then the last `scrollto` has pushed it above the screen, so `exists` checks it where `wait` would fail.
- **Soreness (demo).** Scroll to the chest question and answer it. Steps: `scrollto text "How did your chest recover?"`, `wait text "Target 150 * 8"`, `tap #chip.healed-just-in-time`, `absent text "How did your chest recover?"`. The card disappears. The answer re-plans that muscle's sets only when the soreness belongs to this day's session last week and the muscle has no logged set yet (`MesoPlanner.recordSoreness`). In the demo, Bench Press still shows `Target 150 × 8` after the answer (`03-soreness-answered` tree).

## Gotchas

- An empty set field shows its placeholder: the unit for weight, `<n> RIR` for reps (`reps` in a deload). A zero weight or zero reps reads as empty. Assert typed values with `value #set.weight.<n>`, not by matching the field's text.
- The session is a lazy stack, so cards below the fold are not in the tree. Scroll before asserting on them.
- XCUITest calls a chip under the pinned header hittable, but a tap there lands on the header. `scrollto` brings its target to the middle half of the screen, so tap a chip only after a `scrollto` on it or on a neighbor.
- Feedback chips carry the Selected trait. The header checkmark proves all three questions are answered.
- Feedback and soreness written in a `-seedDemo` run vanish on relaunch. Prove their persistence on the on-disk path. A soreness question needs feedback given for that muscle in the previous session.
- The decimal pad covers the lower part of the list and hides the tab bar. Tap `#keyboard.done` before tapping anything it might cover.
- `Finish Workout` is absent from the tree while any set is pending (neither logged nor skipped), so a `wait` or `tap` on it times out while any set is open.
- Remove Bench's other exercises while one Bench set is still unlogged. A fully logged Bench adds the chest feedback card, which pushes the next card's `Exercise menu` off screen.
- The tab builds a block day as soon as it shows it, so an open `ZWORKOUT` row is no proof that training started. Until a set is logged, the day's start time resets each time the tab shows it.
- The `Workout menu` items do not appear in `tree` dumps, but tapping them by id works.
