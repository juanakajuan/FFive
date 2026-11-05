# Settings

Settings, pushed from the More tab, holds the weight unit (Pounds or Kilograms) and the app version. The unit applies to new prescriptions and to how loads are labeled. Already-logged loads are not converted.

## Sub-features

- `settings-open` opens Settings from More and shows `Version, <short> (<build>)`.
- `settings-unit` switches between `Pounds (lb)` and `Kilograms (kg)`, stored as the `weightUnit` UserDefault. The chosen row carries the Selected trait.
- `settings-unit-effect` labels loads in the chosen unit (the weight fields' placeholder, the History sheet, Progress, and workout details), with new targets in that unit's increments. Logged numbers are relabeled, not converted.

## How to get to it (user POV)

- More tab, then the `Settings` row. It is a pushed page; back is labeled `More`, the same as the tab bar's `More` button.

## Driving it with ffive-verify

Preconditions:

- Demo baseline. The unit lives in the real UserDefaults even under `-seedDemo`.
- Journey: `journeys/settings.steps`. It ends on Pounds.

- **Open.** Steps: `launch -seedDemo`, `tap #tab.more timeout=20`, `tap #more.settings`, `wait nav "Settings"`, `wait text "~Version"`.
- **Switch to kg.** Steps: `tap #settings.unit.kg`, `selected #settings.unit.kg`. The journey then flips to Pounds and back to prove both rows switch, and checks the stored unit with `defaults-expect weightUnit kg`.
- **Effect.** Steps: `launch -seedDemo`, `wait text "WEEK 2 DAY 1" timeout=20`, `wait field "kg"`, `absent field "lb"`, `tap #exercise.history.1`, `wait text "* kg * *"`, which matches a set such as `135 kg × 8`. The demo seed reads the unit, so the in-progress session's loads come out in kg. The field match is on the accessibility placeholder, which is not on screen while the fields hold numbers, so the first card's History sheet is the visible proof.
- **Restore.** Steps: `launch -seedDemo`, `tap #tab.more timeout=20`, `tap #more.settings`, `tap #settings.unit.lb`, `selected #settings.unit.lb`, `defaults-expect weightUnit lb`.

## Gotchas

- A failed run can leave `weightUnit = kg`, which changes every later demo journey's targets (`Target 185 * 7` won't appear). Check `ffive-verify defaults` before trusting a target mismatch. `reset-data` also clears it.
- Switching units mid-block does not convert stored loads. That is a known open item in `docs/DECISIONS.md`, not a regression.
- The `Version` row is static until the marketing or build number changes in the project.
