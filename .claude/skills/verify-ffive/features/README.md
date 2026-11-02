# FFive verification map

This directory is the maintained source for verifying FFive's user-facing behavior. Read this index before driving the app, then use the matching feature file as the recipe. Each recipe has a runnable step file in `../journeys/`.

## Baseline preconditions

- `ffive-verify` means `.claude/skills/verify-ffive/scripts/ffive-verify`, run from the repo root.
- `ffive-verify launch` printed `READY`, and `ffive-verify doctor` prints `HEALTHY` with an install stamp that matches the source.
- **Demo baseline** (read-only journeys): every drive starts with `launch -seedDemo`. The block "Full Body, 3 Days" is at Week 2 of 5. Week 1 is finished, Week 2 · Day 1 is in progress with Squat logged, and Week 2 · Day 3 is skipped. "Morning Workout" and "Evening Workout" are free-form history.
- **On-disk baseline** (write journeys): `ffive-verify reset-data`, then a bare `launch`. The Train tab shows `Plan a Mesocycle` and `Quick Workout`.
- The on-disk journeys form one chain on a single store: `reset-data` → quick-workout → plan-mesocycle → train-session → skip-day → unskip-day. Each one's `Before:` header names the state it needs.
- Never drive a simulator that `ffive-verify launch` did not create in this checkout.

## Driving conventions

- Prefer navigation titles, button labels, and placeholders over indexes. Use `#n` only where the app gives no label (set fields, grid cells), and say so in the recipe.
- Treat every step as literal. Labels include their punctuation: `·`, `×`, curly quotes.
- Wait for the new screen's `nav` title or a state-specific label after every navigation, not a fixed `sleep`.
- Put durable writes on the on-disk path. `-seedDemo` is in-memory and resets on every `launch`, but it shares the real UserDefaults, so restore `weightUnit` to `lb`.

## Proof and skip reporting

- Capture the user action and the resulting state: `shot` before and after, plus an assertion on the new state.
- Writes need a second, read-only view: `ffive-verify store "<sql>"` or `ffive-verify defaults`, saved next to the run with `tee`, plus a relaunch for persistence.
- Record the feature ID and entry point with every artifact (`--name <feature-id>`).
- Report an unreachable path with the failing step from `steps.log` and the unmet precondition. Do not report a skipped entry point as verified through another one.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then has exactly four H2 sections in this order.

1. `Sub-features` lists short IDs, one line per behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with ffive-verify` starts with `Preconditions:`. Its labeled bullets pair each user action with the exact steps and the observable result.
4. `Gotchas` lists traps that can waste or invalidate a run.

## Features

- [Plan a mesocycle](./plan-mesocycle.md): pick a template, customize name and length, and start the block (on disk).
- [Train a planned session](./train-session.md): open the next session, log sets against targets, give feedback and soreness, and finish (on disk and demo).
- [Skip a day](./skip-day.md): skip from the Next up card or the schedule grid, then train it after all (on disk).
- [Quick workout](./quick-workout.md): a free-form session with exercises from the picker (on disk).
- [Progress](./progress.md): volume against landmarks, the strength trend, and history (demo).
- [Settings](./settings.md): weight unit and app version (demo plus UserDefaults).

Not mapped yet: Learn (article list and article pages), ending a mesocycle, swapping or removing exercises, and discarding a workout.
