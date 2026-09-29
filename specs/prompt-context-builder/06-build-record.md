# Build record

## September 24, 2026 day-one input increment

The current source adds field-value matching with grouped queries, Salesforce File selection,
approved service settings, one common Flow and Apex entry, the private Prompt Input Log, and saved
input lifecycle processing. It intentionally contains no old API wrapper or third delivery choice.

Current validation evidence:

- `0AfRL00000i63GP0AY`: 204 components compiled and 36/36 focused Apex tests passed. The dry run is
  shown as Failed only because a focused test list does not cover every deployed Apex class.
- `0AfRL00000i64M90AI`: 204 components compiled and 19/19 end-to-end input and lifecycle tests
  passed, including exact selected-file details saved through `PromptContextInputApi`.
- Local file, input-log, common-entry, day-one, permission, namespace, language, and grouped-query
  contract checks passed during development.
- LWC Jest passed 21/21 tests after the file picker and builder changes.
- `0AfRL00000i66UQ0AY`: the final explicit `RunSpecifiedTests` dry run passed with 204/204
  components, 112/112 repository Apex tests, zero component or test errors, no coverage warnings,
  and 85.79% aggregate coverage.
- `0AfRL00000i62p00AA`: the `RunLocalTests` dry run passed with 204/204 components, 41/41 Apex
  tests, zero component or test errors, and no coverage warnings. Aggregate source coverage in the
  preceding successful full validation was 79.2%.
- `0AfRL00000i7CCn0AM`: the subsequent full source deployment succeeded in `pcb-package-test` with
  204/204 components deployed, 42/42 local Apex tests passed, and zero component or test errors.
- Post-deployment destructive validation `0AfRL00000i7BJy0AM` failed safely before running tests or
  deleting metadata because Salesforce will not delete the active
  `Prompt_Context_Account_Record_Page` FlexiPage. The retired `PromptContextApi` and
  `PromptContextApiTest` classes, FlexiPage, and `Prompt_Context_Source__c` tab therefore remain in
  the scratch org until the page is deactivated and the exact four-component deletion is revalidated.
- The final local gate passed 22/22 LWC tests, including stable next-page File browsing that retains
  the user's current selection.
- The final Recommended Code Analyzer scan reported 0 Critical, 0 High, and 0 Security-tagged
  findings; the full source tree has 203 Moderate, 443 Low, and 4 Informational maintainability
  findings.
- Official AWS API references were rechecked on September 24, 2026 and still state the five-document,
  4.5 MB-per-document, text-block, user-role, format, neutral-name, and model-dependent Amazon S3
  source rules recorded in specification 13.

The dry runs did not change metadata. The later deployment recorded above deployed this increment to
the identified scratch org, but the blocked destructive cleanup means the org is not yet an exact
mirror of the local deletions. No new package version was created or promoted, and browser
verification has not been run for this increment. Live AWS upload, scanning, Amazon Bedrock,
response, and cleanup evidence is unavailable because the required security-owner decision, AWS
service, Named Credential, region, and approved model were not provided or authorized.

## Evidence scope

The deployment IDs, package results, browser checks, and screenshots below record the verified
September 19, 2026 product build. The plain-language revision completed on September 22, 2026
changes labels, help text, messages, comments, and guidance. Its local checks and Salesforce code
scan are recorded separately below. The revision also passed a validation-only deployment and a
separate Apex test run in the identified package-test scratch org. It is not described as deployed,
browser-verified, or package-verified.

## Plain-language revision

- Customer-facing Salesforce wording is checked by `npm run check:language`.
- Humanizer checks now cover product guidance and design records through `npm run check:docs`.
- Prompt Builder wording has a focused 12-test Jest regression suite.
- The September 22 Recommended Salesforce Code Analyzer scan found no Critical or High findings
  and offered no automatic fixes. It reported 148 Moderate, 323 Low, and 2 Info findings from the
  repository's broader quality backlog.
- `npm run ci:gates` passed for the revised source.
- Validation-only deployment `0AfRL00000i0ERT0A2` passed in `pcb-package-test`: 142/142 components
  succeeded with no component errors. No metadata was deployed.
- Apex test run `707RL00001iI0ZU` passed 78/78 tests with 85% coverage in the same org.

## Delivered boundary

The delivered application builds a prompt from a Salesforce root record and configured related
or limited reference-record context. Files, external-provider calls, provider responses, saved conversations,
personas, and customer record writes are deliberately excluded.

## Version 1 decisions

- Runtime-authored configuration uses `Prompt_Template__c` and child
  `Prompt_Context_Source__c` records.
- Templates use the org's runtime object and field API names. No package namespace is assumed.
- Every source has a unique lexical alias. Two sources may query the same object while retaining
  independent fields, filters, sorting, and row limits.
- Source filters use limited named groups: `AND` inside a group and only a typed `AND`/`OR` choice
  between groups. Arbitrary SOQL and free-form WHERE clauses are never accepted.
- Root and related field paths may traverse at most five relationships.
- Related mode supports equality between one source field and one root-record field. Reference
  mode provides a visibly broader, limited query that remains subject to user-mode security.
- Ungrouped scalar aggregate queries are supported through a distinct allowlisted result mode.
  Polymorphic paths, grouped queries, nested `each` blocks, files, external-provider calls, and conversation
  storage remain excluded.
- Publishing requires a successful preview against a real record. Publication stores a
  fingerprint of the validated configuration.
- Generation is all-or-none: an access, configuration, query, or size error returns no partial prompt.

## Security implementation

- Entry services run `with sharing`; reusable data services run `inherited sharing`.
- Dynamic reads use `Database.queryWithBinds` in `AccessLevel.USER_MODE`.
- Editable configuration writes use user-mode DML. Publication creates immutable version snapshots
  in system mode after authorization, validation, and preview so authors cannot insert snapshots
  directly.
- Object and field names are resolved from schema describes and allowlists, never concatenated
  directly from unchecked input.
- Every requested root, related, filter, matching, and sort field is checked for accessibility.
- Encrypted and blob fields are rejected. Inaccessible data returns an access error and is never
  silently omitted or replaced with a misleading value.
- Permission sets separate template configuration from runtime generation.

## Executed delivery sequence

1. Captured the complete conversation and converted it into product, scenario, security,
   execution, and traceability specifications.
2. Created the greenfield Salesforce DX project and a 30-day scratch org from
   `rhc-devlabs-dev-hub`.
3. Implemented the configuration objects, fields, tabs, application, list views, labels, and
   permission sets.
4. Implemented schema validation, the limited query engine, merge-language parser and renderer,
   template lifecycle, controller boundary, and security enforcement.
5. Implemented the junior-admin Prompt Builder and record-page Prompt Generator LWCs.
6. Added unit tests, Jest tests, deployment validation, sample templates, and sample record data.
7. Completed successful check-only and full deployments, sample-data seed, post-deploy
   verification, 2GP creation, clean install, two upgrades, installed-package regression tests,
   and isolated namespaced regression testing.

## Deployment evidence

| Item                               | Value                                                 |
| ---------------------------------- | ----------------------------------------------------- |
| Scratch org alias                  | `promptcontextbuilder`                                |
| Scratch org ID                     | Redacted from the public build record                 |
| Scratch org expiration             | 2026-10-19                                            |
| Check-only deployment              | `0AfEc00000o36aLKAQ`: 51/51 components, 28/28 tests   |
| Deployment                         | `0AfEc00000o36bxKAA`: 51/51 components, 28/28 tests   |
| Final field-access list validation | `0AfEc00000o36nFKAQ`: 50/50 components, 28/28 tests   |
| Hardened deployment                | `0AfEc00000o377WKAQ`: 53/53 components, 38/38 tests   |
| Final hardened deployment          | `0AfEc00000o3EjDKAU`: 55/55 tests, 85.06% coverage    |
| Improvement release deployment     | `0AfEc00000o3RbZKAU`: 143/143 components, 71/71 tests |
| Seeded published template          | Record ID redacted from the public build record       |
| Seeded Account used for preview    | Record ID redacted from the public build record       |

The seed template demonstrates two Contact data sets with different filters and sorting. Its stable
automation key is `account_contact_context`. It was republished as version 3 into fixed template
and data set version records using syntax version 1 and contract version 1.0. Its publication
preview completed successfully and generated a 217-character prompt.

## Final verification

- Final source deployment: 143/143 components deployed and 71/71 local tests passed.
- Flow, Queueable, Batch, and Scheduled execution-context tests all passed against the same public
  API and published snapshot.
- Runtime smoke test: compiled and passed, generated 217 characters from two independent aliases,
  used nine SOQL queries, and performed no DML.
- LWC Jest: 2/2 suites and 13/13 tests passed.
- ESLint and Prettier checks passed.
- Salesforce Code Analyzer reported 0 Critical, 0 High, and 0 Security-category findings.
- Isolated `rhc` namespace regression: 78/78 Apex tests passed at 85% coverage.
- Official SLDS linter reported zero findings; the SLDS quality analyzer scored 100/100 in every
  category.
- Deployed Builder, query-source, and record-page Generator screenshots are stored in
  `docs/screenshots`.

## 2GP and upgrade evidence

Packaging was enabled in `rhc-devlabs-dev-hub`, then verified through the `Package2` Tooling API.
The unlocked package is `0Hobm0000006TnJCAU` and remains owned by the requested product Dev Hub.

| Item                           | Evidence                                      |
| ------------------------------ | --------------------------------------------- |
| Initial package version        | `1.0.0.1` / `04tbm000000iuo5AAA`              |
| First verified upgrade         | `1.0.1.1` / `04tbm000000iuphAAA`              |
| Final hardened package version | `1.0.2.1` / `04tbm000000iuw9AAA`              |
| Improvement package version    | `1.0.3.2` / `04tbm000000ivYrAAI`              |
| Package code coverage          | 85%; Salesforce coverage check passed         |
| Clean validation org           | `pcb-package-test` (Org ID redacted)          |
| Validation org expiration      | 2026-10-19                                    |
| Final installed-package tests  | `707RL00001hvRQh`: 78/78 passed, 85% coverage |
| Installed final version        | `1.0.3.2`; mixed-mode upgrade succeeded       |

The package and project are namespace-neutral: there are no hardcoded runtime data prefixes, and
the namespace-free release path is fully verified. Compatibility was additionally executed in the
isolated `pcb-rhc-ns-test` scratch org (Org ID redacted, expired 2026-09-20) using the existing
`rhc` registry and `rhc-dev-hub`. Core deploy `0Afcf00000BrAitCAF`, FlexiPage deploy
`0Afcf00000BrEMfCAN`, and app/permission-set deploy `0Afcf00000Br7LDCAZ` succeeded. Apex run
`707cf00001FKV7y` passed 78/78 tests at 85% coverage and
reported `NamespacePrefix: rhc`. The shipping package remains owned by `rhc-devlabs-dev-hub` and
namespace-free; the separate FlexiPage fixture is integration-only.

## Improvement release completed

The release adds guided related data setup, starter recipes, a synchronized template and preview
workspace, setup checks, required field access, data-classification warnings, fixed-version
comparison, safe restore-to-draft, and named filter groups with firm limits. Filter rules inside
one group use `AND`; groups can use only the typed `AND` or `OR` choice. The current-record match
remains required, so an OR group can never include unrelated records.

It also adds calculated values, privacy-safe Platform Event measurements, scheduled setup checks,
translatable record-page generator labels, curated Salesforce object choices, responsive layouts,
and a criterion-by-criterion accessibility review.

Final evidence:

- Namespace-free deployment `0AfEc00000o3RbZKAU`: 143/143 components, 71/71 tests.
- Daily health job `08eEc00000i6L8ZIAU`: `WAITING`, next fire 2026-09-20 09:00 UTC.
- `rhc` regression `707cf00001FKV7y`: 78/78 tests, 85% coverage.
- Package `1.0.3.2` / `04tbm000000ivYrAAI`: 85% package coverage; upgrade succeeded.
- Installed-package regression `707RL00001hvRQh`: 78/78 tests, 85% coverage.
- Code Analyzer `code-analyzer-results-20260919-175418.json`: 0 Critical, 0 High, 0 Security.
- Local gates: Prettier, namespace fixtures, ESLint, and 13/13 Jest tests passed.
- Browser journeys and current screenshots cover configuration, aggregate setup, validation,
  preview, comparison, responsive rendering, and runtime generation.

## Verification template catalog

On 2026-09-19, `scripts/apex/seedVerificationTemplates.apex` created 12 numbered examples against
the deterministic **Prompt Context Verification Account**. The independent
`verifyVerificationTemplates.apex` assertion run compiled and completed successfully: nine
Published templates generated prompts, two Draft examples behaved as designed, and one Inactive
template was rejected and excluded from runtime choices. The catalog covers every merge,
filter, sort, source mode, result mode, aggregate operation, lifecycle, empty-state, parent-path,
and maximum-source option family. Details and replay instructions are in
`11-sample-template-catalog.md`.
