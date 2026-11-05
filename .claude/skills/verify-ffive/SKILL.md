---
name: verify-ffive
description: Drive the FFive iOS app (SwiftUI, SwiftData) on a throwaway iOS simulator to prove user-facing behavior. It launches the app, runs scripted XCUITest step files against the app's accessibility identifiers and labels, captures screenshots and UI trees, and reads the on-disk store and settings. Use it whenever a change to FFive's Workout tab (session, skip, quick workout), Mesos, Templates, Exercises, mesocycle builder, Progress, or Settings screens has to be shown working in the real app, not just in scripts/check-*.sh.
---

# Verify FFive

FFive is an iPhone app (`com.juanix.FFive`, iOS 17+, one SwiftUI target in `FFive.xcodeproj`). The user touches only the app UI: five tabs (Workout, Mesos, Templates, Exercises, More, with Progress, Learn, and Settings pushed from More) plus sheets. There is no server, CLI, or URL scheme. `swift test --package-path FFiveCore` tests the engine and planner without UI. This skill covers the UI.

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

This creates the simulator if needed (latest iOS runtime, iPhone 18 Pro, override with `FFIVE_DEVICE_TYPE`) and boots it. It builds the app and the driver into `.verify/build*`, installs the app, then runs a smoke drive: launch with `-seedDemo` and wait for the Workout tab and its `Workout menu`. It is ready when the last line is `READY udid=<UDID> stamp=<git sha>`. A cold first run takes about 3 minutes. With build caches in place, a launch that has to boot a shut-down simulator took about 100 seconds; one on a booted simulator rebuilds incrementally in under a minute.

Run `launch` again after every app or driver code change, because `drive` does not rebuild. `launch` is idempotent and reuses the same simulator.

Two data modes, picked per `launch` step inside a drive:

- **Demo, in memory:** `launch -seedDemo`. The `DemoSeed` data loads into an in-memory store: two free-form workouts and the "Full Body, 3 Days" block with week 1 logged, week 2 day 1 in progress, and week 2's last day skipped. Nothing persists between launches. `-demoRoute <train|builder|session|progress|strength>` opens straight into a screen. Use it for read-only journeys.
- **On disk, the real user path:** a bare `launch`. This is the SwiftData store at `<app data container>/Library/Application Support/default.store`. It persists across launches and is what `store` reads. Start it empty with `$V reset-data`, which uninstalls and reinstalls the app and wipes the store and UserDefaults. Use it for any proof of a write.

Teardown: see Cleanup. Simulators of removed worktrees are swept automatically.

## Doctor

```bash
$V doctor
```

This check is read-only. It confirms that the simulator recorded in `.verify/state.env` exists, carries our name, and is booted, that `com.juanix.FFive` is installed, that the driver is built, and that the installed build matches the source. The install is stamped with `HEAD` plus a hash of uncommitted `FFive/` and `FFiveCore/` changes. It ends with `HEALTHY` (exit 0) or `UNHEALTHY` (exit 1). It also warns when a drive holds the lock. Run it first whenever anything looks off. A stale-install failure means "run `launch`", not "the feature is broken".

## Drive

```bash
$V drive .claude/skills/verify-ffive/journeys/plan-mesocycle.steps --name plan-mesocycle
$V drive - --name scratch --timeout 120 <<'EOF'
launch -seedDemo
tap #tab.more timeout=20
tap #more.learn
tree learn
EOF
```

Each drive runs one XCUITest (`xcodebuild test-without-building`). It prints one `ok`/`FAIL` line per step, then `PASS <run dir> (<n>s)` or `FAIL <run dir> (<n>s)` with the drive's wall time, and exits non-zero on failure. On failure the run dir also holds `failure.png` and `failure.tree.txt`, the screen and UI tree at the failing step.

`--timeout <seconds>` caps a drive's wall time at 600 s by default. Ten seconds before the cap, the driver's watchdog appends `TIMEOUT during step <k>: <line>` to `steps.log`. A step that is polling (`wait`, `absent`, `exists`, `store-expect`, `defaults-expect`, and every action waiting for its target) fails right there, and the run writes `failure.png` and `failure.tree.txt` as for any failed step. A step stuck inside XCUITest, for example on its idle wait, runs on: the watchdog writes the tree and screenshot itself, and at the cap `drive` kills `xcodebuild` and the driver. Either way `drive` prints `FAIL` with `timed out` and exits with status 124. If the driver died before it wrote a tree, `failure.tree.txt` says so and `failure.png` comes from `simctl`.

`drive` adds `-disableAnimations` to every `launch` step, so the app skips its animations and each tap lands on a settled screen. To drive with animations, write `launch -animations`, quoted or not. `drive` drops that token before the app sees it.

Before it touches the simulator, `drive` checks the target of every step against `A11y.swift`, wherever options such as `timeout=` put it. It stops at the first unknown id and names the closest known one:

```
ffive-verify: step 7: unknown identifier set.wieght.1; closest set.weight.N
```

Step language: one step per line, `#` starts a comment line, and arguments with spaces go in double quotes. A target is `#<id>` or `<kind> "<label>"`.

Address every control by `#<id>`. The ids come from the `A11y` enum in `FFiveCore/Sources/FFiveCore/A11y.swift`, in three kinds:

- Plain ids are the raw value, as in `#workout.menu`.
- Indexed ids add a 1-based index to a family, as in `#set.weight.3` (set 3's weight field) or `#exercise.menu.2` (the second card's menu). The enum's `indexed` set lists these families.
- Keyed ids add the slug of a name to a family, as in `#picker.row.lateral-raise`. The slug is the name in lowercase, with every run of characters outside a-z and 0-9 turned into one hyphen and no hyphen at either end. `Upper/Lower, 4 Days` becomes `upper-lower-4-days`. The enum's `keyed` set lists these families.

An id matches every element with that accessibility identifier, and an action takes the first one on screen. An id takes no `#n` index, and `drive` rejects a step that adds one, as in `step 4: #1 after #set.weight.1: an #id target takes nothing after it, not even a #n index`.

Use `<kind> "<label>"` for text assertions and for the few controls without an id:

- `kind` is one of `button`, `text` (static text), `field` (text field), `search` (search field), `cell`, `tab` (tab bar buttons only), `switch`, `image`, `nav` (navigation bar, matched by title), `alert`, or `any`.
- `"<label>"` matches the accessibility label, identifier, or placeholder exactly. A `~` prefix (`"~Verify Block"`) matches a substring. A label with `*` is a wildcard pattern over the whole text, where `*` matches any run of characters and `?` any one character (`"Target 185 * 7"`). The first match wins, so make it unique.
- Keep separator characters out of text assertions. They are `·`, `•`, `×`, a spaced `-`, and `/`. Put a `*` where the separator sits, as in `wait text "Sets per muscle*Week 2"`. Splitting it into two `~` steps loses the fact that both halves sit in one text.
- Optional `#n` picks a label match by 0-based index. `#0` is the first, `#1` the second. For actions, n counts only on-screen (hittable) matches.

Optional `timeout=<seconds>` changes the default 5 s wait for either target form.

| Step | Effect |
| --- | --- |
| `launch [args...]` | Terminates and relaunches the app with those launch arguments (`-seedDemo`, `-demoRoute session`). `drive` adds `-disableAnimations`. |
| `terminate` | Terminates the app. |
| `tap <target>`, `longpress <target>` | Acts on the first on-screen match. Long press is 1.2 s, which opens context menus. |
| `drag <target> to <target>` | Presses the first target for 0.8 s, then drags it onto the second. Use it on a list row's reorder handle in edit mode. |
| `type <target> "<text>"` | Taps the field and types. |
| `replace <target> "<text>"` | Focuses the field with a tap as near its trailing edge as takes focus, deletes its contents, and types. |
| `wait <target>` / `assert <target>` | Fails unless the element exists and is hittable within the timeout. An element off screen or under a sheet fails with `not on screen within <t>s`. |
| `exists <target>` | Fails unless the element exists, on screen or not. Use it only when the element is meant to be off screen or covered. |
| `absent <target>` | Fails unless the element disappears within the timeout. |
| `value <target> "<v>"` | Fails unless the on-screen element's value equals `v`. |
| `selected <target>` / `unselected <target>` | Waits for the element on screen, then checks the accessibility selected trait. |
| `count <target> "<n>"` | Fails unless exactly n elements match. |
| `scrollto <target>` | Swipes up until the element is on screen (12 swipes at most). |
| `store-expect <Model> <field> <value> [timeout=<s>]` | Polls the on-disk store until some `<Model>` row has `<field>` equal to `<value>`. |
| `defaults-expect <key> <value> [timeout=<s>]` | Polls the app's UserDefaults plist until `<key>` reads `<value>`, for 30 s by default. |
| `swipe up/down/left/right` | Swipes the app. |
| `shot <name>` | Screenshot to `<run>/<name>.png`. |
| `tree <name>` | Full accessibility tree to `<run>/<name>.tree.txt`. |
| `sleep <s>` | Fixed wait. Use only for exploration and prefer `wait`. |

`store-expect` reads the same store as `$V store`, read-only. The table is `Z` plus the model name in uppercase, and the column is `Z` plus the field name in uppercase. The value takes three forms:

- A value compares the way the column stores it. In a number column `store-expect SetEntry weight 25` passes on `25.0` and fails on `250.0`. In a text column `store-expect Mesocycle name 2024` compares the string `2024`. A Bool field holds `1` or `0`. Quote a value with spaces, as in `store-expect Mesocycle name "Verify Block"`.
- `null` passes when some row has no value in the field.
- `not-null` passes when some row has a value, as in `store-expect Workout endDate not-null`.

The step passes when any row matches, not a particular one. A row left by an earlier drive satisfies it, so a journey that asserts a fresh write starts from `$V reset-data`.

A failure names what the column holds, as in `no SetEntry row has weight = 25; values: 250.0`. A missing table or column fails at once with the list of the ones that exist. While the app holds the store locked, the step keeps polling, and at the timeout it fails naming the lock, as in `store is locked (SQLITE_BUSY: database is locked)`. `-seedDemo` keeps its store in memory, so `store-expect` while the last `launch` had `-seedDemo` fails at once with `the demo store is in memory`. `defaults-expect` reads the plist `$V defaults` prints, and a failure names the stored value, as in `weightUnit is "lb", expected "kg"`. The system writes that plist a few seconds after the app changes a value, and later still when values change in quick succession, so the step waits up to 30 s instead of 5.

Find ids in `A11y.swift`, and dump a tree (`tree x`) to see what is on screen. Ids and labels in this app:

- Tab bar: `#tab.workout`, `#tab.mesos`, `#tab.templates`, `#tab.exercises`, `#tab.more`. It is a custom bar of plain buttons, so the `tab` kind matches nothing. The selected tab carries Selected. Only the selected tab is rendered, and a tab resets each time it is opened. More's rows are `#more.progress`, `#more.learn`, and `#more.settings`.
- Tab roots draw their title in the page, not in a navigation bar: `text "Mesocycles"`, `text "Templates"`, `text "Exercises"`, `text "More"`. Pushed screens keep navigation titles: `nav "Progress"`, `nav "Learn"`, `nav "Settings"`, `nav "New Mesocycle"`, `nav "Customize"`, `nav "Add Exercise"`, a workout's name on its detail page. A back button is labeled with the previous screen's title, as in `button "Progress"`.
- Workout tab header: `text "WEEK 2 DAY 1"` (or `DELOAD DAY n`, `QUICK WORKOUT`) and a subtitle such as `Full Body A · Full Body, 3 Days`, matched with `text "~Full Body A"`. `#workout.schedule` opens a sheet with the grid and the week's volume, and `#sheet.done` closes it. `#workout.menu` holds `#menu.add-exercise`, `#menu.skip-day`, `#menu.quick-workout` (Quick Workout or Resume Quick Workout), `#menu.workout-note`, `#menu.bodyweight` (Set Bodyweight, or Bodyweight with the value once set; its alert's field has no id, so address it as `field "Bodyweight (lb)"`), `#menu.rename`, `#menu.discard`, and `#menu.end-mesocycle`. Skip Day shows only while the day has no logged set, Rename only on a quick workout, and Quick Workout only on a block day. Menu items don't appear in `tree` dumps, but a tap on their id works once the menu is open.
- Confirmation dialogs: `#dialog.end-mesocycle`, `#dialog.discard`, and `#dialog.train-day`.
- Empty Workout tab (no active block): `#workout.plan`, `#workout.quick`, and the stats row (`This Week`, `Time`, `All Time`). The "Block complete" card has `#workout.end` and `#workout.quick`.
- Exercise cards, indexed by position from 1: `#exercise.cue.<n>`, `#exercise.history.<n>`, `#exercise.pin.<n>`, and `#exercise.menu.<n>`, which holds `#menu.swap`, `#menu.add-set`, `#menu.skip-remaining` (only while a set is pending), `#menu.exercise-note`, `#menu.delete-note`, and `#menu.remove-exercise`. The pin button reads `Pin note` or `Unpin note`, so assert the pin state by that label. The target strip is text, as in `text "Target 185 * 7"` or `text "~Calibrate"`. The header stays pinned at the top while the cards scroll. `#workout.finish` is pinned above the tab bar and exists only once every exercise has at least one set and all its sets are logged or skipped, so `absent` proves the gate and no `scrollto` is needed.
- Set rows, indexed by set number within their card: `#set.weight.<n>`, `#set.reps.<n>`, `#set.menu.<n>` (holds `#menu.add-set`, `#menu.skip-set`, the Set Type picker, and `#menu.delete-set`; `#menu.skip-set` reads Skip Set on a pending set and Unskip Set on a skipped one, and is absent on a logged one; tap a type by its label, as in `button "Myorep match"`), and the checkbox `#set.log.<n>`, which carries Selected once logged and the value `Skipped` once skipped. Every card has a set 1, so `#set.weight.1` matches one field per card. An action takes the first one on screen, which is the first card's only while that card is on screen. Once the list scrolls it past, the same step hits the topmost visible card's field. Placeholders are the unit and `<n> RIR`, or `reps` with no RIR in a deload or quick workout. They show only on empty fields, but `field "kg"` still matches every weight field in kilograms. The keyboard toolbar's Done is `#keyboard.done`.
- Note editor sheet: `#note.text`, `#note.save`, `#note.cancel`.
- Exercise picker: `#picker.search`, `#picker.row.<slug>`, `#picker.cancel`. Exercises tab: `#exercises.search`, `#exercises.row.<slug>`.
- Builder: `#builder.template.<slug>`, `#builder.blank`, `#builder.name`, `#builder.start`, `#builder.cancel`. The length stepper has no id. Its buttons are labeled `Increment` and `Decrement`.
- Mesos tab: `#mesos.row.<slug>` opens the detail, and `#mesos.menu.<slug>` holds `#menu.view` and `#menu.end-mesocycle`. The header's `#mesos.new` (also on Templates) is disabled while a block is active. `#mesos.plan` is the empty state's button.
- Schedule grid cells have no ids. Their identifiers are SF Symbol names: `checkmark.circle.fill` (finished), `circle.lefthalf.filled` (built, open), `play.circle.fill` (next, not built yet, rare because the tab builds the day it shows), `forward.circle` (skipped), `circle` (upcoming). Finished cells are always buttons that open the read-only workout. Skipped, open, and upcoming cells are buttons only in the current week of an unfinished block. A cell's long-press `Skip Day` is `#menu.skip-day`.
- Segmented controls: `#segment.<slug>`, as in `#segment.volume`, `#segment.history`, `#segment.w1`, `#segment.dl`. Feedback and soreness chips: `#chip.<slug>`, as in `#chip.pretty-good` and `#chip.healed-just-in-time`. Chips carry Selected when chosen.
- Progress rows: `#strength.row.<slug>` and `#history.row.<slug>`. A quick workout's name depends on the clock, so its history row is tapped by label, `button "~Workout,"`.
- Settings: `#settings.unit.lb` and `#settings.unit.kg`.

Gotchas:

- `~Workout` matches the Workout tab button before any history row. Use `~Workout,` or the full workout name.
- `scrollto` swipes a long way and stops as soon as its target is on screen, which can leave it under the tab bar. Scroll to the element just below a row, then tap the row.

To watch a drive live, open the simulator panel (iOS Simulator `attach` with the simulator's UDID) or `open -a Simulator`. Do not tap while a drive runs.

## Reading state

- `$V store` lists the store's entity tables with row counts: `ZWORKOUT`, `ZEXERCISE`, `ZSETENTRY`, `ZMESOCYCLE`, `ZMESODAY`, `ZDAYSLOT`, `ZMUSCLEFEEDBACKRECORD`, `ZPINNEDNOTE`.
- `$V store "<sql>"` runs a read-only query. Columns are the model properties, uppercased with a `Z` prefix: `ZWORKOUT(ZNAME, ZSTARTDATE, ZENDDATE, ZWEEK, ZDAYINDEX, ZMESOCYCLE, ZNOTE)`, `ZPINNEDNOTE(ZNAME, ZTEXT)`, `ZEXERCISE(ZNAME, ZORDER, ZMUSCLERAW, ZWORKOUT, ZNOTE)`, `ZSETENTRY(ZWEIGHT, ZREPS, ZISDONE, ZISSKIPPED, ZTARGETWEIGHT, ZTARGETREPS, ZEXERCISE)`, `ZMESOCYCLE(ZNAME, ZACCUMULATIONWEEKS, ZFINISHEDDATE, ZSKIPPEDSESSIONS)`. Dates are Core Data seconds since 2001. `ZSKIPPEDSESSIONS` is a JSON blob: read it with `cast(ZSKIPPEDSESSIONS as text)`.
- `$V defaults` prints the app's UserDefaults plist (`weightUnit`).
- `$V shot <name>` takes a screenshot outside a drive, into the newest run dir.

The store only exists after an on-disk launch has saved something. `-seedDemo` launches never write it, but they do read and write the real UserDefaults.

## Evidence

Every drive writes to `.verify/artifacts/<YYYYmmdd-HHMMSS>-<name>/`:

- `steps.txt`: the exact steps run, with `-disableAnimations` added to each `launch`.
- `steps.log`: one ok/FAIL line per step.
- `*.png` and `*.tree.txt` from `shot` and `tree` steps.
- `xcodebuild.log` and `result.xcresult`.
- `failure.png` and `failure.tree.txt` when a step fails or the drive times out.

Save the output of `store` and `defaults` checks next to the run, for example `$V store "<sql>" | tee <run>/store.txt`.

Proof standards:

- Drive the real user path: taps on the same controls a lifter uses. `-demoRoute` and `-seedDemo` are setup shortcuts. Never present them as proof of the screens they skip. If a feature has several entry points (see its feature file), prove each one or report the ones you skipped.
- Capture the action and the resulting state: a shot before and after, plus a `wait` or `absent` assertion on the new state. A final screenshot alone is not proof.
- Verify side effects alongside the screen. Confirm every write with `store-expect` or `defaults-expect` in the journey, or with `store` (rows, weights, reps, dates) or `defaults` after it. Confirm persistence with a second `launch` in the same drive. A journey once passed every screen assertion while the store held 250 lb instead of the 25 it typed.
- No mocks: there is no network or external system. The in-memory demo store is the app's own seeding path, not a mock, but it proves nothing about persistence.

## Cleanup

```bash
$V cleanup            # shut down and delete this checkout's simulator, remove state.env and locks
$V cleanup --purge    # also delete .verify/build and .verify/build-driver
```

Cleanup deletes only the simulator whose UDID is recorded in `state.env`, and only if its name is still our `FFive Verify …` name. It never kills processes by name. Evidence in `.verify/artifacts/` always survives. Delete old run dirs by hand when you no longer need them. After cleanup, the next `launch` creates a fresh simulator.

```bash
$V sweep              # delete simulators whose worktree no longer exists
$V sweep --dry-run    # print what sweep would delete or adopt
```

`launch` records which checkout owns each simulator in `.git/ffive-verify/<udid>`, the git directory every worktree shares. `sweep` deletes a simulator only when its recorded checkout is no longer on disk and its name still matches the record. A simulator whose worktree still exists is never touched, even if its branch is merged. A simulator that predates the registry is adopted when a live checkout hashes to its name, and skipped otherwise. The project's `SessionStart` and `SessionEnd` hooks in `.claude/settings.json` run `sweep` automatically, so a removed worktree's simulator goes away at the next session start. Run `cleanup` yourself when you finish with a simulator in a worktree you are keeping.

## Feature map

`features/README.md` indexes the user-facing features with a recipe each. `journeys/*.steps` are the runnable step files those recipes use. Read the feature file before driving a feature, and update both when the UI changes.

## Gotchas

- `drive` runs the build `launch` last installed. After editing Swift, run `launch` first, or `doctor` will report a stale install.
- SwiftUI lists are lazy, so rows below the fold are absent from the tree, not just hidden. `scrollto` them before `wait`/`tap`.
- Screens under a sheet or full-screen cover stay in the tree. `exists` can match them, but `wait` and `tap` cannot. Assert on the presented screen's `nav` title first.
- A control's own label is not hittable: the text inside a `Stepper` or `Button` hit-tests to the control. `wait` the control by its full label, as in `wait any "5 training weeks, then 1 deload week"`, not `wait text "5 training weeks"`.
- Feedback and soreness chips carry the Selected trait. The feedback header's `image "checkmark.circle.fill"` appears once all three questions are answered, but the `scrollto` that reaches the last question pushes the header above the screen, so check it with `exists`, not `wait`. A soreness answer shows as its card going `absent`.
- A `~substring` label takes the first match in tree order. `~Lateral Raise` hits "Behind-the-Back Cable Lateral Raise", so tap picker rows by id, as in `#picker.row.lateral-raise`.
- The decimal pad has no return key. Tap `#keyboard.done` before tapping elements the keyboard covers.
- `#workout.finish` is absent until every set of every exercise is logged or skipped. To finish early, skip the rest (`#exercise.menu.<n>`, `#menu.skip-remaining`), delete the unlogged sets (`#set.menu.<n>`, `#menu.delete-set`), or remove exercises (`#exercise.menu.<n>`, `#menu.remove-exercise`), as a lifter would.
