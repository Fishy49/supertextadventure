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

On any failure, stop immediately. Print what failed and what the human needs to do to unblock.

> **Important:** This skill is a thin orchestrator. All logic lives in the
> individual skills above. Do NOT duplicate their instructions here.

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

## Phase 3: Plan

Invoke the skill:
```
/plan-feature pr-{number}-{filename}
```

If it prints open questions or ambiguities, note them but continue — do not stop for human input. If it fails, stop and report.

## Phase 4: Implement

Invoke the skill:
```
/implement-feature pr-{number}-{filename}
```

If it fails, stop and report.

## Output

Print the final output from `/implement-feature` (the PR link and test counts).
