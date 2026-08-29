# Changelog

All notable changes to Cortex will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0-alpha] - 2026-08-29

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
- Account schema version 3 with GUID-keyed characters, bounded history, and compact resumable session snapshots.
- Atomic, idempotent migrations from schema versions 1 and 2 plus defensive read-only debug inspection.
- Lightweight repositories for characters, sessions, and history, with `/cortex debug db` summary output.
- Event-driven Context Engine with capability-scoped character, gear, currency, quest, weekly, instance, profession, reputation, location, and local Warband collectors.
- Timestamped facts with available/stale/unavailable states, last-known reads, targeted invalidation, burst coalescing, and manual debug refresh commands.
- Empty-socket and equipped upgrade-track detection without tooltip parsing; costs, vendor eligibility, and missing permanent enchants remain explicitly unavailable.
- Generic typed Goal Engine with persisted progress, dependency graph diagnostics, blockers, unblocked action discovery, and a Great Vault-backed weekly completion goal.
- `/cortex goal list`, `/cortex goal debug`, and `/cortex goal weekly [count]` commands.
- Account schema version 4 migration normalizing legacy goals to goal schema 2 without discarding their existing data.
- Generic rule-based Recommendation Engine with explainable recommendation objects, isolated rule failures, and deterministic deduplication.
- Extensible Importance, GoalRelevance, Urgency, Efficiency, and Cost scoring with debug breakdowns.
- Safe onboarding, goal action, blocked goal, weekly, empty socket, and remaining upgrade-track rules plus `/cortex recommend`.
- Modern non-secure Cortex dashboard with header, sidebar navigation, Overview cards, status footer, and reusable lightweight UI components.
- Event-driven recycled recommendation rows, inline “Why?” explanations, draggable/clamped placement, ESC handling, and persisted UI scale/position.
- Account schema version 5 with validated dashboard placement settings.
- Independent command registry and search provider with COMMAND, GOAL, RECOMMENDATION, CHARACTER, and MODULE results.
- Raycast-style command palette with live filtering, recycled rows, keyboard navigation, `/cortex` toggle, and assignable WoW key binding.
- Deterministic Session Planner with explicit duration estimates, finite/unlimited budgets, dependency-bundle ordering, blocker diagnostics, and optional current-map relevance.
- Reusable Plan and PlanEntry models plus a recycled Session dashboard page for 30, 60, 120 minute, and unlimited plans.
- Schema-6 Warband snapshots with independent field timestamps, LIVE/CACHED/UNKNOWN semantics, bounded transferable-currency data, and GUID-keyed repository access.
- Event-driven Warband Intelligence module, cautious cross-character profession contribution hints, and a paged recycled Warband dashboard.
- Deterministic Detective service with Evidence, Condition, Blocker, and Explanation records plus SUMMARY, DETAIL, and DEBUG rendering.
- Explicit rule fact provenance and Fact → Rule → Recommendation → Goal traces exposed through Overview “Why?” and `/cortex why`.
- Versioned, deterministic Share Codes for allowlisted goal, session, and task-list templates with bounded non-executable serialization and strict validation.
- Import/Preview/Confirm dialog, one-shot confirmation tokens, schema-7 template persistence, and clean rejection of incompatible, unknown, malformed, or oversized payloads.
- Disabled-by-default DEBUG profiler for collector, recommendation, UI, and event metrics.
- Compliant Debrief using only supported native post-combat encounter metadata and Damage Meter aggregates.
- Version-pinned technical audit covering performance, persistence, events, taint, Secret Values, APIs, and release gates.

### Changed

- `/cortex debug` now toggles DEBUG/INFO when called without an argument.
- Removed the `/ctx` alias to keep WoW-required global slash-command entries minimal.
- Tailored `.gitignore` for Lua tooling, addon packaging, editors, and local agent state.
- New persistent writes are centralized in `CortexDB`; `CortexCharacterDB` is retained only as a legacy timestamp migration bridge.
- Synchronized public alpha version metadata and added `/cortex version` plus expanded `/cortex status` diagnostics.

### Fixed

- Targeted Recommendation invalidation by source and materially changed facts, with one dependency-graph rebuild per recommendation pass.
- Coalesced event correctness, equipped-item cache filtering, Warband capture deduplication, and page-scoped UI refreshes.
- Retail API documentation aligned to build 12.1.0.69404, including the public `C_Reputation` namespace; release compatibility rechecked against build 12.1.0.69497.

<!--
Use these headings as needed for future releases:
Added, Changed, Deprecated, Removed, Fixed, Security.

Release example:
## [0.1.0] - YYYY-MM-DD
-->

[Unreleased]: https://github.com/faeria/FaeUtiles/compare/v0.1.0-alpha...HEAD
[0.1.0-alpha]: https://github.com/faeria/FaeUtiles/releases/tag/v0.1.0-alpha
