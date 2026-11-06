# Bodyweight

A lifter sets their body weight for a session from the workout menu. A new session, quick or in a block, starts with the body weight of the most recently started session that has one. On a bodyweight lift (catalog equipment Bodyweight, such as Pull-Up or Dip) the weight field holds load added to body weight: empty is body weight alone, a positive number is added load, and a negative number is assistance. The card's subtitle reads `Bodyweight · 180 lb`, the column header reads `BW +/−`, and the empty field's placeholder is `BW`. Without a body weight the card shows a callout, and the lift gives no strength point and progresses by reps only. With one, e1RM, workout volume, and progression use body weight plus the logged load, and labels read `BW`, `BW+25`, or `BW−40`.

## Sub-features

- `bodyweight-set` sets the session's body weight with `#workout.menu`, `#menu.bodyweight`, then `type field "Bodyweight (lb)" "<n>"` and `button "Save"`. An empty field, 0, or a negative number clears it.
- `bodyweight-callout` shows `Set your bodyweight in the workout menu to track strength on this lift.` on a bodyweight lift while the session has no body weight.
- `bodyweight-signed-load` logs added load or assistance in `#set.weight.<n>`. The keyboard has a minus key.
- `bodyweight-labels` shows `BW+25` and `BW−40` (U+2212) in the finished workout's detail page and the exercise history sheet.
- `bodyweight-strength` counts body weight in the Progress strength row, as in `Pull-Up, Back, 1 session, 260 lb` for 180 + 25 × 8.
- `bodyweight-carry` starts the next session with the last body weight entered.

## How to get to it (user POV)

- Workout tab, any session: the workout menu's Set Bodyweight item, which reads `Bodyweight · <n> lb` once set.
- Workout tab: a bodyweight lift's set rows.
- More, Progress, Strength and History.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data`.
- Journey: `journeys/bodyweight.steps`.

The journey adds Pull-Up to a quick workout, checks the callout, sets 180 lb, checks `store-expect Workout bodyweight 180`, logs +25 × 8 and −40 × 10, checks `store-expect SetEntry weight -40`, finishes, relaunches, checks the 260 lb strength row, the `BW+25` and `BW−40` history rows, and the 3,040 volume, then starts a second quick workout and checks Dip shows `Bodyweight · 180 lb`.

## Gotchas

- The alert's text field drops its accessibility identifier, so address it by its placeholder, `field "Bodyweight (lb)"`, or `Bodyweight (kg)` in kilograms.
- Progress opens on Volume. Tap `#segment.strength` before waiting for a `#strength.row.<slug>`.
