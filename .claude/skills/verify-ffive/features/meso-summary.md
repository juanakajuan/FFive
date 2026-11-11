# Mesocycle summary and rename

A lifter reviews how a block went and renames it. The summary shows done sets per muscle for each week (deload last, colored against the muscle's landmarks), the first and last estimated 1RM of every exercise across the hard weeks, and each muscle's feedback answers per week as bars. It opens on its own as a sheet when a block ends.

## Sub-features

- `summary-detail` pushes the summary from the block's detail page: `#meso.menu`, then `#menu.summary`. Its title is `<name> Summary`.
- `summary-list` pushes it from any block's Mesos row: `#mesos.menu.<slug>`, then `#menu.summary`.
- `summary-on-end` presents it as a sheet right after any end (see [End a mesocycle](./end-mesocycle.md)). `#sheet.done` closes it.
- `rename` renames the block from the detail page or its Mesos row: `#meso.menu` or `#mesos.menu.<slug>`, then `#menu.rename`, alert `Rename Mesocycle` with field `Mesocycle name`, then `button "Save"`. Surrounding spaces are trimmed and an empty name is ignored.

## Driving it with ffive-verify

- Demo: `ffive-verify drive .claude/skills/verify-ffive/journeys/meso-summary.steps --name meso-summary`. It opens the summary from the detail page, renames the block, ends it, and checks the sheet.
- On disk: `ffive-verify reset-data`, then `ffive-verify drive .claude/skills/verify-ffive/journeys/rename-mesocycle.steps --name rename-mesocycle`. It plans "Verify Block", renames it, checks `store-expect Mesocycle name "Spring Block"`, relaunches, ends it from the Mesos row, and opens the summary from the row menu.
- The summary cards have no ids. Assert them by text: `text "Sets per Muscle"`, `text "Estimated 1RM"`, `text "Feedback"`, and `text "No sessions yet"` for an untrained mesocycle.
