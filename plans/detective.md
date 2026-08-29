# Cortex Detective

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex can explain a goal, recommendation, or blocker at SUMMARY, DETAIL, and DEBUG levels using only recorded facts, rule identity, recommendation data, goal state, and dependency graph results. DEBUG exposes the deterministic Fact → Rule → Recommendation → Goal trace.

## Current state

- Facts already retain source, availability, reason, and timestamps in `FactStore`.
- Recommendations retain `ruleId`, reason, blockers, goal linkage, and scoring metadata, but rules do not declare their input fact keys.
- Goals expose normalized status/progress and dependency blockers.
- The Overview “Why?” control currently shows only `Recommendation:GetReason()`.

## API evidence

- Client: Retail 12.1.0 / Interface `120100`.
- No new WoW API, event, widget contract, SavedVariables key, or protected action is introduced.
- Detective reads only Cortex domain objects and sanitized FactStore records.

## Design

- Small immutable-style constructors normalize `Evidence`, `Condition`, `Blocker`, and `Explanation` records.
- Rules declare stable `factKeys`; RuleEngine copies this provenance into recommendation metadata.
- `DetectiveService` resolves a requested recommendation, goal, fact, or blocker and builds ordered evidence, conditions, blockers, and trace nodes.
- Player text is assembled from localized deterministic templates. Unknown data remains explicit and never becomes an inferred claim.
- Overview “Why?” uses Detective DETAIL output. `/cortex why ...` exposes all levels without adding a large UI surface.

## Event/UI lifecycle

- Detective registers no game event and owns no frame.
- Explanations are rebuilt on request from current facts and engines, so existing invalidation remains the source of truth.
- The existing recycled Overview card receives only a prebuilt explanation string.

## Steps

- [x] Add Detective domain records and deterministic rendering.
- [x] Add rule fact provenance and Recommendation accessors.
- [x] Implement target resolution and Fact → Rule → Recommendation → Goal tracing.
- [x] Wire Overview “Why?”, slash commands, TOC, localization, and documentation.
- [x] Add smoke coverage for all levels, blocked dependencies, unknown facts, and deterministic output.

## Validation

- [x] SUMMARY contains only the result and a supported reason.
- [x] DETAIL lists concrete known evidence and blockers.
- [x] DEBUG lists fact keys/status/source plus rule, recommendation, and goal nodes in stable order.
- [x] Repeated explanations over unchanged state are identical.
- [x] Missing targets and unknown facts are explicit.
- [x] Existing foundation/persistence tests, TOC check, and diff hygiene pass.
- [ ] Retail `/reload`, combat, scale, Lua-error, and taint checks remain in-game validation.

## Risks and rollback

The primary risk is implying causality that a rule did not declare. Explicit rule `factKeys` and neutral UNKNOWN evidence prevent that. Removing the Detective files and the metadata declarations restores the prior single-reason behavior without affecting SavedVariables.

## Decisions and progress

- 2026-08-23 — Kept Detective stateless; facts and engines remain authoritative and no explanation cache is persisted.
- 2026-08-23 — Chose explicit rule provenance instead of inspecting Lua closures or inventing causal links.

## Result

Implemented with stateless domain records, explicit rule provenance, slash/UI integration, and passing static smoke coverage. Retail `/reload`, combat, UI scale, Lua-error, and taint checks remain explicit in-game validation.
