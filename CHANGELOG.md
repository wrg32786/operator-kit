# Changelog

All notable changes to AIgent Operator Kit are documented here.

## [2.1.2] - 2026-08-08

### Added

- A lightweight visual roster that maps each character identity directly to its agent definition.
- Agent display colors matching the roster: cyan Echo, blue Newton, red Hypatia, purple Iris, and green Lyra.
- README guidance for automatic delegation, guaranteed `@` invocation, deliberate code review, and explicit publishing.

### Changed

- Agent descriptions now encourage proactive delegation for clear task matches.
- Lyra returns verified working-tree changes but never commits, pushes, opens pull requests, enables auto-merge, or merges.
- Plugin acceptance CI now reads the manifest version dynamically instead of hardcoding it.

## [2.1.1] - 2026-08-08

### Fixed

- Corrected plugin-user setup instructions so they no longer assume a local clone.
- Corrected the hero description to match the actual Iris-to-Lyra design and build flow.
- Added an explicit privacy warning for context-loader excerpts.

### Added

- Smallest-team usage recipes: one specialist by default, composition only when roles cross.
- Platform support and uninstall guidance.
- A clean Claude Code CLI acceptance job that validates, installs, inspects, executes, and uninstalls the plugin.
- Automatic GitHub release publishing after the validated `main` build succeeds.

## [2.1.0] - 2026-08-08

### Added

- Native Claude Code plugin and self-hosted marketplace packaging.
- Least-privilege tool boundaries for all five agents.
- Dependency-free smoke validation and GitHub Actions CI.

### Changed

- Reworked the context loader to match only submitted prompt text, use project-local configuration first, reject path escapes, avoid project writes, and keep diagnostics opt-in.
- Hardened the legacy installer with fail-closed JSON handling, atomic writes, backups, migration, and idempotency.
