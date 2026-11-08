# Muscle priorities

A lifter marks each muscle the block trains as Emphasize, Normal, or Maintain, in the builder before starting or on the block's detail page while it runs. A maintained muscle starts at its MV instead of its MEV and never adds sets. An emphasized muscle adds one more set whenever its feedback earns an increase. A change on the detail page applies from the next session the block builds.

## Sub-features

- `priority-builder` sets a priority in the builder's `Muscle Priorities` section, below the days.
- `priority-week1` starts a maintained muscle's week 1 sets at MV (chest in Upper/Lower, 4 Days: 4 sets per session instead of 5).
- `priority-detail` shows and changes priorities on the block's detail page, in the `Muscle Priorities` card below the week's sets. A finished block shows them read-only.
- `priority-persist` keeps priorities after a relaunch, stored in `ZMESOCYCLE.ZMUSCLEPRIORITYRAW` as JSON with normal muscles left out.
- `priority-progression` is covered by `PlannerTests.testMusclePriorities`, not driven: it needs a logged week with feedback.

## How to get to it (user POV)

- Builder: `Plan a Mesocycle` or the Mesos tab's `New Mesocycle` "+", pick a template, scroll past the days to `Muscle Priorities`, and tap a muscle's priority menu. The Guided Plan screen (`#builder.guided`) has the same menus; see `guided-plan.md`.
- Mesos tab: tap the block's row, scroll to the `Muscle Priorities` card, and tap a muscle's priority menu.

## Driving it with ffive-verify

Preconditions:

- On disk: `ffive-verify reset-data`, then `launch`.
- Journey: `journeys/muscle-priorities.steps`.

- **Set in builder.** Steps: `tap #builder.template.upper-lower-4-days`, `scrollto #muscle-priority.chest`, `scrollto #muscle-priority.back`, `tap #muscle-priority.chest`, `tap button "Maintain"`, `value #muscle-priority.chest "Maintain"`.
- **Week 1 sets.** After `tap #builder.start`, run `ffive-verify store "select e.ZNAME, count(s.Z_PK) from ZEXERCISE e join ZSETENTRY s on s.ZEXERCISE=e.Z_PK group by e.Z_PK"`. Bench Press has 4 sets.
- **Change on detail.** Steps: `tap #tab.mesos`, `tap #mesos.row.upper-lower-4-days`, `scrollto #muscle-priority.chest`, `scrollto #muscle-priority.back`, `tap #muscle-priority.back`, `tap button "Normal"`, `value #muscle-priority.back "Normal"`.
- **Persist.** Relaunch, reopen the detail page, and check both `value` steps again. `ffive-verify store "select cast(ZMUSCLEPRIORITYRAW as text) from ZMESOCYCLE"` prints `{"chest":"maintain"}`.

## Gotchas

- Do not rename the block before scrolling: the keyboard covers the list and `scrollto` cannot reach the section.
- The builder list is long. One `scrollto` can stop with the row under the Start button, so scroll on to the next muscle before tapping.
- The menu's options are buttons labeled `Emphasize`, `Normal`, and `Maintain`. The row's id carries the current priority as its value.
