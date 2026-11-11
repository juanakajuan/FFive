# Guided plan

A lifter who doesn't want to pick a template asks the builder to plan the days for them. They choose how many days a week they train (2 to 6, 4 by default) and a priority for each muscle, then `Build Plan` opens Customize with a draft named `<n>-Day Plan`. Emphasized muscles train three times a week, normal ones twice, and maintained ones once. Days are named Upper, Lower, or Full Body, lettered when a name repeats. Every slot names only a muscle, so `Start Mesocycle` stays disabled until the lifter picks or autofills the exercises. The rule is `GuidedPlan` in FFiveCore.

## Sub-features

- `guided-open` opens `Guided Plan` from the builder's `Plan It for Me` section (`#builder.guided`, the `Guided Plan` row).
- `guided-days` is the `Days per Week` `SegmentedButtons` row, `#builder.guided-days`, whose options are `#segment.2` to `#segment.6`.
- `guided-priorities` is one priority menu per muscle, `#muscle-priority.<muscle raw value>`. Front delts, traps, forearms, and abs start at Maintain; the rest start at Normal.
- `guided-build` is `#builder.guided-build`. It pushes Customize with muscle-only slots and the chosen priorities in the editor's `Muscle Priorities` section.
- `guided-start` autofills the slots (`#builder.menu`, `#menu.autofill`) and starts the block. Its days and slots persist as `MesoDay` and `DaySlot` rows.

## How to get to it (user POV)

- Workout tab with no active block: `Plan a Mesocycle`, then `Guided Plan`.
- Mesos tab: `Plan a Mesocycle` in the empty state or the `New Mesocycle` "+", then `Guided Plan`.

## Driving it with ffive-verify

Preconditions:

- On disk: `ffive-verify reset-data`, then `launch`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/guided-plan.steps --name guided-plan`.

- **Open.** Steps: `tap #workout.plan`, `wait nav "New Mesocycle"`, `tap #builder.guided`, `wait nav "Guided Plan"`, `value #muscle-priority.abs "Maintain"`, `value #muscle-priority.chest "Normal"`.
- **Choose.** Steps: `wait #builder.guided-days`, `tap #segment.3`, `tap #muscle-priority.chest`, `tap button "Emphasize"`, `value #muscle-priority.chest "Emphasize"`.
- **Build.** Steps: `tap #builder.guided-build`, `wait nav "Customize"`, `scrollto field "Day name"`, `value field "Day name" "Full Body A"`, `scrollto text "Choose an exercise"`. The first day sits behind the bottom bar's hint until scrolled. The draft has empty slots, so Start is disabled.
- **Autofill and start.** Steps: `tap #builder.menu`, `tap #menu.autofill`, `absent text "Choose an exercise"`, `tap #builder.start`, `store-expect MesoDay name "Full Body C"`, `store-expect DaySlot muscleRaw abs`.
- **Proof.** Run `ffive-verify store "select ZNAME from ZMESODAY order by ZORDER"`. It returns `Full Body A`, `Full Body B`, `Full Body C`.

## Gotchas

- `value field "Day name"` matches the first day's name field only. Later days are below the fold.
- `replace #builder.name` leaves the keyboard over the first day; `key return` before scrolling to it.
