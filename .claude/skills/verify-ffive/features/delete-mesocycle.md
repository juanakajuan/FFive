# Delete a mesocycle

A lifter deletes a block, finished or current. A confirmation, "Delete this mesocycle?", says how many logged workouts go with it. Deleting removes the block, its days, and every session built for it, so its logged sets leave History and Progress. Quick workouts stay.

## Sub-features

- `delete-row` deletes from the Mesos row's `<name> menu`: `#menu.delete-mesocycle`, then `#dialog.delete-mesocycle`.
- `delete-detail` deletes from the block's detail page menu (`#meso.menu`), which pops back to the Mesos list.
- `delete-count` the dialog message reads `Its <n> logged workout(s) leave(s) History and Progress. This can't be undone.`, or `It has no logged workouts.` for none.
- `delete-history` the block's sessions leave Progress, History and Strength.

## How to get to it (user POV)

- Mesos tab: a block row's `<name> menu`, then `Delete`, then `Delete Mesocycle`.
- Mesos tab, a block's detail page: the top-right menu, then `Delete`, then `Delete Mesocycle`.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline: `ffive-verify reset-data`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/delete-mesocycle.steps --name delete-mesocycle`. It plans and ends "Old Block" with one logged Squat set, plans "Live Block" and logs one set, deletes Old Block from its row, then Live Block from its detail page, and relaunches.

- **Row delete.** Steps: `tap #mesos.menu.old-block`, `tap #menu.delete-mesocycle`, `wait text "~Its 1 logged workout leaves History and Progress."`, `tap #dialog.delete-mesocycle`, `absent #mesos.row.old-block`.
- **History.** Steps: `count #history.row.full-body-a "1"` before, `"0"` after.
- **Detail delete.** Steps: `tap #mesos.row.live-block`, `tap #meso.menu`, `tap #menu.delete-mesocycle`, `tap #dialog.delete-mesocycle`, `wait #mesos.plan`.
- **Store.** After the journey, `ffive-verify store` shows 0 rows in every table.

## Gotchas

- `store-expect` cannot assert that rows are gone. Read `ffive-verify store` after the drive instead.
