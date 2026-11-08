# Custom templates

A lifter saves a block's layout, or a builder draft, as a template of their own. Custom templates show in their own section on the Templates tab and in the builder's template list, where the lifter can start from, rename, or delete them. A template holds day names and each day's exercises, not the block's length or priorities.

## Sub-features

- `save-draft` saves the builder's current days from the `Save as Template` toolbar button on `Customize`. It is disabled while any slot is empty (the same rule as Start). Days with no exercise are left out.
- `save-meso` saves a block's days from the `Save as Template` button on its detail page, active or finished.
- `list` shows `Custom templates` above `FFive templates` on the Templates tab, filtered by the same search and days-per-week filter. An emphasis filter hides every custom template. With none saved it shows a hint.
- `picker` shows `Your templates` above `Start from a template` in the builder, only when one exists.
- `copy` duplicates a template from its preview menu or a custom row's menu, as `<name> copy`, and opens it in `Edit Template`.
- `rename-delete` uses the row's menu on the Templates tab. Names stay unique across built-in and custom templates: a taken name gets ` 2`, ` 3`, and so on.
- `persist` keeps templates after a relaunch, in `ZCUSTOMTEMPLATE(ZNAME, ZLAYOUTDATA)`, where the layout is JSON.

## How to get to it (user POV)

- Builder: `Plan a Mesocycle` or the `New Mesocycle` "+", pick a template, then the download icon in the toolbar on `Customize`.
- Mesos tab: tap the block's row, scroll to the bottom, tap `Save as Template`.
- Templates tab: the `Custom templates` section, with a menu on each row.

## Driving it with ffive-verify

Preconditions:

- On disk: `ffive-verify reset-data`, then `launch`.
- Journey: `journeys/custom-templates.steps`.
- Journey: `journeys/template-during-block.steps` saves a template from Templates' "+" while a block is active (start from `ffive-verify reset-data`).

- **Save a draft.** Steps: `tap #builder.template.upper-lower-4-days`, `tap #builder.save-template`, `replace field "Template name" "My Upper Lower"`, `sleep 1`, `tap button "Save"`, `store-expect CustomTemplate name "My Upper Lower"`.
- **List and rename.** Steps: `tap #tab.templates`, `wait #templates.custom.my-upper-lower`, `tap #templates.menu.my-upper-lower`, `tap #menu.rename-template`, then replace the field and Save as above. `wait #templates.custom.<new slug>`.
- **Start from one.** Steps: `tap #builder.custom-template.<slug>`, `value #builder.name "<name>"`. From the Templates tab a row opens the preview first; see `template-preview.md`.
- **Save a block.** Steps: `tap #mesos.row.<slug>`, `scrollto #meso.save-template`, `tap #meso.save-template`, then name it and Save.
- **Delete.** Steps: `tap #templates.menu.<slug>`, `tap #menu.delete-template`, `tap #dialog.delete-template`, `absent #templates.custom.<slug>`.

## Gotchas

- The name alert's field and buttons carry no ids. Address them as `field "Template name"` and `button "Save"`.
- `Customize` is pushed when reached from the template list, so `#builder.cancel` is one screen back, behind `button "New Mesocycle"`. From a Templates tab row the preview opens first; its `#template-preview.plan` opens the builder straight on `Customize` and Cancel is there.
