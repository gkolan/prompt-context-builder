# Repository working agreement

Run `npm run ci:gates` before handing off a change. Do not describe source as deployable until the
local gate passes and any required Salesforce validation has been run against an identified,
approved org.

Never create or delete a scratch org without explicit authorization for that specific operation.
Reuse a purpose-specific project org when one is available and authorized. Package creation and
promotion are release-owner decisions.

## Mandatory session guidance

For any Apex, Salesforce metadata, Apex-test, org-validation, or deployment work, read
[Change safety playbook](docs/contributing/change-safety-playbook.md) before acting. It is the owner
page for test isolation, deterministic fixtures, Code Analyzer review, approved-org validation,
source conflicts, Scheduled Apex recovery, deployment sequencing, and evidence language.

Apply these rules in every repository session:

- Inspect `git status --short` before editing and preserve unexplained user changes.
- Apex tests in `force-app` must not perform DML on `Account`, `Contact`, or `User`. In-memory
  standard records are allowed for schema, parser, and rendering behavior. Persist package-owned
  fixtures only when the test requires database behavior. The one exception is the test-only
  `integration-tests/security` suite, which inserts a minimum-access `User` that Salesforce rolls
  back so security is tested as a real restricted user.
- Do not use `SeeAllData=true`, profile display names, or org-existing business data as test setup.
- Test queries must identify records by semantic keys or states. Do not use an unqualified
  `LIMIT 1` when more than one semantic record can exist; add `ORDER BY` when order matters.
- Run Code Analyzer for Apex or metadata changes. Review serious and changed-surface findings; do
  not equate a severity count with proof that no defect exists.
- Run `npm run ci:gates`, then validate Apex or metadata against an identified approved org. Local
  gates are not Salesforce compilation or deployment evidence.
- A successful check-only deployment is validation, not deployment, and does not authorize
  overwriting org-side changes.
- On source conflicts, stop, narrow and inspect the conflict, and obtain explicit user approval
  before `--ignore-conflicts`, source-tracking reset, or any equivalent overwrite.
- Before changing a class used by Scheduled Apex, inventory the exact jobs. Restore and verify every
  temporarily paused or aborted job after success or failure.
- Never claim universal org compatibility. State the tested org shape, controlled dependencies,
  and unverified variants.

## Regression-first development

Every bug fix must leave an executable guard:

1. Add or identify a focused test that reproduces the observable failure.
2. Run it against the broken implementation and confirm the expected red result.
3. Apply the smallest complete fix.
4. Preserve the regression and cover affected sibling paths.
5. Run the focused test, relevant gates, and `npm run ci:gates`.
6. Keep local, org, browser, and package evidence distinct.

A lesson added to the playbook's "Why these rules exist" table needs an executable guard with a
positive and a negative scenario in `scripts/lesson-guards.test.mjs`.

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

For UI documentation, also read the [Screenshot evidence procedure](docs/screenshots/README.md).
Every image must be inventoried in `docs/screenshots/manifest.json`, visually inspected for secrets
and stale content, and labeled as local, deployed-org, or package evidence. Run
`npm run check:screenshots`; never use a screenshot to imply that undeployed workspace changes are
browser-verified.

## Where things live

| Need                           | Location                                                      |
| ------------------------------ | ------------------------------------------------------------- |
| Product documentation          | `docs/README.md`                                              |
| Exact limits                   | `force-app/main/default/classes/PromptContextContract.cls`    |
| Stable result codes            | `force-app/main/default/classes/PromptContextReasonCodes.cls` |
| Flow and Apex boundary         | `force-app/main/default/classes/PromptContextInputApi.cls`    |
| Security authorization         | `force-app/main/default/classes/PromptContextAccess.cls`      |
| Record-page components         | `force-app/main/default/lwc`                                  |
| Apex tests                     | `force-app/main/default/classes/*Test.cls`                    |
| LWC tests                      | `force-app/main/default/lwc/**/__tests__`                     |
| Build history and traceability | `specs/prompt-context-builder`                                |
| Local quality workflow         | `.github/workflows/quality.yml` and `package.json`            |
| Permission boundary gate       | `scripts/check-permission-contract.mjs`                       |
| LWC coverage completeness      | `scripts/check-lwc-coverage.mjs`                              |
| Static-analysis configuration  | `code-analyzer.yml`                                           |
| Change-safety owner page       | `docs/contributing/change-safety-playbook.md`                 |
| Apex test-isolation gate       | `scripts/check-test-data-isolation.mjs`                       |
| Lesson-guard scenarios         | `scripts/lesson-guards.test.mjs`                              |
| Apex security-surface gate     | `scripts/check-apex-surface.mjs`                              |
| Screenshot evidence and policy | `docs/screenshots/README.md` and `manifest.json`              |
| Screenshot contract gate       | `scripts/check-screenshot-contract.mjs`                       |
