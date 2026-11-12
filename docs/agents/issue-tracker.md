# Issue tracker

DogeDock tracks issues and specs in `harryxu/omarchy-dogedock` on GitHub. Use the `gh` CLI. Set `GH_REPO=harryxu/omarchy-dogedock` for these commands to target DogeDock explicitly, including from a fork.

## Issues and specs

- **Create or publish** with `gh issue create --title "..." --body-file <path>`.
- **Read a ticket** with `gh issue view <number> --json number,title,body,labels,comments`.
- **List tickets** with `gh issue list --state open --json number,title,body,labels,comments`. Use `--label` and `--state` to scope the results.
- **Comment** with `gh issue comment <number> --body-file <path>`.
- **Change labels** with `gh issue edit <number> --add-label <label>` or `--remove-label <label>`. Use [the triage label mapping](triage-labels.md) when a skill names a triage role.
- **Close** by posting the explanation as a comment, then running `gh issue close <number>`.

## Parent issues and dependencies

- Create a sub-issue with `gh issue create --parent <parent> ...` or attach an existing issue with `gh issue edit <parent> --add-sub-issue <child>`. If sub-issues are unavailable, start the child's body with `Part of #<parent>`.
- Use native GitHub issue dependencies with `gh issue create --blocked-by <number>,<number> ...` or `gh issue edit <child> --add-blocked-by <blocker>`. If dependencies are unavailable, put `Blocked by: #<number>, #<number>` at the top of the child issue.
- A ticket is unblocked when all its blockers are closed. Check the native open blocker count with `gh api repos/harryxu/omarchy-dogedock/issues/<number> --jq .issue_dependencies_summary.blocked_by`.

## Pull requests as a triage surface

**PRs as a request surface: no.**

When enabled, use the issue triage labels and states with `gh pr view`, `gh pr diff`, `gh pr comment`, `gh pr edit`, and `gh pr close`. Use author association to identify external PRs. GitHub issues and PRs share a number space. Resolve an ambiguous number with `gh pr view <number>`, then `gh issue view <number>` if needed.

## Wayfinding

- Keep Notes, Decisions-so-far, and Fog in one issue labeled `wayfinder:map`.
- Link tickets as sub-issues and label them `wayfinder:<type>`, where the type is `research`, `prototype`, `grilling`, or `task`. If sub-issues are unavailable, use a task list in the map and include the parent reference in each child.
- Take the first open, unassigned ticket in map order with all blockers closed. Claim it with `gh issue edit <number> --add-assignee @me`.
- Resolve a ticket by posting the answer, closing it, and adding a short summary and link to Decisions-so-far on the map.
