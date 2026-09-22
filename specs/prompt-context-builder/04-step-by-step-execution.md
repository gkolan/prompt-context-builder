# Step-by-step execution plan

The user authorized the full greenfield implementation after this plan was written. The build used
this sequence; final decisions and execution evidence are recorded in `06-build-record.md`.

Each implementation phase begins with a failing executable test or fixture for its observable
contract, then adds the smallest production behavior needed to pass, followed by boundary tests.

## Final execution disposition

The approved version 1 scope is complete. This plan intentionally contains candidate capabilities
that were evaluated and then explicitly deferred; they are not partial hidden features.

| Phase | Disposition     | Final evidence or scope decision                                                                                                                          |
| ----- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0-1   | Complete        | Closed product/syntax contracts, central limits/reasons, 160-scenario corpus, stable automation keys                                                      |
| 2-3   | Complete for v1 | Five-level schema paths, cached Describe, closed tokens/blocks, strict `fallback`/`format` attributes                                                     |
| 4-5   | Complete        | RELATED/REFERENCE scopes, record/scalar aggregate results, typed OR groups, deterministic sort plus Id, binds, user mode, overflow and resource admission |
| 6-7   | Complete        | CRUD/FLS/sharing/restriction-rule enforcement through user mode, atomic generation, bounded renderer                                                      |
| 8     | Complete for v1 | Four-step junior-admin builder, searchable keyset catalog, lazy detail load, preview, publish, deactivate, duplicate                                      |
| 9     | Complete        | Canary leakage tests, gated bounded diagnostics, correlation IDs, later-source atomic-failure test, Start over cleanup test                               |
| 10    | Complete        | Restricted user, 35/201-record bulk, automation contexts, 2GP install/upgrades, and isolated namespaced regression passed                                 |
| 11    | Complete        | Admin, architecture, security, execution, traceability, screenshots, build, package, and quality records are current                                      |

Delivered after the original version 1 baseline: bounded named OR groups and distinct scalar
aggregate sources. Still excluded are grouped aggregates, polymorphic sources, cross-source query
chaining, arbitrary raw SOQL, model/files/conversation persistence, explicit currency conversion,
and nested `each`. Raw query text, binds, and retrieved rows are not exposed in the UI because doing
so would widen the privacy boundary.

The shipping project and unlocked package remain namespace-free. Namespace compatibility was
executed separately with the already registered `rhc` namespace, without changing package
ownership or assigning a permanent product namespace. The current namespaced scratch deployment and
all 78 Apex tests passed; a split FlexiPage fixture preserves the correct component descriptor in each
mode.

## Phase 0: Lock product decisions

### Step 0.1: Confirm the product boundary

Approve the in-scope and out-of-scope lists in `01-product-contract.md`.

Exit gate:

- The product builds prompts only.
- Files, model calls, conversations, persistence, and customer-record writes remain excluded.

### Step 0.2: Approve canonical syntax

Approve:

- `{!record.Field}`;
- `{!related.alias[index].Field}`;
- `{!related.alias.count}`;
- `each`, `if`, and `else` blocks;
- lexical aliases;
- `format` and `fallback`; and
- the rule that `related.*` supersedes the earlier `query.*.rows` proposal.

Exit gate: examples parse unambiguously on paper, including nested blocks and quoted attributes.

### Step 0.3: Set exact limits

Decide numeric values for every item in Product Contract section 15. Record the reason for each
limit and whether it is author-configurable or framework-fixed.

Exit gate: no implementation constant remains unspecified.

### Step 0.4: Approve storage and lifecycle

Decide the metadata/data model for template identity, drafts, sources, versions, publication,
deactivation, and validation fingerprints. Runtime-authored configuration generally requires a
custom-object lifecycle; package-controlled administrative configuration may use Custom Metadata.
Do not mix the two without an explicit decision.

Exit gate: ownership, CRUD, sharing, versioning, and deployment behavior are documented.

### Step 0.5: Approve version 1 relationship support

Decide exact support for:

- parent depth;
- direct children;
- parent-path correlation from a related source;
- junction objects;
- aggregates and grouped aggregates;
- self relationships; and
- polymorphic relationships.

Exit gate: every scenario is marked supported, rejected, or deferred with an error message.

## Phase 1: Establish contracts and test fixtures

### Step 1.1: Define typed contracts

Specify types for:

- template draft and published version;
- related source;
- selected field;
- correlation;
- typed filter;
- sort key;
- parsed token/block node;
- access manifest;
- resource plan;
- immutable merge context;
- validation finding; and
- generation response.

Exit gate: every boundary has one versioned input/output shape with required/optional fields.

### Step 1.2: Define stable reason codes

Create a reason-code catalog covering syntax, schema, source, order, limit, access, execution, and
output failures. Pair each code with a plain-language message and whether it is safe for ordinary or
diagnostic display.

Exit gate: no test asserts only free-form exception text.

### Step 1.3: Create the scenario corpus

Convert every row in `02-scenario-matrix.md` into a fixture containing:

- root object and record shape;
- template;
- source definitions;
- permissions/visibility assumptions;
- expected compile findings;
- expected runtime outcome; and
- expected completed prompt when successful.

Exit gate: every matrix ID has one durable fixture or an explicit platform-only verification path.

### Step 1.4: Create independent expected-output fixtures

Write expected prompts manually from the business scenario without copying renderer output.
Include ordinary, empty, invalid, security, locale, namespace, and limit cases.

Exit gate: expected results exist before renderer implementation.

## Phase 2: Build schema and field-planning foundation

### Step 2.1: Add a transaction-scoped Describe cache

Resolve object, field, relationship, type, accessibility, sortability, namespace, encryption, and
compound-field facts once per transaction.

Tests first:

- standard/custom/namespaced objects;
- missing object/field;
- parent paths;
- null and excessive depth;
- encrypted, Blob, Rich Text, formula, address, and geolocation types.

Exit gate: all schema facts are obtained through one service; no consumer performs ad hoc Describe
logic.

### Step 2.2: Implement field-path planning

Resolve a path into typed relationship segments and one terminal field. Reject invalid, cyclic,
unsupported, or excessive paths.

Exit gate: root tokens, source projections, access manifest, query planner, and renderer share the
same typed field shape.

### Step 2.3: Implement the access-manifest compiler

Collect every field used for output, correlation, filter, order, group, aggregate, and traversal.

Exit gate: fixture manifests match exact independently authored expectations.

## Phase 3: Implement the merge parser and validator

### Step 3.1: Add failing parser tests

Cover scalar tokens, attributes, indexed sources, counts, `each`, `if`, `else`, nesting, source
positions, malformed braces, unknown namespaces, duplicate attributes, and alias scope.

Exit gate: tests fail because parser behavior does not exist, not because fixtures are malformed.

### Step 3.2: Implement a tokenizer with source locations

Recognize literal spans and reserved constructs without resolving Salesforce data.

Exit gate: every token/block reports exact start/end location for editor diagnostics.

### Step 3.3: Parse once into a typed syntax tree

Build typed nodes for text, root field, related field, count, each block, if block, and else branch.
Do not let downstream consumers reparse property strings.

Exit gate: round-trip inspection of the scenario corpus produces stable typed shapes.

### Step 3.4: Add semantic validation

Validate namespaces, aliases, lexical scope, fields, attributes, formats, indexes, selected
projections, and source availability.

Exit gate: every TMP scenario returns its expected stable finding.

### Step 3.5: Enforce parser/resource limits

Apply token and nesting caps before expensive schema or data work.

Exit gate: limit fixtures fail deterministically without high CPU or heap use.

## Phase 4: Implement the guided related-source model

### Step 4.1: Add source-definition tests

Cover duplicate aliases, stable alias behavior, invalid objects, invalid correlations, typed filters,
sortability, maximum rows, namespaced fields, unused fields, and inactive sources.

### Step 4.2: Implement reference-name generation

Generate readable valid identifiers from labels, reject reserved names, and prevent accidental
published renames.

### Step 4.3: Implement typed filters

Expose operators by field type. Convert values before query planning. Represent AND/OR groups as a
typed tree, while keeping mandatory root correlation outside and ANDed with that tree.

### Step 4.4: Implement deterministic sort planning

Validate sortable fields and add an Id tiebreaker. Preserve authored key order, direction, and null
placement.

### Step 4.5: Implement source projection planning

Select only fields required by tokens, rendering, correlation, sort, grouping, currency basis, and
runtime proof. Warn about configured but unused output fields.

Exit gate for Phase 4: every SRC and ORD compile-time scenario returns the expected outcome without
executing customer-data SOQL.

## Phase 5: Implement safe query compilation

### Step 5.1: Add adversarial query-plan tests

Cover quotes, wildcard text, typed dates/numbers/IDs, injection strings, invalid identifiers,
correlation escape attempts, unsafe clauses, unsupported shapes, and user-supplied limits.

### Step 5.2: Generate query structure only from trusted typed shapes

Object/field identifiers come from Describe-backed plans. Values become named binds. The generated
query has one outer SELECT and one mandatory correlation boundary.

### Step 5.3: Enforce explicit user mode

Execute through one query service that always selects user mode and cannot be switched by authored
configuration.

### Step 5.4: Apply row caps and overflow probes

Distinguish an intentional authored maximum from a hidden framework safety cap. Use cap-plus-one
detection where truncation could otherwise produce a plausible incomplete prompt.

### Step 5.5: Calculate transaction resource plan

Before customer data access, prove that source count, query count, expected rows, selected fields,
heap estimate, and output estimate fit approved limits.

Exit gate for Phase 5: SEC-011 through SEC-015 and all source/query limit fixtures pass; no string
value can alter query structure.

## Phase 6: Implement runtime access enforcement

### Step 6.1: Validate request and root identity

Authorize template use, validate record ID, derive actual object type, compare it with the published
root object, and reject mismatch before related queries.

### Step 6.2: Preflight the access manifest

Check object and field readability for the running user, including correlation/filter/sort fields.
Return one atomic access failure when required access is missing.

### Step 6.3: Load root data in user mode

Retrieve exactly the planned root and parent fields. Distinguish a null parent from unavailable
data.

### Step 6.4: Execute related sources once

Execute referenced sources in a deterministic plan order, store rows under stable aliases, and do
not expose raw rows outside the server merge context.

### Step 6.5: Inspect defense-in-depth stripping if used

If `stripInaccessible` is used, abort when its removed fields intersect the access manifest. Do not
turn stripped fields into nulls.

Exit gate for Phase 6: all SEC-001 through SEC-010 and SEC-022 fixtures pass using representative
restricted access in platform-level tests.

## Phase 7: Implement deterministic rendering

### Step 7.1: Add failing renderer tests

Cover null, missing index, zero rows, loop/else behavior, nested scope, repeated tokens, zero, false,
literal `null`, Unicode, locale, timezone, currency, rich text, and record data containing syntax.

### Step 7.2: Build immutable merge context

Freeze root values, typed source rows, counts, locale/timezone/currency information, and the
published version. Rendering receives no query capability.

### Step 7.3: Render typed values

Apply format only to typed fields. Apply fallback only to legitimate empty values. Convert supported
rich text to inert plain text.

### Step 7.4: Render blocks

Honor stable row order, lexical aliases, `else`, and nesting limits. Never reparse rendered values.

### Step 7.5: Enforce output limits atomically

Build in a bounded buffer. When the final character/byte budget would be exceeded, discard output
and return `LIMIT_EXCEEDED`; never return clipped text.

Exit gate for Phase 7: DAY, EMP, FMT, and rendering-related SEC fixtures pass with exact expected
prompts.

## Phase 8: Build the configuration experience

### Step 8.1: Implement draft editor shell

Support template name, root object, text editing, draft save, validation summary, and no runtime
execution of drafts.

### Step 8.2: Implement field/token picker

Show searchable labels and API names, types, nullability, parent paths, sources, exposed fields,
count, conditions, and complete block insertion.

### Step 8.3: Implement guided source builder

Provide label, generated reference name, related object, relationship, typed filters, sort, maximum,
and exposed fields. Keep generated SOQL read-only and collapsed.

### Step 8.4: Implement plain-language findings

Show display labels, locations, reasons, and corrective actions. Preserve stable machine reason
codes outside the prose.

### Step 8.5: Implement access-manifest view

Group required access by object and explain output/filter/sort use without requiring SOQL knowledge.

### Step 8.6: Implement four-part preview

Show Template, Related Data Retrieved, Completed Prompt, and Errors and Warnings as separate areas.
Do not persist prompt contents.

### Step 8.7: Implement publish/deactivate lifecycle

Require all publish gates, record immutable version/fingerprint and audit facts, and provide
recoverable deactivation.

Exit gate for Phase 8: every UX scenario is covered by component tests plus browser verification.

## Phase 9: Logging, privacy, and failure handling

### Step 9.1: Define safe telemetry schema

Permit identifiers, version, reason code, timing, and aggregate resource counts only. Forbid prompt
text, field values, query bind values, record descriptions, and hidden counts.

### Step 9.2: Add negative leakage tests

Seed unique canary values and assert they never appear in debug statements, exceptions, telemetry,
events, browser storage, or ordinary error responses.

### Step 9.3: Add atomic failure tests

Force a failure after one source succeeds and assert that no partial prompt or source row is returned.

### Step 9.4: Add client cleanup tests

Verify reset and teardown clear completed prompt and retrieved context.

Exit gate for Phase 9: SEC-019 through SEC-021 and recovery scenarios pass.

## Phase 10: Platform, scale, and compatibility verification

### Step 10.1: Run Apex unit and static analysis

Verify sharing declarations, explicit user-mode data operations, no SOQL-in-loop, no dangerous
dynamic query construction, bounded resource use, and no debug-value leakage.

### Step 10.2: Run LWC unit and accessibility tests

Verify labels, keyboard operation, focus, error association, non-color-only findings, safe text
rendering, state cleanup, and no unsafe HTML.

### Step 10.3: Run representative-permission tests

Verify full access, missing root field, missing related field, sharing restriction, restriction rule,
and diagnostics authorization.

### Step 10.4: Run namespace and package tests

Verify namespaced objects/fields, installed-package removal, package-version context, and no hardcoded
namespace assumptions.

Executed evidence: isolated org `pcb-rhc-ns-test` (Org ID redacted), namespaced core deploy
`0Afcf00000BrAitCAF`, namespaced page deploy `0Afcf00000BrEMfCAN`, app/permission deploy
`0Afcf00000Br7LDCAZ`, and Apex run `707cf00001FKV7y` with 78/78 passing at 85% coverage.

### Step 10.5: Run locale and org-variation tests

Verify locale, timezone, multicurrency, large data volume, null ordering, and supported runtime
security variations.

### Step 10.6: Run browser lifecycle tests

Verify draft, validation, source configuration, preview, publish, use, edit-as-new-version,
deactivate, and recovery from schema drift.

Exit gate: every scenario matrix row is linked to passing evidence or an explicitly approved pending
platform verification.

## Phase 11: Documentation and release readiness

### Step 11.1: Publish administrator-facing reference

Document syntax, editor actions, examples, empty behavior, visible-scope meaning, access manifest,
limits, reason codes, and troubleshooting in plain language.

### Step 11.2: Publish technical architecture

Document layers, trust boundaries, typed contracts, parser, planner, access enforcement, query
compiler, renderer, lifecycle, and forbidden dependencies.

### Step 11.3: Verify claims against evidence

Every documentation claim must map to source and an executable test. Planned platform evidence must
remain labeled pending until run; all release gates in this plan now have executed evidence.

### Step 11.4: Complete release gates

Run formatting, lint, unit, static analysis, contract, metadata, packaging, deploy-validation, and
browser gates appropriate to the final repository agreement. Do not create a scratch org without
the explicit authorization required at that time.

Final exit gate:

- all approved scenario rows pass;
- no security or limit red scenario returns a partial prompt;
- the configuration flow can be completed without writing SOQL;
- documentation and product behavior agree; and
- files, model calls, conversations, and prompt persistence remain absent.
