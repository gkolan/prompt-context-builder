# Repository working agreement

Run `npm run ci:gates` before handing off a change. Do not describe source as deployable until the
local gate passes and any required Salesforce validation has been run against an identified,
approved org.

Never create or delete a scratch org without explicit authorization for that specific operation.
Reuse a purpose-specific project org when one is available and authorized. Package creation and
promotion are release-owner decisions.

## Regression-first development

Every bug fix must leave an executable guard:

1. Add or identify a focused test that reproduces the observable failure.
2. Run it against the broken implementation and confirm the expected red result.
3. Apply the smallest complete fix.
4. Preserve the regression and cover affected sibling paths.
5. Run the focused test, relevant gates, and `npm run ci:gates`.
6. Keep local, org, browser, and package evidence distinct.

For customer-data access, preserve sharing-aware Apex, explicit user-mode queries, schema-backed
identifiers, typed bind values, bounded resources, and atomic failure. A fallback must never turn a
missing permission into an ordinary null value.

## Documentation contract

Durable product guidance lives under `docs`; `specs` is design and build history. Every supported
user task has one owner page. Verify exact labels, API names, defaults, limits, permissions, method
signatures, and result behavior against source before documenting them.

Update all affected surfaces when a contract changes: administrator guide, exact reference,
architecture/security page, developer contract, tests, and navigation. Do not present planned,
source-reviewed, or locally tested behavior as deployed, browser-verified, or package-verified.

Read [Documentation standard](docs/quality-gates/documentation-standard.md) before creating or
substantively revising a user-facing page.

## Where things live

| Need                           | Location                                                      |
| ------------------------------ | ------------------------------------------------------------- |
| Product documentation          | `docs/README.md`                                              |
| Exact limits                   | `force-app/main/default/classes/PromptContextContract.cls`    |
| Stable result codes            | `force-app/main/default/classes/PromptContextReasonCodes.cls` |
| Flow and Apex boundary         | `force-app/main/default/classes/PromptContextApi.cls`         |
| Security authorization         | `force-app/main/default/classes/PromptContextAccess.cls`      |
| Record-page components         | `force-app/main/default/lwc`                                  |
| Apex tests                     | `force-app/main/default/classes/*Test.cls`                    |
| LWC tests                      | `force-app/main/default/lwc/**/__tests__`                     |
| Build history and traceability | `specs/prompt-context-builder`                                |
| Local quality workflow         | `.github/workflows/quality.yml` and `package.json`            |
| Permission boundary gate       | `scripts/check-permission-contract.mjs`                       |
| LWC coverage completeness      | `scripts/check-lwc-coverage.mjs`                              |
| Static-analysis configuration  | `code-analyzer.yml`                                           |
