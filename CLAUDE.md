# FFive

## Commands

- `scripts/check` is the one gate. It prints `CHECK PASS` or `CHECK FAIL <step>` in about 15 seconds. Run it before every push. CI runs the same command on every PR and every push to `main`.
- `scripts/lint.sh` holds the lint rules. Its baseline, `scripts/lint-baseline.txt`, lists the hits that already exist. A new hit fails, and so does a baseline line whose hit is gone. Fix a hit and delete its line. Add a line only with the operator's approval.
- Use the `verify-ffive` skill to prove a change on the simulator. `scripts/check` does not drive the app.

## Rules

Each rule is enforced by the check named beside it. A rule with no check is a judgment call, so follow it by hand.

| Rule | Enforced by |
| --- | --- |
| A view never writes model state (`context.delete`, `insert`, `save`, or an assignment to `finishedDate` or `endDate`) | `scripts/lint.sh` rule `view-writes` |
| A view never stores a `@ViewBuilder` closure, it stores the built view | `scripts/lint.sh` rule `no-stored-builder` |
| Alerts, sheets, confirmation dialogs and covers attach to a screen struct (a name ending in `View` or `Screen`), never a row or card | `scripts/lint.sh` rule `presentation-at-screen-root` |
| Every file under `FFive/` typechecks together for iOS | `scripts/typecheck-app.sh` |
| Engine and planner rules keep their behavior | `scripts/check-engine.sh`, `scripts/check-planner.sh` |
| Each lint rule still catches its real past mistake | `scripts/lint.sh --self-test` |
| Every PR and every push to main runs the gate in CI | `.github/workflows/check.yml` |
| A PR or issue whose change shows on screen carries screenshots or a recording | none, judgment |

## Pull requests and issues

Include screenshots or a screen recording in every PR and issue whose change or bug shows up in the app. Leave them out only when nothing on screen changes (engine, scripts, docs).

- Capture them with the `verify-ffive` skill on its simulator. For a UI change, show before and after side by side in a table, with `width="300"` on each `<img>`. For an interaction, record the drive with `xcrun simctl io <udid> recordVideo <file>.mp4` and link the clip.
- `gh` can't upload images. Push them to the orphan `pr-assets` branch under `pr-<number>/` or `issue-<number>/` with git plumbing (`hash-object`, `mktree`, `commit-tree`, then push the commit to `refs/heads/pr-assets`, using the current tip as parent when the branch exists), so the working branch stays untouched.
- Embed them from `https://raw.githubusercontent.com/juanakajuan/FFive/<assets commit sha>/<path>`. Use the commit SHA, not `pr-assets`: raw URLs on a branch are cached for minutes, so replaced images show stale.
