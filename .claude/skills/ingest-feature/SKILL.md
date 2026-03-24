---
name: ingest-feature
description: Ingest a feature spec from specs/, create a branch and draft PR, rename the spec file with the PR number, and add a PR link to the top of the file.
argument-hint: [spec-filename]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *)
context: fork
---

# Ingest Feature Spec

Register a spec file in `specs/` by creating a branch, opening a draft PR,
and linking the two together. Does not implement anything — that is a separate step.

**When called with no argument:** auto-selects if exactly one unprocessed spec
exists, otherwise fails with a list of candidates.
**When called with a `pr-X-` prefixed file:** reports current PR state and exits.

> **Important:** Every shell command must be a single, simple call — no `$()`,
> no `&&` chains. Use separate tool calls and carry values between them.

---

## Phase 1: Find the spec

If `$ARGUMENTS` names a specific file, use that.

Otherwise:
1. List all files in `specs/` using Glob.
2. Identify unprocessed files: filename does NOT start with `pr-`.
3. If none: print "No unprocessed specs found in specs/" and stop.
4. If exactly one: proceed with it.
5. If multiple: print "Multiple unprocessed specs found — pass a filename as an argument:" followed by the list, then stop.
6. If `$ARGUMENTS` names a `pr-X-` file: run `gh pr view {number} --json state,isDraft,title` and report the result, then stop.

## Phase 2: Validate the spec

Read the spec file and verify:
- It has a top-level `#` heading
- It has an `## Acceptance criteria` section with content

On failure: print exactly what is missing and stop. Do not create anything.

## Phase 3: Set up the branch and draft PR

Run each command as a separate tool call:

1. `git checkout main`
2. `git pull`
3. Derive branch name from filename: strip `.md`, replace `_` with `-`, prefix `feature/`
   e.g. `npc_dialogue_trees.md` → `feature/npc-dialogue-trees`
4. `git checkout -b <branch-name>`
5. `git push -u origin <branch-name>`
6. `git commit --allow-empty -m "chore: initialize <branch-name>"`
7. `git push`
8. Run `gh pr create --draft --title "<# heading from spec>" --body "<body>"` where the body is:
   ```
   <2-3 sentence summary of what the feature does, written for a reviewer>

   Spec: specs/pr-{number}-{original_filename}
   ```
   The PR URL is printed by `gh pr create` — parse the PR number from that URL directly.
   Do not run a second command to fetch the PR number.

## Phase 4: Rename the spec file and add PR link

1. Use the Edit tool to prepend the following to the top of the spec file (above the `#` heading):
   ```
   > PR: https://github.com/Fishy49/supertextadventure/pull/{number}

   ```
2. Use the Bash tool to rename the file:
   `git mv specs/{original_filename} specs/pr-{number}-{original_filename}`
3. `git add specs/`
4. `git commit -m "chore: link spec to PR #{number}"`
5. `git push`

## Output

Print a single summary line:
```
✓ PR #{number} created: https://github.com/Fishy49/supertextadventure/pull/{number} — specs/pr-{number}-{filename}
```
