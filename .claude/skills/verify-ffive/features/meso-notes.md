# Mesocycle notes

A lifter keeps a list of notes on the whole block, each up to 500 characters. Notes are stored in order on `Mesocycle.notes` and show newest first.

## How to get to it (user POV)

- Workout tab, while a block is active: `Workout Menu`, then `Mesocycle Notes` (`#menu.meso-notes`). It shows on block days and on a quick workout run during a block.
- Mesos tab, a block's detail page: the `Mesocycle Notes` card below Muscle Priorities. Its button `#meso-notes.edit` reads `Add Note` with no notes and `Edit` otherwise.
- The block's summary (`Mesocycle Menu`, `Summary`, or the sheet shown on end) shows the same `Mesocycle Notes` card read-only when the block has notes.

Both entry points open the `Mesocycle Notes` sheet: a field `#meso-note.text` with a `n/500` counter, `#meso-note.add`, and one card per note with a trash button `#meso-note.delete.<n>`, numbered from 1 in on-screen (newest first) order. `#sheet.done` closes it.

## Driving it with ffive-verify

- Before: `ffive-verify reset-data`. Journey: `journeys/meso-notes.steps`. It plans a block, adds a note from the workout menu, adds a second and deletes the first from the detail page, checks the summary, and relaunches to prove the writes saved.
- Proof: `ffive-verify store "select ZNAME, cast(ZNOTES as text) from ZMESOCYCLE"` prints the notes as JSON.

## Gotchas

- The field cuts typing at 500 characters, and `Store.addNote` also cuts longer text and ignores blank text.
