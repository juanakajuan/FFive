# Rate FFive

More's App section ends with a "Rate FFive" row (`#more.rate`) that opens the App Store write-review page. After the summary of the lifter's first finished block closes, the app calls `requestReview` once and records `reviewRequested = true` in UserDefaults. Later blocks never ask again. The rule is `ReviewPrompt.shouldAsk` and `Store.takeReviewPrompt` in FFiveCore, tested in `ReviewPromptTests`.

## Driving it with ffive-verify

- Baseline: `ffive-verify reset-data`, then `ffive-verify drive .claude/skills/verify-ffive/journeys/rate-ffive.steps --name rate-ffive`.
- **Row.** `tap #tab.more`, `wait #more.rate`.
- **Prompt once.** Plan a block, log one set, end it, close the summary with `#sheet.done`, `wait button "Not Now" timeout=20`, `defaults-expect reviewRequested 1`, relaunch. End a second block: `sleep 10`, `count button "Not Now" "0"` and the flag stays set.
- **Rate.** `tap #more.rate` leaves FFive for the URL handler (the status bar shows the `FFive` back chip).

## Gotchas

- The review dialog ("Enjoying FFive?", `Not Now`) appears a few seconds after the summary closes. It runs out of process: it shows in the tree but ignores taps, so the journey relaunches the app to clear it. Demo launches (`-seedDemo`) never ask.
- `AppStoreListing.appID` is a placeholder until the App Store ID is recorded, so the review page will not resolve.
