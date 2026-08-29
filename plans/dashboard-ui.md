# Cortex dashboard UI

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

`/cortex` opens a movable, scalable, modern dashboard with persistent placement, sidebar navigation, an event-driven Overview page, and reusable lightweight visual components.

## Current state

- `MainWindow` is a fixed 420×220 informational frame with one close button.
- `Navigation` stores one page name but no UI consumes it.
- Context, Goals, Recommendations, and Warband summaries already expose the data required for an Overview without new game API calls.
- Account schema 4 has no window placement setting.

## API evidence

- Client: Retail 12.1.0 / interface 120100.
- Gethe `wow-ui-source` `live` confirms current Blizzard use of anonymous `CreateFrame`, `SetMovable`, `SetClampedToScreen`, `StartMoving`, and `StopMovingOrSizing` in `Blizzard_DebugTools/Blizzard_TexelSnappingVisualizer.lua`.
- Current Blizzard UI uses `EnableKeyboard(true)` with an `OnKeyDown` ESC handler in `Blizzard_CatalogShopTopUpFlow.lua`. Cortex will consume ESC only while shown and propagate other keys.
- Existing project contracts already establish `CreateTexture`, `CreateFontString`, `StatusBar`, and event bus use. No protected template or action is introduced.

## Design

- Add a small `Cortex.UI` namespace containing a theme and six focused component constructors: Button, Card, ProgressBar, Section, Badge, and a fixed-capacity recycled ScrollList.
- `OverviewPage` owns presentation composition only. It receives a view model built by `MainWindow`; it never reads WoW APIs or decides recommendations.
- `MainWindow` creates frames once, subscribes to Context/Goal/Recommendation/Navigation events, builds the view model from services/modules, and updates only while visible.
- Sidebar pages other than Overview use reusable placeholder sections until their dedicated product views are implemented.
- Account schema 5 adds `settings.window` with a validated UIParent-relative point, offsets, and scale. Drag stop writes only this compact preference.
- The root frame is anonymous and non-secure. ESC uses keyboard propagation rather than `UISpecialFrames`, avoiding a required global frame name.

## Steps

- [x] Add schema-5 window placement migration and Database accessors.
- [x] Add theme and reusable UI components with fixed creation counts.
- [x] Build the Overview page and reusable placeholder page.
- [x] Replace MainWindow with header/sidebar/content/footer composition and view-model mapping.
- [x] Connect navigation, Why explanation, dragging, scaling, persistence, ESC, and event-driven refresh.
- [x] Extend localization, smoke mocks/tests, README, and changelog.
- [x] Run smoke, persistence, static, TOC, and diff validation.

## Validation

- [x] Existing schema versions migrate without losing settings; placement values are validated.
- [x] Window and components are created once and reused across refreshes/navigation.
- [x] Overview renders safely with available, unavailable, and empty data.
- [x] Why displays `Recommendation:GetReason()` without recalculating business logic.
- [x] Drag stop persistence and placement restoration are covered; `/reload` remains an in-client check.
- [x] ESC closes without adding an addon-owned global.
- [x] Combat updates remain visual-only and invoke no protected action.
- [x] Smoke tests, Lua Language Server, TOC order, and `git diff --check` pass.

## Risks and rollback

Keyboard capture and frame placement are the main UI risks. Keyboard input is enabled only while visible, non-ESC keys propagate, coordinates are clamped, and corrupt placement falls back to center. Replacing `MainWindow` with the previous minimal file rolls back presentation without affecting domain state.

## Decisions and progress

- 2026-08-23 — Avoided `UISpecialFrames` because it requires a global frame name; the private anonymous frame handles ESC locally.
- 2026-08-23 — Kept page components fixed and reusable rather than creating a general-purpose UI framework.

## Result

Implemented a fixed-allocation dashboard with a modern flat theme, reusable components, five-page sidebar, data-driven Overview, inline recommendation explanations, status footer, validated persistent placement/scale, and private ESC handling. Foundation and persistence smoke suites pass, refresh reuse is asserted, Lua Language Server reports no error-level diagnostics, all 47 TOC Lua files exist, and `git diff --check` passes. Manual WoW Retail validation remains required for visual scaling, drag feel, font wrapping, `/reload`, and combat/taint observation.
