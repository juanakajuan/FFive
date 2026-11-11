# Performed filter

The Exercises tab's Filters menu has `Only Exercises I’ve Performed` (`#exercises.performed-only`, a switch; the menu label then reads `Performed`). The exercise picker has the same filter as a check row under the search box (`#picker.performed-only`, Selected while on). Both keep only exercises with a logged set in a finished workout, the same rule as [Last performed](./last-performed.md): a set logged in an open workout doesn't count. On the tab the filter combines with search, muscle, equipment and Show Hidden. The picker has no Show Hidden, its muscle is fixed by whoever opened it, and it applies only the My Equipment toggle. With no history the tab shows `No matching exercises` and the picker shows `No exercises performed yet`.

- **Journey.** `journeys/performed-filter.steps` (on disk, after `reset-data`): both filters are empty with no history and with a set logged in an open workout. After Finish, both list Bench Press and nothing else.
