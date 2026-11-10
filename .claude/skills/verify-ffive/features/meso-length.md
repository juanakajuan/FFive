# Block length

While a block runs, the Workout tab's schedule sheet has a length card under the grid. Its stepper adds a training week before the deload or removes the last one, between 3 and 6 training weeks. The grid gains or loses a row, the RIR strip under the stepper counts down again to 0 before the deload, and sessions already built but not logged in the weeks that changed are rebuilt for their new RIR. Logged sessions keep the RIR they were trained at. Removing is refused once the last training week or the deload has a logged set, and adding once the deload has one; the card's footnote says why.

## Sub-features

- `add-week` taps `Increment` and the block gains a training week.
- `remove-week` taps `Decrement` and the block loses its last training week.
- `length-bounds` stops at 3 and 6 training weeks.
- `length-persist` keeps the new length after a relaunch, stored in `ZMESOCYCLE.ZACCUMULATIONWEEKS`.
- `remove-refused` disables `Decrement` once the last training week or the deload has a logged set. Covered by `MesoLengthTests`, not yet driven.

## How to get to it (user POV)

- Workout tab: `#workout.schedule`, then the length card's stepper (`#schedule.length`).

## Driving it with ffive-verify

Preconditions:

- On disk: `ffive-verify reset-data`, then `journeys/meso-length.steps`, which plans "Length Block" from Upper/Lower, 4 Days.

- **Add a week.** Steps: `tap #workout.schedule`, `tap button "Sheet Grabber"`, `tap button "~Increment"`, `wait any "5 training weeks, then 1 deload week"`, `store-expect Mesocycle accumulationWeeks 5`, `count image "circle" "20"` (the future-week cells of 4 days over 5 weeks).
- **Remove weeks.** Steps: `tap button "~Decrement"` twice, `wait any "3 training weeks, then 1 deload week"`, `store-expect Mesocycle accumulationWeeks 3`.
- **Floor.** A third `Decrement` changes nothing: the label still reads 3 training weeks.
- **Persist.** Steps: `launch`, `tap #workout.schedule`, `wait any "3 training weeks, then 1 deload week"`.

## Gotchas

- The stepper's label is not hittable on its own. Wait for the whole stepper label, `any "<n> training weeks, then 1 deload week"`.
- The builder's stepper is also labeled `Increment` and `Decrement`. The schedule sheet's is the only one on screen while the sheet is up.
- `count image "circle"` counts only future weeks' cells. Current-week cells are buttons.
