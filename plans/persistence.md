# Cortex persistence

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex remembers a compact account-wide view of known characters, active goals, recent history, module settings, and the last resumable session for each character across reloads and multi-day absences.

## Current state

`CortexDB` currently uses account schema version 2 and stores settings, goals, and character records under `warband.characters`. `CortexCharacterDB` stores only login/logout timestamps. Migrations are incremental but mutate the loaded table directly, and there is no snapshot, bounded history, or read-only debug inspection API.

The development addon is loaded from `FaeUtiles.toc`. Both SavedVariables are already declared. `CortexCharacterDB` remains declared temporarily so version-2 installations can import their per-character timestamps; all new persistent state is written to `CortexDB`.

## API evidence

- Client: Retail 12.1.0, interface `120100`.
- Source branch/build: `Gethe/wow-ui-source` `live`, commit `9f2b839dbb9059f00dedb10628db1da28dd9cad4`, build 69382 (2026-08-18), as recorded in `plans/cortex-foundation.md`.
- `UnitGUID("player")`: verified in `Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`; its accessible out-of-combat value is the stable character key. Cortex does not fall back to character name when the GUID is unavailable or restricted.
- `PLAYER_LOGIN` and `PLAYER_LOGOUT`: existing verified lifecycle events decoded by `Core/Bootstrap.lua`; no new game event is introduced.
- `time()`: existing addon timestamp source; no new version-sensitive API is introduced.
- Assumptions still requiring verification: none for the storage shape. SavedVariables persistence across `/reload` and logout/login requires in-client validation.

## Design

`CortexDB` schema version 3 owns the required roots: `settings`, `characters`, `goals`, `history`, `sessions`, `warband`, and `modules`. Character and session records are keyed by the accessible player GUID. A session snapshot stores timestamps, a minimal last-known state, active goal IDs, and selected task references; it does not copy equipment, currencies, quests, or other immediately queryable game state.

Migration runs against a deep copy and replaces the global SavedVariables table only after all migration and validation steps succeed. Version 3 moves `warband.characters` to `characters` and `settings.modules` to `modules.states`, preserving entries before removing the duplicate legacy locations. Migration steps remain forward-only and idempotent.

Light repositories encapsulate characters, bounded history, and session snapshots. Debug inspection returns deep copies so callers cannot mutate persisted state accidentally.

## Steps

- [x] Define schema version 3 defaults, validation, and compact snapshot limits.
- [x] Add idempotent version-3 migration and atomic initialization.
- [x] Add lightweight character, history, and session repositories.
- [x] Capture login/logout, goal references, and planned task references.
- [x] Add read-only debug inspection and a compact `/cortex debug db` summary.
- [x] Add migration/snapshot tests and persistence documentation.

## Validation

- [x] Lua 5.1 error-level analysis: no problems in 25 addon files or 2 test files.
- [ ] Clean `CortexDB` initialization — fixture added; dynamic execution unavailable because no standalone Lua runtime is installed.
- [ ] Account migrations from versions 1 and 2 to 3 preserve data — fixtures added; dynamic execution unavailable locally.
- [ ] Re-running version-3 migration is idempotent — fixture added; dynamic execution unavailable locally.
- [ ] Debug-returned tables cannot mutate SavedVariables — fixture added; dynamic execution unavailable locally.
- [ ] Snapshot history and reference lists remain bounded — fixture added; dynamic execution unavailable locally.
- [x] TOC audit: 25 entries, no missing, duplicate, or unlisted production Lua files; smoke loader order matches exactly.
- [x] Localization parity: 58 English and 58 French keys.
- [x] `git diff --check` and sensitive-pattern scan passed.
- [ ] Fresh login or `/reload` in Retail.
- [ ] Logout/login persistence in Retail.
- [ ] No Lua errors, taint warnings, chat spam, or obvious performance regression.

## Risks and rollback

The principal risk is corrupting existing version-2 tables. Copy-before-migrate prevents partial writes, and the migration moves legacy collections only after copying every recoverable entry. A newer unknown schema is opened read-only rather than rewritten. Removing `Data/Repositories.lua` and reverting the account schema constant restores the previous implementation; users already migrated to version 3 would then need the forward schema retained.

## Decisions and progress

- 2026-08-23 — Selected `UnitGUID("player")` as the only character key; a missing/restricted GUID skips persistence instead of creating an ambiguous name key.
- 2026-08-23 — Kept `CortexCharacterDB` only as a one-release migration bridge. New state is account-wide in `CortexDB`.
- 2026-08-23 — Chose bounded reference snapshots over copying derived WoW state.
- 2026-08-23 — Made account migration atomic by migrating a deep copy and publishing it only after migration and validation succeed.
- 2026-08-23 — A clean install leaves `CortexCharacterDB` nil; it is initialized only when legacy per-character data was actually loaded.
- 2026-08-23 — Static validation completed with Lua Language Server 3.18.2. Dynamic smoke execution remains outstanding because this workstation has no standalone Lua runtime.

## Result

Implemented account schema version 3, GUID-keyed character records, compact session snapshots, bounded history, lightweight repositories, and defensive debug inspection. Existing version-1/2 character and module data is moved to the new roots, and legacy per-character timestamps are imported when present.

All available static, TOC, localization, diff, and secret checks pass. The two smoke fixtures parse without errors but still require execution in a Lua runtime, followed by the documented Retail `/reload` and logout/login matrix.
