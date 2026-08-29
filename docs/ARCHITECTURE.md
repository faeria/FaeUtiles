# Cortex architecture

This document describes the runtime architecture of Cortex `0.1.0-alpha`. The code favors explicit dependencies and small services over a framework.

## Runtime identity and namespace

The installed addon directory and manifest are currently `FaeUtiles/FaeUtiles.toc`. WoW passes `addonName` and the private addon table through `...`; every runtime file receives that table as `Cortex`.

Cortex does not export `_G.Cortex`. The only addon-owned globals are those required by WoW:

- `CortexDB` and `CortexCharacterDB` for SavedVariables;
- `SLASH_CORTEX1` and `SlashCmdList.CORTEX` for `/cortex`;
- `BINDING_NAME_CORTEX_COMMAND_PALETTE` for the key-binding label.

## Load order

`FaeUtiles.toc` is the authoritative load order:

1. namespace, constants, and locale fallback/override;
2. module registry, logger, profiler, event bus, and command registry;
3. schema, migrations, repositories, and database;
4. FactStore, collector registry/utilities, collectors, and ContextService;
5. Goals, Sharing, Warband, Debrief, Recommendations, Detective, Planner, and search services;
6. theme, reusable UI components, pages, navigation, windows, palette, and chat commands;
7. `Core/Bootstrap.lua` last, after every descriptor has registered.

Files register objects but do not initialize them during loading. Dependencies declared in `Cortex:RegisterService` and `Cortex:RegisterModule` are resolved by the registry during bootstrap.

## Lifecycle

`Core/Bootstrap.lua` owns the only core WoW event frame.

- `ADDON_LOADED` for the matching addon initializes every service, loads settings, applies log/profiler state, and enables configured modules.
- `PLAYER_LOGIN` records the session and requests a Context refresh.
- `PLAYER_LOGOUT` captures compact resumable state and timestamps the session.
- `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` maintain Cortex's lockdown state and flush keyed deferred work only after combat.

Initialization and module enable/disable callbacks are protected with `pcall`. Module dependencies are enabled before dependents, and an enabled dependency cannot be disabled while a dependent remains enabled.

## Data flow

```text
WoW APIs and events
        ↓
specialized read-only collectors
        ↓
FactStore (value, availability, source, timestamp)
        ↓
ContextService
        ↓
Goals + Rules → Recommendations → Prioritizer
        ↓                         ↓
   Detective traces          Session Planner
        ↓                         ↓
             UI view models
```

Collectors sanitize API output and contain no recommendation policy. Context invalidates only the collector that owns a changed capability and coalesces event bursts. Facts distinguish current `available`, `stale`, and `unavailable` state from an explicitly requested last-known value.

Rules declare their fact dependencies. Recommendation invalidation uses the changed source/fact set, and one dependency graph is reused during each rebuild. UI components receive view models and do not query WoW APIs directly.

## Services and modules

Services provide infrastructure or stateless/shared domain behavior, for example `Database`, `Context`, `Facts`, `Events`, `Commands`, `Detective`, and the UI owners. Modules are independently enabled domain lifecycles:

- `Goals`
- `Warband`
- `Debrief`
- `Recommendations`
- `Planner`

Consumers use `Cortex:GetService(name)`, `Cortex:GetModule(name)`, and `Cortex.Events:Publish(...)`. Persistent module overrides live under `CortexDB.modules.states`.

## Persistence

`CortexDB` is the active account database at schema version 7. It stores settings, GUID-keyed character snapshots, goals, bounded history, compact session memory, Warband metadata, module states, and validated share templates.

`CortexCharacterDB` is not used for new per-character state. It remains declared only so an existing legacy timestamp record can be imported once into the account database without losing data.

Migrations run sequentially and idempotently against an in-memory copy. The global SavedVariables table is replaced only after migration and validation succeed. A database created by a newer Cortex schema is opened read-only.

The detailed storage contract is in [`PERSISTENCE.md`](PERSISTENCE.md).

## UI ownership

The command palette, main dashboard, and share dialog create their frame trees once and reuse rows/components. Updates are driven by Cortex events and visible-page checks. There is no frame reconstruction per fact change and no `OnUpdate` refresh loop.

The dashboard and palette are ordinary non-secure frames. They do not set secure attributes or execute protected actions. Placement and scale are validated before persistence.

## Midnight safety boundary

Cortex reads only APIs recorded in [`API_CAPABILITIES.md`](API_CAPABILITIES.md). Values are checked with the available Secret Value primitives before indexing, comparing, formatting, or persisting. Inaccessible values become unavailable facts.

There is no combat-log ingestion, aura/combat decision engine, addon-message telemetry, secure action button, protected action, or attempt to reconstruct restricted data. Debrief's narrower post-combat boundary is documented in [`DEBRIEF_FEASIBILITY.md`](DEBRIEF_FEASIBILITY.md).

## Extension rules

- Add a service only for shared infrastructure or behavior with a clear owner.
- Add a module only when independent enable/disable lifecycle is useful.
- Put WoW API reads in collectors or a narrowly documented adapter, never in recommendation rules or UI components.
- Declare every service/module dependency and every rule fact dependency.
- Add persisted fields only with defaults, validation, migration, and tests.
- Add player-facing strings to `enUS` and `frFR`; `enUS` is the fallback.
