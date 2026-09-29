# Requirement traceability

## 1. Requirement coverage

Private planning transcripts are not part of the public source tree. The durable product,
security, scenario, and execution contracts preserve the requirements needed to understand,
maintain, and verify the implementation.

| Requirement                                                                                         | Durable specification owner                                                                                          |
| --------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Build only the prompt from a record and explicitly configured context                               | Product Contract sections 1-2 and invariant 8                                                                        |
| Support multiple independently filtered, sorted, and limited datasets for the same object           | Product Contract sections 6-12; Scenario Matrix sections A-D and H; Execution Phases 3-7                             |
| Cover everyday, invalid, adversarial, edge, recovery, and usability behavior before implementation  | Scenario Matrix in full; Product Contract sections 3, 5, 9, 13-15; Execution Phase 0 and Phase 8                     |
| Enforce field security, record access, query safety, limited execution, and safe diagnostics        | Security Contract in full; Scenario Matrix sections G-I; Execution Phases 5, 6, 9, and 10                            |
| Complete a greenfield implementation without legacy compatibility                                   | Application source, metadata, tests, and execution record                                                            |
| Support record-page, Flow, Apex, Batch, Queueable, and Scheduled Apex entry points                  | Stable bulk Apex API, Flow invocable action, resource planner, and execution documentation                           |
| Preserve versioned contracts, immutable publication snapshots, stable keys and codes, and extension | Versioned contracts, immutable publication snapshots, stable keys/codes, Describe cache, resource plan, lazy loading |

## 2. Scope traceability

| Requirement                     | Contract                              | Scenarios                                       | Execution             |
| ------------------------------- | ------------------------------------- | ----------------------------------------------- | --------------------- |
| Prompt construction only        | Product §1-2                          | Final release exclusion checks                  | Phase 0.1, Phase 11.4 |
| Root record fields              | Product §8                            | DAY-001-004                                     | Phases 2, 3, 6, 7     |
| Parent relationships            | Product §8-10                         | DAY-003-004, REL coverage in source/field cases | Phases 2.1-2.2, 6.3   |
| Child/related collections       | Product §6-8                          | DAY-005-015                                     | Phases 4-7            |
| Multiple sources on same object | Product §7                            | DAY-010-011, ORD-013-015                        | Phases 4.1-4.5, 6.4   |
| Independent filters/sort/limits | Product §6, §10                       | ORD and SRC sections                            | Phases 4-5            |
| Stable alias identity           | Product §6-8                          | DAY-016, ORD-014-015, SRC-001-004               | Phases 4.1-4.2        |
| No inline SOQL requirement      | Product §3, §5-6                      | UX-001-006                                      | Phase 8               |
| Readable syntax                 | Product §8-9                          | TMP and UX sections                             | Phases 3 and 8        |
| Fallbacks and empty branches    | Product §8, §11                       | EMP section                                     | Phase 7               |
| Preview and editing             | Product §5, §13                       | UX-007-012                                      | Phase 8               |
| Draft/publish/deactivate        | Product §13                           | REC-007-008, UX-007-012                         | Phases 0.4 and 8.7    |
| No prompt persistence           | Product §2, invariant 8; Security §14 | SEC-020-021, REC-010                            | Phases 9 and 10       |

## 3. Merge-language traceability

| Language rule                         | Contract             | Negative/edge scenarios                                                     | Planned tests         |
| ------------------------------------- | -------------------- | --------------------------------------------------------------------------- | --------------------- |
| Namespaced root fields                | Product §8           | TMP-001-004                                                                 | Phase 3.1-3.4         |
| Related indexed fields                | Product §8           | ORD-004, ORD-011-012                                                        | Phases 3.4, 4.4, 7.1  |
| Related count                         | Product §8           | EMP-008-009                                                                 | Phase 7.1-7.4         |
| `each`/`else`                         | Product §8           | TMP-008-010, EMP-001-002                                                    | Phases 3 and 7        |
| `if`/`else`                           | Product §8           | TMP-009-010                                                                 | Phases 3 and 7        |
| Lexical aliases                       | Product §8           | TMP-012-013                                                                 | Phases 3.3-3.4, 7.4   |
| `format`                              | Product §8           | TMP-017, FMT section                                                        | Phases 3.4 and 7.3    |
| `fallback`                            | Product §8, §11      | TMP-014-016, EMP section                                                    | Phases 3.4 and 7.3    |
| No reparse of values                  | Product invariants 7 | TMP-021, SEC-017                                                            | Phases 7.2-7.4, 9.2   |
| `related.*` supersedes `query.*.rows` | Product §8           | Parser corpus includes rejected legacy syntax or explicit migration finding | Phase 0.2 and Phase 3 |

## 4. Query and determinism traceability

| Rule                                   | Record Health Check precedent                         | Contract/scenarios           | Planned evidence                               |
| -------------------------------------- | ----------------------------------------------------- | ---------------------------- | ---------------------------------------------- |
| Parse token once into typed shape      | Merge-token architecture                              | Product §12; TMP scenarios   | Parser typed-AST tests                         |
| Requested field must be selected       | Query-token projection rules                          | Product §6, §12; TMP-005     | Projection-plan tests                          |
| Positional row requires explicit order | Query-token deterministic-ordering rules              | Product §10; ORD section     | Ordering tests                                 |
| Index must fit limit                   | Query-token authored-limit validation                 | Product §8, §10; ORD-011-012 | Index/cap tests                                |
| Unsafe query shapes rejected           | User-mode SOQL template validation                    | Security §9; SEC-013-015     | Query compiler adversarial tests               |
| Only root values bind related queries  | Merge-syntax binding rules                            | Product §2 and §12; SRC-016  | Surface validation tests                       |
| Bound tokens/output/rows               | Record Health Check parser/output/row-cap design      | Product §15; LIM section     | Phase 0.3, Phase 3.5, Phase 5.4-5.5, Phase 7.5 |
| Return no prompt after an access error | Record Health Check validation and reason-code design | Product §11-16               | Every red fixture asserts no prompt            |

## 5. Security traceability

| Requirement                     | Security contract | Scenarios                     | Execution                             |
| ------------------------------- | ----------------- | ----------------------------- | ------------------------------------- |
| Separate template capabilities  | §2                | Authorization paths in SEC/UX | Phases 0.4, 6.1, 8.7                  |
| Runtime CRUD/FLS                | §3-6              | SEC-001-006                   | Phase 6.2-6.5                         |
| Sharing/restriction/scoping     | §3-4, §8          | SEC-007-009                   | Phase 6 and platform tests            |
| Explicit user mode              | §4                | SEC-001-009, SEC-013          | Phases 5.3 and 6                      |
| No silent stripping             | §7                | EMP-010-012, SEC-002/004      | Phase 6.5                             |
| No hidden-existence leakage     | §8                | SEC-008-009, SEC-022          | Phases 6 and 9                        |
| Bind-based query construction   | §9                | SEC-011-015                   | Phase 5                               |
| Record-ID/object validation     | §10               | SEC-010                       | Phase 6.1                             |
| Closed non-executable grammar   | §11               | TMP section, SEC-016-018      | Phases 3 and 7                        |
| Sensitive field exclusions      | §12               | FMT-007-014                   | Phases 2, 4, 7                        |
| Safe plain-text rendering       | §13               | TMP-021-023, SEC-016-018      | Phases 7, 8, 10                       |
| No storage/log/cache/event leak | §14-15            | SEC-019-021, REC-010          | Phase 9                               |
| Prompt-data boundary            | §16               | SEC-018                       | Template examples and rendering tests |
| Audit without customer content  | §17               | REC and UX lifecycle          | Phases 8.7 and 9.1                    |

## 6. Scenario completeness

| Category                        | Scenario IDs | Durable owner      |
| ------------------------------- | ------------ | ------------------ |
| Everyday                        | DAY-001-020  | Scenario Matrix §A |
| Multiple sources and ordering   | ORD-001-015  | Scenario Matrix §B |
| Template misconfiguration       | TMP-001-023  | Scenario Matrix §C |
| Related-source misconfiguration | SRC-001-020  | Scenario Matrix §D |
| Empty and missing data          | EMP-001-012  | Scenario Matrix §E |
| Field types and formatting      | FMT-001-014  | Scenario Matrix §F |
| Security and adversarial        | SEC-001-022  | Scenario Matrix §G |
| Limits/performance/consistency  | LIM-001-012  | Scenario Matrix §H |
| Schema change and recovery      | REC-001-010  | Scenario Matrix §I |
| Configuration usability         | UX-001-012   | Scenario Matrix §J |

Total specified scenarios: 160.

## 7. Resolved version 1 decisions

1. Exact hard caps are code-owned in `PromptContextContract`; author limits can only reduce them.
2. Drafts and active definitions use custom objects; publishing creates immutable template and
   source snapshot records.
3. Ungrouped scalar aggregate sources are delivered through a distinct typed result mode and
   `{!aggregate.alias.value}` namespace. Grouped aggregates remain excluded.
4. Parent and matching field paths are capped at five relationships.
5. Polymorphic relationship paths are deferred.
6. Warnings are returned per validation/generation run and are not persisted or acknowledged.
7. Version 1 supports default typed date/datetime rendering plus `upper`, `lower`, and `percent`;
   explicit currency-basis conversion is deferred.
8. Ordinary responses use stable reason codes and safe prose. Separately authorized diagnostics
   contain at most 200 characters of contract, syntax, outcome, and template-version metadata. No
   prompt, field value, bind value, record count, query text, or stack trace.

## 8. Definition of traceable

The public specification is traceable when:

- all supported requirements have a durable specification owner;
- superseded syntax is identified in the standard contract;
- everyday, invalid, edge, security, volume, recovery, and usability behavior is enumerated;
- execution is ordered into gated steps; and
- completed build evidence is recorded separately in `06-build-record.md`.
