# AI Skills Repository

This repository contains reusable skills, Cursor rules, and helper scripts for agent workflows.

## Included In This Repository

### Skills

- `skills/weekly-report/SKILL.md`
  Generates a weekly engineering HTML summary from `sources.md` inputs (Slack, Linear, GitHub, P2s, Reddit, forums).

- `skills/address-pr-comments/SKILL.md`
  Implements the `/address-pr-comments` workflow: triage unresolved PR comments, fix actionable items, resolve threads, summarize outcomes, and trigger re-review.

### Cursor Rules

- `.cursor/rules/github-a8c-proxy.mdc`
  Uses `HTTPS_PROXY="socks5://127.0.0.1:8080"` for `gh` commands against A8c GitHub enterprise instance.

- `.cursor/rules/git-branch-safety.mdc`
  Prevents direct commits on `develop`/`main`/`master` unless explicitly requested.

- `.cursor/rules/commit-conventions.mdc`
  Enforces Conventional Commit messages and issue-linked branch naming.

- `.cursor/rules/pr-conventions.mdc`
  Enforces PR conventions (no issue ID in title by default, reviewer assignment, draft-by-default, and base branch guidance).

### Scripts

- `sync-claude-md.sh`
  Generates `CLAUDE.md` by combining all `.cursor/rules/*.mdc` files (frontmatter stripped).

## Usage

### Sync Cursor rules to Claude CLI instructions

```bash
chmod +x ./sync-claude-md.sh
./sync-claude-md.sh
```

Optional custom paths:

```bash
./sync-claude-md.sh "/path/to/rules" "/path/to/CLAUDE.md"
```
