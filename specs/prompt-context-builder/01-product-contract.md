# Product contract

## 1. Purpose

Prompt Context Builder produces one editable plain-text prompt from:

1. one selected Salesforce root record;
2. readable fields on that record and its parent relationships; and
3. one or more independently configured related-record datasets.

It does not call an AI model. It does not analyze files, save conversations, or persist generated
prompts.

## 2. Product boundary

### In scope

- Reusable prompt templates.
- A guided template editor with insert controls and live validation.
- Current-record fields.
- Parent relationship field paths.
- Multiple named related-record sources, including multiple sources against the same object.
- Related-record filters, deterministic sorting, row limits, and selected output fields.
- Scalar tokens, indexed related rows, collection blocks, `if`, `else`, `format`, and `fallback`.
- Draft, preview, validation, publish, deactivate, and version/fingerprint behavior.
- An access manifest covering every object and field required by a template.
- Explicit user-mode access and atomic prompt generation.
- An editable completed prompt and an explicit copy action.

### Out of scope

- Files or attachment content.
- Amazon Bedrock or any other model call.
- AI responses or multi-turn conversations.
- Saving generated prompts, analysis results, or conversation history.
- DML against customer records.
- Callouts, email, events, or asynchronous work during generation.
- Arbitrary Apex, JavaScript, formula, or executable expressions in templates.
- Inline raw SOQL in the prompt body.
- Query results feeding later queries.
- Child-subquery row rendering in version 1.
- Unconstrained polymorphic relationships in version 1.

## 3. Language and configuration principles

- Configuration is task-based and does not use persona narratives.
- Common configuration must not require manually written SOQL.
- The editor inserts valid syntax; direct typing remains possible and readable.
- Labels are human-readable. Reference names are stable machine identifiers.
- Validation messages name the human-readable label and explain the correction.
- A plain-language query summary is available; raw generated SOQL and bind values are never shown.
- An incomplete configuration may be saved as a draft.
- Only a valid published version may generate a prompt from an ordinary record page.

## 4. Terminology

| Term            | Meaning                                                                               |
| --------------- | ------------------------------------------------------------------------------------- |
| Root object     | Salesforce object selected for the template, such as Account                          |
| Root record     | Record whose ID starts one generation request                                         |
| Template        | Authored text containing supported merge expressions                                  |
| Related source  | Named, bounded definition that retrieves records connected to the root record         |
| Display label   | Editable human name, such as `Recent Contacts`                                        |
| Reference name  | Stable token name, such as `recentContacts`                                           |
| Access manifest | Objects and fields required for output, relationships, filters, sorting, and grouping |
| Compile         | Parse and validate a template and its source definitions without producing a prompt   |
| Preview         | Generate a prompt using a selected real record and the current user's access          |
| Publish         | Freeze a validated version for runtime use                                            |
| Empty           | A readable value is null, or a source returns zero visible rows                       |
| Unavailable     | Access, schema, configuration, query, or limit failure prevents a truthful result     |

## 5. Configuration flow

The editor follows this fixed sequence:

1. Select the root object.
2. Name the template.
3. Write or paste the prompt text.
4. Insert root and parent fields from a searchable field picker.
5. Add related sources through the guided source builder.
6. Insert related fields as a first-record value, indexed value, list block, condition, or count.
7. Review plain-language source summaries and the access manifest.
8. Select a real record and preview.
9. Fix blocking errors and review warnings.
10. Publish an immutable validated version.

## 6. Related-source definition

Each source owns these properties:

| Property           | Contract                                                                         |
| ------------------ | -------------------------------------------------------------------------------- |
| Display label      | Required; editable; shown in the editor and messages                             |
| Reference name     | Required; unique within the template; generated from label; stable after publish |
| Related object     | Required and schema-valid                                                        |
| Root correlation   | Required and separate from optional filters                                      |
| Selected fields    | Explicit allowlist of fields exposed to the template                             |
| Additional filters | Typed, guided conditions applied after the mandatory root correlation            |
| Sort keys          | Ordered list of sortable fields, directions, and null placement                  |
| Maximum records    | Positive bounded integer                                                         |
| Active state       | Inactive sources cannot be referenced by a published template                    |

Example configuration:

```text
Display label: Recent Contacts
Reference name: recentContacts
Related object: Contact
Connected through: Contact.AccountId = Current Account.Id
Additional filters: Email is not blank
Sort: Created Date, newest first
Maximum records: 5
Exposed fields: Name, Email, Title, CreatedDate
```

The correlation is always ANDed with optional filters. Optional filter logic cannot escape it.

```sql
WHERE AccountId = :rootRecordId
  AND (Email != NULL)
```

The builder must not generate:

```sql
WHERE AccountId = :rootRecordId
   OR CreatedDate = TODAY
```

## 7. Multiple sources for one object

Object identity is not dataset identity. These are three independent sources:

```text
Recent Contacts        -> recentContacts
Executive Contacts     -> executiveContacts
Contacts Without Email -> contactsWithoutEmail
```

Each owns its own correlation, filters, order, selected fields, and maximum records. Each executes
at most once per generation. Identical internal plans may share an execution optimization only when
that does not change either source's contract or identity.

Changing a display label does not change its published reference name. A reference-name change must
either update all references atomically while still a draft or be rejected for a published version.

## 8. Canonical merge syntax

The earlier discussion included `query.<alias>.rows`. The canonical author-facing version 1 syntax
is the later, simpler `related.<referenceName>` form below. The transcript preserves the earlier
proposal for history; it is not the implementation contract.

### Root field

```text
{!record.Name}
{!record.Owner.Name}
{!record.Account.Owner.Email}
```

### Field attributes

```text
{!record.Name format="upper" fallback="Not available"}
```

Attribute rules:

- Attributes use `name="value"`.
- `fallback` applies only to a readable null value or missing row position.
- `format` accepts exactly `upper`, `lower`, or `percent` in version 1.
- Unknown, duplicate, malformed, or unsupported attributes block validation instead of being
  silently ignored.
- Unknown, repeated, unquoted, or inapplicable attributes are errors.

### Indexed related row

```text
{!related.recentContacts[0].Name fallback="No contact found"}
```

Indexes are zero-based. Any potentially multi-row positional reference requires deterministic
sorting and must be lower than the source maximum.

### Returned-record count

```text
{!related.recentContacts.count}
```

`count` means the number of rows intentionally returned to the prompt under the configured maximum.
It does not claim an org-wide total and does not reveal hidden rows. A full matching-set count uses
a separately configured scalar aggregate source and `{!aggregate.alias.value}`; it never changes
the meaning of this record-source property.

### Collection block

```text
{!#each related.recentContacts as="contact"}
- {!contact.Name}: {!contact.Email fallback="No email"}
{!else}
No contacts were found.
{!/each}
```

### Conditional block

```text
{!#if related.openCases.hasRecords}
There are {!related.openCases.count} open cases.
{!else}
There are no open cases.
{!/if}
```

Version 1 supports only `each`, `if`, and `else` blocks. It does not support arbitrary expressions.

### Lexical scope

- A loop alias exists only inside its matching block.
- Nested blocks must use distinct aliases.
- An `else` belongs to the nearest open compatible block.
- Resolved record values are literal output and are never reparsed as syntax.

## 9. Field picker behavior

The picker groups insertable items into:

1. Current record fields.
2. Parent relationship fields.
3. Related sources.
4. Fields exposed by each related source.
5. Related-source helpers such as count and has-records.

The picker must:

- show labels with API names available as secondary detail;
- exclude unsupported encrypted and binary fields;
- show field data type;
- indicate nullable fields;
- insert complete syntax instead of partial fragments;
- generate complete `each` and `if` blocks;
- prevent selecting a related field not exposed by its source; and
- preserve namespaced API names exactly.

## 10. Deterministic ordering

- Every multi-row source used by an indexed token or loop declares a business order.
- `LIMIT 1` without order is invalid.
- The system adds `Id` as the final stable tiebreaker when not already present.
- Direction for the `Id` tiebreaker follows the final authored sort direction unless a future
  explicit rule supersedes it.
- Null placement is explicit when supported and meaningful.
- A provably single-record ID query does not need an order.
- An ungrouped single-row aggregate does not need an order.
- Grouped results need an order before indexing or iteration.

## 11. Empty, missing, and unavailable states

| State                                         | Rendering behavior                                         |
| --------------------------------------------- | ---------------------------------------------------------- |
| Readable populated field                      | Render formatted value                                     |
| Readable null field                           | Render blank or `fallback`                                 |
| Zero visible source rows                      | Render `else`; `count` is zero                             |
| Missing row index                             | Render field fallback when present; otherwise blank        |
| Null parent lookup                            | Render field fallback when present; otherwise blank        |
| Inaccessible field/object/record              | Abort; do not use fallback or `else`                       |
| Invalid or removed schema                     | Abort with configuration failure                           |
| Query execution failure                       | Abort with execution failure                               |
| Authored source or combined row bound reached | Return deterministic bounded rows with an explicit warning |
| Unplanned framework or character cap exceeded | Abort; never silently truncate                             |

## 12. Compile and runtime phases

Generation follows these phases and performs no lazy data access:

1. Authorize template use.
2. Validate record ID and actual root object type.
3. Load the exact published template version.
4. Parse the template once into typed token and block shapes.
5. Resolve every referenced source and field.
6. Validate schema, relationship paths, projections, formats, indexes, order, and limits.
7. Build the complete access manifest and resource plan.
8. Check runtime object and field access.
9. Load the root record and required parent fields in explicit user mode.
10. Execute every referenced related source once in explicit user mode using typed bind values.
11. Detect overflow by probing beyond framework caps where needed.
12. Freeze an immutable in-memory context map.
13. Render plain text without further queries.
14. Enforce the final character and serialization budgets.
15. Return the completed bounded editable prompt with explicit row-limit warnings, or one atomic
    failure; never return an unexplained partial prompt.

## 13. Draft, preview, publish, and deactivate

### Draft

- May be incomplete or invalid.
- Shows live errors, warnings, and information.
- Cannot generate prompts from ordinary runtime surfaces.

### Preview

- Requires a real record matching the root object.
- Runs with the current user's data access.
- Shows Template, Related Data Retrieved, Completed Prompt, and Errors and Warnings separately.
- Shows a plain-language explanation for each source.
- Does not save or log the completed prompt.

### Publish

Requires:

- valid syntax and block structure;
- valid root and related schemas;
- valid source correlation;
- every referenced field exposed and supported;
- deterministic ordering;
- valid limits and resource plan;
- complete access manifest;
- no blocking error; and
- a successful preview against at least one matching record.

Publishing records an immutable version/fingerprint, publisher, and timestamp.

### Deactivate

- Prevents new runtime generation.
- Does not delete the draft or version history.
- Is the recovery path for schema or access changes that invalidate a published template.

## 14. Validation levels

### Error

Blocks publishing and generation. Examples include malformed syntax, unknown fields, undefined
sources, invalid correlation, unsafe query construction, inaccessible required data, unordered row
access, unsupported field types, and exceeded hard limits.

### Warning

Allows publishing after review. Examples include unused sources or fields, high configured row
counts, long-text size risk, several sources querying one object, and a prompt close to its limit.

### Information

Explains generated behavior, including automatic `Id` tie-breaking, visible-record semantics,
configured maximums, and the access context used for preview.

## 15. Limits requiring an explicit pre-build decision

Implementation must not begin until exact numeric values are approved for:

- templates per generation;
- related sources per template;
- fields per source;
- filters per source;
- rows per source and default row maximum;
- total related rows;
- relationship depth;
- token count;
- block nesting depth;
- generated query count;
- total queried characters; and
- completed prompt characters/bytes.

Record Health Check's bounded-token, bounded-output, row-cap, and cap-plus-one detection patterns are
the starting reference, but Prompt Context Builder limits must be selected for prompt construction.

## 16. Product invariants

1. A related source is identified by its stable reference name, never merely by object API name.
2. Every related source remains correlated to the root record under every filter branch.
3. Every output value was selected, type-validated, and readable to the running user.
4. Security failure never becomes blank data, fallback text, or an empty list.
5. Repeated tokens and source references cause no additional queries.
6. No query executes during rendering.
7. Resolved data never becomes executable template syntax.
8. Generated prompts are not automatically persisted, logged, cached, or published.
9. Failure is atomic; no partial prompt is returned.
10. The same inputs, visible data, locale, timezone, and template version produce the same ordering
    and rendering.
