# Critical Rules — Survive Compaction

These rules MUST be followed regardless of what was discussed earlier in the session. If context has been compressed, re-read this file.

<!--
HOW TO USE THIS TEMPLATE

This file is designed to survive Claude Code's context compaction. When long sessions get compressed,
most conversation history is lost — but files explicitly included in your project settings are re-injected.

Wire this file so it always loads. Add an import line to your project's `CLAUDE.md`:

```
@rules/post-compact-critical.md
```

Claude Code reads `CLAUDE.md` on every session start and re-injects `@`-imported files automatically, including after context compaction. Place the import at the top of your CLAUDE.md so it is the first thing loaded.

Then fill in the rules below that matter for YOUR project. Delete the placeholder sections
and replace them with actual rules your agent must always follow.

Good candidates for this file:
- Database connection rules (which DB is production, which is test — don't mix them)
- Code style rules that must hold even mid-refactor
- Architectural invariants (never call X without Y, always check Z before writing to W)
- Vendor/API conventions specific to your stack
- Known footguns in your codebase that keep biting you
- Model routing rules if you use multiple Claude tiers

Keep rules short, directive, and absolute. "NEVER do X" and "ALWAYS do Y" format.
Rules that explain WHY they exist are more durable than rules that just state what to do.
-->

---

## Project identity

<!-- One sentence: what is this project and what does it do? -->

**[YOUR PROJECT NAME]** — [one sentence description].

---

## Data / storage rules

<!-- Example: -->
<!-- 1. ALWAYS verify DB connection before querying: run SELECT current_database() first. -->
<!-- 2. NEVER write to the test database when production data is involved. -->
<!-- 3. Production DB is [name/connection string identifier]. Never use [staging/test identifier]. -->

1. [Your data rule here]
2. [Your data rule here]

---

## Code rules

<!-- Example: -->
<!-- 1. NEVER skip error handling on async functions — all promises need .catch() or try/catch. -->
<!-- 2. ALWAYS run the linter before marking a task complete. -->
<!-- 3. Main branch is protected. NEVER push directly to main — always use a feature branch. -->

1. [Your code rule here]
2. [Your code rule here]

---

## Model routing

<!-- Only needed if you use multiple Claude tiers. -->
<!-- Example: -->
<!-- - haiku: reads, context loading, status checks -->
<!-- - sonnet: writes, code generation, edits -->
<!-- - opus: strategy, architecture decisions (main session only) -->

- [Your routing rule here]

---

## Known footguns

<!-- The mistakes that keep happening. State them bluntly. -->
<!-- Example: -->
<!-- 1. The payments webhook does NOT fire on sandbox — always test with the CLI trigger. -->
<!-- 2. Cache invalidation is manual — after any schema change, run `npm run cache:clear`. -->

1. [Your footgun here]
2. [Your footgun here]

---

## Verification rules

<!-- What counts as "done"? What must be checked before reporting success? -->
<!-- Example: -->
<!-- 1. "It works locally" is not done. Deploy to staging and verify the actual endpoint responds. -->
<!-- 2. NEVER report a fix complete without running the test suite. -->

1. [Your verification rule here]
