---
name: weekly-report
description: Generate a weekly engineering summary HTML report. First ask which area to report on (e.g. DayOne, PocketCasts, and future areas), then read that area's sources.md to discover Slack channels, Linear team, GitHub repos, P2s, Reddit, and forum URLs. Produces a self-contained tabbed HTML file in that area folder. Use when asked to generate a weekly report, weekly summary, or weekly digest.
---

Generate a weekly engineering summary report for the selected area's team defined in `sources.md`.

## Arguments

The user may provide:
- An **area** (e.g. `DayOne`, `PocketCasts`).
- A **date range** (e.g. "Apr 6–13", "last week", "this week"). Default to the last 7 days from today.
- An **output filename**. Default to `weekly-summary-YYYY-MM-DD.html` using the end date.

If area is not provided, ask the user which area to use before continuing.
If no date range is given, use the last 7 days.

## Step 1 — Select area and locate sources.md

Resolve the target area folder before any data fetch:

- Detect available areas by listing child folders in the current directory that contain a `sources.md` file.
- Ask the user to choose one area (for now this may include `DayOne` and `PocketCasts`; support any future area discovered this way).
- Set `AREA_DIR` to the selected folder.

Read `AREA_DIR/sources.md`. Parse it to extract:

- **Meta.Team** — the team name (used in the report title and search queries)
- **Meta.Search terms** — keywords to use when querying P2s and MGS
- **Meta.Priority Slack channels** — channels to fetch with higher message limits
- **Slack** — all channel names listed (strip the backtick-wrapped `#` prefix)
- **Linear** — extract the team key from the board URL (e.g. `DAYONE` from `.../team/DAYONE/...`)
- **GitHub** — extract `owner/repo` from each link
- **P2s** — all WordPress.com blog domains listed
- **Web** — all URLs listed; detect Reddit URLs (contain `reddit.com/r/`) and forum/support URLs separately

If no area folders with `sources.md` are found, or `AREA_DIR/sources.md` is missing, stop and ask the user for the correct area and sources file.

## Step 2 — Load providers

Load these providers in parallel using the context-a8c MCP:
- `slack`
- `linear`
- `mgs`
- `github`

Reddit MCP is required. Check whether `mcp__reddit__get_top_posts` is available.
If it is not available, stop and prompt the user to install it with:
`claude mcp add --transport stdio reddit -- npx reddit-mcp-server`
After they confirm installation, continue.

`WebFetch` is always available for public forum URLs.

## Step 3 — Fetch data in parallel

Compute the start date from the date range. For Slack, compute the Unix timestamp for use as `oldest`.

Run all fetches simultaneously using data from `AREA_DIR/sources.md`:

**Slack** — for every channel in sources.md:
- Priority channels (from Meta): `count: 50`
- All other channels: `count: 30`
```
slack.search: { query: "in:#channel-name", days: N, count: 50 }
```

**Linear** — using the team key from sources.md:
```
linear.team-issues: { team: "KEY", days: N, limit: 100 }
linear.projects:    { team: "KEY" }
```

**P2s / MGS** — using the search terms from sources.md:
```
mgs.search: { query: "SEARCH_TERM", date_from: "YYYY-MM-DD", sort: "date_desc", per_page: 20 }
```

**GitHub** — for each repo in sources.md:
```
github.pull-requests: { owner: "ORG", repo: "REPO", state: "all", sort: "updated", direction: "desc", perPage: 20 }
github.releases:      { owner: "ORG", repo: "REPO", perPage: 5 }
```

**Reddit** — for each Reddit URL in sources.md, extract the subreddit name and:
```
mcp__reddit__get_top_posts:  { subreddit: "NAME", time_filter: "week", limit: 30 }
mcp__reddit__search_reddit:  { query: "SEARCH_TERM", subreddit: "NAME", sort: "new", time_filter: "week", limit: 30 }
```
Then fetch comments for the top 5–6 posts by score:
```
mcp__reddit__get_post_comments: { post_id: "ID", subreddit: "NAME", sort: "top", limit: 20 }
```

**Forums** — for each non-Reddit web URL in sources.md:
```
WebFetch: url, prompt: "List all threads from the last 7 days: title, date, reply count, brief summary."
```
Then fetch the body of the top 3 threads by reply count.

## Step 4 — Synthesize

Analyse all gathered data and organise into five sections. Prioritise signal over volume — a 40-reply forum thread outweighs 10 low-engagement Slack messages. Apply editorial judgment.

### Section 1 — Most Important Events (3–8 items)
Things that actually happened during the period: releases shipped, incidents triggered or resolved, major decisions made, significant features launched. Be factual and specific. Include version numbers, affected user counts, PR links.

### Section 2 — Wins (3–8 items)
Concrete positive outcomes with measurable impact: incidents resolved, launches that went smoothly, team milestones, tooling shipped. Favour impact over activity — "fixed crash affecting 9K users" beats "merged 3 PRs".

### Section 3 — Areas of Attention (3–8 items)
Things that require attention **beyond engineering**: user sentiment, public narratives, product confusion, support ticket trends, community signals from Reddit and forums, billing or onboarding issues. These are items for PM, marketing, CS, and leadership — not just the engineering team. Severity: Critical > High > Medium.

### Section 4 — Engineering Focus (6–10 items)
Specific actions and watches for the Head of Engineering: process gaps, stale PRs, stability risks, third-party dependencies, architectural decisions, tooling investments. Each item should name the next concrete action and link to the relevant artefact.

### Section 5 — From the Community (all relevant items)
Everything from Reddit and public forums, grouped by source. For Reddit: show score, title, 2–3 key quotes from top comments, and a direct link. For forums: show reply count, summary, and link. Include a prominent alert banner if there is strong positive or negative sentiment. List any competitor apps mentioned in community threads.

## Step 5 — Generate HTML

Write a self-contained HTML file. No external dependencies — all CSS and JS inline.

### Structure
- **Header**: team name, date range, subtitle listing sources
- **Sources row**: small chips for each source — ✓ (fetched) or ✗ (unavailable/blocked). Reddit should always be ✓ once the prerequisite MCP is installed.
- **Stat strip**: 4 key numbers from the week (choose the most impactful: crash events, upvotes on critical posts, PRs merged, releases shipped, etc.)
- **Tab navigation**: one tab per section, labels include item counts
- **Tab panels**: one per section, hidden/shown via vanilla JS

### Card design
Each item is a card with:
- Color-coded left border (severity band)
- Tag chip (e.g. "Critical", "Win", "Action")
- Title (bold, concise)
- 2–4 sentence description
- Platform chips: iOS · Android · Web · Server · All
- Links row: color-coded chips per destination type

### Link chip colors
- Slack → blue
- GitHub PR/release → gray
- P2 post → green
- Linear issue → purple
- Reddit thread → orange-red
- Forum thread → amber

### Severity bands (left border color)
- Critical → red
- High → amber
- Medium → blue
- Info/neutral → gray
- Win → green
- Engineering action → orange
- Community → rust/terracotta

### Platform chips
Small inline colored chips: iOS (sky blue), Android (green), Web (purple), Server (orange), All (gray).

### Community section specifics
- Orange alert banner at the top if Reddit or forums show strong sentiment (positive or negative)
- Chip list of competitor apps mentioned, if any
- Grouped by source with a small label (e.g. "Reddit — r/subreddit" / "Forums — support.example.com")
- Each post card: score or reply count badge, title, italicised key quotes, author/date/metadata, link chip

### Visual style
- Off-white page background (`#f5f4f0`), white cards, subtle gray borders
- System font stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`)
- Two-column card grid for Wins; single column for all other sections
- Fully mobile-responsive (single column below 640px)
- Tab switching via a small inline `<script>` — no frameworks

## Step 6 — Save and confirm

Write the HTML file to `AREA_DIR` (the selected area folder). Print the full output path and a 2–3 sentence summary of the most important findings across all sections.
