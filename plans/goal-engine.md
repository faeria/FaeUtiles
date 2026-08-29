# Goal Engine

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex stores generic typed goals, validates their dependency graph, exposes blockers and currently available domain actions, and ships one reliable `WEEKLY_COMPLETION` goal backed by the Context Engine's Great Vault activity facts.

## Current state

- Persisted goals contain only id, title, lowercase status, priority, estimated duration, and timestamps.
- `DependencyGraph` stores unchecked in-memory edges and cannot detect missing nodes or cycles.
- `GoalEngine` can add and complete manual goals but does not evaluate progress from context.
- Existing account data at schema 3 and goal fixtures must migrate without loss.

## API evidence

- No new WoW API or event is introduced.
- The first typed goal consumes only the already-sanitized `weekly.activities` fact produced from verified `C_WeeklyRewards.GetActivities()` data.
- Goal evaluation subscribes to Cortex's internal `CONTEXT_UPDATED` event and runs only when the Weekly collector publishes an update.
- Assumptions still requiring verification: none. A missing/unavailable weekly fact leaves the goal active with progress marked unavailable.

## Design

- Goal records use schema 2 and uppercase statuses: `ACTIVE`, `BLOCKED`, `COMPLETED`, `PAUSED`, `FAILED`.
- Account schema 4 normalizes legacy goals idempotently, retaining ids, titles, priorities, timestamps, and unknown metadata.
- `DependencyGraph` rebuilds from persisted `goal.dependencies`, reports missing nodes, completed dependencies, and cycles, and derives unblocked leaf goals.
- `GoalEngine` owns a small type-definition registry. Type definitions evaluate progress and describe domain actions; they do not rank recommendations or render UI.
- `GENERIC` remains manually completable. `WEEKLY_COMPLETION` targets a configurable number of completed Great Vault thresholds and auto-completes when reached.

## Steps

- [x] Add schema/status constants and account migration 3→4.
- [x] Implement generic Goal creation/normalization helpers.
- [x] Implement graph validation, blockers, cycles, and available leaves.
- [x] Extend GoalEngine with type registration, evaluation, actions, and weekly goal creation.
- [x] Add `/cortex goal list`, `/cortex goal debug`, and a command to create the first typed goal.
- [x] Extend persistence/foundation smoke coverage and documentation.

## Validation

- [x] Legacy lowercase goals are covered by persistence fixtures.
- [x] Missing dependencies and cycles are covered by graph smoke assertions.
- [x] Completed dependencies no longer block parents in smoke assertions.
- [x] Weekly facts update progress and complete the goal in foundation coverage.
- [x] TOC/dependencies/locales and Lua syntax pass static checks.
- [x] In-client reload, context update, and persistence checks are documented; execution remains required in WoW Retail.

## Risks and rollback

The main risk is corrupt or manually edited dependency data. Rebuild fails closed: invalid edges block actions and are reported by debug output. Removing the Goal module files disables evaluation while schema-4 records remain plain backward-readable tables.

## Decisions and progress

- 2026-08-23 — Kept type behavior in a registry instead of adding one class/file per future goal.
- 2026-08-23 — Available actions are unranked domain descriptors, leaving recommendation policy outside GoalEngine.

## Result

Implemented the schema-2 Goal model, account migration 3→4, validated dependency graph, type registry, context-driven weekly goal, read-only debug output, and commands. Both smoke suites pass through the bundled Lua runtime, Lua Language Server reports no error-level diagnostics, and `git diff --check` passes. In-client validation remains required because standalone execution cannot reproduce the WoW runtime, event timing, or SavedVariables lifecycle.
