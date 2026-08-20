# PLANS.md

## When a plan is required

Create or update a plan before work that is multi-file, changes SavedVariables, touches secure/protected UI, introduces a feature, alters addon load order, or depends on an unfamiliar/version-sensitive WoW API. A one-line typo or isolated documentation correction does not need a formal plan.

Store active plans in `plans/` as `<short-feature-name>.md`. Keep the plan current while implementing; it is a working record, not a speculative essay.

## Planning principles

- State the player-visible outcome first.
- Prefer the smallest change that can be validated independently.
- Separate known facts from assumptions.
- Verify API contracts before designing around them.
- Include in-game validation, not only static checks.
- Surface taint, combat-lockdown, load-order, persistence, compatibility, and performance risks explicitly.

## Plan template

```markdown
# <Feature or change>

Status: Draft | Approved | In progress | Blocked | Complete
Owner: <name or agent>
Last updated: YYYY-MM-DD

## Outcome

What the player or maintainer will be able to observe when this is complete.

## Current state

Relevant files, load order, existing behavior, and constraints discovered in the repository.

## API evidence

- Client: Retail
- Source branch/build: `Gethe/wow-ui-source` `live`, <commit/build if known>
- Verified APIs/events/widgets: <names and source paths>
- Assumptions still requiring verification: <list or none>

## Design

Data flow, ownership, event lifecycle, SavedVariables impact, and UI behavior. Include a small Mermaid diagram only when it makes a non-trivial flow easier to review.

## Steps

- [ ] One concrete, independently verifiable change
- [ ] Next change
- [ ] Documentation/migration work

## Validation

- [ ] Static checks/linting available in the repository
- [ ] Fresh login or `/reload`
- [ ] Relevant events and state transitions
- [ ] Combat entry/exit if protected UI may be affected
- [ ] SavedVariables persistence/migration if applicable
- [ ] No Lua errors, taint warnings, chat spam, or obvious performance regression

## Risks and rollback

Risk, mitigation, and the simplest safe way to disable or revert the behavior.

## Decisions and progress

- YYYY-MM-DD — Decision or discovery, with reason and source.

## Result

Completed behavior, files changed, validation performed, and any follow-up work.
```

## Completion gate

A plan is complete only when its observable outcome is implemented, required validation has been performed or clearly marked as unavailable, migrations are documented, and remaining risks or follow-ups are explicit. Do not mark work complete merely because code was written.
