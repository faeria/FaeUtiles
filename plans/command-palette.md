# Cortex Command Palette

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

`/cortex` and an assignable WoW key binding open a searchable command palette with dynamic COMMAND, GOAL, RECOMMENDATION, CHARACTER, and MODULE results plus full keyboard navigation.

## Current state

- `/cortex` opens the palette; the dashboard remains available through its page commands.
- `CommandRegistry` owns validated module commands and `SearchProvider` independently aggregates all five result types.
- `CommandPalette` reuses eight result rows and refreshes on text and relevant internal events.

## API evidence

- Retail `Blizzard_SharedXML/UI.xsd` on Gethe `wow-ui-source` `live` declares EditBox scripts `OnTextChanged`, `OnEnterPressed`, `OnEscapePressed`, and `OnArrowPressed`.
- Current Blizzard XML uses EditBox enter/escape handlers, including `Blizzard_HelpFrame/HelpFrame.xml`.
- Retail `Bindings.xml` files use `<Binding name=... category=...>` script bodies. Cortex uses the already-required `SlashCmdList.CORTEX` entry, so the binding introduces no callable addon global.
- `Bindings.xml` is a WoW-special file loaded by the client outside normal TOC Lua ordering. One namespaced `BINDING_NAME_*` localization global is required by WoW's binding UI.

## Design

- `CommandRegistry` validates and owns registered COMMAND entries. Any service/module can register during `Initialize`.
- `SearchProvider` owns provider registration, normalization, token/fuzzy matching, scoring, deterministic sorting, limits, and safe execution. It has no UI dependency.
- Built-in dynamic providers project goals, recommendations, saved characters, and registered modules into transient search results.
- `CommandPalette` creates one anonymous non-secure frame, one EditBox, and eight reusable rows. It only renders search results and forwards selected actions.
- Empty `/cortex` opens the palette. Dashboard and page navigation remain available as registered commands.

## Steps

- [x] Add CommandRegistry and independent SearchProvider services.
- [x] Register navigation, dashboard, goal, recommendation, settings/debug commands outside CommandPalette.
- [x] Add dynamic GOAL, RECOMMENDATION, CHARACTER, and MODULE providers.
- [x] Build the recycled palette UI with live filtering and UP/DOWN/ENTER/ESC.
- [x] Add the assignable Bindings.xml entry without a callable addon global.
- [x] Extend localization, tests, docs, and TOC ordering.
- [x] Run smoke, search behavior, persistence, XML/TOC, and diff validation.

## Validation

- [x] Registry rejects malformed and duplicate commands.
- [x] Search handles empty, substring, keyword, multi-token, fuzzy, and no-result queries deterministically.
- [x] All five result types are produced from current state.
- [x] Keyboard selection wraps safely and ENTER executes the selected action.
- [x] ESC closes and repeated searches create no new rows.
- [x] `/cortex` and the binding invoke the same palette toggle path.
- [x] No protected binding mutation or combat-sensitive action is performed.

## Risks and rollback

The primary risks are keyboard focus conflicts and accidental execution. The EditBox owns keyboard scripts only while the palette is shown, ESC always closes, and each action is an explicit selected entry. Removing the palette UI leaves the registry/search engine independently usable.

## Decisions and progress

- 2026-08-23 — Kept command registration distributed and dynamic providers separate from the palette renderer.
- 2026-08-23 — Used WoW's declarative binding file to expose a user-assignable key without setting or overriding bindings at runtime.

## Result

Implemented and validated with the foundation and persistence smoke tests, XML parsing, TOC path checks, and `git diff --check`. Retail runtime validation remains required for EditBox focus, key-binding assignment, combat entry/exit, and taint diagnostics.
