# Train a planned session

A lifter opens the next session of their block, sees per-set targets (or "Calibrate" in week 1), logs weight and reps, and marks sets done. They rate pump, workload, and joint pain once a muscle's sets are done, and answer how a muscle recovered since it was last trained. Finishing the session marks the grid cell done and advances Next up.

## Sub-features

- `session-open` opens the next or in-progress session from the Next up card or its schedule-grid cell.
- `session-targets` shows `Target <w> × <r>` from last week's logs, or `Calibrate · <range> reps at <n> RIR` in week 1.
- `session-log` edits weight and reps and toggles a set done.
- `session-feedback` shows the "How did <muscle> feel today?" card once all of that muscle's sets are done, and records Pump, Workload, and Joint pain.
- `session-soreness` shows "How did your <muscle> recover?" for a muscle trained in an earlier session, and re-plans that muscle's targets on answer.
- `session-finish` finishes the session (enabled after one done set), marks the cell finished, and moves Next up.
- `session-close` closes the session, leaving it in progress (`Resume`).

## How to get to it (user POV)

- Train tab: tap the Next up / In progress card (`Start Workout` / `Resume`).
- Train tab schedule grid: tap the `play.circle.fill` or `circle.lefthalf.filled` cell of the current week.
- Train tab schedule grid: tap a finished `checkmark.circle.fill` cell to review it read-only (WorkoutDetail).

## Driving it with ffive-verify

Preconditions:

- On-disk: plan-mesocycle.steps ran on this store, so "Verify Block" has Week 1 · Day 1 next up. Journey: `journeys/train-session.steps`.
- Demo: `launch -seedDemo` (Week 2 · Day 1 in progress, quads logged). Journey: `journeys/train-session-seeded.steps`.

- **Open (on disk).** Tap the Next up card. Steps: `tap button "~Next up, Week 1 · Day 1"`, `wait nav "Verify Block"`, `wait text "Bench Press"`, `wait text "~Calibrate"`.
- **Log a set.** Enter 135 × 9 in set 1 and mark it done. Steps: `replace field "0" #0 "135"`, `replace field "0" #1 "9"`, `value field "0" #0 "135"`, `value field "0" #1 "9"`, `tap button "Done"`, `tap button "circle"`.
- **Finish.** Tap `Finish`. Steps: `tap button "Finish"`, `wait button "~Next up, Week 1 · Day 2"`. The W1 D1 cell becomes `checkmark.circle.fill`.
- **Proof (on disk).** Run `ffive-verify store "select w.ZWEEK, w.ZDAYINDEX, w.ZENDDATE is not null as finished, s.ZWEIGHT, s.ZREPS from ZWORKOUT w join ZEXERCISE e on e.ZWORKOUT = w.Z_PK join ZSETENTRY s on s.ZEXERCISE = e.Z_PK where w.ZMESOCYCLE is not null and s.ZISDONE = 1"`. It returns `0 | 0 | 1 | 135.0 | 9`.
- **Targets and feedback (demo).** Resume the in-progress session. Steps: `tap button "~In progress, Week 2 · Day 1"`, `wait nav "Full Body, 3 Days"`, `wait text "Target 185 × 7"`, `wait text "How did quads feel today?"`, `scrollto button "A lot"`, `tap button "Great"`, `tap button "Pretty good"`, `tap button "None"`, `wait image "checkmark.circle.fill"`. The feedback header shows its checkmark.
- **Soreness (demo).** Scroll to the chest question and answer it. Steps: `scrollto text "How did your chest recover?"`, `wait text "Target 150 × 8"`, `tap button "Healed just in time"`, `absent text "How did your chest recover?"`. The card disappears and Bench Press targets are re-planned.

## Gotchas

- Set fields have no labels. `field "0" #0` and `#1` are the first on-screen set's weight and reps. Later sets are `#2`, `#3`, and so on. Rows below the fold are not in the tree.
- `button "circle"` is the first on-screen open set. Under the full-screen cover the Train grid also has `circle` buttons, which is why actions only count on-screen matches.
- Chips have no selected trait (the selection is color only). Prove feedback with the header checkmark, not `selected`.
- Feedback and soreness written in a `-seedDemo` run vanish on relaunch. Prove their persistence on the on-disk path, after week 1 is finished, when soreness questions appear.
- The decimal pad covers the lower part of the list. Tap `button "Done"` before tapping anything it might cover.
- `Finish` stays disabled until one set is done. Tapping it then does nothing, and the next `wait` times out.
