# Retail API capabilities audit

Status: Complete
Owner: Codex
Last updated: 2026-08-20

## Outcome

Maintainers can decide which Cortex features are technically reliable on WoW Retail 12.1.0 from a source-backed capability matrix, including combat, instance, Secret Value, protected-action, and addon-communication constraints.

## Current state

Cortex currently reads only the local player's identity/class/level outside combat and persists user-authored goals. No gameplay domain collectors beyond character identity exist. The requested audit is documentation-only and does not change runtime code, load order, SavedVariables, or UI.

## API evidence

- Client: Retail 12.1.0, interface `120100`.
- Source branch/build: `Gethe/wow-ui-source` `live`, commit `9f2b839dbb9059f00dedb10628db1da28dd9cad4`, build `12.1.0.69382`.
- Primary definitions: `Interface/AddOns/Blizzard_APIDocumentationGenerated`, 613 generated documentation files.
- Transition checks: `Interface/AddOns/Blizzard_Deprecated` from the same commit.
- Blizzard call sites: relevant first-party UI addons will be inspected when generated definitions do not establish lifecycle or availability.
- Assumptions still requiring verification: runtime data completeness and cache timing that are not expressed by generated definitions; these will be labeled `TO VERIFY` rather than inferred.

## Design

`docs/API_CAPABILITIES.md` will define the four requested availability grades, then provide one row per meaningful data capability. Broad domains may have several rows when read-only state, history, account scope, or protected mutation differ materially.

The final section will identify an MVP containing only stable, read-only, outside-combat capabilities. Combat-facing analysis will be separated from historical post-combat data, because Midnight's restriction annotations can differ between live and historical sessions.

## Steps

- [x] Inventory generated systems and exact API symbols for every requested domain.
- [x] Audit Secret Values, restricted maps/instances, combat lockdown, protected actions, and addon communication.
- [x] Write the capability matrix with evidence paths and explicit `TO VERIFY` gaps.
- [x] Propose a technically reliable MVP and validate documentation consistency.

## Validation

- [x] Every requested domain appears in the matrix (27 requested domain labels, 43 matrix rows).
- [x] Every fully-qualified API symbol exists in the pinned `live` source (45 checked); legacy globals are backed by current Blizzard callsites or labeled `TO VERIFY`.
- [x] Secret/restriction claims match generated annotations.
- [x] Markdown table structure checked (43 rows, 0 malformed rows); pinned source links reviewed.
- [x] No runtime files or SavedVariables changed.

## Risks and rollback

The audit is a snapshot of build 69382 and will age as Retail changes. The document will carry its exact build and require revalidation on interface changes. Rollback is deletion of the documentation and this plan; runtime behavior is unaffected.

## Decisions and progress

- 2026-08-20 — Pinned the audit to the current `live` commit rather than treating all Retail 12.x builds as identical.
- 2026-08-20 — Chose generated Blizzard definitions as the authority for signatures and `Secret*` annotations.
- 2026-08-20 — Separated current-instance metadata from durable instance history, and official post-combat aggregates from the restricted raw combat log.
- 2026-08-20 — Kept mutation APIs out of the Cortex scope whenever the generated metadata does not establish the exact protected/hardware-event contract; these points are labeled `TO VERIFY`.

## Result

Created `docs/API_CAPABILITIES.md` as the version-pinned project reference. The recommended MVP is a read-only, outside-combat progression assistant; raw live combat analysis, critical in-instance communications, and gameplay mutations are deferred.
