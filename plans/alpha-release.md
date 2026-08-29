# Cortex 0.1.0-alpha release preparation

Status: Complete
Owner: Codex
Last updated: 2026-08-29

## Outcome

Cortex can be copied into Retail as a clearly identified `0.1.0-alpha` build, starts with debug facilities disabled, exposes truthful version/status diagnostics, and ships maintainer/player documentation that matches the implemented code.

## Current state

- The runtime manifest is `FaeUtiles.toc`; the visible addon title and Lua namespace are `Cortex`.
- `CortexDB` is the account database. `CortexCharacterDB` remains declared only as a legacy migration bridge.
- Account schema is currently version 7 and module state is persisted under `CortexDB.modules`.
- `/cortex status` exists but does not yet expose every requested field; `/cortex version` is absent.
- The worktree contains the cumulative, uncommitted Cortex implementation and must be preserved.
- No project license declaration has been found locally so far; a license will not be invented.

## API evidence

- Client: World of Warcraft Retail / Midnight.
- Source: `Gethe/wow-ui-source` `live`, commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`, build `12.1.0.69497`, checked 2026-08-29.
- `version.txt` reports `12.1.0.69497`; changes since Cortex's build-69404 API audit add unrelated Unit assistance contracts, adjust Blizzard aura/private-aura implementation, and add Voice Chat secret annotations. No API called by Cortex changed.
- Interface remains `120100`; no new WoW API is introduced by this release-preparation pass.
- Runtime behavior and API capabilities remain bounded by `docs/API_CAPABILITIES.md` and `docs/DEBRIEF_FEASIBILITY.md`.

## Design

- Keep the existing runtime graph and SavedVariables schema unchanged.
- Synchronize the release string between the TOC and `Core/Constants.lua`.
- Add read-only registry/database diagnostics needed by `/cortex status` only if existing public methods are insufficient.
- Keep all new player-facing output in both locale files.
- Replace broad implementation claims in the README with a concise, verifiable alpha surface and explicit limitations.

## Steps

- [x] Audit manifest metadata, file existence/order, namespace globals, settings/defaults, migrations, modules, slash commands, and combat-sensitive patterns.
- [x] Implement synchronized `0.1.0-alpha`, `/cortex version`, and complete `/cortex status` output.
- [x] Add/update README, changelog, architecture, and development documentation; add LICENSE only if an existing license can be proven.
- [x] Run syntax/static, localization, TOC, migration/module, and smoke checks available in the workspace.
- [x] Record release gate results and the remaining in-game validation matrix.

## Validation

- [x] Every non-comment TOC entry exists exactly once and dependencies load before consumers.
- [x] TOC and runtime versions match; SavedVariables declarations match code globals.
- [x] Locale keysets match and new output has English/French entries.
- [x] Lua syntax/static checks pass. Standalone smoke execution is unavailable because no Lua interpreter is installed; test files and TOC load lists were checked statically.
- [x] Fresh-profile, migration, idempotence, and newer-schema fixtures are present and parse cleanly; execution still requires a compatible Lua runtime.
- [x] Debug logging and profiling are disabled in defaults.
- [x] Static scan finds no combat-log reader, addon communication, protected action, or `OnUpdate` loop.
- [ ] In-game: clean install, login/reload, `/cortex`, version/status, module toggles, combat entry/exit, logout/login persistence, Lua errors and taint. Not available from this environment; mandatory before public upload.

## Risks and rollback

The main risk is declaring runtime confidence without launching the WoW client. Static and fixture checks can verify structure and pure-Lua behavior, but UI, taint, event payloads, and SavedVariables disk writes still require in-game validation. The release metadata/command changes can be reverted independently without migrating the database.

## Decisions and progress

- 2026-08-29 — Retained the `FaeUtiles` technical addon id because the installed directory and matching manifest already use it; public docs will make the required folder name explicit.
- 2026-08-29 — Did not infer a software license. A `LICENSE` file will only be added if the repository history or project metadata proves one.
- 2026-08-29 — Verified 71 TOC entries with zero missing/duplicates and an exact match with the foundation smoke-test load list; `Core/Bootstrap.lua` is last.
- 2026-08-29 — Verified 23 services and 5 modules with no duplicate or missing dependency. Late `MainWindow` lookups remain intentional cycle breakers; `ChatCommands` now declares its Profiler dependency.
- 2026-08-29 — Verified account migrations 1–7, character migration 1, default log level INFO, and profiling disabled.
- 2026-08-29 — Lua Language Server 3.18.2 checked 81 files in Lua 5.1 mode with no Error diagnostics. The 286 English/French locale keys and format placeholders match.
- 2026-08-29 — `git diff --check` passes; CRLF conversion notices are informational only. Static scans found no combat-log/addon-message/protected-action/secure-template/`OnUpdate` usage.
- 2026-08-29 — No standalone Lua interpreter or WoW client was available. Smoke execution and the Retail manual matrix remain publication gates, not assumed passes.

## Result

The `0.1.0-alpha` release candidate is structurally installable and documented. Version/status diagnostics and static release gates pass. Public upload remains blocked on the explicit in-game validation matrix and a maintainer licensing decision if the project is intended to grant reuse rights.
