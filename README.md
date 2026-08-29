# Cortex

- Version: `0.1.0-alpha`
- Game: World of Warcraft Retail 12.1.0 / Midnight
- Interface: `120100`

## What is Cortex?

Cortex is an outside-combat planning assistant for World of Warcraft Retail. It turns facts that the client safely exposes into persistent goals, explainable recommendations, session plans, and a progressively built view of characters previously seen by Cortex.

Cortex is read-only with respect to gameplay. It does not automate actions, choose combat abilities, or reconstruct restricted combat information.

## Current features

- A searchable command palette opened with `/cortex`, with keyboard navigation and an optional key binding.
- A non-secure dashboard with working Overview, Session Planner, and Warband pages. Goals, Weekly, and Gear pages are currently placeholders.
- Versioned `CortexDB` persistence for settings, goals, bounded history, session memory, module states, share templates, and compact character snapshots.
- Event-driven collectors for the active character, gear, currencies, quests, Great Vault state, instance, professions, reputation/renown, location, and local Warband context when the relevant API is available.
- A generic Goal Engine, including a Great Vault-backed weekly completion goal.
- Explainable recommendation rules for supported facts only, plus deterministic “Why?” traces.
- A deterministic Session Planner with clearly labelled duration estimates and dependency/blocker handling.
- Prospective Warband snapshots with `LIVE`, `CACHED`, and `UNKNOWN` states; offline characters are never queried dynamically.
- Strict, non-executable Share Codes for goal, session, and task-list templates with Preview and Confirm before import.
- A limited Debrief based only on Blizzard's native post-combat Damage Meter data when that API and an unambiguous session are available.
- English fallback and French localization.

## Installation

1. Download or clone the repository.
2. Place the addon at `World of Warcraft/_retail_/Interface/AddOns/FaeUtiles`.
3. Verify that `FaeUtiles/FaeUtiles.toc` exists; `FaeUtiles` is the current technical addon id, while the name shown in WoW is **Cortex**.
4. Enable Cortex on the character selection screen and log in.
5. Run `/cortex version` and `/cortex status`.

For a clean alpha test, back up and temporarily move `FaeUtiles.lua` and `FaeUtiles.lua.bak` from the account and character-specific `WTF/.../SavedVariables` directories before logging in. Those files contain `CortexDB` and the legacy `CortexCharacterDB` variable.

## Commands

- `/cortex` — toggle the command palette.
- `/cortex help` — list commands in game.
- `/cortex version` — show the addon version.
- `/cortex status` — show version, database schema, enabled modules, debug state, log level, and profiling state.
- `/cortex goal add <title>` / `goal done <id>` / `goal weekly [count]` — manage the currently supported goal flows.
- `/cortex goal list` / `goal debug` / `goals` — inspect goals.
- `/cortex recommend` — inspect current explainable recommendations.
- `/cortex why [recommendation <id>|goal <id>|fact <key>] [summary|detail|debug]` — explain known evidence and blockers.
- `/cortex now [minutes|unlimited]` — build a session plan; the default budget is 30 minutes.
- `/cortex share import [code]` / `share export <goal|session|tasks> <id>` — preview imports or export supported templates.
- `/cortex debrief` — show the latest supported native post-combat summary, if one exists.
- `/cortex log <ERROR|WARN|INFO|DEBUG|TRACE>` — persist the log level.
- `/cortex debug [on|off]` — switch between INFO and DEBUG logging.
- `/cortex debug db|context|refresh [collector]|profile [on|off|show|reset]` — developer diagnostics.

Debug logging and profiling are disabled by default.

## Known limitations

- This is an alpha. In-game validation across different classes, regions, UI scales, and instance types is still required.
- Goals, Weekly, and Gear dashboard pages are placeholders; their underlying engines and facts are available through Overview, commands, and debug output only where documented.
- There is no full Settings page yet. Window placement/scale, logging, profiling, and module states are persisted by the existing services.
- Cortex only knows offline characters that were logged in while Cortex was enabled. Their data is cached and may be stale or unknown.
- Gear upgrades expose remaining track levels when safely available, not upgrade cost, vendor eligibility, or DPS value. Missing permanent enchant detection is not implemented.
- Profession snapshots do not include offline recipe catalogs and never prove that a specific craft can be completed.
- Great Vault data is not a complete model of every weekly activity in the game.
- Debrief does not provide missed interrupts, defensive-usage timelines, death causality, or generic tactical mistake detection.

## Midnight limitations

Retail 12.x can mark values or tables as secret and restrict combat-related APIs. Cortex treats inaccessible data as unavailable, does not compare or persist it, and does not use it for recommendations.

Collectors that can encounter restricted values are deferred until combat lockdown ends. Cortex does not register combat-log readers, use addon communication for combat telemetry, create secure action buttons, invoke protected gameplay actions, or run an `OnUpdate` analysis loop. Debrief reads only documented native aggregates after combat.

The API capability matrix is in [`docs/API_CAPABILITIES.md`](docs/API_CAPABILITIES.md), Debrief constraints are in [`docs/DEBRIEF_FEASIBILITY.md`](docs/DEBRIEF_FEASIBILITY.md), and the latest code audit is in [`docs/TECHNICAL_AUDIT.md`](docs/TECHNICAL_AUDIT.md).

Maintainers should also read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
