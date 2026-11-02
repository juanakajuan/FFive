# Plan a mesocycle

A lifter with no active block plans one from a program template. They rename it, set 3 to 6 training weeks plus a deload, and start it. The Train tab then shows the block, its week and RIR badge, the Next up card, and the schedule grid. The block persists across launches.

## Sub-features

- `plan-open` opens the builder from the empty Train tab.
- `plan-template` picks one of the four templates (Full Body 3 days, Upper/Lower 4, Upper/Lower + Arms & Delts 5, Push/Pull/Legs 6) and lands on Customize with its days and exercises.
- `plan-customize` renames the block and changes its length with the stepper, which updates the RIR countdown.
- `plan-start` starts the block, closes the builder, and shows the dashboard at Week 1.
- `plan-persist` keeps the block after a relaunch.
- `plan-scratch` builds a block from scratch (`Build from scratch`). Not yet driven.

## How to get to it (user POV)

- Train tab with no active block: choose `Plan a Mesocycle`.
- The builder sheet: choose a template row, or `Build from scratch`.
- There is no other entry point while a block is active. The lifter must end it first (`End Mesocycle`).

## Driving it with ffive-verify

Preconditions:

- On-disk baseline: `ffive-verify reset-data`, or at least no active block. Train shows `button "Plan a Mesocycle"`.
- Journey: `ffive-verify drive .claude/skills/verify-ffive/journeys/plan-mesocycle.steps --name plan-mesocycle`.

- **Open builder.** Tap `Plan a Mesocycle`. Steps: `tap button "Plan a Mesocycle"`, `wait nav "New Mesocycle"`. The template sheet appears.
- **Pick template.** Tap the Upper/Lower 4-day row. Steps: `tap button "~Upper/Lower, 4 Days"`, `wait nav "Customize"`. The name field holds `Upper/Lower, 4 Days`.
- **Customize.** Rename the block and add a week. Steps: `replace field "Mesocycle name" "Verify Block"`, `tap button "~Increment"`, `wait text "5 training weeks"`.
- **Start.** Tap `Start Mesocycle`. Steps: `tap button "Start Mesocycle"`, `wait text "Verify Block"`, `wait text "Week 1 of 6"`, `wait button "~Next up, Week 1 · Day 1"`. The dashboard shows `3 RIR` and a 4 × 6 grid.
- **Persist.** Relaunch. Steps: `launch`, `wait text "Verify Block" timeout=20`.
- **Proof.** Run `ffive-verify store "select ZNAME, ZACCUMULATIONWEEKS, ZFINISHEDDATE from ZMESOCYCLE"`. It returns one row, `Verify Block | 5 | (null)`, and `ffive-verify store` shows `ZMESODAY 4`. Keep shots `02-customized`, `03-dashboard`, and `04-after-relaunch`.

## Gotchas

- `~Upper/Lower, 4 Days` must keep the `, 4 Days`, because `~Upper/Lower` also matches the 5-day template.
- The template row label is the template's name, summary, and day names joined together. Do not match it exactly.
- `-seedDemo -demoRoute builder` jumps straight to Customize for the first template. It is a shortcut for looking, not proof of `plan-open` or `plan-template`.
- Total weeks shown on the dashboard is training weeks + 1 (deload): 5 training weeks give `Week 1 of 6`.
