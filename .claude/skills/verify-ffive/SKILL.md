---
name: verify-ffive
description: Drive the FFive iOS app (SwiftUI, SwiftData) on a throwaway iOS simulator to prove user-facing behavior. It launches the app, runs scripted XCUITest step files against real accessibility labels, captures screenshots and UI trees, and reads the on-disk store and settings. Use it whenever a change to FFive's Train, session, mesocycle builder, skip, quick workout, Progress, or Settings screens has to be shown working in the real app, not just in scripts/check-*.sh.
---

# Verify FFive

FFive is an iPhone app (`com.juanix.FFive`, iOS 17+, one SwiftUI target in `FFive.xcodeproj`). The user touches only the app UI: three tabs (Train, Progress, Learn) plus sheets and full-screen covers. There is no server, CLI, or URL scheme. `scripts/check-engine.sh` and `scripts/check-planner.sh` test the engine without UI. This skill covers the UI.

The harness has two parts:

- `scripts/ffive-verify`: a bash control script. It owns a dedicated simulator, builds, installs, drives, reads the store, and cleans up.
- `harness/FFiveDriver.xcodeproj`: a standalone XCUITest bundle that runs a plain-text step file against the installed app. The app project is not modified.

All commands below run from the repo root. Set this alias first:

```bash
V=.claude/skills/verify-ffive/scripts/ffive-verify
```

## Isolation

- Each checkout (worktree) gets its own simulator, named `FFive Verify <8 hex>` from a hash of the repo path. The script never drives, erases, or deletes any other simulator, including the user's booted `iPhone 18 Pro`.
- Two instances can run side by side when they come from different checkouts. Within one checkout, `drive` takes `.verify/drive.lock` and refuses a second concurrent drive. Do not work around the lock: two drivers on one simulator corrupt each other's steps.
- All state lives in `.verify/` (gitignored): `state.env`, build caches, and `artifacts/`.

## Launch

```bash
$V launch
```

This creates the simulator if needed (latest iOS runtime, iPhone 18 Pro, override with `FFIVE_DEVICE_TYPE`) and boots it. It builds the app and the driver into `.verify/build*`, installs the app, then runs a smoke drive: launch with `-seedDemo` and wait for the Train tab. It is ready when the last line is `READY udid=<UDID> stamp=<git sha>`. A cold first run takes about 3 minutes. Later runs rebuild incrementally in under a minute.

Run `launch` again after every app or driver code change, because `drive` does not rebuild. `launch` is idempotent and reuses the same simulator.

Two data modes, picked per `launch` step inside a drive:

- **Demo, in memory:** `launch -seedDemo`. The `DemoSeed` data loads into an in-memory store: two free-form workouts and the "Full Body, 3 Days" block with week 1 logged, week 2 day 1 in progress, and week 2's last day skipped. Nothing persists between launches. `-demoRoute <train|builder|session|progress|strength>` opens straight into a screen. Use it for read-only journeys.
- **On disk, the real user path:** a bare `launch`. This is the SwiftData store at `<app data container>/Library/Application Support/default.store`. It persists across launches and is what `store` reads. Start it empty with `$V reset-data`, which uninstalls and reinstalls the app and wipes the store and UserDefaults. Use it for any proof of a write.

Teardown: see Cleanup.

## Doctor

```bash
$V doctor
```

This check is read-only. It confirms that the simulator recorded in `.verify/state.env` exists, carries our name, and is booted, that `com.juanix.FFive` is installed, that the driver is built, and that the installed build matches the source. The install is stamped with `HEAD` plus a hash of uncommitted `FFive/` changes. It ends with `HEALTHY` (exit 0) or `UNHEALTHY` (exit 1). It also warns when a drive holds the lock. Run it first whenever anything looks off. A stale-install failure means "run `launch`", not "the feature is broken".

## Drive

```bash
$V drive .claude/skills/verify-ffive/journeys/plan-mesocycle.steps --name plan-mesocycle
$V drive - --name scratch <<'EOF'
launch -seedDemo
tap tab "Learn" timeout=20
tree learn
EOF
```

Each drive runs one XCUITest (`xcodebuild test-without-building`, about 20 to 40 seconds of overhead). It prints one `ok`/`FAIL` line per step, then `PASS <run dir>` or `FAIL <run dir>`, and exits non-zero on failure. On failure the run dir also holds `failure.png` and `failure.tree.txt`, the screen and UI tree at the failing step.

Step language: one step per line, `#` starts a comment line, and arguments with spaces go in double quotes. An element is `<kind> "<label>"`:

- `kind` is one of `button`, `text` (static text), `field` (text field), `search` (search field), `cell`, `tab` (tab bar buttons only), `switch`, `image`, `nav` (navigation bar, matched by title), `alert`, or `any`.
- `"<label>"` matches the accessibility label, identifier, or placeholder exactly. A `~` prefix (`"~Next up, Week 1"`) matches a substring. The first substring match wins, so make it unique.
- Optional `#n` picks the n-th match. For actions, n counts only on-screen (hittable) matches.
- Optional `timeout=<seconds>` changes the default 5 s wait.

| Step | Effect |
| --- | --- |
| `launch [args...]` | Terminates and relaunches the app with those launch arguments (`-seedDemo`, `-demoRoute session`). |
| `terminate` | Terminates the app. |
| `tap <el>`, `longpress <el>` | Acts on the first on-screen match. Long press is 1.2 s, which opens context menus. |
| `type <el> "<text>"` | Taps the field and types. |
| `replace <el> "<text>"` | Taps the trailing edge of the field, deletes its contents, and types. |
| `wait <el>` / `assert <el>` | Fails unless the element exists. |
| `absent <el>` | Fails unless the element disappears within the timeout. |
| `value <el> "<v>"` | Fails unless the on-screen element's value equals `v`. |
| `selected <el>` / `unselected <el>` | Checks the accessibility selected trait. |
| `count <el> "<n>"` | Fails unless exactly n elements match. |
| `scrollto <el>` | Swipes up until the element is on screen (12 swipes at most). |
| `swipe up/down/left/right` | Swipes the app. |
| `shot <name>` | Screenshot to `<run>/<name>.png`. |
| `tree <name>` | Full accessibility tree to `<run>/<name>.tree.txt`. |
| `sleep <s>` | Fixed wait. Use only for exploration and prefer `wait`. |

Find handles by dumping a tree (`tree x`) and grepping it, not by reading SwiftUI source. Stable handles in this app:

- Tab bar: `tab "Train"`, `tab "Progress"`, `tab "Learn"`.
- Navigation titles: `nav "Train"`, `nav "Progress"`, `nav "Learn"`, `nav "Settings"`, `nav "New Mesocycle"`, `nav "Customize"`, `nav "Add Exercise"`. A session's title is the block name (`nav "Full Body, 3 Days"`), or `nav "Workout"` for a quick workout.
- Train toolbar: `button "Settings"`, and `button "Quick Workout"` or `button "Resume Quick Workout"`.
- The Next up card is one button whose label combines its texts, such as `Next up, Week 1 · Day 1, Upper A, Bench Press · …, Start Workout`. Match it with `~Next up, Week 1 · Day 1` or `~In progress, Week 2 · Day 1`.
- Schedule grid cells have no labels of their own. Their identifiers are SF Symbol names: `checkmark.circle.fill` (finished), `play.circle.fill` (next), `circle.lefthalf.filled` (in progress), `forward.circle` (skipped), `circle` (upcoming).
- Set rows: weight and reps fields have no labels, only the placeholder `0`. On-screen order is weight, then reps, per set, so the first set is `field "0" #0` (weight) and `field "0" #1` (reps). The done toggle is `button "circle"` when open and `button "checkmark.circle.fill"` when done.

To watch a drive live, open the simulator panel (iOS Simulator `attach` with the simulator's UDID) or `open -a Simulator`. Do not tap while a drive runs.

## Reading state

- `$V store` lists the store's entity tables with row counts: `ZWORKOUT`, `ZEXERCISE`, `ZSETENTRY`, `ZMESOCYCLE`, `ZMESODAY`, `ZDAYSLOT`, `ZMUSCLEFEEDBACKRECORD`.
- `$V store "<sql>"` runs a read-only query. Columns are the model properties, uppercased with a `Z` prefix: `ZWORKOUT(ZNAME, ZSTARTDATE, ZENDDATE, ZWEEK, ZDAYINDEX, ZMESOCYCLE)`, `ZEXERCISE(ZNAME, ZORDER, ZMUSCLERAW, ZWORKOUT)`, `ZSETENTRY(ZWEIGHT, ZREPS, ZISDONE, ZTARGETWEIGHT, ZTARGETREPS, ZEXERCISE)`, `ZMESOCYCLE(ZNAME, ZACCUMULATIONWEEKS, ZFINISHEDDATE, ZSKIPPEDSESSIONS)`. Dates are Core Data seconds since 2001. `ZSKIPPEDSESSIONS` is a JSON blob: read it with `cast(ZSKIPPEDSESSIONS as text)`.
- `$V defaults` prints the app's UserDefaults plist (`weightUnit`).
- `$V shot <name>` takes a screenshot outside a drive, into the newest run dir.

The store only exists after an on-disk launch has saved something. `-seedDemo` launches never write it, but they do read and write the real UserDefaults.

## Evidence

Every drive writes to `.verify/artifacts/<YYYYmmdd-HHMMSS>-<name>/`:

- `steps.txt`: the exact steps run.
- `steps.log`: one ok/FAIL line per step.
- `*.png` and `*.tree.txt` from `shot` and `tree` steps.
- `xcodebuild.log` and `result.xcresult`.
- `failure.png` and `failure.tree.txt` when a step fails.

Save the output of `store` and `defaults` checks next to the run, for example `$V store "<sql>" | tee <run>/store.txt`.

Proof standards:

- Drive the real user path: taps on the same controls a lifter uses. `-demoRoute` and `-seedDemo` are setup shortcuts. Never present them as proof of the screens they skip. If a feature has several entry points (see its feature file), prove each one or report the ones you skipped.
- Capture the action and the resulting state: a shot before and after, plus a `wait` or `absent` assertion on the new state. A final screenshot alone is not proof.
- Verify side effects alongside the screen. Any write must be confirmed with `store` (rows, weights, reps, dates) or `defaults`, and persistence with a second `launch` in the same drive. A journey once passed every screen assertion while the store held 250 lb instead of the 25 it typed.
- No mocks: there is no network or external system. The in-memory demo store is the app's own seeding path, not a mock, but it proves nothing about persistence.

## Cleanup

```bash
$V cleanup            # shut down and delete this checkout's simulator, remove state.env and locks
$V cleanup --purge    # also delete .verify/build and .verify/build-driver
```

Cleanup deletes only the simulator whose UDID is recorded in `state.env`, and only if its name is still our `FFive Verify …` name. It never kills processes by name. Evidence in `.verify/artifacts/` always survives. Delete old run dirs by hand when you no longer need them. After cleanup, the next `launch` creates a fresh simulator.

## Feature map

`features/README.md` indexes the user-facing features with a recipe each. `journeys/*.steps` are the runnable step files those recipes use. Read the feature file before driving a feature, and update both when the UI changes.

## Gotchas

- `drive` runs the build `launch` last installed. After editing Swift, run `launch` first, or `doctor` will report a stale install.
- SwiftUI lists are lazy, so rows below the fold are absent from the tree, not just hidden. `scrollto` them before `wait`/`tap`.
- Screens under a sheet or full-screen cover stay in the tree. `wait` can match them, `tap` cannot. Assert on the presented screen's `nav` title first.
- Feedback and soreness chips expose selection only through color, with no selected trait. Prove an answer by its effect: the feedback header's `image "checkmark.circle.fill"` once all three are answered, or the soreness card going `absent`.
- `"~substring"` takes the first match in tree order: `~Lateral Raise` hits "Behind-the-Back Cable Lateral Raise". Picker rows are labeled `<name>, <equipment>`, as in `button "Lateral Raise, Dumbbell"`.
- The decimal pad has no return key. Tap `button "Done"` (keyboard toolbar) before tapping elements the keyboard covers.
- `Finish` is disabled until at least one set is done.
