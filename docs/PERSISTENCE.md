# Cortex persistence contract

## SavedVariables

`CortexDB` is the source of truth for all new persistent Cortex state. Account schema version 7 has these top-level keys:

```lua
CortexDB = {
    schemaVersion = 7,
    settings = {},
    characters = {},
    goals = {},
    history = {},
    sessions = {},
    warband = {},
    modules = {},
    templates = {},
}
```

`CortexCharacterDB` remains declared temporarily as a migration bridge for installations that already stored `session.lastLoginAt` and `session.lastLogoutAt` there. Once an accessible character GUID is available, those timestamps are copied to the account snapshot and the legacy database is marked as imported. No new session state is written there.

## Stable character key

Characters and snapshots use the accessible value returned by `UnitGUID("player")` as their key. Cortex deliberately does not fall back to a name or `name-realm` key: if the GUID is missing, secret, or otherwise inaccessible, persistence for that refresh is skipped rather than creating an ambiguous identity.

## Stored data

- `settings`: user choices such as the log level and compact dashboard placement/scale.
- `characters[guid]`: compact identity, class, level, last-seen time, and field-timestamped Warband observations.
- `goals`: user-authored account goals.
- `history`: at most 50 compact Cortex events. Each event stores scalar metadata only.
- `sessions.byCharacter[guid]`: the resumable snapshot for a character.
- `warband`: account-wide Cortex metadata, including the last active character key.
- `modules.states`: explicit per-module enabled/disabled overrides.
- `templates`: at most 50 imported session templates and 50 task-list templates, sharing one monotonic local ID sequence.

The session snapshot contains:

```lua
{
    schemaVersion = 1,
    lastLogin = 0,
    lastLogout = 0,
    lastKnownCharacterState = {
        schemaVersion = 1,
        capturedAt = 0,
        level = 80,
    },
    unfinishedGoals = { 1, 4 },
    unfinishedTasks = {
        { id = "goal:1", goalId = 1 },
    },
}
```

Goal and task lists are capped at 50 references. Cortex does not snapshot gear, currencies, quest logs, collections, lockouts, or other state that can be queried immediately when needed.

The Warband portion of a character record is deliberately compact:

```lua
snapshot = {
    schemaVersion = 1,
    capturedAt = 0,
    fields = {
        itemLevel = { capturedAt = 0, value = 728 },
        professions = { capturedAt = 0, value = { { name = "Blacksmithing", skillLine = 164 } } },
        weekly = { capturedAt = 0, value = { completedActivities = 2, totalActivities = 3 } },
        transferableCurrencies = { capturedAt = 0, value = { { currencyID = 1, quantity = 12 } } },
    },
}
```

Each field is independently absent when UNKNOWN. Offline values are CACHED; a field is LIVE only after it has been captured since the current login boundary. Currency snapshots contain at most 32 discovered account-transferable, non-account-wide entries. Recipe lists, full gear, and immediately available account-wide currency totals are never stored.

## Migration path

- Version 1 introduced account settings, goals, and `warband.characters`.
- Version 2 introduced module state overrides under `settings.modules`.
- Version 3 moves characters to `characters`, moves module overrides to `modules.states`, and adds bounded history and per-character session snapshots.
- Version 4 normalizes goals to schema 2 with typed targets, progress, dependencies, metadata, and uppercase lifecycle statuses.
- Version 5 adds the validated `settings.window` point, offsets, and scale used by the dashboard.
- Version 6 adds validated, field-timestamped compact Warband snapshots and character-record schema 2.
- Version 7 adds the validated `templates.sessions` and `templates.taskLists` repository used by confirmed Share Code imports.

Migrations are forward-only and idempotent. Initialization deep-copies the loaded SavedVariables, migrates and validates the copy, and replaces `CortexDB` only after success. If the stored schema is newer than the addon understands, Cortex uses a normalized in-memory copy in read-only mode and does not rewrite the SavedVariables.

## Internal API

```lua
local database = Cortex:GetService("Database")

local snapshot = database:GetSnapshot() -- defensive copy for the active character
local sessions = database:DebugInspect("sessions") -- defensive copy
local summary = database:DebugSummary() -- counts and schema only
```

Changing a table returned by `GetSnapshot` or `DebugInspect` cannot change `CortexDB`. `/cortex debug db` prints the non-mutating summary.

## Manual validation

1. Back up the account and character SavedVariables files.
2. Start from no Cortex SavedVariables, log in, and run `/cortex debug db`; confirm schema 7 and one GUID-keyed character/snapshot.
3. Add a goal and run `/cortex now 30`, then `/reload`; confirm the goal and task reference remain.
4. Log out normally, log in several days later, and confirm `lastLogout`, the active goals, and selected task references remain in the snapshot.
5. Load a version-1 through version-6 fixture and confirm all characters, goals, settings, and module overrides survive migration; legacy lowercase goal statuses become uppercase, missing window placement receives safe defaults, existing characters receive an empty UNKNOWN Warband snapshot, and the empty template repository is added.
6. Confirm no Lua errors, taint warnings, unexpected chat output, or unbounded SavedVariables growth.
