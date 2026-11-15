# Issue tracker: GitHub

Issues and specs live in https://github.com/Fusion2k/smash-fight.
Use the gh CLI for all operations.

## Conventions

Pass --repo Fusion2k/smash-fight explicitly to gh issue, gh pr,
and gh label commands. This also avoids local Git ownership
checks interfering with repository discovery.

- Create: gh issue create --repo Fusion2k/smash-fight --title "..." --body-file <file>
- Read: gh issue view <number> --repo Fusion2k/smash-fight --json number,title,body,labels,comments
- List: gh issue list --repo Fusion2k/smash-fight --state open --json number,title,body,labels,comments
- Comment: gh issue comment <number> --repo Fusion2k/smash-fight --body-file <file>
- Labels: gh issue edit <number> --repo Fusion2k/smash-fight --add-label "..." or --remove-label "..."
- Close: post the explanation as a comment, then run gh issue close <number> --repo Fusion2k/smash-fight.
  Comment separately even when the issue is already closed.

Use a temporary UTF-8 file for multiline bodies.

## Parent issues and blockers

Use native GitHub sub-issues:
gh issue edit <parent> --repo Fusion2k/smash-fight --add-sub-issue <child>

Use native GitHub dependencies:
gh issue edit <child> --repo Fusion2k/smash-fight --add-blocked-by <blocker>

If unavailable, put "Part of #<parent>" and "Blocked by: #<number>"
at the top of the child body, and link children from the parent.

An issue is startable only when all its blockers are closed.
Count open blockers with:
gh api repos/Fusion2k/smash-fight/issues/<number> --jq .issue_dependencies_summary.blocked_by

## Repository targeting

File issues only in the user's repository. Before the first issue
creation in a session, verify the destination:
gh repo view Fusion2k/smash-fight --json nameWithOwner

Never file into mattpocock/skills unless the user owns that repository.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Skill operations

"Publish to the issue tracker" means create a GitHub issue.
"Fetch the relevant ticket" means read the GitHub issue.

## Wayfinding operations

- Map: one issue labelled wayfinder:map, containing Notes,
  Decisions-so-far, and Fog.
- Children: sub-issues labelled wayfinder:research,
  wayfinder:prototype, wayfinder:grilling, or wayfinder:task.
- Frontier: the first open child in map order with no open
  blockers and no assignee.
- Claim: assign the ticket to @me before working.
- Resolve: comment with the answer, close the ticket, and append
  a summary and link to the map's Decisions-so-far.
