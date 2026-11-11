# FFive

## Commands

- `scripts/check` is the one gate. It prints `CHECK PASS` or `CHECK FAIL <step>` in about 15 seconds. Run it before every push. CI runs the same command on every PR and every push to `main`.
- `scripts/format.sh` reformats every Swift file in place with swift-format, which ships with the Swift toolchain. Its settings live in `.swift-format`. `scripts/format.sh --lint` fails on any file it would change and on any swift-format lint rule hit. Run `scripts/format.sh` before you commit.
- `scripts/lint.sh` holds the lint rules. Its baseline, `scripts/lint-baseline.txt`, lists the hits that already exist. A new hit fails, and so does a baseline line whose hit is gone. Fix a hit and delete its line. Add a line only with the operator's approval.
- Use the `verify-ffive` skill to prove a change on the simulator. `scripts/check` does not drive the app.

## Branches and worktrees

Never change files or commit in the main checkout. It stays on `main` and only pulls.

- Start each change in its own worktree off `origin/main`: `git fetch origin && git worktree add -b <branch> .claude/worktrees/<name> origin/main`. Name the branch `fix/<issue>-<slug>` or `feat/<issue>-<slug>`.
- Edit, run `scripts/check`, commit and push from the worktree, then open the PR.
- Every change ends in an open PR. Once `scripts/check` passes, push the branch and run `gh pr create` without asking. This rule is standing approval to push a non-`main` branch and open a PR. It does not cover pushing to `main`, force-pushing, or merging.
- `scripts/git-hooks/pre-commit` refuses commits on `main`. Enable it once per clone with `git config core.hooksPath scripts/git-hooks`.

## Layout

- `FFiveCore/` is a local Swift package with the engine, catalog, `@Model` types and planner. Domain rules and model behavior live there, and the app sees only what is `public`. Add `public` only to a symbol a view uses.
- `FFive/` holds the app target: one folder per tab (`Workout`, `Mesos`, `Templates`, `Exercises`, `More`), plus `Shared` and `App`.

## Rules

Each rule is enforced by the check named beside it. A rule with no check is a judgment call, so follow it by hand.

| Rule | Enforced by |
| --- | --- |
| A view never writes model state (`context.delete`, `insert`, `save`, or an assignment to `finishedDate` or `endDate`) | `scripts/lint.sh` rule `view-writes` |
| A view never stores a `@ViewBuilder` closure, it stores the built view | `scripts/lint.sh` rule `no-stored-builder` |
| Alerts, sheets, confirmation dialogs and covers attach to a screen struct (a name ending in `View` or `Screen`), never a row or card | `scripts/lint.sh` rule `presentation-at-screen-root` |
| Every card draws through `.surfaceCard()` in `Theme.swift`, never a hand-built `Theme.surface` rounded background | `scripts/lint.sh` rule `one-card-modifier` |
| Text fonts, corner radii and on-accent colors come from `Theme` tokens, never a literal size, a numeric radius or `.white` | `scripts/lint.sh` rule `theme-tokens` |
| Every divider is `Hairline()` in `Theme.swift`, never a hand-built `Theme.hairline` rectangle | `scripts/lint.sh` rule `one-divider` |
| A nav-bar menu sits in `.primaryAction`, and every menu's label reads "<Thing> Menu" | `scripts/lint.sh` rule `nav-menu-convention` |
| Every ⓘ action icon and text link is `Theme.infoText`: a link never uses `Theme.accent`, and a ⓘ action icon is `ActionIcon.info(filled:)` | `scripts/lint.sh` rule `info-and-link-tint` |
| Every segmented control is `SegmentedButtons` in `Components.swift`, never a `Picker` with `.pickerStyle(.segmented)` | `scripts/lint.sh` rule `one-segmented-control` |
| A meaning that has a symbol in the `Symbol` registry in `Theme.swift` (skip, edit, rename, cue, note, pin, progress) draws through it, never a literal | `scripts/lint.sh` rule `one-symbol-per-meaning` |
| Every file under `FFive/` typechecks together for iOS, against the built `FFiveCore` package | `scripts/typecheck-app.sh` |
| Engine and planner rules keep their behavior | `swift test --package-path FFiveCore` |
| Swift files match `.swift-format` and pass its lint rules | `scripts/format.sh --lint` |
| Each lint rule still catches its real past mistake | `scripts/lint.sh --self-test` |
| Every PR and every push to main runs the gate in CI | `.github/workflows/check.yml` |
| No commit lands on `main` locally; changes happen in a worktree | `scripts/git-hooks/pre-commit` |
| Every change ends in an open PR, opened without asking | none, judgment |
| A PR or issue whose change shows on screen carries screenshots or a recording | none, judgment |

## Pull requests and issues

Include screenshots or a screen recording in every PR and issue whose change or bug shows up in the app. Leave them out only when nothing on screen changes (engine, scripts, docs).

- Capture them with the `verify-ffive` skill on its simulator. For a UI change, show before and after side by side in a table, with `width="300"` on each `<img>`. For an interaction, record the drive with `xcrun simctl io <udid> recordVideo <file>.mp4` and link the clip.
- `gh` can't upload images. Push them to the orphan `pr-assets` branch under `pr-<number>/` or `issue-<number>/` with git plumbing (`hash-object`, `mktree`, `commit-tree`, then push the commit to `refs/heads/pr-assets`, using the current tip as parent when the branch exists), so the working branch stays untouched.
- Embed them from `https://raw.githubusercontent.com/juanakajuan/FFive/<assets commit sha>/<path>`. Use the commit SHA, not `pr-assets`: raw URLs on a branch are cached for minutes, so replaced images show stale.
