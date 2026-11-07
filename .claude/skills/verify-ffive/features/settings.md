# Settings

Settings, pushed from the More tab, holds the weight unit (Pounds or Kilograms), the equipment the lifter has, the Auto-Match Weights toggle, and the app version. The unit applies to new prescriptions and to how loads are labeled. Already-logged loads are not converted.

## Sub-features

- `settings-open` opens Settings from More and shows `Version, <short> (<build>)`.
- `settings-unit` switches between `Pounds (lb)` and `Kilograms (kg)`, stored as the `weightUnit` UserDefault. The chosen row carries the Selected trait.
- `settings-unit-effect` labels loads in the chosen unit (the weight fields' placeholder, the History sheet, Progress, and workout details), with new targets in that unit's increments. Logged numbers are relabeled, not converted.
- `settings-equipment` is one row per equipment type, `#settings.equipment.<raw value>` (`barbell`, `dumbbell`, `cable`, `machine`, `smith`, `assistedmachine`, `bodyweightloadable`, `bodyweightonly`, as slugs), stored as the `equipment` UserDefault, an array of raw values (`defaults-expect` can't match an array; read it with `ffive-verify defaults`). Selected rows carry the Selected trait, and the last selected row can't be cleared. With any type off, the Exercises tab and the picker show `#equipment-filter`, a button reading `Show All` (or `My Equipment` once tapped), and hide catalog exercises for the missing types. Custom exercises always show. Journey: `journeys/equipment-filter.steps`, on-disk after `reset-data`. It ends with barbell off.
- `settings-auto-match` is the `#settings.auto-match` switch, stored as the `autoMatchWeights` UserDefault (`1` or `0` in `defaults-expect`; absent means on). While on, a weight edit carries to every later set of that exercise that is not logged and had the same weight when the field took focus. Journey: `journeys/auto-match-weights.steps`, on-disk after `reset-data`. It ends with the toggle back on. The switch sits below the Equipment section, so `scrollto` it before a tap.

- `settings-sync` is the iCloud Sync row `#settings.sync`, one combined element whose label starts with the state: `Off` under `-seedDemo` (the in-memory store never syncs), `Checking iCloud`, `Sign In to iCloud` (the verify simulator has no Apple ID), `iCloud Unavailable`, `Syncing`, `On` (with `Synced <time> ago` once an import or export finishes), `Offline`, `iCloud Storage Full`, or `Sync Paused`. The states past `Sign In to iCloud` need a simulator signed in to iCloud, which this harness can't do, so `CloudKitSchemaTests` covers them. Journey: `journeys/icloud-sync.steps`, on-disk after `reset-data`. It also proves the CloudKit-mirrored store persists a write across a relaunch.

## How to get to it (user POV)

- More tab, then the `Settings` row. It is a pushed page; back is labeled `More`, the same as the tab bar's `More` button.

## Driving it with ffive-verify

Preconditions:

- Demo baseline. The unit lives in the real UserDefaults even under `-seedDemo`.
- Journey: `journeys/settings.steps`. It ends on Pounds.

- **Open.** Steps: `launch -seedDemo`, `tap #tab.more timeout=20`, `tap #more.settings`, `wait nav "Settings"`, `exists text "~Version"` (below the fold).
- **Switch to kg.** Steps: `tap #settings.unit.kg`, `selected #settings.unit.kg`. The journey then flips to Pounds and back to prove both rows switch, and checks the stored unit with `defaults-expect weightUnit kg`.
- **Effect.** Steps: `launch -seedDemo`, `wait text "WEEK 2 DAY 1" timeout=20`, `wait field "kg"`, `absent field "lb"`, `tap #exercise.history.1`, `wait text "* kg * *"`, which matches a set such as `85 kg × 6`. The demo seed reads the unit and converts its pound loads to kg, so the in-progress session's loads come out in kg. Real logged loads are only relabeled, never converted. The field match is on the accessibility placeholder, which is not on screen while the fields hold numbers, so the first card's History sheet is the visible proof.
- **Restore.** Steps: `launch -seedDemo`, `tap #tab.more timeout=20`, `tap #more.settings`, `tap #settings.unit.lb`, `selected #settings.unit.lb`, `defaults-expect weightUnit lb`.

## Gotchas

- A failed run can leave `weightUnit = kg`, which changes every later demo journey's targets (`We recommend 175*195 lb` won't appear). Check `ffive-verify defaults` before trusting a target mismatch. `reset-data` also clears it.
- Switching units mid-block does not convert stored loads. That is a known open item in `docs/DECISIONS.md`, not a regression.
- The `Version` row is static until the marketing or build number changes in the project.
