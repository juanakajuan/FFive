# Exercise detail from the picker

Each exercise picker row has an info button (`#picker.detail.<slug>`, labeled `<name> details`) beside the row's pick button (`#picker.row.<slug>`). It pushes the Exercises tab's detail page (cue, last performed, pinned note, history) inside the picker's own navigation stack, so the picker sheet stays open underneath. The back button, `button "Add Exercise"` (or the picker's title, as in `Swap <name>`), returns to the picker with its search text and equipment filter unchanged. History rows open the read-only workout from there too.

- **Journey.** `journeys/picker-detail.steps` (demo): pins a note on Bench Press, opens the picker, searches "Bench", opens Bench Press's detail and sees the cue, last performed date and note, goes back and finds the search still "Bench", then picks Incline Bench Press with the row's main button.
