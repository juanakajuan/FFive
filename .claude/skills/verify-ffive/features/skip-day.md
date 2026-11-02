# Skip a day

A lifter can skip a session of the current week, either from the Next up card or by long-pressing its grid cell. A skipped day shows a fast-forward icon, Next up moves on, and the skip persists. Tapping a skipped day of the current week offers to train it after all, which opens that session.

## Sub-features

- `skip-card` skips the next session with the card's `Skip` button.
- `skip-grid` skips an upcoming current-week day from the cell's long-press `Skip Day` menu.
- `skip-persist` keeps skips after a relaunch, stored in `ZMESOCYCLE.ZSKIPPEDSESSIONS`.
- `unskip` taps a skipped current-week cell and chooses `Train Day <n>`. It removes the skip and opens the session.
- `skip-complete` reaches "Block complete" once every session is done or skipped. Not yet driven.

## How to get to it (user POV)

- Train tab, Next up card: `Skip` (bottom-right of the card). It only appears when the session can be skipped.
- Train tab, schedule grid: long-press an upcoming current-week cell, then `Skip Day`.
- Train tab, schedule grid: tap a skipped current-week cell, then `Train Day <n>`.

## Driving it with ffive-verify

Preconditions:

- On disk: train-session.steps ran on this store ("Verify Block", 4 days, W1 D1 finished, Week 1 · Day 2 next up).
- Journeys: `journeys/skip-day.steps`, then `journeys/unskip-day.steps`.

- **Skip from card.** Steps: `tap button "Skip"`, `wait button "~Next up, Week 1 · Day 3"`, `count button "forward.circle" "1"`.
- **Skip from grid.** Long-press Day 4's cell. Steps: `longpress button "circle"`, `tap button "Skip Day"`, `count button "forward.circle" "2"`.
- **Persist.** Steps: `launch`, `wait button "~Next up, Week 1 · Day 3" timeout=20`, `count button "forward.circle" "2"`.
- **Proof of skip.** Run `ffive-verify store "select cast(ZSKIPPEDSESSIONS as text) from ZMESOCYCLE"`. It lists `dayIndex` 1 and 3 with `week` 0.
- **Train after all.** Steps: `tap button "forward.circle"`, `wait text "Train this day after all?"`, `tap button "Train Day 2"`, `wait nav "Verify Block"`, `wait text "~Lower A"`, `tap button "Close"`, `wait button "~In progress, Week 1 · Day 2"`, `count button "forward.circle" "1"`.
- **Proof of unskip.** The same query lists only `dayIndex` 3. `ffive-verify store "select ZNAME, ZDAYINDEX, ZENDDATE from ZWORKOUT where ZDAYINDEX = 1"` shows an open `Lower A` row.

## Gotchas

- The JSON key order in `ZSKIPPEDSESSIONS` is not stable (`{"week":0,"dayIndex":1}` or `{"dayIndex":1,"week":0}`). Compare parsed values, not strings.
- `longpress button "circle"` hits the first on-screen upcoming current-week cell. Future weeks' circles are images, not buttons, so they never match.
- Only current-week cells react. A skipped cell in an earlier week is a plain image.
- The in-progress session cannot be skipped. `Skip` disappears from its card.
- In the demo seed, Week 2 · Day 3 starts out skipped. Account for it before you count `forward.circle` in a `-seedDemo` run.
