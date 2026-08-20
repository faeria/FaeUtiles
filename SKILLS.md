# SKILLS.md

This file defines the project playbooks agents should apply to recurring World of Warcraft addon work. These are repository procedures, not claims that a WoW API exists.

## `wow-api-research`

Use before introducing or changing an API, event, enum, widget method, mixin, template, or callback.

1. Identify the target client as Retail and the intended behavior.
2. Search the `live` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).
3. Prefer generated definitions under `Interface/AddOns/Blizzard_APIDocumentation*` for signatures.
4. Inspect Blizzard addon call sites for lifecycle and usage constraints.
5. Check `Interface/AddOns/Blizzard_Deprecated` for transition guidance.
6. Record the exact symbol, source path, branch/commit when relevant, arguments, returns, nilability, and restrictions.
7. Implement only after the evidence is sufficient; otherwise keep the uncertainty visible in the plan.

Deliverable: a short API evidence section in the active plan or change notes.

## `wow-event-feature`

Use when implementing behavior driven by game events.

1. List the minimum events and verify each payload.
2. Define when handlers register and unregister.
3. Decode event arguments at the boundary, then call focused domain functions.
4. Make repeated/out-of-order events safe where practical.
5. Coalesce event bursts and avoid expensive work in the handler.
6. Test login/reload and the actual state transitions that emit the event.

Deliverable: event lifecycle, payload assumptions, and manual scenarios documented in the plan.

## `wow-secure-ui`

Use for action buttons, bindings, unit frames, secure templates, protected frames, or any code that can encounter combat lockdown.

1. Verify which frames, attributes, and methods are protected.
2. Separate unrestricted visual updates from protected mutations.
3. Apply protected configuration out of combat.
4. Queue necessary changes during combat and flush them on `PLAYER_REGEN_ENABLED`.
5. Prefer supported templates, state drivers, callbacks, and `hooksecurefunc` over replacement hooks.
6. Test before combat, during combat, and immediately after combat.
7. Treat blocked actions and taint logs as failures.

Deliverable: a combat/taint risk section and explicit in-game checks.

## `wow-saved-variables`

Use when adding or changing persisted settings or data.

1. Declare the SavedVariables name in the `.toc` file.
2. Define documented defaults and a schema version.
3. Validate loaded data before use.
4. Merge missing defaults without overwriting valid user choices.
5. Write idempotent migrations for schema changes.
6. Avoid storing transient or derived data.
7. Test a clean profile, an existing profile, migration, `/reload`, and logout/login.

Deliverable: schema/defaults, migration path, and persistence checks.

## `wow-ui-component`

Use when creating or extending frames, widgets, tooltips, menus, or settings panels.

1. Verify relevant Blizzard templates/mixins and whether they are public/stable enough to use.
2. Define frame ownership and cleanup.
3. Fully specify anchors, strata/level when needed, sizing, scaling, and show/hide lifecycle.
4. Keep player-facing strings localizable.
5. Avoid per-frame `OnUpdate` scripts unless event/callback/ticker designs cannot satisfy the requirement.
6. Test multiple UI scales, reload, state changes, and combat if relevant.

Deliverable: UI lifecycle and visual/manual validation notes.

## `wow-performance-check`

Use for scans, frequent events, combat-log handling, aura/unit updates, or `OnUpdate` logic.

1. Identify trigger frequency and worst-case work.
2. Remove redundant registrations and allocations in hot paths.
3. Cache only stable data with clear invalidation.
4. Throttle/coalesce refreshes without making state stale.
5. Measure with WoW profiling tools when available; do not assert an optimization without evidence.
6. Recheck correctness under event bursts and long sessions.

Deliverable: measured or reasoned performance impact plus regression checks.

## `wow-release-check`

Use before tagging or distributing the addon.

1. Verify `.toc` metadata, interface number, load order, dependencies, and SavedVariables declarations.
2. Ensure packaged files exclude `.git`, plans, local tooling, tests, screenshots, and development-only artifacts unless intentionally shipped.
3. Validate from a clean addon installation and clean character profile where possible.
4. Run the relevant manual matrix from `AGENTS.md`.
5. Confirm no Lua errors, taint warnings, missing assets, debug output, or secrets.
6. Summarize compatibility and known limitations in release notes.

Deliverable: a release checklist with results and the tested Retail build.
