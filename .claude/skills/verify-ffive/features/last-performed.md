# Last performed date

An exercise picker row (`#picker.row.<slug>`) for an exercise with a finished session that has a logged set shows `Last performed <Mon d, yyyy>` under the muscle and equipment. The row is one button, so the date is also in its accessibility value, after the muscle. The exercise detail page shows the same text under its header (`#exercise.last-performed`), matching the top History row. Open sessions and sessions with no logged set don't count, and an exercise never done shows no date.

- **Journey.** `journeys/last-performed.steps` (demo): Bench Press is logged in the in-progress Week 2 Day 1, so the picker and the detail page show Week 1 Day 1's date (the top History row), not today's. Incline Bench Press, never done, has no date.
