# Session Planner

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

The player can choose a 30, 60, 120 minute, or unlimited session and receive an ordered, explainable plan containing only feasible actions, with dependencies before their dependents and every duration labelled as an estimate.

## Current state

- `Planner/SessionPlanner.lua` greedily takes actionable recommendations in existing order and returns a raw table.
- Recommendation durations are normalized but there is no estimator contract, plan model, dependency bundle resolution, or planner page.
- The dashboard already provides fixed-capacity recycled lists, non-secure buttons, event-driven refresh, localization, and persistent window placement.

## API evidence

- Client: Retail 12.1.0 / Interface `120100`.
- No new WoW API, event, widget method, template, or callback is introduced.
- The UI reuses the project's already verified anonymous `Frame`, `Button`, text, and fixed-capacity `ScrollList` contracts.
- Location is consumed only from the existing sanitized `location.current` Context fact; absent or unavailable location never blocks planning.

## Design

- `DurationEstimator` resolves explicit recommendation/action/goal estimates and always returns `isEstimate = true` plus its source.
- `PlanEntry` is an explainable selected action; `Plan` owns budget, ordered entries, estimated total, remaining time, location snapshot, and skipped diagnostics.
- `SessionPlanner` builds candidates from recommendations and direct goal actions, sorts deterministically by adjusted score, priority, duration, then id, and greedily selects dependency bundles that fit the remaining budget.
- Missing, cyclic, paused, failed, or unschedulable dependencies reject the dependent candidate. A resolvable dependency is inserted before its dependent.
- Matching candidate `mapID` metadata receives a small documented locality bonus; no route or travel-time claim is inferred when metadata is absent.
- The Session page owns only budget selection and rendering. `MainWindow` creates its view-model from the Planner module.

## Steps

- [x] Add DurationEstimator, PlanEntry, and Plan models.
- [x] Replace the planner with deterministic dependency-aware constrained selection.
- [x] Add direct goal-action access without recommendation logic in GoalEngine.
- [x] Add localized Session navigation, command, page, and view-model.
- [x] Update chat output, TOC, documentation, and smoke coverage.
- [x] Validate load order, bounded UI allocation, planner behavior, persistence compatibility, and diff hygiene.

## Validation

- [x] 30/60/120/unlimited budgets normalize correctly.
- [x] Selected estimated time never exceeds a finite budget.
- [x] Blocked standalone actions are excluded.
- [x] Resolvable dependencies are ordered before their dependent.
- [x] Missing or cyclic dependency chains are excluded.
- [x] Equal inputs produce equal order and explanations.
- [x] Session page reuses rows and changes budget without frame growth.
- [x] Foundation and persistence smoke tests pass.
- [ ] Login/reload, combat, UI scale, Lua errors, and taint require in-game validation.

## Risks and rollback

Durations are user-facing approximations, so every model and label retains estimate semantics. The greedy selector is intentionally understandable and may not find the mathematical optimum; deterministic behavior and explainability are preferred for this version. The page is non-secure and performs no gameplay action.

## Decisions and progress

- 2026-08-23 — Reused existing sanitized Context location instead of adding any WoW API call.
- 2026-08-23 — Chose dependency-bundle greedy selection over knapsack/dynamic programming for a transparent first implementation.

## Result

Implemented the four-model planner architecture, deterministic constrained selection, dependency ordering, explicit estimated-duration provenance, optional current-map relevance, compact unfinished-task persistence, and the recycled Session dashboard page. Foundation/persistence smoke tests, TOC path checks, Bindings XML parsing, and `git diff --check` pass. In-client visual, reload, combat, and taint validation remains unavailable in this environment and is documented in the README manual matrix.
