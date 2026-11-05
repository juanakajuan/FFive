# Set type

A lifter marks any set as Regular, Myorep, or Myorep match from the set's menu. A non-regular set shows a `MYO` or `MATCH` tag between its reps field and its log checkbox, and the same tag under the set number in the finished workout's detail page and in the exercise history sheet. A set added with `Add Set` copies the type of the set before it. Progression ignores myo-rep sets for load and rep targets and for 1RM estimates.

## Sub-features

- `set-type-pick` sets the type with `#set.menu.<n>`, then `button "Regular"`, `button "Myorep"`, or `button "Myorep match"`. The current type carries a checkmark.
- `set-type-row` shows the tag on the row. The tag is hidden from accessibility, so assert the menu's label, as in `any "Set 2 menu, Myorep match"`.
- `set-type-history` shows the type in the finished workout's detail page. Assert the row label, as in `any "Set 2, Myorep match*25 lb*5"`.

## How to get to it (user POV)

- Workout tab, any session: a set row's `Set <n> menu`.
- More, Progress, History: tap a finished workout.
- Workout tab: an exercise card's history button.

## Driving it with ffive-verify

Preconditions:

- On-disk baseline right after `ffive-verify reset-data`.
- Journey: `journeys/set-type.steps`.

The journey logs a regular set and a Myorep match set in a quick workout, checks `store-expect SetEntry typeRaw myorepMatch`, finishes, relaunches, and checks the type in history.
