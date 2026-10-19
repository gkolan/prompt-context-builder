# Changelog

This file records user-visible changes. Package identifiers remain in `sfdx-project.json`.

## Unreleased

### Added

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

### Fixed

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
