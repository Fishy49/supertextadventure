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

## Phase 4: Write all tests first

Write **both** unit tests and system (integration) tests before any implementation.

### 4a: Unit tests
1. Create the unit test file(s) described in the plan's **Test plan** section.
2. Follow the exact patterns in `test/lib/classic_game/handlers/` — use `ClassicGameTestHelper`, `FakeGame`, `build_world`, `build_game`, `player_state_in`.
3. Run: `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/`
4. Confirm the tests **fail**. If they pass already, stop and report — something is wrong.

### 4b: System tests
1. Create system test file(s) that exercise the new functionality through the browser via `/dev/game`.
2. Follow the patterns in `test/system/qa_world/` — use `visit dev_game_path`, `find(".terminal-input").send_keys(...)`, and Capybara assertions.
3. Run: `bin/rails test:system`
4. Confirm the new system tests **fail**.

## Phase 5: Implement

Work through the **Implementation steps** from the plan in order:

1. Make each change as described using the Edit or Write tools.
2. After each logical unit of work, run: `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/`
3. Do not move to the next step until the current tests pass.

## Phase 6: Update QA world

Any new functionality (items, NPCs, creatures, room features, dialogue topics, etc.) must be represented in the QA world so it can be manually tested via `/dev/game` and exercised by system tests.

1. Update `test/support/qa_world_data.rb` to include representative examples of the new functionality.
2. Update or add system tests in `test/system/qa_world/` to cover the new QA world content.

## Phase 7: Full suite + RuboCop

Once all engine tests pass, run each command as a separate tool call:

1. `PARALLEL_WORKERS=1 bin/rails test`
2. `bin/rails test:system`
3. `bundle exec rubocop --parallel`

Fix all failures and offenses before continuing. Do not suppress RuboCop rules unless `.rubocop.yml` already disables that cop.

## Phase 8: Commit and mark ready

Run each command as a separate tool call:

1. `git add -A`
2. `git commit -m "feat: <feature title from spec>"`
3. `git push`
4. Run `gh pr view {number} --json body -q .body` — capture the output as the current body
5. Append a **Summary** section to the PR body using `gh pr edit`. Structure it as:

   ```markdown
   ## Summary

   <1-2 sentence high-level description of what changed and why>

   ### Changes
   - **file_or_area** — what changed and why
   - **file_or_area** — what changed and why
   - ...

   ### Test results
   - Unit: X runs, Y assertions, 0 failures
   - System: X runs, Y assertions, 0 failures
   - RuboCop: X files, no offenses
   ```

   Keep each bullet concise (one line). Group related changes into a single bullet
   (e.g. one bullet for "fixture + helper + seeds" rather than three separate ones).
   Use the `--body` flag with the full body (current body + appended summary).
   Write the body to a temp file and pass it via `--body-file` to avoid shell quoting issues.
6. `gh pr ready {number}`

## Output

Print:
```
✓ PR #{number} is ready for review: https://github.com/Fishy49/supertextadventure/pull/{number}
```

Then print the test count (runs/assertions/failures/errors) from the final test run.
