# Cortex

Cortex is an outside-combat second brain for World of Warcraft Retail. It turns account-wide goals and Warband context into explainable recommendations that fit the time a player has available.

This repository currently contains the initial modular foundation: explicit service/module dependencies, an internal event bus, versioned persistence, a transient fact store, safe character capture, account-wide goals, a rule-based recommendation engine, a session planner, and a minimal localized window. It deliberately does not inspect live combat data or automate gameplay.

## Compatibility

- World of Warcraft Retail 12.1.0
- Interface `120100`
- No external libraries
- Account SavedVariables: `CortexDB`
- Per-character SavedVariables: `CortexCharacterDB`

The development checkout is installed in a folder named `FaeUtiles`, so its active TOC is `FaeUtiles.toc`. A release archive should contain a `Cortex` folder and a correspondingly renamed `Cortex.toc`.

## Commands

- `/cortex` — open or close the minimal Cortex window.
- `/cortex help` — show help.
- `/cortex goal add <title>` — add an account-wide goal.
- `/cortex goal done <id>` — complete a goal.
- `/cortex goals` — list active goals.
- `/cortex now [minutes]` — build a plan for 5 to 240 minutes; the default is 30.
- `/cortex status` — show version, active goal count, and known Warband character count.
- `/cortex log <ERROR|WARN|INFO|DEBUG|TRACE>` — set and persist the log level.
- `/cortex debug [on|off]` — toggle quickly between DEBUG and INFO.

## Architecture

All addon-owned objects live in the private `Cortex` table supplied through `...`; Cortex is not exported to `_G`. Infrastructure is registered as services and domain behavior as modules:

```lua
local context = Cortex:GetService("Context")
local goals = Cortex:GetModule("Goals")

Cortex.Events:Publish("MY_INTERNAL_EVENT", value)
Cortex:DisableModule("Planner")
Cortex:EnableModule("Planner")
```

The initial modules are `Goals`, `Recommendations`, and `Planner`. Feature modules such as Weekly, Gear, Warband, Detective, Sharing, and Debrief will be added only when they contain implemented behavior. Module state overrides are stored in `CortexDB.settings.modules`; dependencies are enabled first and prevent unsafe disablement while an enabled dependent still requires them.

## Safety model

Cortex reads only the current player's identity and level. Capture is refused during combat, and every potentially restricted return is checked with the Secret Value access primitives before comparison, formatting, or table indexing. If login occurs during combat, capture waits for `PLAYER_REGEN_ENABLED`.

The bootstrap owns the only game-event frame and publishes lifecycle events onto the internal bus. Keyed work can be deferred until combat lockdown ends. The minimal window is unnamed and non-secure. There are no secure templates, protected actions, hooks, combat-log readers, aura readers, addon communications, timers, or `OnUpdate` scripts in this slice.

## Manual validation

Enable Lua errors, then verify:

1. Log in or use `/reload`; no message should appear at the default INFO level.
2. Run `/cortex`, confirm the minimal window opens, then run it again to close it.
3. Run `/cortex status` and confirm the current character is counted.
4. Run `/cortex now 30` with no goals and confirm the onboarding recommendation.
5. Add a goal, list it, request a 30-minute plan, then complete it.
6. Run `/cortex debug` twice and confirm DEBUG then INFO are persisted.
7. Use `/reload` and confirm goals, module settings, and the selected log level persist.
8. Reload during combat when practical; confirm capture completes after combat with no protected-action or taint warning.

API feasibility is recorded in [`docs/API_CAPABILITIES.md`](docs/API_CAPABILITIES.md). Architecture decisions and validation are recorded in [`plans/initial-architecture.md`](plans/initial-architecture.md).
