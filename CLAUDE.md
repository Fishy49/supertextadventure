# SuperTextAdventure

A Rails 8 text adventure game engine with a classic parser-based game mode.

## Writing a feature spec

Feature specs live in `specs/` and drive the build pipeline (`/ingest-feature` → `/plan-feature` → `/implement-feature`).

### Required structure

```markdown
# Feature Title

Brief description of what the feature does and why.

## Acceptance criteria

- Concrete, testable statement of done
- Another criterion
- ...
```

The `# heading` and `## Acceptance criteria` section are **required** — the ingest tool will reject the file without them.

### Optional sections

Add any of these if they help clarify intent:

- **Player-facing behaviour** — examples of what the user sees (commands, output)
- **Constraints** — hard rules, performance bounds, security requirements
- **Gotchas** — edge cases, known pitfalls, things to verify before assuming they work

### Tips

- Keep it short. Describe *what* and *why*, not *how* — the plan step figures out implementation.
- Name the file descriptively with underscores (e.g. `qa_world.md`). The pipeline derives the branch name from it.
- Don't add a `pr-` prefix — that's added automatically by `/ingest-feature`.

### Pipeline

1. **`/ingest-feature`** — creates a branch, opens a draft PR, links the spec
2. **`/plan-feature`** — reads the spec, explores the codebase, writes an implementation plan
3. **`/implement-feature`** — writes tests first, implements, runs full suite, marks PR ready

## Preferences
> **Important:** Every shell command must be a single, simple call — no `$()`,
> no `&&` chains. Use separate tool calls and carry values between them.

## Full-Game System Test

Any feature that adds or modifies ClassicGame mechanics **must** update
`test/lib/classic_game/full_game_system_test.rb` to exercise the new
behavior. The test serves as a blocking sanity check in CI.
