---
name: watch-pr
description: Open a draft PR for the current change, ask @indent to review it, watch for review findings and CI failures, fix them until @indent reports no issues and CI is green on the head commit, then mark the PR ready for review. Use when the user says "open a draft PR and get @indent to review it", "watch the PR until indent is happy", "watch the PR until CI is green", or similar.
disable-model-invocation: true
---

# Watch a PR through @indent review and CI

Work through these steps in order. Don't mark the PR ready until both are true for the current head commit:

- @indent's latest review says it found no issues.
- Every CI check has passed (or was skipped). None is failing or pending.

## 1. Open the draft PR

- Run `git branch --show-current` and `git status --short -b`. If you're on `main`, `develop` or `master`, stop and ask before committing.
- Commit, push and open the PR as a draft, following the repo's PR conventions.
- Note `<owner>/<repo>` and the PR number `<n>`.

## 2. Ask @indent to review

@indent is not a collaborator on the repo, so `--reviewer indent` does nothing. Ask for the review in a PR comment:

```
@indent please review this PR and post any findings as review comments. Please don't push commits to the branch.
```

Write down the UTC time of the comment (`date -u +%FT%TZ`). The watcher uses it as its start point.

## 3. Watch

Start a Monitor with the maximum timeout. It prints one line for each new @indent comment or review, and one line each time the CI state of the head commit changes:

```bash
since=<UTC timestamp>; seen=""
while true; do
  head=$(gh pr view <n> -R <owner>/<repo> --json headRefOid --jq .headRefOid 2>/dev/null)
  ci=$(gh pr checks <n> -R <owner>/<repo> --json bucket \
         --jq 'if length==0 then "pending"
               elif any(.[]; .bucket=="fail" or .bucket=="cancel") then "fail"
               elif any(.[]; .bucket=="pending") then "pending"
               else "pass" end' 2>/dev/null)
  out=$( { gh api "repos/<owner>/<repo>/issues/<n>/comments?since=$since" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "comment \(.id)"';
           gh api "repos/<owner>/<repo>/pulls/<n>/reviews" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "review \(.id) \(.state)"';
           gh api "repos/<owner>/<repo>/pulls/<n>/comments" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "inline \(.id)"';
           [ -n "$ci" ] && [ "$ci" != pending ] && echo "ci $ci ${head:0:12}"; } 2>/dev/null || true)
  while IFS= read -r l; do [ -z "$l" ] && continue
    case "$seen" in *"|$l|"*) ;; *) echo "$l"; seen="$seen|$l|";; esac; done <<<"$out"
  sleep 45
done
```

`ci pass <sha>` and `ci fail <sha>` are printed once per head commit, after every check has finished. A new push produces a new line. If the repo has no CI checks at all, nothing is printed for CI; once you've confirmed that with `gh pr checks <n>`, treat CI as green.

If the monitor expires before review and CI are both done, start it again. Don't poll by hand while it runs.

## 4. Read each event

For @indent comments, fetch the body with `gh api repos/<owner>/<repo>/issues/comments/<id> --jq .body` and strip the HTML.

- "Indent is reviewing this pull request" banner, or "Review started on <sha>": progress only. Keep waiting.
- "Review of <sha> found no issues": the review is clean. Check that `<sha>` matches the PR's current head commit, then go to step 7.
- Review comments or inline comments with findings: go to step 5.
- `ci fail <sha>`: go to step 6.
- `ci pass <sha>`: CI is green for that commit. If it matches the current head, go to step 7.

Ignore events for an older head commit; only the current head counts.

## 5. Fix review findings and ask again

- Read every finding. Check each one against the code before changing anything; don't accept a finding just because @indent reported it.
- Fix the valid findings in new commits. Rerun the tests that cover the change, then push.
- Reply once on the PR, grouped as Fixed (with the commit), Not fixed (with the reason), and Validation (the commands you ran and their results).
- Ask for another review:

  ```
  @indent could you review this again? <one line on what changed>
  ```

- Reset `since`, then return to step 4. Repeat until a clean review covers the head commit.
- If @indent keeps raising the same finding you disagree with, or the loop goes past about 3 rounds, stop and ask the user.

## 6. Fix CI failures

- List the failing checks: `gh pr checks <n> -R <owner>/<repo> --json name,bucket,link --jq '.[] | select(.bucket=="fail" or .bucket=="cancel")'`.
- For GitHub Actions, read the failed logs: `gh run view <run-id> -R <owner>/<repo> --log-failed`. Take the run ID from the check's link. For other CI providers, open the link or use their CLI.
- Find the root cause before changing anything. Reproduce it locally when you can (same test, lint or build command as CI).
- Decide what kind of failure it is:
  - Caused by the change (test, lint, type or build error): fix it in a new commit, rerun the same command locally, then push.
  - Flaky or infrastructure (timeout, network, runner crash, unrelated test that passes on rerun): rerun once with `gh run rerun <run-id> -R <owner>/<repo> --failed`. If it fails again, treat it as a real failure.
  - Already failing on the base branch, or needs secrets or permissions you don't have: don't paper over it. Stop and ask the user.
- Never skip, disable or loosen tests, lint rules or checks to get green unless the user says so.
- If a fix pushed new code, ask @indent to review again (step 5) so the clean review covers the new head.
- Return to step 4. If CI is still red after about 3 fix attempts, stop and ask the user.

## 7. Finish

Only finish when the clean @indent review and `ci pass` both refer to the current head commit. If only one of them does, keep waiting in step 4.

- Run `gh pr ready <n>` and stop the monitor.
- Report to the user:
  - the PR link
  - how many review rounds it took and what was fixed
  - the CI failures you hit, how each was fixed (or rerun), and the final CI status
  - the branch used, and whether `main`, `develop` or `master` was changed
  - leftovers to clean up, such as the worktree or the original uncommitted copy of the change
