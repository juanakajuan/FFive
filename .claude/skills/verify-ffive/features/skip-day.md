# Skip a day

A lifter can skip a session of the current week, either from the `Workout menu` or by long-pressing its cell in the schedule grid. A skipped day shows a fast-forward icon, the Workout tab moves on to the next day, and the skip persists. Tapping a skipped day of the current week offers to train it after all, which shows that session on the Workout tab.

## Sub-features

- `skip-menu` skips the day the Workout tab shows with `Workout menu`, then `Skip Day`.
- `skip-grid` skips an upcoming current-week day from the cell's long-press `Skip Day` menu.
- `skip-persist` keeps skips after a relaunch, stored in `ZMESOCYCLE.ZSKIPPEDSESSIONS`.
- `unskip` taps a skipped current-week cell and chooses `Train Day <n>`. It removes the skip and shows that day on the Workout tab.
- `skip-complete` reaches "Block complete" once every session is done or skipped. Not yet driven.

## How to get to it (user POV)

- Workout tab: `Workout menu`, then `Skip Day`. It only appears while the shown day has no logged set.
- Schedule grid (the Workout tab's `Schedule` sheet, or the block's detail page on the Mesos tab): long-press an upcoming current-week cell, then `Skip Day`.
- The same grid: tap a skipped current-week cell, then `Train Day <n>`.

## Driving it with ffive-verify

Preconditions:

- On disk: train-session.steps ran on this store ("Verify Block", 4 days, W1 D1 finished, Week 1 · Day 2 showing).
- Journeys: `journeys/skip-day.steps`, then `journeys/unskip-day.steps`.

- **Skip from menu.** Steps: `launch`, `wait text "WEEK 1 DAY 2" timeout=20`, `tap button "Workout menu"`, `tap button "Skip Day"`, `wait text "WEEK 1 DAY 3"`, `tap button "Schedule"`, `count button "forward.circle" "1"`.
- **Skip from grid.** Long-press Day 4's cell in the open sheet. Steps: `longpress button "circle"`, `tap button "Skip Day"`, `count button "forward.circle" "2"`.
- **Persist.** Steps: `launch`, `wait text "WEEK 1 DAY 3" timeout=20`, `tap button "Schedule"`, `count button "forward.circle" "2"`.
- **Proof of skip.** Run `ffive-verify store "select ZNAME, cast(ZSKIPPEDSESSIONS as text) as skipped from ZMESOCYCLE"`. It lists `dayIndex` 1 and 3 with `week` 0.
- **Train after all.** Steps: `launch`, `wait text "WEEK 1 DAY 3" timeout=20`, `tap button "Schedule"`, `count button "forward.circle" "2"`, `tap button "forward.circle"`, `wait text "Train this day after all?"`, `tap button "Train Day 2"`, `wait text "WEEK 1 DAY 2"`, `wait text "~Lower A"`, `tap button "Schedule"`, `count button "forward.circle" "1"`.
- **Proof of unskip.** `ffive-verify store "select cast(ZSKIPPEDSESSIONS as text) from ZMESOCYCLE"` lists only `dayIndex` 3. `ffive-verify store "select ZNAME, ZWEEK, ZDAYINDEX, ZENDDATE from ZWORKOUT where ZDAYINDEX = 1"` shows an open `Lower A` row.

## Gotchas

- The JSON key order in `ZSKIPPEDSESSIONS` is not stable (`{"week":0,"dayIndex":1}` or `{"dayIndex":1,"week":0}`). Compare parsed values, not strings.
- `longpress button "circle"` hits the first on-screen plain `circle` cell of the current week. The day the Workout tab shows is already built, so its cell is `circle.lefthalf.filled` and never matches. Future weeks' circles are images, not buttons.
- Only current-week cells react. A skipped cell in an earlier week is a plain image.
- A day with a logged set cannot be skipped. `Skip Day` disappears from the workout menu and from the cell's long-press menu.
- The `Workout menu` items do not appear in `tree` dumps, but tapping them by label works.
- In the demo seed, Week 2 · Day 3 starts out skipped. Account for it before you count `forward.circle` in a `-seedDemo` run.
