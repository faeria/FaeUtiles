# AGENTS.md

## Scope

These instructions apply to the entire FaeUtiles addon repository.

## Project intent

FaeUtiles is a World of Warcraft Retail addon. Keep changes small, readable, and compatible with the current Retail client. Prefer the simplest implementation that satisfies the requested behavior; do not add frameworks or abstractions without a demonstrated need.

## Sources of truth

- Use the `live` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) for the current Retail UI implementation.
- Look first in `Interface/AddOns/Blizzard_APIDocumentation*` for generated API definitions and in Blizzard addons for usage examples.
- Treat copied Blizzard implementation details as unstable unless they are documented public API.
- Never invent an API, event, enum, mixin, widget method, argument, or return value. Verify it against the source for the matching client version.
- When behavior is version-sensitive, record the verified branch, file, and relevant interface/build version in the plan or change notes.

## Addon structure

- Keep a valid `.toc` file at the addon root. Its file order is the load order and must make dependencies explicit.
- Declare `## Interface`, `## Title`, and any SavedVariables in the `.toc` file. Update `## Interface` only after verifying the current Retail interface number.
- Prefer one responsibility per Lua file. Suggested folders are `Core/`, `Features/`, `UI/`, `Data/`, and `Locales/`; create only those the addon actually needs.
- Use XML only when it materially improves templates or inheritance. Prefer Lua for straightforward frame construction.
- Do not bundle Blizzard UI source files into this addon.

## Lua conventions

- Target the Lua dialect embedded by WoW; do not assume features from modern standalone Lua versions.
- Use `local` by default for variables and functions. Introduce globals only when WoW requires one, and namespace addon-owned globals under `FaeUtiles`.
- Start Lua entry files with the addon namespace pattern when useful: `local addonName, addon = ...`.
- Use descriptive `camelCase` names for locals/functions and `UPPER_SNAKE_CASE` for true constants. Use predicate names such as `isEnabled`, `hasAura`, and `canUpdate`.
- Prefer guard clauses over deep nesting. Keep functions focused and separate event decoding, state changes, and rendering when complexity grows.
- Do not modify tables returned or owned by Blizzard unless the API explicitly permits it. Copy data before normalizing or sorting.
- Comments explain constraints and reasons, especially taint, combat lockdown, throttling, and version workarounds; do not narrate obvious code.
- Avoid speculative compatibility shims. If a deprecated API must be supported, isolate it behind a small adapter and document why.

## WoW runtime rules

- Register only required events. Unregister events and cancel timers/callbacks when their owner is disabled or destroyed.
- Keep event handlers cheap. Coalesce bursts and throttle expensive scans or redraws; never perform avoidable full-table work in `OnUpdate`.
- Do not use an `OnUpdate` script when an event, callback, ticker, or explicit refresh is sufficient.
- Respect combat lockdown. Never change protected frames, secure attributes, bindings, or protected layout while `InCombatLockdown()` is true; defer work until `PLAYER_REGEN_ENABLED`.
- Treat taint as a correctness defect. Do not hook or overwrite protected/global behavior when `hooksecurefunc` or a supported callback exists.
- Avoid forbidden automation: addon code must not make protected gameplay decisions or perform protected actions without a hardware event.
- Use `C_Timer` deliberately and retain handles when cancellation is required.
- Avoid chat spam. Debug logging must be opt-in and prefixed with the addon name.

## State and SavedVariables

- Define defaults separately from persisted data and merge missing keys without overwriting user choices.
- Version the SavedVariables schema when migrations are required. Migrations must be idempotent and preserve recoverable user data.
- Validate persisted values before use; SavedVariables may be absent, stale, or manually edited.
- Do not persist derived or easily recomputed data without a measured reason.

## UI and localization

- Use Blizzard templates, mixins, atlases, colors, and shared helpers only after verifying their current contract.
- Keep layout deterministic across UI scales. Anchor frames completely and avoid circular or ambiguous anchor chains.
- Do not hard-code player-facing text in feature logic. Route it through a localization table, with a reliable fallback locale.
- Add accessible labels/tooltips where an icon alone is ambiguous, and preserve keyboard/gamepad behavior when extending Blizzard UI.

## Validation

- Review every changed API call against `wow-ui-source` when the contract is not already established in the repository.
- Perform static checks available in the repository; do not claim standalone Lua execution proves WoW runtime compatibility.
- Test in Retail with Lua error display enabled or an error-capture addon.
- For UI/event changes, verify: login/reload, enable/disable if supported, combat entry/exit, relevant zone/spec changes, and persistence after `/reload`.
- Check for Lua errors, taint/protected-action warnings, event leaks, excessive CPU allocations, and chat spam.
- Record manual validation steps and results in the active plan or handoff.

## Change discipline

- Read `PLANS.md` before substantial or multi-file work and maintain a plan when its criteria apply.
- Use the procedures in `SKILLS.md` for recurring addon tasks.
- Do not edit generated Blizzard source or vendored code as if it were project code.
- Keep diffs scoped. Do not reformat unrelated files or silently change addon behavior outside the request.
- Never commit secrets, account data, character data, or local WoW paths other than generic documentation examples.
