---
name: implement-feature
description: Read an ingested, planned spec file and implement the feature — tests first, then code, then mark the PR ready for review.
argument-hint: [pr-X-spec-filename]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(bin/rails *), Bash(bundle *)
context: fork
---

# Implement Feature

Execute the implementation plan from a spec file. Writes tests first, then
implements, then marks the PR ready for review.

**Requires a `pr-X-` prefixed spec filename with an `## Implementation plan` section.**

> **Important:** Every shell command must be a single, simple call — no `$()`,
> no `&&` chains. Use separate tool calls and carry values between them.

---

## Phase 1: Find the spec

If `$ARGUMENTS` names a specific file, use that.

Otherwise:
1. List all files in `specs/` using Glob.
2. Find files with a `pr-` prefix that contain `## Implementation plan` but whose PR is still a draft.
3. If none: print "No specs ready to implement." and stop.
4. If exactly one: proceed with it.
5. If multiple: print "Multiple specs ready — pass a filename:" followed by the list, then stop.

## Phase 2: Check preconditions

1. File must have `## Implementation plan`. If not, print "Run /plan-feature first." and stop.
2. Extract PR number from the `> PR:` line at the top of the file.
3. Run `gh pr view {number} --json state,isDraft` — if merged or closed, print the state and stop.
4. Derive branch name from filename: strip `pr-X-` prefix, strip `.md`, replace `_` with `-`, prefix `feature/`
5. `git checkout <branch-name>`

## Phase 3: Read the plan

Read the full spec file using the Read tool. The `## Implementation plan` section is the authoritative source — do not re-explore the codebase beyond what the plan references.

## Phase 4: Write tests first

1. Create the test file(s) described in the plan's **Test plan** section.
2. Follow the exact patterns in `test/lib/classic_game/handlers/` — use `ClassicGameTestHelper`, `FakeGame`, `build_world`, `build_game`, `player_state_in`.
3. Run: `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/`
4. Confirm the tests **fail**. If they pass already, stop and report — something is wrong.

## Phase 5: Implement

Work through the **Implementation steps** from the plan in order:

1. Make each change as described using the Edit or Write tools.
2. After each logical unit of work, run: `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/`
3. Do not move to the next step until the current tests pass.

## Phase 6: Full suite + RuboCop

Once all engine tests pass, run each command as a separate tool call:

1. `PARALLEL_WORKERS=1 bin/rails test`
2. `bundle exec rubocop --parallel`

Fix all failures and offenses before continuing. Do not suppress RuboCop rules unless `.rubocop.yml` already disables that cop.

## Phase 7: Commit and mark ready

Run each command as a separate tool call:

1. `git add -A`
2. `git commit -m "feat: <feature title from spec>"`
3. `git push`
4. Run `gh pr view {number} --json body -q .body` — capture the output as the current body
5. Run `gh pr edit {number} --body "{current body}\n\n## Summary\n\n<2-3 sentences on what was implemented>"`
   where `{current body}` is the literal text returned in step 4
6. `gh pr ready {number}`

## Output

Print:
```
✓ PR #{number} is ready for review: https://github.com/Fishy49/supertextadventure/pull/{number}
```

Then print the test count (runs/assertions/failures/errors) from the final test run.
