# Changelog

This file records user-visible changes. Package identifiers remain in `sfdx-project.json`.

## Unreleased

### Added

- Added `integration-tests/security`, which runs generation, publishing, and lifecycle writes as a
  minimum-access user who holds only the package Permission Sets, so Salesforce enforces sharing,
  object access, and field access for real.
- `npm run ci:gates` now runs Salesforce Code Analyzer and fails on any critical or high finding.
  GitHub CI installs the Salesforce CLI for it and adds an `apex-validation` job that runs a
  check-only deployment with local tests once an `SF_VALIDATION_AUTH_URL` secret is set.
- Added a nightly Prompt Input Log purge and `PromptContextSchedules`, which registers the health
  check and the purge once each. Scheduled classes start their worker by name, so a scheduled job no
  longer blocks deploying the package; `check:apex-surface` enforces that.
- Prompt Builder shows **Saved changes not published** while a live template's saved draft differs
  from the version users receive, and warns when a restored version used an older syntax version.
- `{!record.Owner.Name}` and other `Name` fields across a relationship that can point to more than
  one kind of record now work when every target has a readable `Name`.
- Validation warns with `SENSITIVE_FIELD_REVIEW` when a template prints long text, which can
  contain instructions aimed at the model. The security and template guides describe the safe
  pattern.
- `check:docs` verifies that every field named in the first-template walkthrough is a real Prompt
  Builder label.
- Added syntax version 2. New publications print picklist labels, plain text from rich text, fixed
  ISO dates and UTC date-times, currency codes, and percent signs; reject Address and Location
  fields and impossible row indexes; and support `maxLength="n"` and the `{!!}` literal escape.
  Publications made with syntax version 1 keep their exact output until republished, and version
  comparison reports the change.
- Added **Is one of** and **Is not one of** filters, Salesforce relative date literals, and numbered
  filter logic such as `1 AND (2 OR NOT 3)`, parsed into a tree so the stored text never reaches the
  query.
- Added draft conflict detection: a save based on an older draft returns `DRAFT_CHANGED` instead of
  overwriting newer changes.
- Prompt Builder now shows the expected value format for each filter, offers dropdowns for yes/no
  and picklist values, numbers each filter, and hides Address and Location fields.
- Added entry-point contract tests for Apex, the Flow action, the Lightning controller, Queueable, and
  a full 200-record Batch scope, plus test-only Flow runtime tests in `integration-tests/flow-runtime`
  for an autolaunched Flow and a bulk record-triggered Flow.
- Added the `check:apex-surface` gate, which pins reviewed system-mode and sharing exceptions and
  requires every Apex entry class to authorize through `PromptContextAccess`.
- Added field-value data-set matching so a source field can match a compatible current-record
  field without requiring the administrator to choose a relationship path.
- Added bulk prompt preparation with ordered per-record results, bounded work, and atomic failure
  for each requested record.
- Added Salesforce File policy metadata, deterministic current-version selection, format and size
  limits, provider approval metadata, and a separate permission for allowing file references to
  leave Salesforce. The package does not read file bodies or call a model.
- Added the `PromptContextInputApi` Flow and Apex boundary with explicit **Return to Apex** and
  **Save to Prompt Input Log** delivery choices, idempotent request keys, and a private managed input
  log for approved later processing.
- Added dedicated Save Input, Send Files, and Process Input permissions plus executable gates for
  the common entry point, day-one contract, file policy, input log, bulk matching, field
  descriptions, permissions, namespace fixtures, and test-data isolation.
- Added a durable change-safety playbook that covers regression-first fixes, org-independent Apex
  fixtures, static analysis, source conflicts, Scheduled Apex recovery, and evidence boundaries.
- Added a dated screenshot manifest, current deployed-org browser captures, accurate historical
  file extensions, and a screenshot contract gate for inventory, file signatures, evidence scope,
  and alternative text.

### Security

- Template status, published version, version signature, draft revision, and health fields are now
  read-only in every Permission Set. Publish, deactivate, save, and the health check write them only
  after a user-mode update proves the person can edit that template. An author can no longer
  republish an inactive template, switch to an older version, or mark a template Healthy from the
  standard record page.
- Prompt Context Configure no longer grants Delete on Prompt Template, so a template's version
  history cannot be erased. Deactivate retires a template. The Prompt Templates object tab is no
  longer in the app navigation; edit templates in Prompt Builder.
- Generation now reads only the template header and its fixed published version. Prompt Context
  Generate no longer grants read access to draft template text or draft data sets.

### Fixed

- Flow, Apex, and Batch requests no longer drop related records for a record whose match value
  sorts after a busy one. A grouped query that fills its row limit is repeated for the match values
  it could not settle, within the transaction's query and row budget; otherwise the request returns
  `TRANSACTION_BUDGET_EXCEEDED` instead of an incomplete prompt.
- Publish returns `DRAFT_CHANGED` when someone saved the draft after the publisher reviewed it, and
  concurrent publishes of one template now run one at a time. Restoring a version over a newer draft
  also returns `DRAFT_CHANGED` instead of erasing the newer edits.
- `PromptContextInputLifecycle.claimAvailable` claims the longest-waiting logs first.
- `diagnosticSummary` keeps the template version when a request fails after preparation, such as a
  Request Key conflict or the Flow response-size limit.
- Flow and Batch averages over a formula match field now print the same digits as the record page.
- Added `npm run scan:sfge`, which runs Graph Engine field-security analysis on a parse-compatible copy
  and fails on engine errors. The misconfiguration matrix now requires a valid baseline and that
  generic codes name the changed setting; new tests cover mixed v1 and v2 templates in one bulk call
  and the ten-template limit.
- A query Salesforce refuses, such as ContentDocumentLink without an Id filter or a non-selective
  query on a very large object, now returns `QUERY_NOT_SUPPORTED` instead of an unexpected error.
- External, big, and Knowledge article objects are no longer offered and are refused in syntax
  version 2 (`OBJECT_KIND_NOT_SUPPORTED`).
- Validation warns about unknown picklist filter values and filter values padded with spaces.
- Syntax version 2 removes invisible control and text-direction characters from record values.
- Formula fields: syntax version 2 requires read access to every field a formula uses, fails closed
  for polymorphic formulas, refuses calculations on fields Salesforce marks as not calculable
  (`AGGREGATE_FIELD_NOT_SUPPORTED`), and calculates in Apex when a formula match field cannot be
  grouped, so Flow and Batch match the record page.
- Rich text and formula links keep their address as `text (url)`, images keep their alternative
  text, and unsafe link schemes are dropped.
- Access failures no longer name the hidden object or field to people without diagnostics access.
- `check:apex-surface` now rejects Apex reserved words used as variable names, including in
  `integration-tests`.
- Fixed four failures found by the realistic scenario suite: a huge row index no longer raises a
  platform error, more than 100 blocks is now a named validation error instead of a generation-time
  failure, `maxLength` no longer splits an emoji, and calculated values print `180` instead of
  `180.0`.
- Prompt Generator now clears an auto-selected template and generated output when refreshed
  template choices no longer contain that template or when template loading fails.
- Prompt Generator now ignores a completed generation response after the user changes templates,
  preventing context from the previous template from appearing under the new selection.
- Prompt Generator now disables template and text controls while generation is pending.
- Prompt Generator now displays successful empty-string results and their warnings instead of
  treating them as though generation never ran.
- Prompt Builder now restores the complete server-saved template when an administrator discards
  changes instead of replacing it with a catalog summary that lacks the body and sources.
- Prompt Builder now ignores stale template and field-option responses after a newer administrator
  selection.
- LWC coverage now measures the shipped component JavaScript instead of succeeding with an empty
  0% report, and the complete local gate enforces coverage floors.
- LWC coverage now runs without the transform cache and fails when either shipped component is
  absent from the generated coverage report.
- Successful Flow and Apex responses now preserve bounded-generation warning codes and explanations.

### Documentation

- Added task-oriented administrator, record-page, developer, architecture, security, operations,
  reference, contribution, support, and quality-gate documentation.
- Added dedicated Flow, diagnostics, vulnerability-reporting, issue-intake, and pull-request guidance.
- Corrected Permission Set guidance to reflect that Prompt Context Configure already includes the
  Generate and Diagnostics custom permissions.
- Documented field-value matching, bulk preparation, Salesforce File metadata, provider approval,
  Prompt Input Log retention, delivery choices, permissions, limits, reason codes, security
  boundaries, and record-page behavior across the task guides and exact references.
- Separated local, check-only validation, deployment, browser, and package claims throughout the
  contributor and screenshot evidence guidance.

### Repository

- Added a public-release hygiene gate for local paths, full Salesforce Org IDs, private keys,
  generated analyzer output, and private planning transcripts.
- Added public contribution, support, security, release-checklist, Node-version, and line-ending
  guidance; aligned npm metadata with the Salesforce package version.
- Added a Contributor Covenant Code of Conduct, ownership routing, and a fork-to-pull-request
  contributor path for public community participation.
- Redacted environment identifiers and removed private planning transcripts and generated analysis
  reports from the public source set.
- Reworked the repository landing page around a prepared evaluator journey, added a complete
  scratch-org demo guide, and exposed repeatable source-demo setup and verification commands.
- Clarified that historical package aliases are not public installation approval and added
  executable guards for the demo entry points and required ignore rules.
- Split upgrade and removal guidance by source, package, and scratch-org lifecycle so evaluators do
  not apply package assumptions to source-deployed metadata.

## 1.0.3

- Added aggregate record sources and the separate `{!aggregate.alias.value}` merge namespace.
- Added packaged and namespace-compatibility verification described in the repository build record.

Earlier implementation history and verification evidence remain in
`specs/prompt-context-builder/06-build-record.md`.
