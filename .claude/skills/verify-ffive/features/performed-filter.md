# Performed filter

The Exercises tab's Filters menu has `Only exercises I’ve performed` (`#exercises.performed-only`, a switch; the menu label then reads `Performed`). The exercise picker has the same filter as a check row under the search box (`#picker.performed-only`, Selected while on). Both keep only exercises with a logged set in a finished workout, the same rule as [Last performed](./last-performed.md): a set logged in an open workout doesn't count. The filter combines with search, muscle, equipment and Show hidden. With no history the tab says `No exercises match.` and the picker shows `No exercises performed yet`.

- **Journey.** `journeys/performed-filter.steps` (on disk, after `reset-data`): both filters are empty with no history and with a set logged in an open workout. After Finish, both list Bench Press and nothing else.
