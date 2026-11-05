# End a mesocycle

A lifter ends the active block early or once it is complete. Ending finishes the open session if it has logged sets and drops untouched ones. The Workout tab returns to its empty state with `Plan a Mesocycle`, the logged session reaches History, and the Mesos row shows the block as finished.

## Sub-features

- `end-menu` ends the block from the Workout tab: `Workout menu`, `End Mesocycle`, then `End Mesocycle` again in the "End this mesocycle?" dialog.
- `end-history` keeps the in-progress session's logged sets as a finished workout in Progress, History.
- `end-mesos` marks the Mesos row `Finished` and re-enables the `New Mesocycle` "+".
- `end-other-entries` ends the block from the Mesos row's `<name> menu`, the block's detail page, or the "Block complete" card. Not yet driven.

## How to get to it (user POV)

- Workout tab during a block session: `Workout menu`, then `End Mesocycle`, then confirm.
- Workout tab once every session is done or skipped: the "Block complete" card's `End Mesocycle`.
- Mesos tab: the block row's `<name> menu`, then `End Mesocycle`, or the same button on the block's detail page.

## Driving it with ffive-verify

Preconditions:

- Demo baseline (`launch -seedDemo`): Week 2 · Day 1 in progress with Squat logged, Week 1's Full Body A already in History.
- Journey: `journeys/end-mesocycle.steps`. The demo store is in memory, so this proves the screens only. For persistence, end an on-disk block and check `ffive-verify store "select ZNAME, ZFINISHEDDATE from ZMESOCYCLE"`.

- **End.** Steps: `wait text "WEEK 2 DAY 1" timeout=20`, `tap #workout.menu`, `tap #menu.end-mesocycle`, `tap #dialog.end-mesocycle`, `wait #workout.plan timeout=10`.
- **History.** Steps: `tap #tab.more`, `tap #more.progress`, `tap #segment.history`, `count #history.row.full-body-a "2"`. Before ending, the count is 1.
- **Mesos.** Steps: `tap #tab.mesos`, `wait any "Finished"`.

## Gotchas

- The menu item and the dialog's confirmation button both read `End Mesocycle`. The journey taps them by id, `#menu.end-mesocycle` and then `#dialog.end-mesocycle`.
- After ending, Progress's Volume pane still shows the finished block, not the "No mesocycle yet" empty state.
- `wait #history.row.full-body-a` alone proves nothing: Week 1's session is already in History before the block ends.
