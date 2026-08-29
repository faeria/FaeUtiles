# Cortex Share Codes

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Players can export and import deliberately shareable goal, session, and task-list templates. Import always follows paste → validate → preview → explicit confirm; invalid or oversized codes never mutate Cortex data.

## Current state

- Goals are persisted and created through GoalEngine.
- Session plans are generated dynamically; no reusable session/task-list template store exists yet.
- The command palette and lightweight non-secure UI components are available.
- No serialization library or executable deserializer is bundled.

## API evidence

- Client: Retail 12.1.0 / Interface `120100`.
- No new WoW API, event, secure template, protected action, or external library is introduced.
- The import dialog reuses the already established plain `EditBox` contract used by CommandPalette: `GetText`, `SetText`, focus, maximum length, and enter/escape scripts.

## Design

- Format: `CORTEX:<formatVersion>:<type>:<base64 payload>`.
- Serializer uses a bounded typed data grammar; functions, userdata, threads, metatables, cycles, sparse arrays, and unsupported map keys are rejected.
- Deserializer is a cursor parser over that grammar. It never uses `loadstring`, `load`, `RunScript`, or code evaluation.
- Versioning validates the envelope before payload decoding.
- Type validators project an allowlisted payload for GOAL, SESSION, or TASK_LIST and discard/reject all unknown shape.
- Account schema 7 adds bounded `templates.sessions` and `templates.taskLists`; imported goal templates create a new goal only after confirmation.
- `ShareCodeService:Preview` returns an opaque validated preview token. `Confirm` accepts only the exact pending preview identity, preventing confirmation from re-parsing changed input.
- The dialog owns one reusable frame and keeps the pending preview only in memory.

## Security and limits

- Maximum share-code length: 12 KiB; maximum decoded payload: 8 KiB.
- Maximum nesting depth: 8; maximum parsed nodes: 512; maximum string: 1024 bytes.
- Maximum 50 tasks per template, with strict field lengths and duration/budget bounds.
- Codes reject incompatible versions, unknown types, malformed base64/grammar, trailing bytes, duplicate map keys, non-finite numbers, and oversized payloads.
- Share payloads exclude GUIDs, character names, realms, currencies, equipment, history, SavedVariables internals, goal progress/status, and arbitrary metadata.

## Event/UI lifecycle

- No game events are registered.
- The dialog is non-secure, created once, hidden on ESC, and performs no protected action in combat.
- Confirm triggers the only write path; Import and Preview are read-only.

## Steps

- [x] Add bounded Serializer, Deserializer, Versioning, Validation, and ShareCode models/services.
- [x] Add schema-7 migration and compact template repository.
- [x] Add export/preview/confirm application paths.
- [x] Add reusable Import/Preview/Confirm dialog and command integration.
- [x] Document and test valid round trips plus every required rejection case.

## Validation

- [x] GOAL, SESSION, and TASK_LIST round trips are deterministic.
- [x] Preview does not mutate SavedVariables or goals.
- [x] Confirm imports exactly once from the validated pending preview.
- [x] Incompatible version, unknown type, malformed payload, excessive size, unsupported value, and trailing content are rejected.
- [x] Foundation/persistence smoke tests, TOC/XML checks, and diff hygiene pass.
- [ ] Retail paste/focus, `/reload`, combat, UI scale, Lua-error, and taint checks remain in-game validation.

## Risks and rollback

Parser complexity is the primary risk. The grammar is intentionally small and bounded, and type validation happens after parsing but before any write. Removing Sharing files and the schema-7 template root leaves existing goals and character data untouched.

## Decisions and progress

- 2026-08-23 — Chose a local typed grammar plus Base64 to avoid executable Lua serialization and external dependencies.
- 2026-08-23 — Kept preview tokens in memory so copied codes never enter SavedVariables before confirmation.

## Result

Implemented with schema 7, bounded template persistence, deterministic codec round trips, strict rejection tests, a private one-shot confirmation snapshot, and a reusable import dialog. Retail paste/focus, `/reload`, combat, UI scale, Lua-error, and taint checks remain explicit in-game validation.
