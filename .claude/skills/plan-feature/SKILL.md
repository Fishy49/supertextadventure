---
name: plan-feature
description: Read an ingested spec file, explore the codebase, write a detailed implementation plan, and append it to the spec file and PR.
argument-hint: [pr-X-spec-filename]
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Edit
model: opus
effort: high
context: fork
---

# Plan Feature Implementation

Read an ingested spec and produce a detailed implementation plan that a
separate agent can execute without further codebase exploration.

**Requires a `pr-X-` prefixed spec filename as argument.**
**When called with no argument:** auto-selects if exactly one ingested-but-unplanned
spec exists, otherwise fails with a list of candidates.

> **Important:** Every shell command must be a single, simple call — no `$()`,
> no `&&` chains. Use separate tool calls and carry values between them.

---

## Phase 1: Find the spec

If `$ARGUMENTS` names a specific file, use that.

Otherwise:
1. List all files in `specs/` using Glob.
2. Find files with a `pr-` prefix that do NOT already contain `## Implementation plan`.
3. If none: print "No specs awaiting a plan." and stop.
4. If exactly one: proceed with it.
5. If multiple: print "Multiple specs awaiting a plan — pass a filename:" followed by the list, then stop.

## Phase 2: Check preconditions

1. File must have a `pr-X-` prefix. If not, print "Run /ingest-feature first." and stop.
2. Extract the PR number by reading the `> PR: ...` line at the top of the file.
3. Run `gh pr view {number} --json state,isDraft` — if merged or closed, print the state and stop.
4. If `## Implementation plan` already exists in the file, print "Plan already exists for PR #{number}." and stop.

## Phase 3: Explore the codebase

Read each file individually using the Read tool (not shell commands):

- The full spec file (especially `## Acceptance criteria`)
- `app/lib/classic_game/base_handler.rb`
- `app/lib/classic_game/command_parser.rb`
- `app/lib/classic_game/engine.rb`
- All files in `app/lib/classic_game/handlers/`
- `test/support/classic_game_helper.rb`
- All files in `test/lib/classic_game/`

Use Grep to find existing code related to the feature.

## Phase 4: Write the implementation plan

The plan must be detailed enough that an implementer needs **zero additional
codebase exploration**. Include all five sections:

### 1. Files to create
Each new file: full path + one-line purpose.

### 2. Files to modify
Each changed file: full path + specific changes (name the methods/constants
being added or changed, not just "update this file").

### 3. Implementation steps
Ordered, atomic steps. For each:
- What to write/change
- Exact location (file + class/method)
- Why, if non-obvious

### 4. Test plan
For each acceptance criterion, one test case:
- **Test name**
- **Setup**: world hash, player state, flags, inventory
- **Input**: the command string
- **Expected output**: exact text or pattern to assert

### 5. Gotchas and constraints
- Patterns from existing handlers that must be followed
- Active RuboCop rules (MethodLength max 60, double-quoted strings, etc.)
- FakeGame methods available in tests
- Edge cases implied by the spec but not stated

## Phase 5: Append the plan to the spec file

Use the Edit tool to append to the end of the spec file:

```
---

## Implementation plan

> Generated {date}

{plan from Phase 4}
```

Then run each git command as a separate tool call:
1. `git add specs/`
2. `git commit -m "chore: add implementation plan to PR #{number}"`
3. `git push`

Then update the PR body:
1. Run `gh pr view {number} --json body -q .body` — capture the output as the current body
2. Run `gh pr edit {number} --body "{current body}\n\n**Implementation plan added** — see spec file."`
   where `{current body}` is the literal text returned in step 1

## Output

Print a single summary line:
```
✓ Implementation plan written for PR #{number} — ready to implement.
```

Then print any open questions or ambiguities the implementer should be aware of.
