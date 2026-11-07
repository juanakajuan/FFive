# Exercise history sheet

The history button on an exercise card (`#exercise.history.<n>`) opens a sheet listing every finished session of that exercise across all mesocycles, newest first. Sessions are grouped under the meso's name, or `Quick Workouts` for free-form sessions. Each row (`#exercise-history.session.<n>`, numbered from 1 down the whole list) reads `Week n · Day n · <day name>` (or `Deload · …`, or the quick workout's name), the date, and each logged set. A row is one accessibility element whose label joins all of that, so match it with `any` and a wildcard. Tapping a row pushes the workout's detail page inside the sheet. Open sessions and sessions with no logged set of the exercise are left out.

- **Journey.** `journeys/exercise-history.steps` (demo): Squat on Week 2 Day 1 shows Week 1 Day 1 under `Full Body, 3 Days` and Morning Workout under `Quick Workouts`, and the first row opens `Full Body A`.
