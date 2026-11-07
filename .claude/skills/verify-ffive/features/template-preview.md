# Template preview

Tapping a template on the Templates tab pushes a read-only preview instead of opening the builder. It shows the template's header, day tabs with each day's exercises, and a Muscle Focus card with one bar per muscle, as long as its exercises a week next to the most trained muscle. `Plan Mesocycle` opens the builder on `Customize` with the template loaded. A custom template's preview also has an options menu: Edit opens the builder in template mode (`Edit Template`: no name, length, schedule, weekdays or priorities; `Save Template` writes the days back), Rename and Delete use the same alert and dialog as the list's row menu. Delete pops back to the list.

## How to get to it (user POV)

Templates tab, tap any row under `Custom templates` or `FFive templates`.

## Driving it with ffive-verify

Preconditions: on disk, `ffive-verify reset-data`, then `launch`. Journey: `journeys/template-preview.steps` covers a built-in preview, planning, saving a custom template, then its preview, edit, rename, plan and delete, and a relaunch.

- Rows: built-in `#templates.template.<slug>`, custom `#templates.custom.<slug>`. The preview's title is `nav "<template name>"`.
- Day tabs `#template-preview.day.<n>` carry Selected. Plan is `#template-preview.plan`.
- Custom only: `#template-preview.menu` holds `#menu.edit-template`, `#menu.rename-template`, `#menu.delete-template`, confirmed by `#dialog.delete-template`.
- Edit mode's save is `#builder.update-template`; `#builder.name` and `#builder.start` are absent.

## Gotchas

- The back button is `button "BackButton"`. `button "Templates"` hits the tab bar.
- Muscle Focus sits below the days; `scrollto text "Muscle Focus"` before a shot of it.
