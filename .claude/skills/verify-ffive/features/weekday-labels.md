# Weekday labels

A block day can carry a weekday label, Monday through Sunday, or none. The builder sets it per day with the `Weekday` picker under the day name. In a block session, `Relabel` in the workout menu lists the seven weekdays (the current one checked) and `No Weekday` once one is set. Picking one asks how far it reaches: `Every Week` relabels the `MesoDay`, every session of that day already built, and later weeks; `This Session Only` relabels only the open session. The label is stored as `weekdayRaw` on `MesoDay` and `Workout`.

The workout header reads `WEEK <n> <WEEKDAY>` in place of `DAY <n>` when the session has a label. The schedule grid header shows the day's three-letter weekday in place of `D<n>`, and its accessibility label becomes `Day <n>, <Weekday>, <name>`.

## Sub-features

- `builder-weekday` sets the label per day before the block starts.
- `start-weekday` picks the weekday the block starts on in the builder's `Schedule` section and labels every day with a suggested weekday that spreads rest through the week (4 days from Monday: Mon, Tue, Thu, Fri). Each day's picker can still change it. Rule and tests: `Weekday.suggested(days:startingOn:)`, `WeekdayScheduleTests`.
- `relabel-session` changes only the open session.
- `relabel-every-week` changes the day and every session of it.
- `header-weekday` and `grid-weekday` show the label.

## How to get to it (user POV)

- Mesos, New Mesocycle, a template, the `Weekday` row of a day.
- Workout tab, `Workout menu`, `Relabel`, on a block day. Quick workouts have no `Relabel`.
- Workout tab, the calendar button, the grid header.

## Driving it with ffive-verify

Preconditions: `ffive-verify reset-data`. Journey: `journeys/weekday-labels.steps`.

- **Builder.** `scrollto #builder.weekday.1`, `tap #builder.weekday.1`, `tap button "Monday"`. Result: `store-expect MesoDay weekdayRaw monday`, `wait text "WEEK 1 MONDAY"`.
- **Start weekday.** Journey: `journeys/start-weekday.steps`. `tap #builder.start-weekday`, `tap button "Monday"`. Result: each `#builder.weekday.<n>` is labelled `Weekday, <day>`, so assert with `exists button "Weekday, Thursday"`, not `value`.
- **Relabel.** `tap #workout.menu`, `tap #menu.relabel`, `sleep 1`, `tap button "Thursday"`, then `tap #dialog.weekday-session` or `#dialog.weekday-every-week`.

## Gotchas

- The builder's `Starts on` picker sits above the days. After scrolling down to the days, `swipe down` dismisses the builder sheet instead of scrolling back up, and `scrollto` cannot reach it either. Relaunch and reopen the builder to pick again.

- The weekday items sit in a submenu, which XCUITest does not expose by identifier. Tap them by label after a `sleep 1`.
