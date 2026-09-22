# Hardening, extensibility, and UI specification

## Goal

Make Prompt Context Builder useful for common and advanced administrator scenarios without exposing
raw SOQL, bypassing Salesforce security, or making the UI depend on developer knowledge.

## Query scope decision

The product supports structured queries, not arbitrary SOQL. Administrators choose objects,
fields, filters, sorting, and limits from schema-backed controls. The server validates every choice
again before building bind-variable SOQL.

Two source modes cover the intended use cases:

| Mode              | Current-record binding | Intended use                                                                                                                     |
| ----------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Related records   | Required               | Contacts for an Account, Cases for a Contact, junction rows, records correlated through an external key                          |
| Reference records | Not used               | A bounded policy list, active product guidance, regional reference data, or another visible dataset that provides shared context |

Reference mode is deliberately visible and produces a warning during validation. It never grants
access: user-mode SOQL, sharing, restriction rules, object access, field access, filters, sorting,
and limits still apply. Free-form SELECT, WHERE, GROUP BY, HAVING, OFFSET, subqueries, query hints,
or system-mode execution are not accepted.

## User journeys

### Junior administrator

1. Select a root object.
2. Type the prompt and insert root fields using a picker.
3. Add a source and choose whether it is related or reference context.
4. Select the queried object and prompt-visible fields.
5. For related mode, choose the two fields that establish correlation.
6. Add plain-language filter and sort rows.
7. Insert an indexed field, count, or repeat block without typing syntax.
8. Choose a preview record with a record picker.
9. Validate, preview, save a draft, and publish.

### Runtime user

1. Open an authorized record page.
2. Select a published template compatible with that object.
3. Optionally add instructions before the context.
4. Generate and review the editable result.
5. Optionally add instructions after the context.
6. Copy the complete prompt or start over.

### Maintainer

- Duplicate a template before making a materially different version.
- Deactivate a published template immediately when schema or business meaning changes.
- See source scope, row budget, filters, sort rules, and aliases without reading JSON or SOQL.
- Re-preview before every publication; publication fingerprints the exact configuration.

## Red and bad scenarios

| ID       | Scenario                                                             | Required behavior                                                                     |
| -------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| HARD-001 | Administrator pastes SOQL or a WHERE clause                          | No raw-query input exists; server DTO cannot accept executable SOQL                   |
| HARD-002 | Related source omits current-record correlation                      | Validation blocks preview and publication                                             |
| HARD-003 | Reference source is mistaken for related data                        | UI labels it as broader reference context and validation warns                        |
| HARD-004 | User cannot read the queried object                                  | Generation fails atomically with a safe access message                                |
| HARD-005 | User cannot read a selected, correlation, filter, or sort field      | Validation/generation fails closed before returning a prompt                          |
| HARD-006 | Filter field is not filterable                                       | Validation blocks the source                                                          |
| HARD-007 | Sort field is not sortable                                           | Validation blocks the source                                                          |
| HARD-008 | Text-only operator is applied to a number/date                       | Validation blocks the source with a field-specific correction                         |
| HARD-009 | Range operator is applied to Boolean, reference, or unsupported text | Validation blocks the source                                                          |
| HARD-010 | Correlation fields have incompatible types                           | Validation blocks the source                                                          |
| HARD-011 | Two sources query the same object differently                        | Each alias keeps independent filters, sorting, fields, count, and rows                |
| HARD-012 | Two sources share a sequence                                         | Stable alias tie-break keeps execution deterministic and validation warns             |
| HARD-013 | A source returns more rows than its limit                            | Extra row detects truncation; prompt includes only the configured maximum and warns   |
| HARD-014 | Combined sources exceed the template row budget                      | Later sources stop at the total cap and return an explicit warning                    |
| HARD-015 | Output exceeds the character budget                                  | No partial prompt is returned                                                         |
| HARD-016 | Root record ID is from another object                                | User-mode root query returns no row; generation fails closed                          |
| HARD-017 | Root record is deleted or sharing changes after selection            | Preview/generation fails atomically                                                   |
| HARD-018 | Related lookup is null                                               | Source safely returns zero rows; no unrelated rows can match                          |
| HARD-019 | Reference query has no filters                                       | Allowed only within the hard row limit, with warning and deterministic sort           |
| HARD-020 | Filter value cannot convert to the field type                        | Validation/preview returns a correction without exposing SOQL                         |
| HARD-021 | Record text contains merge syntax                                    | It remains inert data and is never parsed a second time                               |
| HARD-022 | Record text contains prompt-injection instructions                   | UI explains that record text is untrusted; generated output preserves it as data      |
| HARD-023 | User double-clicks save, preview, publish, or generate               | Controls disable while the request is active                                          |
| HARD-024 | Clipboard API is unavailable or denied                               | Error is caught and the editable prompt remains available for manual copy             |
| HARD-025 | Administrator changes root object                                    | Existing incompatible sources and preview selection are cleared                       |
| HARD-026 | Administrator changes a source object                                | Object-specific fields, filters, sorts, and merge-field choice are cleared            |
| HARD-027 | Administrator removes a source still used by the template            | Validation identifies the missing alias before publication                            |
| HARD-028 | Administrator switches templates with unsaved edits                  | UI exposes dirty state and asks for confirmation before destructive switching         |
| HARD-029 | Published template is edited                                         | Save creates a draft state; runtime continues to require Published status             |
| HARD-030 | Published template becomes unsafe                                    | Maintainer can deactivate it; it disappears from runtime choices                      |
| HARD-031 | Duplicate aliases differ only by case                                | Validation treats them as duplicates to match case-insensitive Salesforce identifiers |
| HARD-032 | Filters or sorts repeat the same field                               | Allowed when meaningful, but contradictory filters remain visible and deterministic   |
| HARD-033 | Query has no authored sort                                           | `Id ASC` is always appended so output is stable                                       |
| HARD-034 | Authored sort values tie                                             | `Id ASC` is appended as a deterministic tie-breaker                                   |
| HARD-035 | Selected field is unused                                             | Non-blocking warning helps reduce data exposure and prompt size                       |
| HARD-036 | Active source is unused                                              | Non-blocking warning identifies unnecessary query cost                                |
| HARD-037 | Inactive source is referenced                                        | Publication is blocked                                                                |
| HARD-038 | Polymorphic relationship path is selected                            | Rejected until an explicit type strategy exists                                       |
| HARD-039 | Encrypted or binary field is selected                                | Rejected even if the current user could otherwise access it                           |
| HARD-040 | Relationship path is too deep                                        | Rejected beyond five traversals                                                       |
| HARD-041 | Large org contains thousands of objects/fields                       | Pickers load metadata once per selection; runtime queries remain capped               |
| HARD-042 | Ten sources each request fifty rows                                  | Global 200-row budget prevents 500-row prompt expansion                               |
| HARD-043 | Template is used concurrently by many users                          | Generation is stateless and performs no customer-record writes                        |
| HARD-044 | Template changes during a user's session                             | Runtime reloads stored configuration and fingerprints published content               |
| HARD-045 | Publication succeeds but later schema changes                        | Runtime revalidates schema and access before querying                                 |
| HARD-046 | Mobile/narrow layout                                                 | Sections and action rows wrap to one column without horizontal scrolling              |
| HARD-047 | Keyboard-only user                                                   | Every operation is reachable through labeled native or Lightning controls             |
| HARD-048 | Screen-reader user receives validation errors                        | Status region announces actionable messages with severity and location                |
| HARD-049 | Spinner is visible                                                   | It has descriptive alternative text; action controls are disabled                     |
| HARD-050 | No templates match a record                                          | Runtime component renders an actionable empty state                                   |
| HARD-051 | Apex exception contains internal detail                              | Controller returns a stable, safe message without stack trace/SOQL                    |
| HARD-052 | Malicious alias or field name attempts SOQL injection                | Identifier validation/schema canonicalization rejects it before query compilation     |
| HARD-053 | Malicious filter value contains quotes, wildcard, or SOQL text       | Value remains a bind; LIKE wildcards are escaped                                      |
| HARD-054 | Reference query exposes records outside sharing                      | `AccessLevel.USER_MODE` and `with sharing` restrict rows to the running user          |
| HARD-055 | User lacks template object access                                    | Permission failure returns no configuration or generated prompt                       |
| HARD-056 | Copy operation would include hidden values                           | Hidden values never reach the rendered prompt, so they cannot reach clipboard         |
| HARD-057 | Template contains Unicode or RTL content                             | Content remains intact and layout uses logical/wrapping behavior                      |
| HARD-058 | Browser refresh occurs mid-edit                                      | Unsaved browser state may be lost; saved drafts remain authoritative                  |
| HARD-059 | Network request fails                                                | Loading state clears and the user receives an actionable error toast                  |
| HARD-060 | Source is deactivated                                                | It performs no query and cannot be referenced by a publishable template               |

## Extensibility boundaries

The internal DTO, validator, query planner, renderer, selector, and controller remain separate so
future modes can be added without teaching the template language about SOQL. Named filter groups,
privacy-safe audit events, and scalar aggregate sources were delivered through these seams.
Candidate future extensions are:

- relative date literals represented as typed configuration, not text;
- grouped aggregate sources with a dedicated multirow result schema;
- cross-source chaining with cycle detection and a global query plan;
- polymorphic relationship branches with explicit target types;
- reusable source definitions and governed administrator approval;
- token estimation for a selected downstream model;
- additional channel-specific adapters that reuse the delivered Apex/Flow façade and the same
  validation and generation services;
- additional governed metrics beyond the delivered value-free Platform Event contract.

These are extension points, not hidden partial implementations. Raw SOQL and system-mode customer
data access remain permanently outside the administrator-facing contract.

## Completion checklist

- [x] Document record-related and bounded reference query modes.
- [x] Add source-mode metadata, DTO mapping, validation, query planning, and runtime execution.
- [x] Validate field filterability, sortability, operator compatibility, and correlation types.
- [x] Replace manual preview IDs with a root-object record picker.
- [x] Add junior-admin merge insertion controls and plain-language query summaries.
- [x] Add duplicate, deactivate, dirty-state, loading, clipboard-error, and empty-state behavior.
- [x] Expand Apex and Jest tests for positive, negative, and same-object multi-source cases.
- [x] Complete WCAG, LWS, SLDS, architecture, and Code Analyzer reviews.
- [x] Validate and deploy to the scratch org.
- [x] Capture screenshots of the deployed Prompt Builder and Prompt Generator.
