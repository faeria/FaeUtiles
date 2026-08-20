# Changelog

All notable changes to Cortex will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project guidance for World of Warcraft Retail addon development in `AGENTS.md`.
- Planning conventions and validation template in `PLANS.md`.
- Reusable WoW addon development playbooks in `SKILLS.md`.
- Retail 12.1.0 addon manifest with account and per-character SavedVariables.
- Versioned persistence with idempotent schema migrations and validation.
- Outside-combat, Secret Value-aware Warband character capture.
- Account-wide goal repository, explainable recommendation rules, cached prioritization, and time-budget planning.
- English fallback and French localization.
- `/cortex` commands with persistent ERROR through TRACE logging levels.
- Dependency-aware service/module registry and internal event bus.
- Transient fact store and explicit Context, Goals, Recommendations, and Planner contracts.
- Minimal non-secure Cortex window opened with `/cortex`.
- Persisted module state overrides with account schema migration from version 1 to 2.
- Keyed out-of-combat work queue driven by `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`.
- Foundation smoke test covering bootstrap, migration, dependencies, events, UI command, and combat deferral.

### Changed

- `/cortex debug` now toggles DEBUG/INFO when called without an argument.
- Removed the `/ctx` alias to keep WoW-required global slash-command entries minimal.
- Tailored `.gitignore` for Lua tooling, addon packaging, editors, and local agent state.

<!--
Use these headings as needed for future releases:
Added, Changed, Deprecated, Removed, Fixed, Security.

Release example:
## [0.1.0] - YYYY-MM-DD
-->

[Unreleased]: https://github.com/faeria/FaeUtiles/commits/main
