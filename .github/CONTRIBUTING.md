# Contributing

This guide is for contributors changing Prompt Context Builder source or documentation.

## Prepare a local checkout

Use Node.js 22 and the current Salesforce CLI. Fork the repository in GitHub, then clone your fork
and install the locked dependencies:

```bash
git clone https://github.com/YOUR-ACCOUNT/prompt-context-builder.git
cd prompt-context-builder
npm ci
```

Create a focused branch for one logical change:

```bash
git switch -c fix/short-description
```

You do not need a Salesforce org for documentation-only or most local JavaScript changes. Do not
create or delete a scratch org for contribution work unless the repository owner has explicitly
authorized that operation.

## Before opening a pull request

Read the repository
[change safety playbook](../docs/contributing/change-safety-playbook.md) before Apex, metadata,
test-fixture, validation, or deployment work.

1. Reproduce behavior changes with a focused regression test before implementing the fix.
2. Run the focused test against the broken implementation and confirm the expected failure.
3. Apply the smallest complete fix and keep the regression test.
4. Preserve sharing-aware Apex, explicit user-mode queries, field security, typed bind values,
   bounded resources, and atomic failure behavior.
5. Update the owning user guide, exact reference, architecture contract, and `CHANGELOG.md` when
   public behavior changes.
6. Run the complete local gate:

   ```bash
   npm run ci:gates
   ```

7. For Apex or metadata changes, run a validation deployment and `RunLocalTests` in an approved
   Salesforce org. Never create or delete a scratch org without the release owner's authorization.
8. Record local, org, browser, and package evidence separately in the pull request.
9. For test changes, confirm there is no `Account`, `Contact`, or `User` DML and no fixture query
   that relies on an unqualified `LIMIT 1`.
10. For deployment work, report source conflicts explicitly and obtain approval before bypassing
    conflict protection. Restore and verify Scheduled Apex changed for the deployment.

## Open the pull request

Push the branch to your fork and open a pull request against `main`. Complete every applicable item
in the pull-request template and explain any item that does not apply. Keep the change focused;
unrelated cleanup belongs in a separate pull request.

Do not commit Salesforce authentication state, access tokens, customer records, generated prompts,
full Org IDs, private keys, `.env` files, test coverage, dependency folders, or analyzer output. The
public-release gate detects several of these categories, but contributors remain responsible for
reviewing the complete diff.

All participation must follow the [Code of Conduct](./CODE_OF_CONDUCT.md). Report security issues
through the [security policy](./SECURITY.md), not a public issue.

## Documentation and review contracts

Read [Repository contribution guidance](../docs/contributing/README.md), the
[documentation standard](../docs/quality-gates/documentation-standard.md), and the
[quality-gate contract](../docs/quality-gates/README.md) before changing their respective areas.
