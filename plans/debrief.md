# Cortex Debrief

## Objective

Provide a strictly post-combat encounter summary using only public Midnight APIs classified as supported in `docs/DEBRIEF_FEASIBILITY.md`.

## Scope

- Capture explicit `ENCOUNTER_START` / `ENCOUNTER_END` metadata.
- Read native Damage Meter aggregates only outside combat.
- Expose result, native duration, deaths, interrupts, absorbs, and native avoidable damage.
- Reject secret, inaccessible, ambiguous, or unavailable values.

## Explicit exclusions

- Combat Log and deprecated combat APIs.
- Detailed death recap fields until their public schema is documented.
- Defensive usage, missed interrupts, tactical mistakes, and combat recommendations.
- Addon communication for combat telemetry.

## Validation

- Static TOC/file dependency check.
- Smoke test: no detailed Damage Meter read in combat.
- Smoke test: exact session-name matching and supported aggregate copy after combat.
- Manual Retail checks: successful encounter, wipe, unavailable Damage Meter, duplicate session names, `/reload`, combat entry/exit, and Lua/taint errors.
