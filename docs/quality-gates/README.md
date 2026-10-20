# Quality gates

`npm run ci:gates` is the local pull-request gate. It verifies formatting, documentation links and
navigation, screenshot inventory and file signatures, the Permission Set custom-permission
boundary, a description for every Salesforce custom field, the namespace fixture contract,
plain-language and public-release hygiene, the entry-point, file, input-log, and bulk-matching
source contracts, Apex test-data isolation, the Apex security surface, LWC lint, LWC Jest behavior,
enforced JavaScript coverage floors, and Salesforce Code Analyzer. It needs Node.js 22, the
Salesforce CLI, and the Code Analyzer plugin (`sf plugins install code-analyzer`), but no
Salesforce org.

The coverage command disables Jest's transform cache and then verifies that the controller of every
component folder under `force-app/main/default/lwc` is present in `coverage-final.json`. A green
percentage threshold is not accepted when coverage data for a component is missing. Prompt Builder
is split into section components, and each one keeps its own line-coverage floor in
`jest.config.js`.

## Evidence by change type

| Change            | Required evidence                                                                     |
| ----------------- | ------------------------------------------------------------------------------------- |
| JavaScript or LWC | ESLint, focused Jest regression, complete Jest suite                                  |
| Apex              | Focused Apex regression, `RunLocalTests`, coverage result, static analysis            |
| Metadata          | Formatter, field-description and namespace gates, approved-org deployment validation  |
| Documentation     | Formatter, local-link validation, source review of every exact claim                  |
| UI screenshots    | Manifest, file signature, alternative text, visual review, named browser evidence     |
| Package boundary  | Package-version test and clean install/upgrade evidence approved by the release owner |

Code Analyzer uses `code-analyzer.yml` to apply the repository's ESLint configuration and keep
Node-only repository scripts out of LWC rule scope. `npm run scan:code-analyzer` runs the Recommended
rules on `force-app` and fails on any critical or high finding. Moderate and low findings are
advisory; review them in changed files as the change safety playbook describes. Do not suppress a finding merely because it is
inconvenient; document and narrowly bound any genuine engine false positive.

The Apex test-data isolation gate rejects Account, Contact, and User DML in package test classes.
Tests may construct those records in memory for language and schema behavior, reuse the running test
user, and persist only package-owned fixtures. Deploy-critical tests therefore do not depend on
subscriber validation rules, flows, or triggers on those org-owned records.

The Apex security-surface gate (`check:apex-surface`) fails when production Apex declares an
unreviewed `without sharing` class or changes the reviewed `SYSTEM_MODE` count. It also fails on a
production `Test.isRunningTest()` branch, an Apex reserved word used as a variable name in any class
including `integration-tests`, inline SOQL without `WITH USER_MODE`, Database calls
without an explicit `AccessLevel`, DML statements, or an entry class that neither calls
`PromptContextAccess.require*()` nor delegates to an approved class that does. See
[Security and data access](../architecture/security-and-data-access.md).

`npm run scan:sfge` runs Salesforce Graph Engine, the path-based field and object security analyzer,
on a temporary copy of the production Apex. Graph Engine cannot parse `??` inside a for-each header,
so the copy drops only that fallback. The scan fails when the engine reports an error or any
unreviewed production finding, so an engine crash cannot pass as a clean scan. It needs Java and is
not part of `ci:gates`; run it before release and after changing data access.

The agent-guidance gate verifies that `AGENTS.md` retains the mandatory session link and that the
[change safety playbook](../contributing/change-safety-playbook.md) remains connected to contributor
and quality documentation. Repository-aware agents receive `AGENTS.md` at session start; the linked
playbook is mandatory reading for Apex, metadata, validation, and deployment work.

## Automated and external evidence

| Check                                              | In `ci:gates` and GitHub CI | Requires an approved Salesforce org |
| -------------------------------------------------- | --------------------------- | ----------------------------------- |
| Formatting and documentation links                 | Yes                         | No                                  |
| Screenshot inventory, signatures, and references   | Yes                         | No                                  |
| Agent-guidance presence and navigation             | Yes                         | No                                  |
| Apex test-data isolation source check              | Yes                         | No                                  |
| Apex security-surface source check                 | Yes                         | No                                  |
| LWC lint, Jest behavior, and coverage completeness | Yes                         | No                                  |
| Salesforce Code Analyzer, critical and high        | Yes                         | No                                  |
| Apex compilation and `RunLocalTests`               | CI only, once configured    | Yes                                 |
| Check-only deployment                              | CI only, once configured    | Yes                                 |
| Source-conflict inspection and resolution          | No                          | Yes                                 |
| Scheduled Apex inventory and restoration           | No                          | Yes                                 |
| Mutating deployment                                | No                          | Yes                                 |
| Browser or package verification                    | No                          | Yes                                 |

The `apex-validation` CI job runs a check-only deployment of `force-app` and the three test-only
suites in `integration-tests/flow-runtime`, `integration-tests/formula-fixtures`, and
`integration-tests/security` with `RunLocalTests`. The security suite needs one free Salesforce user
license in the validation org. The job is skipped until the repository owner stores an SFDX
authorization URL for an approved validation org in the `SF_VALIDATION_AUTH_URL` repository
secret, and it never deploys. Use an org reserved
for validation: pull requests from this repository run their Apex tests there, and secrets are not
available to pull requests from forks.

The local gate cannot prove Apex compilation, Salesforce test results, source-conflict safety,
deployment, schedule restoration, browser behavior, or package installation. Follow the
[change safety playbook](../contributing/change-safety-playbook.md) for those steps and report each
evidence category separately.

## Screenshot boundary

`check:screenshots` verifies that every image under `docs/screenshots` is recorded in the manifest,
that its extension matches its PNG or JPEG signature, that current entries include surface, state,
and viewport metadata, and that Markdown images have alternative text. It also prevents the root
README from embedding an image marked historical.

The gate cannot prove that a screenshot is fresh, that it came from the named org, that the visible
state matches the working tree, or that no sensitive value is visible. A reviewer must inspect the
image and the capture notes. Use the [UI screenshot evidence](../screenshots/README.md) procedure.

## Isolation-gate boundary

`check:test-data-isolation` is a structural guard, not a complete Apex parser. It detects direct and
typed-variable DML patterns for `Account`, `Contact`, and `User` in test classes and the shared test
factory. Reviewers must also inspect indirect factory calls, multiline expressions, generic
`SObject` aliases, dynamic Apex, and new subscriber-owned object types. A package-owned fixture can
still be affected by subscriber additions in some installation models, so any-org compatibility
claims must name their prerequisites and tested org shapes.

## Regression-first rule

For a bug fix, record the observable failing behavior, run the focused test against the broken
implementation, apply the smallest fix, and rerun the focused and complete gates. Include ordinary,
empty, boundary, error, permission, bulk, namespace, and platform variants when they can affect the
behavior.

## Evidence boundaries

- Formatting proves formatting only.
- Jest proves client behavior in its test environment, not Salesforce deployment.
- Apex tests prove behavior of the source deployed to the target org.
- A source deploy is not an installed-package upgrade.
- Static analysis findings require review; severity alone does not prove a defect.
- Check-only validation does not authorize bypassing Salesforce source-conflict protection.
- A temporarily stopped Scheduled Apex job must be restored and verified even when deployment fails.
