# Plan a mesocycle

A lifter with no active block plans one from a program template. They rename it, set 3 to 6 training weeks plus a deload, and start it. The Workout tab then shows Week 1 · Day 1 inline, headed `WEEK 1 DAY 1` with the subtitle `<day> • <block> • 3 RIR`. The Mesos tab lists the block with a `Current` badge. The block persists across launches.

## Sub-features

- `plan-open` opens the builder from the empty Workout tab.
- `plan-template` picks one of the four templates (Full Body 3 days, Upper/Lower 4, Upper/Lower + Arms & Delts 5, Push/Pull/Legs 6) and lands on Customize with its days and exercises.
- `plan-customize` renames the block and changes its length with the stepper, which updates the RIR countdown.
- `plan-start` starts the block, closes the builder, and shows Week 1 · Day 1 on the Workout tab.
- `plan-mesos` lists the block on the Mesos tab as `<total> WEEKS - <days> DAYS/WEEK` with a `Current` badge.
- `plan-persist` keeps the block after a relaunch.
- `plan-scratch` builds a block from scratch (`Build from scratch`). Not yet driven.

## How to get to it (user POV)

- Workout tab with no active block: choose `Plan a Mesocycle`.
- Mesos tab: `Plan a Mesocycle` in the empty state (only when no block has ever existed), or the `New Mesocycle` "+" in the header.
- Templates tab: tap a template row to open the builder straight on Customize, or the `New Mesocycle` "+" for a blank one.
- The builder sheet: choose a template row, or `Build from scratch`.
- While a block is active, both "+" buttons are disabled, and a builder opened from a Templates row shows "End <name> before starting a new mesocycle." with `Start Mesocycle` disabled. The lifter must end the block first (`End Mesocycle` in the `Workout menu`, the Mesos row's `<name> menu`, or the block's detail page).

## Driving it with ffive-verify

Preconditions:

- On-disk baseline: `ffive-verify reset-data`, or at least no active block and no open quick workout (an open one replaces the empty state). Workout shows `button "Plan a Mesocycle"`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/plan-mesocycle.steps --name plan-mesocycle`.

- **Open builder.** Tap `Plan a Mesocycle`. Steps: `wait button "Plan a Mesocycle" timeout=20`, `tap button "Plan a Mesocycle"`, `wait nav "New Mesocycle"`. The template sheet appears.
- **Pick template.** Tap the Upper/Lower 4-day row. Steps: `tap button "~Upper/Lower, 4 Days"`, `wait nav "Customize"`. The name field holds `Upper/Lower, 4 Days`.
- **Customize.** Rename the block and add a week. Steps: `replace field "Mesocycle name" "Verify Block"`, `tap button "~Increment"`, `wait text "5 training weeks"`.
- **Start.** Tap `Start Mesocycle`. Steps: `tap button "Start Mesocycle"`, `wait text "WEEK 1 DAY 1" timeout=10`, `wait text "~Upper A • Verify Block"`. The subtitle ends in `• 3 RIR` (Week 1 is `min(3, training weeks - 1)` RIR, so a 3-week block starts at `2 RIR`).
- **Mesos.** Steps: `tap button "Mesos"`, `wait text "Verify Block"`, `wait text "~6 WEEKS - 4 DAYS/WEEK"`.
- **Persist.** Relaunch, which opens on the Workout tab. Steps: `launch`, `wait text "WEEK 1 DAY 1" timeout=20`, `wait text "~Verify Block"`.
- **Proof.** Run `ffive-verify store "select ZNAME, ZACCUMULATIONWEEKS, ZFINISHEDDATE from ZMESOCYCLE"`. It returns one row, `Verify Block | 5 | (null)`, and `ffive-verify store` shows `ZMESODAY 4`. Keep shots `02-customized`, `03-session`, `04-mesos`, and `05-after-relaunch`.

## Gotchas

- `~Upper/Lower, 4 Days` must keep the `, 4 Days`, because `~Upper/Lower` also matches the 5-day template.
- The template row label joins the split caption, the template's name, and its `<n>/week` pill. Do not match it exactly.
- `-seedDemo -demoRoute builder` jumps straight to Customize for the first template. It is a shortcut for looking, not proof of `plan-open` or `plan-template`. The demo block is active, so `Start Mesocycle` is disabled there.
- Total weeks is training weeks + 1 (deload): 5 training weeks show as `6 WEEKS` on the Mesos tab and `Week 1 of 6` on the block's detail page.
- The Workout tab builds Week 1 · Day 1 as soon as it shows it, so `ZWORKOUT` already holds an open row for that day before any set is logged.
