# Suggest an exercise

A picker opened for one muscle (Swap from a workout card or the builder) has a Suggest toolbar button, `#picker.suggest`. Each tap shows a Suggested card above the list with the next exercise for that muscle, in the lifter's equipment, not hidden: exercises done before first, most recently done first, then the rest by name, wrapping around. The card's `#picker.suggestion-add` (label `Add <name>`) picks it. Nothing changes until it is tapped. The Add Exercise picker has no muscle and no Suggest button. The rule is `ExerciseListing.suggestion` in FFiveCore.

- **Journey.** `journeys/suggest-exercise.steps` (demo): swapping Bench Press suggests Machine Chest Press, then Incline Dumbbell Press; Cancel leaves Bench Press; Suggest then Add swaps in Machine Chest Press.
