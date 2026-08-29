# Context Engine

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex exposes a queryable, timestamped business context built from small WoW API collectors. Game events invalidate only their owning collector, burst events are coalesced, unavailable/restricted values retain a last-known value separately, and debug commands can request a refresh without persisting transient API data.

## Current state

- `Context/FactStore.lua` stores one value and timestamp per key.
- `Context/ContextService.lua` currently captures only the active character.
- `Core/Bootstrap.lua` asks Context for a refresh on `PLAYER_LOGIN` and already defers work during combat lockdown.
- The account database persists compact character/session snapshots; live context data remains memory-only.
- The TOC is `FaeUtiles.toc`; its displayed addon title and namespace are Cortex.

## API evidence

- Client: Retail 12.1.0 / Midnight, interface `120100`, build `69382` as pinned in `docs/API_CAPABILITIES.md`.
- Source branch/build: `Gethe/wow-ui-source` `live`, audited reference commit `9f2b839dbb9059f00dedb10628db1da28dd9cad4`.
- Character: `UnitFullName`, `UnitGUID`, `UnitClass`, `UnitLevel`; event `PLAYER_LEVEL_UP`.
- Gear: `GetInventoryItemID`, `GetInventoryItemLink`, `C_Item.GetDetailedItemLevelInfo`, `C_Item.GetItemNumSockets`, `C_Item.GetItemGemID`, `C_Item.GetItemUpgradeInfo`, `C_PaperDollInfo.GetInspectItemLevel("player")`; events `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`, `GET_ITEM_INFO_RECEIVED`. Empty sockets and remaining upgrade-track levels are copied from documented structures. Upgrade costs/vendor eligibility and missing permanent enchants remain unavailable.
- Currency: `C_CurrencyInfo.GetCurrencyListSize`, `GetCurrencyListInfo`, `GetCurrencyInfo`; event `CURRENCY_DISPLAY_UPDATE(currencyType, quantity, quantityChange, quantityGainSource, destroyReason)`.
- Quest: `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `GetQuestObjectives`, `IsComplete`, `ReadyForTurnIn`; events `QUEST_LOG_UPDATE`, `QUEST_DATA_LOAD_RESULT`. Nilable or inaccessible ready-for-turn-in results make the aggregate fact unavailable rather than being treated as false.
- Weekly: `C_WeeklyRewards.GetActivities`, `CanClaimRewards`, `HasAvailableRewards`; events `WEEKLY_REWARDS_UPDATE`, `WEEKLY_REWARDS_ITEM_CHANGED`.
- Instance: `IsInInstance`, `GetInstanceInfo`; event `PLAYER_ENTERING_WORLD`.
- Profession: current Blizzard call sites use `GetProfessions` and `GetProfessionInfo`; event `SKILL_LINES_CHANGED`. This legacy global contract must be rechecked on each client build.
- Reputation/renown: `C_Reputation.GetNumFactions`, `GetFactionDataByIndex`, `C_MajorFactions.GetMajorFactionIDs`, `GetMajorFactionData`; events `FACTION_STANDING_CHANGED`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, `MAJOR_FACTION_UNLOCKED`.
- Location: `C_Map.GetBestMapForUnit`, `GetMapInfo`, `GetPlayerMapPosition`; events `PLAYER_MAP_CHANGED`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`.
- Restrictions: `issecretvalue`, `issecrettable`, `canaccessvalue`, `InCombatLockdown`, `C_RestrictedActions.IsAddOnRestrictionActive`, and `ADDON_RESTRICTION_STATE_CHANGED`. Every collector runs outside combat and is also suspended for `Combat`, `Encounter`, `ChallengeMode`, `PvPMatch`, and `Map`; `Chat` is irrelevant because this engine does not communicate. Only individually accessible whitelisted fields are copied. No Secret Value is compared, used as a key, persisted, or fed to recommendations.
- Warband: no universal public Warband roster/state API exists. The collector derives only compact facts from Cortex's locally observed characters and verified account-wide currency/reputation flags.
- Assumptions still requiring verification: reliable missing permanent-enchant applicability. It is not implemented.

## Design

Each collector is a descriptor registered before service initialization. `ContextService` owns one event frame, maps each verified event to the minimum collector set, marks those facts stale immediately, and coalesces the actual reads to the next frame. Collection is deferred through Cortex's combat-lockdown queue. `FactStore` distinguishes `available`, `stale`, and `unavailable`, preserves a last-known value, and records `checkedAt`/`updatedAt`.

## Steps

- [x] Extend FactStore with status, source replacement, timestamps, and last-known reads.
- [x] Add collector registration/utilities and the ten capability-backed collectors.
- [x] Replace the single-character ContextService with targeted event routing and coalescing.
- [x] Add `/cortex debug context` and `/cortex debug refresh [collector]`.
- [x] Update TOC/test load order and add context smoke coverage.
- [x] Run static checks and document unavailable in-game validation.

## Validation

- [x] TOC entries exist and preserve explicit dependency order (37 entries, none missing).
- [ ] Existing foundation and persistence smoke tests were not executed because no standalone Lua runtime is installed; both test files pass Lua Language Server error-level syntax analysis.
- [x] Foundation smoke coverage verifies targeted character invalidation, unavailable last-known values, timestamps, manual refresh, and combat deferral.
- [ ] Fresh login or `/reload` in Retail: unavailable from this environment.
- [ ] Equipment, currency, quest, weekly, reputation, profession, and zone transitions in Retail: unavailable from this environment.
- [ ] Combat entry/exit and deferred refresh in Retail: unavailable from this environment.
- [ ] Runtime Lua errors, forbidden/secret comparison errors, taint warnings, chat spam, and CPU behavior require the in-game matrix above.

## Risks and rollback

- API data can be nil while caches load. The store reports `unavailable` and retains last-known values without presenting them as current.
- Broad journal/reputation/currency events require bounded list scans. Bursts are coalesced and event ownership prevents unrelated scans.
- If a collector regresses on a future client, remove its TOC entry/registration without affecting the store or other collectors.

## Decisions and progress

- 2026-08-23 — Kept all live facts memory-only; only the existing compact character/session snapshot is persisted.
- 2026-08-23 — Rejected tooltip parsing; retained documented socket and `ItemUpgradeInfo` structures, without inferring costs or eligibility.
- 2026-08-23 — All collectors are read-only and out-of-combat; inaccessible values fail closed.

## Result

Implemented ten read-only collectors, a guarded collector registry, an event-driven/coalesced ContextService, and a status-aware FactStore. The TOC and localization sets are consistent, `git diff --check` passes, and Lua Language Server error-level checks report no problems for all addon and test files. Retail runtime, taint, and performance validation remains explicitly pending because the game client cannot be driven from this environment.
