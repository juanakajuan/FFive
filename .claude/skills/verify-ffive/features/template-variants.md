# Template variants and filters

Each whole-body built-in template has a women's version (`Women's Full Body, 2 Days` and so on) with more lower-body and glute volume and the same schedule. The list marks it with `· WOMEN'S` after the emphasis. The Templates tab's filter bar opens a menu of four titled submenus: `Days per week`, `Emphasis`, `Source` (All, Built-in, Custom) and `Variant` (All, Standard, Women's). The bar's label lists the active filters, as in `3/week · Women's`.

## Sub-features

- `marker`: women's rows read `WHOLE BODY · WOMEN'S` above the name.
- `source`: `Built-in` hides the `Custom templates` section, `Custom` hides `FFive templates`.
- `variant`: picks one variant. A custom template has no variant, so any variant filter drops it, like the emphasis filter.

## Driving it with ffive-verify

- Journey: `journeys/template-variants.steps` (demo; saves one custom template in memory first).
- Open a submenu with `tap button "Filters"`, `tap button "Variant"`, then tap the option by label, as in `tap button "Women's"`. Afterwards the bar's own label is the active filter, so reopen it by that label (`tap button "Women's"`), or `~` for a joined label.
- Women's rows: `#templates.template.women-s-full-body-2-days`, and so on.

## Gotchas

- The submenus don't show up in `tree` dumps; tap their options by label.
