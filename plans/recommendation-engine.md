# Recommendation Engine

Status: Complete
Owner: Codex
Last updated: 2026-08-23

## Outcome

Cortex turns safe Context facts and Goal Engine state into explainable, scored recommendations through generic rules, then exposes the current ordered result through `/cortex recommend`.

## Current state

- Recommendations are normalized plain tables but have no object method for their explanation.
- Rules are anonymous evaluator functions receiving an ad-hoc facts table.
- Prioritization only sorts a caller-provided score.
- The planner already consumes actionable, unblocked recommendations and must remain compatible.

## API evidence

- No new WoW API or event is introduced.
- Rules consume only `ContextService:Get()` facts already checked by the collectors and Goal Engine records/actions.
- `gear.missingEnchants` is explicitly unavailable and will not produce a rule.
- Equipped-item upgrade recommendations use only documented `C_Item.GetItemUpgradeInfo` track levels and never claim affordability, vendor eligibility, exact cost, or DPS gain.

## Design

- A rule is a registered record with `id`, `category`, `priority`, optional `conditions`, `evaluate`, and `buildRecommendation` functions.
- Rule failures are isolated with `pcall`; invalid candidates are discarded.
- Recommendations are transient objects with `GetReason()` and the existing planner-compatible fields.
- Prioritizer derives score from base priority and bounded Importance, GoalRelevance, Urgency, Efficiency, and Cost inputs, preserving a human-readable breakdown in metadata.
- Initial rules cover onboarding, available goal actions, blocked goals, incomplete weekly goals, and empty gem sockets.

## Steps

- [x] Implement the Recommendation object contract and explanation method.
- [x] Replace the ad-hoc RuleEngine with a generic rule registry and safe evaluation pipeline.
- [x] Add extensible score factors and deterministic ordering.
- [x] Integrate Context + Goals in RecommendationEngine without duplicating recommendation policy in GoalEngine.
- [x] Add safe validation rules and localized explanations.
- [x] Add `/cortex recommend`, tests, documentation, and static/TOC validation.

## Validation

- [x] Every emitted recommendation has a rule id and non-empty player-facing reason.
- [x] Blocked goals remain non-actionable and expose blockers.
- [x] Gear recommendations make no DPS or affordability claim.
- [x] Sorting is deterministic and score breakdowns are available.
- [x] Planner compatibility and invalidation events remain intact.
- [x] Smoke tests, Lua static checks, TOC order, and `git diff --check` pass.
- [x] In-client event timing and localized command output are documented for manual validation.

## Risks and rollback

The main risk is overclaiming from partial gear data. Rules therefore describe observable state only and recommend review or preparation, never automatic gameplay or a predicted combat gain. Disabling the Recommendations module removes the pipeline without affecting persisted goals or context facts.

## Decisions and progress

- 2026-08-23 — Kept recommendations transient; no SavedVariables migration is needed.
- 2026-08-23 — Reused only sanitized fact keys and Goal Engine action descriptors, so no additional Midnight or Secret Value surface is introduced.

## Result

Implemented the generic rule registry, explainable Recommendation model, extensible factor scorer, six safe initial rules, cached invalidation pipeline, and `/cortex recommend`. Foundation and persistence smoke suites pass, Lua Language Server reports no error-level diagnostics, all 38 TOC Lua files exist in the required load order, and `git diff --check` passes. WoW Retail validation remains required for real event timing and localized chat rendering.
