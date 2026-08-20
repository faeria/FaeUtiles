# Initial modular architecture

Status: Complete
Owner: Codex
Last updated: 2026-08-20

## Outcome

Cortex starts through a deterministic lifecycle, exposes registered services and modules through `Cortex:GetService` and `Cortex:GetModule`, supports runtime/persisted module enablement, publishes internal events, captures context safely outside combat, and opens a minimal localized window with `/cortex`.

## Current state

The repository already contains a small vertical slice with versioned account/character data, current-character capture, goals, recommendation rules, a planner, localized commands, and a single event frame. Components are attached directly to the private addon table and their dependencies are implicit in TOC order. `/cortex` currently prints help instead of opening UI.

The existing account schema is version 1. Adding persisted module settings requires an idempotent migration to version 2. Existing goals and Warband snapshots must be preserved.

## API evidence

- Client: Retail 12.1.0, interface `120100`.
- Source branch/build: `Gethe/wow-ui-source` `live`, commit `9f2b839dbb9059f00dedb10628db1da28dd9cad4`, build `12.1.0.69382`.
- Already verified in `docs/API_CAPABILITIES.md`: `InCombatLockdown`, `UnitFullName`, `UnitGUID`, `UnitClass`, `UnitLevel`, Secret Value inspection primitives, and the Midnight addon restriction model.
- Verified events: `ADDON_LOADED` in `Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`; `PLAYER_LOGIN` and `PLAYER_LOGOUT` in `SystemDocumentation.lua`; `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` in `UnitDocumentation.lua`. Only `ADDON_LOADED` is decoded, using its verified `addOnName` first payload.
- Verified UI surface: unnamed `Frame`/`Button`, addon-owned textures/font strings, anchors, size, text, show/hide, and scripts. Current Blizzard callsites and SharedXML font objects confirm `GameFontNormalLarge` and `GameFontHighlight`; no secure template or protected frame is used.
- Secret access helpers: `issecretvalue`, `issecrettable`, and `canaccessvalue` from `FrameScriptDocumentation.lua`.
- Assumptions still requiring verification: no unresolved API symbol was introduced. Actual taint and rendering behavior still require an in-client run.

## Design

- The private table passed through `...` remains the only Cortex namespace. WoW-required SavedVariables and slash-command registration are the only global entries.
- `ModuleRegistry` owns service/module descriptors, explicit service and module dependency lists, initialization ordering, enabled state, and persisted overrides.
- `EventBus` is internal and synchronous. Subscribers have owners, can be removed by token or owner, and errors are isolated through the logger.
- `Bootstrap` owns the only game-event frame. It initializes the registry on `ADDON_LOADED`, publishes lifecycle events, tracks combat lockdown, queues keyed out-of-combat work, and flushes it on `PLAYER_REGEN_ENABLED`.
- Services own infrastructure/state (`Logger`, `Database`, `Facts`, `Context`, UI/navigation/commands). Modules own domain behavior (`Goals`, `Recommendations`, `Planner`). Empty feature-module folders will not be created until they have behavior, avoiding inert scaffolding.
- Account schema version 2 adds `settings.modules`. Missing/invalid values are repaired without replacing existing user data.
- The minimal window is unnamed, non-secure, centered, and built lazily. It does not use `OnUpdate`, secure templates, bindings, or global frame names.

## Steps

- [x] Verify lifecycle events and minimal UI calls against the pinned Retail source.
- [x] Add constants, EventBus, and dependency-aware service/module registry.
- [x] Split schema/migrations/database and migrate account data to version 2.
- [x] Add FactStore and register Context, Goals, Recommendations, and Planner through explicit dependencies.
- [x] Add minimal UI/navigation and adapt `/cortex` plus `/cortex debug`.
- [x] Rebuild TOC order and validate every declared dependency and referenced file.
- [x] Update project documentation and record validation results.

## Validation

- [x] Every TOC path exists, has the intended order, and is loaded once: 24 entries, 0 missing, 0 duplicate.
- [x] Every declared service/module dependency is registered and acyclic: 12 nodes, 0 unresolved.
- [x] Lua 5.1 syntax parse passes for all 24 addon files plus the smoke test (`luaparse` 0.3.1).
- [x] Isolated smoke test preserves schema-1 goals, migrates to schema 2, and validates persisted module states.
- [x] Isolated smoke test initializes once, dispatches login, and captures the mocked current character.
- [x] Isolated smoke test toggles the minimal window and persisted DEBUG/INFO commands.
- [x] Isolated smoke test publishes lockdown and flushes deferred context refresh after combat.
- [x] Static scan finds no secure template, protected action, combat-log reader, addon communication, `OnUpdate`, or addon-owned global. The two SavedVariables and one slash identifier are WoW-required globals.
- [ ] In-client `/reload`, visual, combat, taint, and persistence checks were not available in this environment; follow the README manual matrix before release.

## Risks and rollback

Load-order or dependency mistakes could prevent startup; static registry validation and TOC checks mitigate this. Migration errors could damage settings; migrations only merge missing keys and retain schema-1 structures. The UI is unprotected and can be disabled by removing its TOC entries without affecting persistence.

## Decisions and progress

- 2026-08-20 — Chose one small registry rather than a framework or dependency-injection container.
- 2026-08-20 — Kept feature module directories absent until implementation; the registry itself is exercised by the existing Goals, Recommendations, and Planner domains.
- 2026-08-20 — Restricted global writes to the two SavedVariables and the WoW-mandated slash command identifiers.
- 2026-08-20 — A disabled module cannot be removed while an enabled dependent requires it; enabling a module first enables and persists its module dependencies.
- 2026-08-20 — The test harness mirrors the TOC load list exactly and mocks only the small WoW surface required by these foundations. It is a logic smoke test, not proof of Retail runtime compatibility.

## Result

Implemented the modular foundation, migrated account schema 1→2, added a minimal localized window and command routing, and validated syntax, TOC order, dependency resolution, migration, event delivery, module state, and combat deferral. No large gameplay feature was added. Retail in-client validation remains the release gate.
