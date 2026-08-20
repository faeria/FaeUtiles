# Cortex foundation

Status: Complete
Owner: Codex
Last updated: 2026-08-20

## Outcome

Cortex loads as a Retail addon, persists account and character state, records the current character outside combat, and answers `/cortex now` with explainable recommendations derived from player-authored goals.

## Current state

The repository contains development guidance but no addon TOC or Lua implementation. The installed directory is named `FaeUtiles`, so the development TOC must remain `FaeUtiles.toc`; its player-facing title and Lua namespace are Cortex. A release package should rename the containing folder and TOC together to `Cortex`.

## API evidence

- Client: Retail 12.1.0, interface `120100`.
- Source branch/build: `Gethe/wow-ui-source` `live`, commit `9f2b839dbb9059f00dedb10628db1da28dd9cad4`, build 69382 (2026-08-18).
- `CreateFrame`, `Frame:RegisterEvent`, `Frame:UnregisterEvent`, and `Frame:SetScript`: standard event-frame pattern used throughout Blizzard addons; no secure template is involved.
- Events: `ADDON_LOADED` (addon-name payload), `PLAYER_LOGIN`, `PLAYER_LOGOUT`, and conditionally `PLAYER_REGEN_ENABLED`. Event arguments are decoded only in `Core/Bootstrap.lua`; the regen event is unregistered as soon as deferred capture completes.
- `UnitFullName`, `UnitGUID`, `UnitClass`, and `UnitLevel`: verified in `Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`. Identity APIs are annotated for Secret Values; Cortex reads only the `player` unit outside combat and rejects every secret return before comparison, concatenation, or table indexing.
- `GetLocale`: verified in `Interface/AddOns/Blizzard_APIDocumentationGenerated/LocaleDocumentation.lua`; no arguments, non-nil locale string return.
- `DEFAULT_CHAT_FRAME:AddMessage` and the global slash-command registry are used by Blizzard chat UI code. Cortex writes only on explicit user commands or WARN/ERROR log calls.
- Assumptions still requiring in-game verification: whether an alternate addon named Cortex already owns `/cortex`; static inspection cannot detect an installed command collision.

## Design

The first vertical slice keeps boundaries explicit: game events call the context service; persisted goals feed rules; the recommendation engine validates, sorts, and caches results; the planner selects work fitting a requested time budget; the chat adapter renders localized text. No raw WoW value reaches the recommendation or UI layers.

Account data lives in `CortexDB`; character session data lives in `CortexCharacterDB`. Both roots have independent schema versions and incremental migration tables. Default merging adds missing keys without overwriting valid values.

## Steps

- [x] Add the Retail TOC, shared namespace, localization, and level-based logger.
- [x] Add versioned account/character persistence and safe outside-combat character capture.
- [x] Add goals, rules, recommendation prioritization, session planning, and chat commands.
- [x] Run available static checks and update documentation/change notes.

## Validation

- [x] TOC load order and all 12 Lua entries verified on disk.
- [x] Lua Language Server check at Warning level under Lua 5.1: no problems found.
- [x] JSON configuration, trailing whitespace, `git diff --check`, and forbidden-pattern scan passed.
- [ ] Fresh login or `/reload` — not run; requires the Retail client.
- [ ] `/cortex`, goal add/list/done, `now 30`, and log-level commands — not run; requires the Retail client.
- [ ] Reload and logout/login persistence — not run; requires the Retail client.
- [ ] Reload during combat and deferred capture on `PLAYER_REGEN_ENABLED` — not run; requires the Retail client.
- [ ] No Lua errors, taint warnings, chat spam, or obvious performance regression — static risk audit passed; final confirmation requires the Retail client.

## Risks and rollback

The only version-sensitive reads are player identity calls. Secret-value guards and out-of-combat deferral make failure graceful: character capture is skipped and retried after combat without affecting goals. Removing the TOC entry for `Context/ContextService.lua` and its bootstrap calls disables capture without invalidating saved goals.

No protected frames, secure attributes, combat data, addon communications, hooks, timers, or `OnUpdate` scripts are introduced.

## Decisions and progress

- 2026-08-20 — Chose a chat-first vertical slice so behavior is independently testable before committing to a full window or Settings UI.
- 2026-08-20 — Targeted interface `120100` after verifying the `live` source build rather than assuming the earlier 12.0.x value.
- 2026-08-20 — Kept `FaeUtiles.toc` for this installed folder; player-facing metadata remains Cortex.
- 2026-08-20 — Rejected restricted player values before every Lua comparison, formatting operation, concatenation, and table key use.
- 2026-08-20 — Static analysis completed with the Lua Language Server 3.18.2 in Lua 5.1 mode; no warning-level diagnostics remain.

## Result

Implemented a complete chat-first foundation across 12 load-ordered Lua files. Account goals and Warband records use `CortexDB`; session timestamps use `CortexCharacterDB`; both roots migrate independently. Goal changes invalidate the recommendation cache, and the planner selects prioritized, unblocked recommendations that fit the requested duration.

Static validation passed. In-game checks are explicitly outstanding because the Retail client cannot be driven from this workspace shell; the exact manual matrix is documented in `README.md`.
