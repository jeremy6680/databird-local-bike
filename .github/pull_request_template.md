## Context

<!-- What is this PR doing and why? Link to any related issue or discussion. -->

## Changes

<!-- List the models added, modified, or removed. -->

- [ ] Staging
- [ ] Intermediate
- [ ] Mart
- [ ] Tests
- [ ] Documentation
- [ ] CI/CD
- [ ] Other

## DAG screenshot

<!-- Paste a screenshot of the relevant DAG section from `dbt docs serve`.
     Required for any PR that adds or modifies models. -->

## Special merge instructions

<!-- Does this PR require a full-refresh?
     Example: `dbt run --full-refresh --select orders`
     If yes, explain why. If no, delete this section. -->

## Breaking changes

<!-- Any renamed models, changed grain, dropped columns, or schema changes
     that downstream consumers (Metabase, other models) need to be aware of?
     If none, delete this section. -->

## Checklist

- [ ] No raw table paths — always `ref()` or `source()`
- [ ] Materialisation is appropriate for the model's DAG position
- [ ] No duplicated logic across models
- [ ] Every new model has a complete `.yml` file (descriptions + tests)
- [ ] `not_null` + `unique` tests pass on all primary keys
- [ ] Every SQL clause is commented
- [ ] DAG is clean (no orphaned or redundant models)
- [ ] CI is green on this PR
