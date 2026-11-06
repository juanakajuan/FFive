# Coaching tips

An exercise card shows one short tip when it applies. Before any set is logged, a block exercise whose next set calibrates (no target weight) says how to pick a starting load. After a set is logged and another waits, the card says how long to rest. Each tip links to its Learn article in a sheet and has a close button. A closed tip stays closed on every card and across launches, stored in UserDefaults under `dismissedTips`.

## Sub-features

- `tip-starting-load`: the starting-load tip on a calibration set, linking to Reps in reserve.
- `tip-rest`: the rest tip after a log, linking to Rest between sets.
- `tip-dismiss`: closing a tip hides it everywhere and it stays hidden after a relaunch.

## How to get to it (user POV)

- Workout tab, week 1 of a new block: the first card shows the starting-load tip.
- Workout tab, any session: log one set of an exercise with more sets left.

## Driving it with ffive-verify

Preconditions: `ffive-verify reset-data`, then the journey plans its own block. Journey: `journeys/coaching-tips.steps`.

- **Starting load:** `wait text "~Pick a weight you expect"`, then `tap #tip.learn-more.1` and `wait nav "Reps in reserve"`. `#sheet.done` closes it.
- **Rest:** fill `#set.weight.1` and `#set.reps.1`, `tap #set.log.1`, then `wait text "~Rest until you could match"`. `#tip.learn-more.1` opens `nav "Rest between sets"`.
- **Dismiss:** `tap #tip.dismiss.1`, then `absent` the tip text. Relaunch and `absent` it again. `ffive-verify defaults` lists the closed tips under `dismissedTips`.

## Gotchas

- `dismissedTips` lives in UserDefaults, which `-seedDemo` shares. A demo drive that closes a tip keeps it closed until `reset-data`.
- The ids are indexed by card position, so `#tip.dismiss.1` is the first card's tip only.
- A quick workout never shows the starting-load tip, because it has no block RIR to calibrate to.
