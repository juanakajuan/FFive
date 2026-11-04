# Notes

A lifter attaches a note, such as a machine setting, to an exercise, and it shows on that exercise's card in every later workout and on its Exercises tab detail page. An exercise note belongs to the exercise name, not to one workout. A lifter can also attach a note to the workout day, and it shows at the top of the session and in the finished workout's detail page.

## Sub-features

- `note-exercise-add` adds an exercise note with `Exercise menu`, then `Add Note`. An `Exercise Note` sheet takes the text in `field "Note"` and saves with `Save`. The card shows it as a callout labeled `Note: <text>`.
- `note-exercise-carry` shows the same note on the exercise's card in a later workout, including after a relaunch.
- `note-exercise-edit` edits it with `Exercise menu`, then `Edit Note`.
- `note-exercise-delete` removes it with `Exercise menu`, then `Delete Note`. Saving blank text also removes it.
- `note-exercise-detail` shows the note on the exercise's page in the Exercises tab.
- `note-day` adds a day note with `Workout menu`, then `Add Note` (or `Edit Note`), through a `Workout Note` sheet. It shows as `Workout note: <text>` at the top of the session and in the summary card of the workout's detail page.

## How to get to it (user POV)

- Workout tab, any session (block day or quick workout): an exercise card's `Exercise menu`.
- Workout tab, any session: the header's `Workout menu`.
- Exercises tab: tap an exercise row to see its note.
- More, Progress, History: tap a finished workout to see its day note.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data`.
- Journey: `journeys/notes.steps`.

- **Add an exercise note.** Steps: `tap button "Exercise menu"`, `wait button "Add Note"`, `tap button "Add Note"`, `wait nav "Exercise Note"`, `type field "Note" "Seat Level: 4"`, `tap button "Save"`, `wait any "Note: Seat Level: 4"`.
- **Add a day note.** Steps: `tap button "Workout menu"`, `wait button "Add Note"`, `tap button "Add Note"`, `wait nav "Workout Note"`, `type field "Note" "Gym was busy"`, `tap button "Save"`, `wait any "Workout note: Gym was busy"`.
- **Carry forward.** Finish the workout, relaunch, start another quick workout, add the same exercise, then `wait any "Note: Seat Level: 4"`.
- **Day note in history.** Steps: `tap button "More"`, `tap button "Progress"`, `tap button "History"`, `tap button "~Workout,"`, `wait any "Workout note: Gym was busy"`.
- **Edit, detail, delete.** `Edit Note` then `replace field "Note" "Seat Level: 5"`. On the Exercises tab, `type field "Search" "Lateral Raise"`, `tap button "Lateral Raise, Side Delts, •, Dumbbell"` and `wait any "Note: Seat Level: 5"`. Back on the Workout tab, `Delete Note`, then `absent any "Note: Seat Level: 5"`. An immediate `launch` then `absent any "~Note: Seat Level"` proves the delete was saved, not left to autosave.
- **Proof.** Run `ffive-verify store "select ZNAME, ZTEXT from ZEXERCISENOTE"` and `ffive-verify store "select ZNAME, ZNOTE from ZWORKOUT"`.

## Gotchas

- The note editor is a sheet because alert text fields lost a cleared-and-retyped edit. Present it from the workout screen root, since a presentation on a card inside the lazy stack was dropped after the picker closed.
- Tapping a menu item right after the exercise picker closes can race the menu. Wait for the item (`wait button "Add Note"`) before tapping it.
- Menu items do not appear in `tree` dumps, but tapping them by label works.
