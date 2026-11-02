# Decision trail: science-based hypertrophy app

Goal: turn a plain set logger into a training app that plans mesocycles and progresses volume and load from feedback, following the approach Renaissance Periodization teaches.

## Done predicate

1. `scripts/check-engine.sh` passes. It covers the RIR schedule, the set-delta table and modifiers, set distribution, load progression, deload, and e1RM.
2. `xcodebuild` for the iOS simulator finishes with zero errors.
3. On the simulator, a store written by the old app opens in the new app with its history intact.
4. On the simulator, a seeded mesocycle shows week 2 targets that follow from week 1 logs and feedback. The volume chart shows sets against landmarks, and Learn opens.

## Decisions

| # | Decision | Alternatives | Why |
| - | -------- | ------------ | --- |
| 1 | Materialize each week's workout lazily when the lifter opens it, built from the same day's previous workout. | Derive targets on the fly from history every render. | Lifters edit sessions (swap an exercise, add a set). A materialized row holds those edits, and the next week builds on what was actually done. The build is keyed by (meso, week, day) and returns the existing row, so it is idempotent. |
| 2 | Each exercise counts toward one primary muscle. | Fractional credit for secondary muscles. | It matches the RP counting convention the landmarks were written against, and it keeps the volume chart readable. |
| 3 | Feedback is per muscle per session. Soreness is asked at the next session for that muscle and written back to the earlier session. | Ask soreness after the workout. | Soreness can't be known when the session ends. Writing it back keeps one feedback record per (session, muscle), which is what the planner reads. |
| 4 | The set change is a lookup table (soreness x workload), nudged by pump and capped by joint pain and weekly MRV. | An if-chain. | One table is easy to read, test, and show to the lifter in Learn. The values are a heuristic, and Learn says so. |
| 5 | Load progression holds weight and adds reps until the rep range top, then adds the smallest increment. | Percentage load jumps each week. | Reps are the most sensitive signal at a fixed load. Small load jumps keep the RIR target honest. |
| 6 | All new SwiftData fields are optional or defaulted, and all new entities are additive. | A versioned schema with a custom migration plan. | Automatic lightweight migration covers additive changes. Verified against a store written by the old build (predicate 3). |
| 7 | Domain and Progression are Foundation-only. | Put the logic on the SwiftData models. | `swiftc` can compile and run the engine checks on macOS with no simulator, so the check is a one-line script. |

## Run log

- Baseline committed (`678fa67`). Type sketch committed (`0af4269`), and it builds.
- Legacy store seeded on the iPhone 18 Pro simulator by the old build. It has a finished workout (Bench Press, Lateral Raise, custom exercise, 9 sets) and an in-progress workout.
- Catalog (`00f0ea0`). 109 exercises and 4 templates. Its check script asserts that every legacy exercise name resolves, so old history gets muscles.
- Engine, models, planner, and UI (`63796c0` to `9edd4a4`). The owner deviated from the sketch in four places:
  - Loads round down to the increment, so a prescription never exceeds what the math supports.
  - MRV room counts days already built this week, so two days can't spend the same room.
  - Answering soreness re-plans that muscle in the current session. Otherwise a muscle trained once a week would never grow.
  - Meso sessions keep undone sets, so next week repeats them instead of dropping the exercise.
- Learn (`9bf84ff`). Before install, its copies of the RIR and set-change rules were replaced with calls to `Progression`, leaving one source of truth.

## Verification (coordinator, on the real artifacts)

| Predicate | Result |
| --------- | ------ |
| 1. `scripts/check-engine.sh` | VERIFIED. 64/64 checks pass. |
| `scripts/check-planner.sh` (in-memory SwiftData) | VERIFIED. 28/28 checks pass. |
| 2. `xcodebuild` for the simulator | VERIFIED. BUILD SUCCEEDED with no compiler warnings. |
| 3. The old store opens in the new build | VERIFIED. The store gained 4 tables. "Legacy Push Day", its 3 exercises, and the in-progress workout survived. The Train screen shows Resume Quick Workout and All Time 1. |
| 4. Seeded meso screens | VERIFIED by screenshot. Train shows the week grid and RIR badge. The session shows "Target 185 × 7" and the feedback card. Progress shows sets against landmarks. Strength shows the e1RM trend. The builder shows the live RIR countdown. Learn opens an article. |

## Open

- A missed day holds the block in that week. The next workout stays on the first unfinished day, and there is no skip action yet.
- Changing units mid-block does not convert stored loads.
- Timed holds such as Plank log seconds as reps.
