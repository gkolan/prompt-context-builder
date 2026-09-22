# Contributing

Prompt Context Builder is a Salesforce DX project with Apex, Lightning Web Components, metadata,
and repository checks.

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
- Preserve explicit user-mode data access, sharing, typed bind values, and atomic failure.
- Do not create a scratch org without explicit authorization. Reuse an identified project org when
  Salesforce verification is authorized.
- Never describe source inspection as deployed or browser-verified evidence.

See [Quality gates](../quality-gates/README.md), the
[documentation standard](../quality-gates/documentation-standard.md), and the repository's design,
scenario, and build history under `specs/prompt-context-builder`.
