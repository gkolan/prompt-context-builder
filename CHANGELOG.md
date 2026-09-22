# Changelog

This file records user-visible changes. Package identifiers remain in `sfdx-project.json`.

## Unreleased

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
