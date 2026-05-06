---
name: address-pr-comments
description: Address unresolved pull request review comments by triaging actionability, implementing fixes, resolving addressed threads, and posting a final PR summary. Use when the user runs /address-pr-comments or asks to process PR review feedback.
disable-model-invocation: true
---

# Address PR Comments

Command: /address-pr-comments

Workflow:
 - check PR for all unresolved review comments
 - verify that they should be actioned
 - if not, just leave a comment with a reason
 - if yes, fix and commit code
 - resolve the specific comment
 - push everything at the end
 - add a new PR comment with a summary of what has been fixed and what not
 - add a new comment to trigger a new review, if it was done by a bot (reuse the bot's own trigger phrase) or trigger a new review request

## Inputs

- PR URL/number (optional; if missing, infer from current branch)
- Base branch override (optional; default `develop` or `main` unless user says otherwise)

## Execution Checklist

Copy this checklist and keep it updated while working:

```text
PR comment resolution progress
- [ ] Identify PR and host
- [ ] Fetch unresolved review threads
- [ ] Triage each thread (action / no-action + reason)
- [ ] Implement and test actionable fixes
- [ ] Commit actionable fixes (Conventional Commits)
- [ ] Resolve only addressed threads
- [ ] Push once at the end
- [ ] Post PR summary comment (fixed / not fixed)
- [ ] Trigger re-review (bot mention or reviewer request)
```

## Detailed Steps

1. Identify PR context.
   - If no PR is provided, use the current branch PR.
   - Capture `owner`, `repo`, and `prNumber`.

2. Fetch unresolved review threads first.
   - Use GitHub GraphQL (`gh api graphql`) to retrieve review threads with:
     - thread id
     - `isResolved`
     - `isOutdated`
     - file path and line
     - latest comments and authors
   - Work only on unresolved threads.

3. Triage each unresolved thread.
   - **Actionable**: a real requested change that still applies to current code.
   - **Not actionable**: already fixed, outdated context, or intentionally not adopted.
   - For not actionable items, reply on that thread with a concise reason.

4. Implement actionable fixes.
   - Batch related fixes when possible; avoid one commit per tiny nit unless required.
   - Run relevant tests/lint for changed areas before committing.

5. Commit safely.
   - Always run before commit/push:
     - `git branch --show-current`
     - `git status --short -b`
   - If branch is `develop`, `main`, or `master`, stop and ask to switch/create a feature branch unless the user explicitly asks to commit directly there.
   - Use Conventional Commit messages.

6. Resolve addressed threads.
   - Resolve only threads that were actually addressed.
   - Keep unresolved when waiting on reviewer decision.

7. Push once at the end.
   - Push all commits together after triage/fixes are complete.

8. Post a final PR summary comment.
   - Include:
     - `Fixed`: bullet list of addressed items
     - `Not fixed`: bullet list with reasons
     - `Validation`: tests/checks run

9. Trigger re-review.
   - If prior review came from a bot account (for example login ends in `[bot]`), infer the trigger phrase from that bot's previous review comment(s) or command and reuse the same phrasing.
   - Prefer exact reuse of the phrase the bot responded to previously.
   - If no prior trigger phrase can be inferred, ask the user what phrase to use.
   - Otherwise request review from the original human reviewer(s), or ask the user who should be requested if unclear.

## Completion Criteria

- All unresolved threads are triaged.
- Each non-actioned thread has a reasoned reply.
- Actionable fixes are committed and pushed.
- Addressed threads are resolved.
- Final PR summary comment is posted.
- Re-review is explicitly triggered.
