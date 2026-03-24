---
name: build-feature
description: Full pipeline — ingest a spec, plan the implementation, implement it, and mark the PR ready for review. No human checkpoints.
argument-hint: [spec-filename (optional)]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(bin/rails *), Bash(bundle *)
context: fork
---

# Build Feature (Full Pipeline)

Runs the complete feature factory pipeline on a spec file:

1. **Ingest** — create branch, draft PR, rename spec file
2. **Plan** — explore codebase, write implementation plan into spec
3. **Implement** — tests first, then code, full suite + RuboCop
4. **Ship** — mark PR ready for review

No human checkpoints. The first human touchpoint is the PR ready for review.

On any failure, stop immediately and leave the repo in a clean state.
Print what failed and what the human needs to do to unblock.

> **Important:** Every shell command must be a single, simple call — no `$()`,
> no `&&` chains. Use separate tool calls and carry values between them.

---

## Phase 1: Find and validate the spec

If `$ARGUMENTS` names a specific file, use that.

Otherwise:
1. List all files in `specs/` using Glob.
2. Find unprocessed files: no `pr-` prefix.
3. If none: print "No unprocessed specs found." and stop.
4. If exactly one: proceed.
5. If multiple: print "Multiple unprocessed specs — pass a filename:" followed by the list, then stop.

Validate the chosen spec:
- Has a top-level `#` heading
- Has a non-empty `## Acceptance criteria` section

On failure: print what is missing and stop.

---

## Phase 2: Ingest

Run each command as a separate tool call:

1. `git checkout main`
2. `git pull`
3. Derive branch name: strip `.md`, replace `_` with `-`, prefix `feature/`
4. `git checkout -b <branch-name>`
5. `git push -u origin <branch-name>`
6. `git commit --allow-empty -m "chore: initialize <branch-name>"`
7. `git push`
8. `gh pr create --draft --title "<# heading>" --body "<2-3 sentence summary>\n\nSpec: specs/pr-{number}-{filename}"`
   Parse the PR number from the URL printed by this command — do not run another command to fetch it.
9. Use the Edit tool to prepend `> PR: https://github.com/Fishy49/supertextadventure/pull/{number}\n\n` to the spec file
10. `git mv specs/{filename} specs/pr-{number}-{filename}`
11. `git add specs/`
12. `git commit -m "chore: link spec to PR #{number}"`
13. `git push`

---

## Phase 3: Plan

Read each file individually using the Read tool (no shell commands for file reading):
- The full spec file (especially `## Acceptance criteria`)
- `app/lib/classic_game/base_handler.rb`
- `app/lib/classic_game/command_parser.rb`
- `app/lib/classic_game/engine.rb`
- All files in `app/lib/classic_game/handlers/`
- `test/support/classic_game_helper.rb`
- All files in `test/lib/classic_game/`

Use Grep to find existing code related to the feature.

Write an implementation plan with these five sections:

**1. Files to create** — full path + one-line purpose for each
**2. Files to modify** — full path + specific changes (name the methods/constants)
**3. Implementation steps** — ordered, atomic; include exact location and reasoning
**4. Test plan** — for each acceptance criterion: test name, setup, input, expected output
**5. Gotchas and constraints** — RuboCop rules, FakeGame methods, edge cases

Use the Edit tool to append to the end of the spec file:
```
---

## Implementation plan

> Generated {date}

{plan}
```

Then run each command as a separate tool call:
1. `git add specs/`
2. `git commit -m "chore: add implementation plan to PR #{number}"`
3. `git push`

Update the PR body:
1. `gh pr view {number} --json body -q .body` — capture the result as `current_body`
2. `gh pr edit {number} --body "{current_body}\n\n**Implementation plan added** — see spec file."`

---

## Phase 4: Implement

Using only the implementation plan (no additional codebase exploration):

**Tests first:**
1. Create test file(s) per the test plan using the Write tool.
2. `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/` — confirm tests fail.

**Implement:**
3. Work through implementation steps in order using Edit/Write tools.
4. After each logical unit: `PARALLEL_WORKERS=1 bin/rails test test/lib/classic_game/`
5. Do not proceed until current tests pass.

**Full validation — run each as a separate tool call:**
6. `PARALLEL_WORKERS=1 bin/rails test`
7. `bundle exec rubocop --parallel`
8. Fix all failures before continuing.

---

## Phase 5: Ship

Run each command as a separate tool call:

1. `git add -A`
2. `git commit -m "feat: <feature title>"`
3. `git push`
4. `gh pr view {number} --json body -q .body` — capture as `current_body`
5. `gh pr edit {number} --body "{current_body}\n\n## Summary\n\n<2-3 sentences on what was built>"`
6. `gh pr ready {number}`

Print:
```
✓ PR #{number} is ready for review: https://github.com/Fishy49/supertextadventure/pull/{number}
```

And the final test count.
