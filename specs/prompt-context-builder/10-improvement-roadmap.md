# Adaptability and administrator-experience roadmap

## Outcome

This roadmap improves configuration and governance without expanding the product into external-provider calls,
files, personas, or conversation storage. Every accepted capability must continue to use the shared
user-mode engine, immutable publication snapshots, schema allowlists, bind variables, all-or-none output,
and code-owned resource ceilings.

## Accepted increments

1. Guide a junior administrator through source scope, object and matching, prompt-visible fields,
   optional rules, and insertion into the prompt. Keep advanced rules collapsed initially.
2. Keep an editable template and the latest merged preview side by side. Explain incomplete blocks
   before a server request and retain authoritative server validation before preview or publication.
3. Provide starter recipes as ordinary editable configuration. Recipes never bypass validation,
   preview, publication, or runtime security.
4. Return a current object-and-field health result and a field-access list without reading customer
   record values. Warn when contact-data or encrypted field types deserve an explicit privacy review.
5. Compare immutable versions with value-free summaries. A rollback copies an old snapshot into the
   draft and requires a new preview/publication, preserving history.
6. Support limited named filter groups. Rules inside a group use `AND`; administrators choose only
   `AND` or `OR` between groups. No expression string, parentheses editor, or raw clause exists.
7. Add privacy-safe operational evidence and scheduled schema-health validation only if it records
   identifiers, outcome codes, timing, and version metadata. It never stores prompts, record values, bind values,
   query text, hidden counts, or exception stacks.
8. Complete keyboard, screen-reader, responsive, localization, browser-journey, namespace, packaging,
   and upgrade regression evidence before release.
9. Add a distinct scalar aggregate result mode with an explicit operation allowlist, operand-type
   validation, a one-row resource charge, and the separate `{!aggregate.alias.value}` namespace.

## Deliberate boundaries

- Existing formatting helpers (`upper`, `lower`, and `percent`) are the only supported calculated-value functions.
  Arbitrary formulas, Apex callbacks, JavaScript, and expression evaluation remain excluded.
- A source count still means the number of included visible rows. Full matching-set calculations use
  the delivered scalar aggregate result mode instead: only `COUNT`, `SUM`, `AVG`, `MIN`, and `MAX`,
  no grouping, one scalar result, schema-checked operands, user-mode execution, and the separate
  `{!aggregate.alias.value}` namespace. It is not represented as an ordinary record row.
- Nested free-form Boolean logic is excluded. The two-level named-group model is intentionally the
  maximum supported shape for this release.
- Scheduled health checks validate configuration and schema only. They do not query sample customer
  records and cannot prove the access of every possible runtime user.

## Red scenarios added by this increment

| ID      | Scenario                                             | Required result                                                               |
| ------- | ---------------------------------------------------- | ----------------------------------------------------------------------------- |
| IMP-001 | Getter renders before tracked arrays initialize      | Empty state renders; the component does not crash                             |
| IMP-002 | Recipe is applied to the wrong root object           | Recipe is not offered                                                         |
| IMP-003 | Recipe references a removed field                    | Current-schema health blocks publication                                      |
| IMP-004 | Field-access list includes a contact-data field      | Value-free privacy warning is shown                                           |
| IMP-005 | Administrator compares the same version              | A value-free “no differences” result is shown                                 |
| IMP-006 | Administrator restores an old version                | Draft changes; immutable snapshots remain unchanged                           |
| IMP-007 | Filter join contains text other than AND/OR          | Validation rejects it before query compilation                                |
| IMP-008 | Filter group name contains syntax                    | Validation rejects it as an identifier                                        |
| IMP-009 | More than five filter groups are configured          | Validation blocks the source                                                  |
| IMP-010 | Two rules share a group                              | Both rules must match                                                         |
| IMP-011 | Groups use OR                                        | Any complete group may match, while the current-record match remains required |
| IMP-012 | Metrics attempt to include prompt or record content  | Storage contract rejects the field; tests scan the DTO/object surface         |
| IMP-013 | Scheduled validator runs after field deletion        | Template is marked unhealthy with value-free reasons                          |
| IMP-014 | Health scheduler lacks configuration access          | It returns an access error and does not switch to system-mode customer reads  |
| IMP-015 | Aggregate uses a record-row merge token              | Validation rejects the result-mode mismatch                                   |
| IMP-016 | Record source uses an aggregate merge token          | Validation rejects the result-mode mismatch                                   |
| IMP-017 | SUM/AVG targets a nonnumeric field                   | Validation blocks the source before query compilation                         |
| IMP-018 | Aggregate operation is not allowlisted               | Validation blocks the source                                                  |
| IMP-019 | Object picker contains feeds/history/share artifacts | Picker omits them while explicit schema validation remains available          |
| IMP-020 | Object label is missing                              | Picker omits the unusable option                                              |

## Execution gates

1. Apex request classes and UI data compile; Jest covers early rendering, recipe application, health results,
   and version comparison.
2. Named filter groups persist in draft and immutable source snapshots and pass positive/adversarial
   Apex tests.
3. Full scratch-org check-only deployment passes all local tests and package coverage remains at
   least 75%.
4. Static analysis reports no Critical, High, or Security findings.
5. Deployed browser journeys capture wide and narrow screenshots for configuration, validation,
   preview, version comparison, and runtime generation.
6. Namespace-free and registered-namespace regressions pass, followed by a clean package install and
   upgrade test.

## Completed evidence

- Final namespace-free deployment `0AfEc00000o3RbZKAU`: 143/143 components and 71/71 tests.
- Registered `rhc` namespace run `707cf00001FKV7y`: 78/78 tests at 85% coverage.
- Installed-package run `707RL00001hvRQh`: 78/78 tests at 85% after upgrade to `1.0.3.2`.
- Recommended analyzer report `code-analyzer-results-20260919-175418.json`: 0 Critical, 0 High,
  and 0 Security-category findings.
- Local CI: Prettier, namespace fixture, ESLint, and 13/13 Jest tests passed.
- Browser evidence covers wide and 390-pixel layouts, aggregate setup, field-access list,
  real-record preview, version comparison, and record-page generation.
