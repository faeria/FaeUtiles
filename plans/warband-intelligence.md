# Cortex Warband Intelligence

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex progressively builds a compact account-wide roster from characters actually observed by Cortex. The active character is labelled LIVE, prior observations are CACHED with age, and never-captured fields are UNKNOWN. The Warband page summarizes every known character and cautious cross-character profession contributions.

## Current state

- `CortexDB.characters` stores GUID-keyed identity plus compact field-timestamped Warband observations.
- Character, item-level, profession, currency, and weekly facts feed snapshots only when their collector reports available sanitized data.
- The Warband module owns capture and conservative inter-character profession hints.
- The dashboard uses fixed recycled rows and explicit LIVE, CACHED, and UNKNOWN presentation states.

## API evidence

- Client: Retail 12.1.0 / Interface `120100`.
- No new WoW API or event is introduced. Capture consumes only sanitized existing facts from Character, Gear, Profession, Currency, and Weekly collectors.
- Offline characters are never queried. Their state comes exclusively from `CortexDB` snapshots recorded during earlier Cortex sessions.
- Per-character currencies persist only discovered, account-transferable, non-account-wide quantities; account-wide quantities remain live Context data and are not duplicated per character.

## Design

- Account schema 6 adds a validated compact snapshot to each GUID-keyed character record; character-record schema becomes 2.
- `WarbandRepository` owns merge, normalization, field timestamps, LIVE/CACHED/UNKNOWN projections, and deterministic roster reads.
- The default-enabled `Warband` module listens to internal login/context/logout events and updates only fields whose sanitized facts are currently available.
- Each snapshot field owns its own `capturedAt`, so a live identity can still expose CACHED or UNKNOWN item level, professions, weekly state, or transferable currency data.
- Cross-character reasoning matches a goal's explicitly declared profession skill-line/name requirement against recorded professions. The result is always POTENTIAL and explicitly states that recipes, reagents, and current craftability are unknown.
- `WarbandPage` uses fixed-capacity recycled character and insight rows; MainWindow supplies a localized view-model.

## SavedVariables

- `CortexDB.schemaVersion`: 5 → 6.
- Character records: schema 1 → 2 with `snapshot = { schemaVersion = 1, fields = {} }`.
- Existing identity, goal, session, history, module, and window data are preserved.
- No equipment links, full gear sets, full currency catalog, recipe catalog, or transient account-wide currency values are persisted.

## Event lifecycle

- `PLAYER_LOGIN`: establishes the boundary used to distinguish newly captured LIVE fields from older CACHED fields.
- Internal `CONTEXT_UPDATED`: captures only Character, Gear, Currency, Weekly, and Profession sources.
- `PLAYER_LOGOUT`: performs one final merge from available sanitized facts.
- Subscriptions exist only while the Warband module is enabled.

## Steps

- [x] Add schema-6 migration and defensive snapshot validation.
- [x] Add WarbandRepository with compact capture and state projection.
- [x] Add event-driven Warband module and cautious profession reasoning.
- [x] Replace the Warband placeholder with a localized recycled overview.
- [x] Update TOC, command/search integration, documentation, and tests.
- [x] Validate migrations, state semantics, bounded persistence, frame reuse, and diff hygiene.

## Validation

- [x] Existing schema-5 data migrates without identity or session loss.
- [x] Current character and freshly captured fields are LIVE.
- [x] Offline observations are CACHED and retain timestamps.
- [x] Missing fields remain UNKNOWN rather than receiving invented defaults.
- [x] Only transferable non-account-wide currencies are stored per character and the list is bounded.
- [x] Profession reasoning says potential contribution and never claims recipe/craft availability.
- [x] Warband page updates event-driven without frame growth.
- [x] Foundation and persistence smoke tests pass.
- [ ] Login, character switch, `/reload`, combat, UI scale, and taint require in-game validation.

## Risks and rollback

The primary risk is presenting stale offline data as current. Field-level timestamps and explicit CACHED/UNKNOWN labels prevent that ambiguity. Removing the Warband module and page leaves schema-6 snapshots inert and preserves all prior data.

## Decisions and progress

- 2026-08-23 — Kept offline knowledge strictly prospective: Cortex records only what it observed while that character was active.
- 2026-08-23 — Excluded recipe claims and full currency catalogs; profession matches are conceptual hints only.

## Result

Implemented and statically validated. Retail login, character switching, `/reload`, combat, scaling, and taint remain explicit in-game validation steps.
