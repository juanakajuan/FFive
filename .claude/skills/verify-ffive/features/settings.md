# Settings

Settings, opened from the Train toolbar gear, holds the weight unit (Pounds or Kilograms) and the app version. The unit applies to new prescriptions and to how loads are labeled. Already-logged loads are not converted.

## Sub-features

- `settings-open` opens Settings from the Train toolbar and shows `Version, <short> (<build>)`.
- `settings-unit` switches between `Pounds (lb)` and `Kilograms (kg)`, stored as the `weightUnit` UserDefault.
- `settings-unit-effect` makes sessions label loads in the chosen unit, with new targets in that unit's increments.

## How to get to it (user POV)

- Train tab, then the `Settings` gear in the toolbar. It is a pushed page; back is `button "Train"`.

## Driving it with ffive-verify

Preconditions:

- Demo baseline. The unit lives in the real UserDefaults even under `-seedDemo`.
- Journey: `journeys/settings.steps`. It ends on Pounds.

- **Open.** Steps: `tap button "Settings" timeout=20`, `wait nav "Settings"`, `wait text "~Version, "`.
- **Switch to kg.** Steps: `tap button "Kilograms (kg)"`, `selected button "Kilograms (kg)"`. Then `ffive-verify defaults` shows `"weightUnit" => "kg"`. Stop the journey here, or run that check from a separate drive, if you need the kg state on record.
- **Effect.** Steps: `launch -seedDemo -demoRoute session`, `wait nav "Full Body, 3 Days" timeout=20`, `wait text "kg"`, `absent text "lb"`. The demo seed reads the unit, so its loads come out in kg.
- **Restore.** Steps: `launch -seedDemo`, `tap button "Settings"`, `tap button "Pounds (lb)"`, `selected button "Pounds (lb)"`. Then `ffive-verify defaults` shows `"weightUnit" => "lb"`.

## Gotchas

- A failed run can leave `weightUnit = kg`, which changes every later demo journey's targets (`Target 185 × 7` won't appear). Check `ffive-verify defaults` before trusting a target mismatch. `reset-data` also clears it.
- Switching units mid-block does not convert stored loads. That is a known open item in `docs/DECISIONS.md`, not a regression.
- The `~Version, ` text is static until the marketing or build number changes in the project.
