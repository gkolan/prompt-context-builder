# Contributing

Prompt Context Builder is a Salesforce DX project with Apex, Lightning Web Components, metadata,
and repository checks.

Before changing Apex, metadata, tests, validation, or deployment automation, read the
[change safety playbook](./change-safety-playbook.md). It records the mandatory lessons for
org-independent test data, deterministic fixture selection, source conflicts, Scheduled Apex,
static analysis, approved-org work, and evidence boundaries.

## Local workflow

```bash
npm ci
npm run ci:gates
```

Run the smallest relevant test while iterating, then run the complete gate before handoff. A green
local gate does not prove Salesforce deployment or Apex behavior; preserve those evidence types
separately.

## Change requirements

- Reproduce every bug with an executable test before changing production code.
- Keep the red test as a regression guard and verify it turns green.
- Update the user guide, exact reference, architecture page, and tests affected by a contract
  change.
- Preserve explicit user-mode data access, sharing, field-type-checked query variables, and
  all-or-none prompt generation for each Salesforce record.
- Do not create a scratch org without explicit authorization. Reuse an identified project org when
  Salesforce verification is authorized.
- Never describe source inspection as deployed or browser-verified evidence.
- Do not perform test DML on `Account`, `Contact`, or `User`; run
  `npm run check:test-data-isolation` for every Apex test-fixture change.
- Select test fixtures by stable semantic keys or states. An unqualified `LIMIT 1` is unsafe when
  multiple semantic records can exist.
- Stop on Salesforce source conflicts. Explicit deployment authorization does not authorize
  `--ignore-conflicts` or another overwrite of divergent org source.
- Inventory and restore Scheduled Apex when a deployment requires a scheduled class to be paused.
- For UI changes, update the screenshot owner guide and manifest, inspect every capture for secrets
  and stale labels, and run `npm run check:screenshots`.

See [Quality gates](../quality-gates/README.md), the
[documentation standard](../quality-gates/documentation-standard.md), the
[screenshot evidence procedure](../screenshots/README.md), and the repository's design, scenario,
and build history under `specs/prompt-context-builder`.
