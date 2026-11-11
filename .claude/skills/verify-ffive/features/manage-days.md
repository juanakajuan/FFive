# Manage builder days

In the builder's Customize screen, the `Mesocycle Menu` (`#builder.menu`, `Template Menu` while editing a template) holds `Manage Days` (`#menu.manage-days`). It opens a sheet listing every day in edit mode: drag a row's handle to reorder, edit its name field to rename, or tap its `Remove Day` (`#manage-days.remove.<n>`) to remove it (the last remaining day has no `Remove Day`). `Done` (`#manage-days.done`) closes it. The sheet opens at half height; `tap button "Sheet Grabber"` expands it before you drive the rows. The order in the sheet is the order the started block trains the days: `MesoDay.order` follows it, so Day 1 of the schedule is the top row. A day's weekday label moves with it.

## Driving it with ffive-verify

- Before: `ffive-verify reset-data`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/manage-days.steps --name manage-days`.
- It labels Upper/Lower's day 4 Friday, drags it to the top, renames day 2, removes Upper B, starts the block and checks the Workout header (`WEEK 1 FRIDAY`, `Lower B`) and the schedule grid.
- Proof: `ffive-verify store "select ZORDER, ZNAME, ZWEEKDAYRAW from ZMESODAY order by ZORDER"` returns `0 Lower B friday`, `1 Upper Heavy`, `2 Lower A`.

## Gotchas

- Name fields are `#manage-days.name.<n>`, indexed by the row's current position.
- Each row's handle is a button labelled `Reorder Day <n> · [<weekday> · ]<k> exercises`; match it with `button "Reorder Day 4*"`. Drag from the handle.
- After a `drag`, `wait` on the row caption (`wait text "Day 1*Friday*6 exercises"`) before a `value` step: `value` can read the field before the drop settles.
- `Remove Day` ids are indexed by the row's current position, like the name fields.
