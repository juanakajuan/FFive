# Template preview

Tapping a template on the Templates tab pushes a read-only preview instead of opening the builder. It shows the template's header, day tabs with each day's exercises, and a Muscle Focus card with one bar per muscle, as long as its exercises a week next to the most trained muscle. `Plan Mesocycle` opens the builder on `Customize` with the template loaded. Every preview has an options menu with Copy, which saves a custom duplicate and opens it in the editor. A custom template's menu also has Edit, Rename and Delete. Edit opens the builder in template mode (`Edit Template`: no name, length, schedule, weekdays or priorities; `Save Template` writes the days back). Rename and Delete use the same alert and dialog as the list's row menu (`Delete this template?`, `Delete Template`). Delete pops back to the list.

## How to get to it (user POV)

Templates tab, tap any row under `Your Templates` or `FFive Templates`.

## Driving it with ffive-verify

Preconditions: on disk, `ffive-verify reset-data`, then `launch`. Journey: `journeys/template-preview.steps` covers a built-in preview, planning, saving a custom template, then its preview, edit, rename, plan and delete, and a relaunch.

- Rows: built-in `#templates.template.<slug>`, custom `#templates.custom.<slug>`. The preview's title is `nav "<template name>"`.
- Day tabs `#template-preview.day.<n>` carry Selected. Plan is `#template-preview.plan`.
- `#template-preview.menu` holds `#menu.copy-template` on every template, plus `#menu.edit-template`, `#menu.rename-template` and `#menu.delete-template` on a custom one, confirmed by `#dialog.delete-template`.
- Copy saves a custom template named `<name> copy` (`<name> copy 2` and up when taken) and opens it in `Edit Template`. Journey: `journeys/copy-template.steps` (from `reset-data`).
- Edit mode's save is `#builder.update-template`; `#builder.name` and `#builder.start` are absent.

## Gotchas

- The back button is `button "BackButton"`. `button "Templates"` hits the tab bar.
- Muscle Focus sits below the days; `scrollto text "Muscle Focus"` before a shot of it.
