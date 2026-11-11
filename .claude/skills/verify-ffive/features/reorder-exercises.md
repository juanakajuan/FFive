# Reorder exercises

`Reorder Exercises` in the workout menu opens a sheet of the session's exercises with drag handles. Save puts the cards in the new order. In a block day the sheet also asks whether later weeks of that day follow the new order (`Later Weeks Too`, the default) or keep theirs (`This Session Only`). A quick workout has no such choice.

## Sub-features

- `reorder-menu` shows `Reorder Exercises` in `#workout.menu` only while the session has 2 or more exercises.
- `reorder-save` saves the dragged order for this session; `Cancel` drops it.
- `reorder-later-weeks` carries the new order into later weeks of the same day, including ones already built and unfinished.
- `reorder-this-session` keeps later weeks on the order they had, stored as `ZEXERCISE.ZPLANNEDORDER`.

## How to get to it (user POV)

- Workout tab, `Workout Menu`, `Reorder Exercises`, on a block day or a quick workout.

## Driving it with ffive-verify

Preconditions: `ffive-verify reset-data`. Journey: `journeys/reorder-exercises.steps`.

- **Open.** Steps: `tap #workout.menu`, `tap #menu.reorder`, `wait nav "Reorder Exercises"`.
- **Drag.** Each row's handle is a button labeled `Reorder <exercise>`. Steps: `drag button "Reorder Bench Press" to button "Reorder Lateral Raise"`, `tap #reorder.save`. Result: the store's `ZORDER` follows the new order and survives a relaunch. The journey's `store-expect` only proves the row exists, so read the order with `ffive-verify store "select ZNAME, ZORDER from ZEXERCISE order by ZORDER"`.
- **Scope.** `#segment.later-weeks-too` and `#segment.this-session-only`, block days only. To see the effect, finish the day (delete extra sets, remove other exercises, log the rest), skip the week's other days with `#menu.skip-day`, and read the next week's `ZORDER` with `ffive-verify store`.

## Gotchas

- `drag` must start on the handle. Dragging the row's text does nothing in edit mode.
- After a muscle's last set is logged its feedback card appears below the card and pushes later cards down, so `#set.log.1` may then hit the already-logged card. Log later cards first.
