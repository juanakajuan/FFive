# FFive

## Pull requests and issues

Include screenshots or a screen recording in every PR and issue whose change or bug shows up in the app. Leave them out only when nothing on screen changes (engine, scripts, docs).

- Capture them with the `verify-ffive` skill on its simulator. For a UI change, show before and after side by side in a table, with `width="300"` on each `<img>`. For an interaction, record the drive with `xcrun simctl io <udid> recordVideo <file>.mp4` and link the clip.
- `gh` can't upload images. Push them to the orphan `pr-assets` branch under `pr-<number>/` or `issue-<number>/` with git plumbing (`hash-object`, `mktree`, `commit-tree`, then push the commit to `refs/heads/pr-assets`, using the current tip as parent when the branch exists), so the working branch stays untouched.
- Embed them from `https://raw.githubusercontent.com/juanakajuan/FFive/<assets commit sha>/<path>`. Use the commit SHA, not `pr-assets`: raw URLs on a branch are cached for minutes, so replaced images show stale.
