---
name: watch-pr
description: Open a draft PR for the current change, ask @indent to review it, watch for findings, fix them until @indent reports no issues, then mark the PR ready for review. Use when the user says "open a draft PR and get @indent to review it", "watch the PR until indent is happy", or similar.
disable-model-invocation: true
---

# Watch a PR through @indent review

Work through these steps in order. Don't mark the PR ready until @indent's latest review of the head commit says it found no issues.

1. Ask @indent to review

@indent is not a collaborator on the repo, so --reviewer indent does nothing. Ask for the review in a PR comment:

@indent please review this PR and post any findings as review comments. Please don't push commits to the branch.
Write down the UTC time of the comment (date -u +%FT%TZ). The watcher uses it as its start point.

2. Watch

Start a Monitor with the maximum timeout. It should print one line for each new @indent comment or review:

since=<UTC timestamp>; seen=""
while true; do
  out=$( { gh api "repos/<owner>/<repo>/issues/<n>/comments?since=$since" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "comment \(.id)"';
           gh api "repos/<owner>/<repo>/pulls/<n>/reviews" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "review \(.id) \(.state)"';
           gh api "repos/<owner>/<repo>/pulls/<n>/comments" \
             --jq '.[] | select(.user.login|test("indent";"i")) | "inline \(.id)"'; } 2>/dev/null || true)
  while IFS= read -r l; do [ -z "$l" ] && continue
    case "$seen" in *"|$l|"*) ;; *) echo "$l"; seen="$seen|$l|";; esac; done <<<"$out"
  sleep 45
done

If the monitor expires before @indent finishes, start it again. Don't poll by hand while it runs.

3. Read each event

Fetch the body with gh api repos/<owner>/<repo>/issues/comments/<id> --jq .body and strip the HTML.

- "Indent is reviewing this pull request" banner, or "Review started on <sha>": progress only. Keep waiting.
- "Review of <sha> found no issues": the review is clean. Check that <sha> matches the PR's current head commit, then go to step 7.
- Review comments or inline comments with findings: go to step 6.

4. Fix the findings and ask again

- Read every finding. Check each one against the code before changing anything; don't accept a finding just because @indent reported it.
- Fix the valid findings in new commits. Rerun the tests that cover the change, then push.
- Reply once on the PR, grouped as Fixed (with the commit), Not fixed (with the reason), and Validation (the commands you ran and their results).
- Ask for another review:

@indent could you review this again? <one line on what changed>
- Reset since, then return to step 4. Repeat until a clean review covers the head commit.
- If @indent keeps raising the same finding you disagree with, or the loop goes past about 3 rounds, stop and ask the user.

5. Finish

- Run gh pr ready <n> and stop the monitor.
- Check CI: gh pr checks <n> --json bucket --jq 'group_by(.bucket)|map("\(.[0].bucket)=\(length)")|join(" ")'.
- Report to the user:
  - the PR link
  - how many review rounds it took and what was fixed
  - the CI status, including any failures
  - the branch used, and whether main, develop or master was changed
  - leftovers to clean up, such as the worktree or the original uncommitted copy of the change