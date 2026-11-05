# Notes

A lifter attaches a note to an exercise in a workout. By default it stays with that workout: it shows on that card and on the exercise in the finished workout's detail page, and not in later workouts. Tapping the pin to the right of the note pins it, and a pinned note, such as a machine setting, shows on that exercise's card in every later workout and on its Exercises tab detail page. A lifter can also attach a note to the workout day, which shows at the top of the session and in the finished workout's detail page.

## Sub-features

- `note-exercise-add` adds an exercise note with `Exercise menu`, then `Add Note`. An `Exercise Note` sheet takes the text in `#note.text` and saves with `#note.save`. The card shows it as a callout labeled `Note: <text>`, with the pin button `#exercise.pin.<n>` beside it.
- `note-exercise-local` keeps an unpinned note off later workouts, and shows it in the finished workout's detail page.
- `note-exercise-pin` pins it with `Pin note`. The button becomes `Unpin note`, and the note shows on the exercise's card in later workouts, including after a relaunch.
- `note-exercise-edit` edits it with `Exercise menu`, then `Edit Note`. Editing a pinned note edits the pin.
- `note-exercise-unpin` unpins with `Unpin note`. The note stays on the current workout and stops carrying forward.
- `note-exercise-delete` removes it, pinned or not, with `Exercise menu`, then `Delete Note`. Saving blank text also removes it.
- `note-exercise-detail` shows a pinned note on the exercise's page in the Exercises tab.
- `note-day` adds a day note with `Workout menu`, then `Add Note` (or `Edit Note`), through a `Workout Note` sheet. It shows as `Workout note: <text>` at the top of the session and in the summary card of the workout's detail page.

## How to get to it (user POV)

- Workout tab, any session (block day or quick workout): an exercise card's `Exercise menu`, and the pin beside its note.
- Workout tab, any session: the header's `Workout menu`.
- Exercises tab: tap an exercise row to see its pinned note.
- More, Progress, History: tap a finished workout to see its day note and its exercises' notes.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data`.
- Journey: `journeys/notes.steps`.

- **Add an exercise note.** Steps: `tap #exercise.menu.1`, `wait #menu.exercise-note`, `tap #menu.exercise-note`, `wait nav "Exercise Note"`, `type #note.text "Seat Level: 4"`, `tap #note.save`, `wait any "Note: Seat Level: 4"`, `wait button "Pin note"`.
- **Add a day note.** Steps: `tap #workout.menu`, `wait #menu.workout-note`, `tap #menu.workout-note`, `wait nav "Workout Note"`, `type #note.text "Gym was busy"`, `tap #note.save`, `wait any "Workout note: Gym was busy"`.
- **Notes in history.** Finish, then `store-expect Workout note "Gym was busy"`, `tap #tab.more`, `tap #more.progress`, `tap #segment.history`, `tap button "~Workout,"`, `wait any "Workout note: Gym was busy"`, `wait any "Note: Seat Level: 4"`.
- **Unpinned stays put.** Start another quick workout, add the same exercise, then `absent any "~Note: Seat Level"`.
- **Pin and carry.** Add a note, `tap #exercise.pin.1`, `wait button "Unpin note"`, `store-expect PinnedNote text "Seat Level: 5"`. Finish, relaunch, and the Exercises tab page (`type #exercises.search "Lateral Raise"`, `tap #exercises.row.lateral-raise`) shows `Note: <text>`. A new quick workout with the exercise shows the note and `Unpin note`.
- **Edit, unpin, delete.** `tap #exercise.menu.1`, `tap #menu.exercise-note` (it reads `Edit Note` now), then `replace #note.text "Seat Level: 6"`. `tap #exercise.pin.1`, then `wait button "Pin note"` with the note still on the card. `tap #exercise.menu.1`, `tap #menu.delete-note`, then `absent any "~Note: Seat Level"`. An immediate `launch` then `absent any "~Note: Seat Level"` proves the writes were saved, not left to autosave.
- **Proof.** The journey's `store-expect` steps check the day note and the pin. For the full picture, run `ffive-verify store "select ZNAME, ZTEXT from ZPINNEDNOTE"`, `ffive-verify store "select ZNAME, ZNOTE from ZEXERCISE"`, and `ffive-verify store "select ZNAME, ZNOTE from ZWORKOUT"`.

## Gotchas

- The note editor is a sheet because alert text fields lost a cleared-and-retyped edit. Present it from the workout screen root, since a presentation on a card inside the lazy stack was dropped after the picker closed.
- Tapping a menu item right after the exercise picker closes can race the menu. Wait for the item (`wait #menu.exercise-note`) before tapping it.
- Menu items do not appear in `tree` dumps, but tapping them by id works.
- `#exercise.pin.<n>` is one id for both `Pin note` and `Unpin note`. Assert the pin state by label, with `wait button "Unpin note"` or `wait button "Pin note"`.
- History rows are keyed by workout name, and a quick workout's name depends on the clock. So the journey taps `button "~Workout,"`, the first finished workout in History. Open it while only one exists, or the match is ambiguous.
