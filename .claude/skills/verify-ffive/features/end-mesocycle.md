# End a mesocycle

A lifter ends the active block early or once it is complete. Ending finishes the open session if it has logged sets and drops untouched ones. The Workout tab returns to its empty state with `Plan a Mesocycle`, the logged session reaches History, and the Mesos row shows the block as finished.

## Sub-features

- `end-menu` ends the block from the Workout tab: `Workout menu`, `End Mesocycle`, then `End Mesocycle` again in the "End this mesocycle?" dialog.
- `end-history` keeps the in-progress session's logged sets as a finished workout in Progress, History.
- `end-summary` opens the block's summary as a sheet over every end entry point. `Done` (`#sheet.done`) closes it.
- `end-mesos` marks the Mesos row `Finished` and re-enables the `New Mesocycle` "+".
- `end-other-entries` ends the block from the Mesos row's `<name> menu`, the block's detail page, or the "Block complete" card. The Mesos row and the detail page are driven by `meso-summary.steps` and `rename-mesocycle.steps`. The "Block complete" card is not yet driven.

## How to get to it (user POV)

- Workout tab during a block session: `Workout menu`, then `End Mesocycle`, then confirm.
- Workout tab once every session is done or skipped: the "Block complete" card's `End Mesocycle`.
- Mesos tab: the block row's `<name> menu`, then `End Mesocycle`, or the same button on the block's detail page.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline: `ffive-verify reset-data`, so the Workout tab shows `Plan a Mesocycle`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/end-mesocycle.steps --name end-mesocycle`. It plans "Ending Block" from the Full Body, 3 Days template, logs one Bench Press set, ends the block, and relaunches.

- **End.** Steps: `tap #workout.menu`, `tap #menu.end-mesocycle`, `tap #dialog.end-mesocycle`, `wait nav "Ending Block Summary" timeout=10`, `tap #sheet.done`, `wait #workout.plan timeout=10`.
- **Store.** Steps: `store-expect Mesocycle finishedDate null` before the end and `store-expect Mesocycle finishedDate not-null` after it, then `store-expect Workout endDate not-null` for the session the end finished. For the row, run `ffive-verify store "select ZNAME, ZFINISHEDDATE from ZMESOCYCLE"`.
- **History.** Steps: `tap #tab.more`, `tap #more.progress`, `tap #segment.history`, `count #history.row.full-body-a "1"`. Before ending, History is empty.
- **Mesos.** Steps: `tap #tab.mesos`, `wait any "Finished"`.
- **Persistence.** A second `launch` lands on `#workout.plan` again: the block stays finished and no session reopens.

## Gotchas

- The menu item and the dialog's confirmation button both read `End Mesocycle`. The journey taps them by id, `#menu.end-mesocycle` and then `#dialog.end-mesocycle`.
- After ending, Progress's Volume pane still shows the finished block, not the "No mesocycle yet" empty state.
- Ending drops an open session with no logged set, so log one set first or History stays empty and `count` fails.
