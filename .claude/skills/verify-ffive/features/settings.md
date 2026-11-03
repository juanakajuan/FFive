# Settings

Settings, pushed from the More tab, holds the weight unit (Pounds or Kilograms) and the app version. The unit applies to new prescriptions and to how loads are labeled. Already-logged loads are not converted.

## Sub-features

- `settings-open` opens Settings from More and shows `Version, <short> (<build>)`.
- `settings-unit` switches between `Pounds (lb)` and `Kilograms (kg)`, stored as the `weightUnit` UserDefault. The chosen row carries the Selected trait.
- `settings-unit-effect` makes sessions label loads in the chosen unit (the weight fields' placeholder), with new targets in that unit's increments.

## How to get to it (user POV)

- More tab, then the `Settings` row. It is a pushed page; back is `button "More"`.

## Driving it with ffive-verify

Preconditions:

- Demo baseline. The unit lives in the real UserDefaults even under `-seedDemo`.
- Journey: `journeys/settings.steps`. It ends on Pounds.

- **Open.** Steps: `launch -seedDemo`, `tap button "More" timeout=20`, `tap button "Settings"`, `wait nav "Settings"`, `wait text "~Version, "`.
- **Switch to kg.** Steps: `tap button "Kilograms (kg)"`, `selected button "Kilograms (kg)"`. The journey then flips to Pounds and back to prove both rows switch. `ffive-verify defaults` shows `"weightUnit" => "kg"`. Stop the journey here, or run that check from a separate drive, if you need the kg state on record.
- **Effect.** Steps: `launch -seedDemo`, `wait text "WEEK 2 DAY 1" timeout=20`, `wait field "kg"`, `absent field "lb"`. The demo seed reads the unit, so the in-progress session's loads come out in kg.
- **Restore.** Steps: `launch -seedDemo`, `tap button "More" timeout=20`, `tap button "Settings"`, `tap button "Pounds (lb)"`, `selected button "Pounds (lb)"`. Then `ffive-verify defaults` shows `"weightUnit" => "lb"`.

## Gotchas

- A failed run can leave `weightUnit = kg`, which changes every later demo journey's targets (`Target 185 × 7` won't appear). Check `ffive-verify defaults` before trusting a target mismatch. `reset-data` also clears it.
- Switching units mid-block does not convert stored loads. That is a known open item in `docs/DECISIONS.md`, not a regression.
- The `~Version, ` text is static until the marketing or build number changes in the project.
