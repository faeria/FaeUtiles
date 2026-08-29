# Developing Cortex

## Target and source of truth

Cortex targets World of Warcraft Retail. For `0.1.0-alpha`, the manifest uses interface `120100`. The release check was performed against `Gethe/wow-ui-source` branch `live`, commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`, build `12.1.0.69497`.

Before adding or changing an API, event, enum, widget method, template, or callback:

1. verify it in `Interface/AddOns/Blizzard_APIDocumentationGenerated` on `live`;
2. inspect a current Blizzard call site for lifecycle and nilability;
3. check `Blizzard_Deprecated`;
4. record Secret Value and combat restrictions in the active plan and capability docs;
5. leave uncertain contracts as `TO VERIFY` and do not implement around them.

Repository conventions are in `AGENTS.md`, `PLANS.md`, and `SKILLS.md`.

## Local installation

Keep the checkout at:

```text
World of Warcraft/_retail_/Interface/AddOns/FaeUtiles
```

`FaeUtiles` is the current technical addon id and must match `FaeUtiles.toc`. The title displayed by WoW is Cortex.

Enable Lua errors in game:

```text
/console scriptErrors 1
/reload
```

## Code organization

- `Core/`: namespace, lifecycle, logging, events, commands, registry, profiler.
- `Data/`: schema, migrations, persistence, repositories.
- `Context/`: transient facts and capability-scoped WoW collectors.
- `Goals/`, `Recommendations/`, `Planner/`: pure domain engines and their module lifecycles.
- `Warband/`, `Detective/`, `Sharing/`, `Debrief/`: bounded domain services/modules.
- `CommandPalette/`: search engine independent of frames.
- `UI/`: theme, reusable components, pages, windows, and slash routing.
- `Locales/`: English fallback followed by locale overrides.
- `docs/`: capability, architecture, safety, persistence, and audit references.
- `tests/`: standalone smoke fixtures with mocked WoW globals; these do not prove in-game compatibility.

## Adding a service or module

Register the object at the end of its file and list dependencies explicitly:

```lua
Cortex:RegisterService("Example", ExampleService, {
    services = { "Events", "Database" },
})

Cortex:RegisterModule("Example", ExampleModule, {
    services = { "Context" },
    modules = { "Goals" },
}, {
    defaultEnabled = false,
})
```

Place the file in the TOC after the files needed to define it and before consumers. Modules that subscribe to events must register in `Enable`, unregister in `Disable`, and make repeated calls safe.

## Collectors and rules

A collector owns API reads and fact production. It must:

- declare only verified events;
- guard nil and inaccessible/secret values before use;
- mark temporary absence as unavailable instead of inventing a default;
- defer restricted reads until out of combat;
- avoid persistence of immediately recomputable API state;
- contain no recommendation logic.

A recommendation rule consumes sanitized facts and goals. Register every fact key/source that can affect it so targeted invalidation remains correct. Every recommendation must include a deterministic reason and must not claim DPS, affordability, recipe knowledge, or tactical combat conclusions without supported evidence.

## SavedVariables and migrations

Do not mutate `Schema.accountDefaults`. Add defaults separately, validate loaded values, and increment `ACCOUNT_SCHEMA_VERSION` only when the persisted contract changes.

For schema `N`:

1. add `Migrations.account[N]`;
2. make it safe to run again;
3. preserve recoverable unknown fields unless the contract intentionally removes one;
4. update validation and persistence documentation;
5. add clean-profile, prior-version, idempotence, malformed-data, and newer-schema read-only fixtures.

New persistent writes belong in `CortexDB`. `CortexCharacterDB` is a legacy migration bridge, not a target for new features.

## Localization

Add every player-facing key to `Locales/enUS.lua` and `Locales/frFR.lua`. English loads first and is the fallback. Avoid hard-coded player text in collectors, engines, or UI components.

The key-binding label is the intentional WoW-required `BINDING_NAME_CORTEX_COMMAND_PALETTE` global.

## Static and smoke checks

Use Lua Language Server with `.luarc.json` for Lua 5.1 syntax/static diagnostics:

```powershell
lua-language-server --check=. --check_format=pretty --checklevel=Error --configpath=.luarc.json
```

With a standalone Lua interpreter available, run:

```powershell
lua tests/foundation_smoke.lua
lua tests/persistence_smoke.lua
```

Also verify:

- every non-comment TOC entry exists exactly once;
- TOC order matches the smoke-test load list;
- locale keysets are identical;
- TOC and `Cortex.Constants.VERSION` match;
- service/module dependencies resolve and contain no cycles;
- scans find no `OnUpdate`, combat-log reader, addon communication, protected mutation, or accidental addon global;
- `git diff --check` passes.

## In-game release matrix

Static tests cannot prove WoW runtime behavior. Before publishing an alpha archive, test from both a clean profile and a migrated profile:

- login and `/reload` with Lua errors enabled;
- `/cortex`, keyboard navigation, key binding, `/cortex version`, and `/cortex status`;
- goal, recommendation, planner, Warband, Detective, Share Code, and supported Debrief paths;
- module enable/disable and dependency refusal behavior;
- entry into combat, UI open/close during combat, and deferred refresh after leaving combat;
- logout/login persistence and a deliberately newer schema opening read-only;
- multiple UI scales and window placement persistence;
- Lua errors, taint/protected-action warnings, chat spam, and profiler-off behavior.

Record the exact Retail build and results in the active release plan.

## Packaging

A public archive should have `FaeUtiles` as its top-level directory and must include `FaeUtiles.toc`, `Bindings.xml`, and every runtime file listed by the TOC. Exclude `.git`, `.codex`, `.agents`, plans, tests, editor settings, logs, screenshots, and local SavedVariables.

No software license is currently declared in the repository history or metadata. Do not add or advertise a license without an explicit maintainer decision.
