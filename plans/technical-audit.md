# Cortex technical audit

Status: Complete (static audit; Retail manual validation pending)
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex has an evidence-backed technical audit, targeted invalidation for high-impact recomputation paths, and an opt-in low-overhead DEBUG profiler. No player-facing feature is added.

## Current state

- The addon is modular and uses an internal event bus, collector registry, persisted repositories, and lazily-created reusable UI rows.
- Context collector events are coalesced per collector and recommendation invalidation is filtered by source plus materially changed facts.
- Warband capture writes only the requested fields and publishes only material changes or `CACHED -> LIVE` transitions.
- MainWindow routes notifications to the visible page/region that consumes them and creates frames once.
- SavedVariables collections are bounded where expected; initialization defensively copies and validates the full account database once per load.

## API evidence

- Client: World of Warcraft Retail 12.x / Midnight.
- Source: Gethe/wow-ui-source `live`, commit `81d15e42f16f3473131880500e7a8c8eb88fa5e6`, build `12.1.0.69404`.
- APIs/events/widgets: inventory, currency, quest, weekly rewards, reputation/renown, map, profession, restriction, frame, combat-lockdown, and damage-meter symbols used by the repository.
- Remaining `TO VERIFY`: exact generated annotations for legacy inventory, profession and instance globals confirmed through Blizzard callsites.

## Design

- Keep existing ownership and module boundaries.
- Add source and fact declarations to recommendation rules so only relevant material changes invalidate the cache.
- Narrow Warband snapshot capture to the field changed by each source.
- Route UI notifications to only the pages/regions that consume them; frames remain created once and rows recycled.
- Add a disabled-by-default Profiler service with constant-time early exits when disabled.

## Steps

- [x] Map load order, dependencies, events, frames, persistence, and caches.
- [x] Trace and classify duplicate context/goal/recommendation/UI work.
- [x] Verify every WoW API and event against current `live` source.
- [x] Apply CRITICAL/HIGH fixes that do not require functional redesign.
- [x] Add the opt-in profiler and DEBUG inspection commands.
- [x] Write `docs/TECHNICAL_AUDIT.md` with severity, evidence, fixes, and remaining risks.
- [x] Run available static checks and document smoke-test/in-game validation gaps.

## Validation

- [x] TOC load order and declared file existence.
- [ ] Existing smoke tests — blocked by absence of Lua/LuaJIT/luac or a compatible Lua parser.
- [x] Static scan for `OnUpdate`, globals, API/event references, and protected mutations.
- [x] Recommendation rebuild assertions added for Gear, unchanged Gear and unrelated Location updates; runtime execution pending.
- [ ] Fresh login, `/reload`, combat enter/leave, persistence, Lua errors, taint, and event burst checks in Retail (manual if client unavailable).

## Risks and rollback

Targeted invalidation can make recommendations stale if a new rule omits its context source. Registration validation and audit documentation must make source declarations explicit. The smallest rollback is to restore broad `CONTEXT_UPDATED` invalidation while keeping profiling enabled only on demand.

## Decisions and progress

- 2026-08-23 — Treat direct Gear→Warband full snapshot copying and broad Context→Recommendation invalidation as high-priority performance/coupling findings because both occur on ordinary equipment events.
- 2026-08-23 — Do not add timers or `OnUpdate`; use existing event-driven paths and fixed frame pools.
- 2026-08-23 — Refine source invalidation to `changedFactKeys`; preserve conservative source-wide fallback for legacy publishers.
- 2026-08-23 — `C_Reputation` is the verified public namespace; the generated source filename is `ReputationInfoDocumentation.lua`.

## Result

Audit and non-redesign CRITICAL/HIGH corrections complete. Manual Retail validation remains a release gate and is documented in `docs/TECHNICAL_AUDIT.md`.
