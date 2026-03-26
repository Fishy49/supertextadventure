---
name: build-feature
description: Full pipeline — ingest a spec, plan the implementation, implement it, and mark the PR ready for review. No human checkpoints.
argument-hint: [spec-filename (optional)]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(bin/rails *), Bash(bundle *), Skill
model: sonnet
effort: low
context: fork
---

# Build Feature (Full Pipeline)

Orchestrates the complete feature factory by calling each skill in sequence:

1. `/ingest-feature` — create branch, draft PR, rename spec file
2. `/plan-feature` — explore codebase, write implementation plan
3. `/implement-feature` — tests first, then code, mark PR ready

No human checkpoints. The first human touchpoint is the PR ready for review.

On any failure, stop immediately. Update the progress checklist to show which phase
failed, then print what failed and what the human needs to do to unblock.

> **Important:** This skill is a thin orchestrator. All logic lives in the
> individual skills above. Do NOT duplicate their instructions here.

---

## Progress checklist

After ingest creates the PR, maintain a **Build Progress** section in the PR body.
Use `gh pr edit {number} --body-file <tmpfile>` to update it at each transition.

The checklist format (always replace the entire Build Progress section, preserving
everything else in the PR body):

```markdown
## Build Progress

- [x] Ingest (started 10:01 UTC · finished 10:03 UTC)
- [ ] Plan (started 10:03 UTC)
- [ ] Implement
```

Rules:
- Use `date -u +%H:%M` (via Bash) to get the current UTC time at each transition.
- Mark a phase `[x]` only when the skill returns successfully.
- When a phase starts, append `started HH:MM UTC` in parens.
- When a phase finishes, append `· finished HH:MM UTC` to the same parens.
- If a phase fails, append `· **FAILED** HH:MM UTC` and stop.
- Write the full PR body to a temp file and use `--body-file` to avoid shell quoting issues.

Update the checklist at these six points:
1. After ingest succeeds — initialize checklist with ingest done, plan/implement pending
2. Before plan starts
3. After plan succeeds (or fails)
4. Before implement starts
5. After implement succeeds (or fails)

---

## Phase 1: Find the spec filename

If `$ARGUMENTS` names a specific file, use that as the spec filename.

Otherwise:
1. List all files in `specs/` using Glob.
2. Find unprocessed files: filename does NOT start with `pr-`.
3. If none: print "No unprocessed specs found." and stop.
4. If exactly one: use it.
5. If multiple: print "Multiple unprocessed specs — pass a filename:" followed by the list, then stop.

## Phase 2: Ingest

Invoke the skill:
```
/ingest-feature <spec-filename>
```

When it completes, note the PR number and the new `pr-{number}-{filename}` from its output. If it fails, stop and report.

After ingest succeeds, initialize the progress checklist on the PR (see above).

## Phase 3: Plan

Update the checklist to show Plan started.

Invoke the skill:
```
/plan-feature pr-{number}-{filename}
```

If it prints open questions or ambiguities, note them but continue — do not stop for human input. If it fails, update the checklist to show Plan failed, then stop and report.

Update the checklist to show Plan finished.

## Phase 4: Implement

Update the checklist to show Implement started.

Invoke the skill:
```
/implement-feature pr-{number}-{filename}
```

If it fails, update the checklist to show Implement failed, then stop and report.

Update the checklist to show Implement finished.

## Output

Print the final output from `/implement-feature` (the PR link and test counts).
