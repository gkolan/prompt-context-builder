# Match records by field value and process records in bulk

Status: Implemented in local source and validated in `pcb-package-test`. Field-value matching,
grouped record and aggregate queries, one-query reference data, blank-match warnings, invalid ID
value handling, multi-currency publication checks, row limits, and regression tests are present.
The current increment was deployed to `pcb-package-test` in job `0AfRL00000i7CCn0AM`; it has not
been browser-verified or package-verified.

Day-one rule: every template and published version must satisfy this complete contract. There are no
older source records, API shapes, migration defaults, or upgrade paths to preserve.

## 1. Outcome

An administrator can add records from another Salesforce object by matching a field on the current
record to a field on the other object. A Salesforce lookup relationship is not required. Examples
include Contacts that match an Account ID, guidance records that match an Industry or Region, the
current record itself, parent fields, and reference records shared by every prompt.

The bulk API groups requests that use the same published template. It loads the Salesforce records
together and runs each compatible source query once for the group. Each returned row is then matched
to the correct Salesforce record. Ordering, record limits, warnings, sharing, restriction rules,
object permissions, field permissions, and user-mode queries still apply to each record.

This follows the Record Health Check pattern for direct child records, parent fields, field-value
matching, shared reference records, and ordered results per Salesforce record. Administrators do not
write SOQL. Prompt Context Builder creates the query from saved object and field selections and
passes field values as query variables.

## 2. Locked boundaries

### 2.1 Supported match shape

Every matching source uses one required equality check:

```text
source.<matchingFieldPath> = currentRecord.<currentRecordFieldPath>
```

For bulk work, the service can query several match values with `IN :matchValues`. It must still match
every returned row to the correct Salesforce record. Administrator filters are added after the
required field match and cannot remove that match.

### 2.2 Ways a source can match

The day-one `Source_Mode__c` values are `RELATED` and `REFERENCE`. The UI uses the labels below.
Package code chooses the matching method.

| Saved mode  | UI label                         | Package method               | Meaning                                                 |
| ----------- | -------------------------------- | ---------------------------- | ------------------------------------------------------- |
| `RELATED`   | Match using current-record value | `SELF`                       | Source `Id` equals current record `Id`                  |
| `RELATED`   | Match using current-record value | `CHILD_DIRECT`               | Source field equals current record `Id`                 |
| `RELATED`   | Match using current-record value | `CHILD_PATH`                 | Source parent field equals current record `Id`          |
| `RELATED`   | Match using current-record value | `VALUE_MATCH`                | Source field equals a non-ID current-record value       |
| `RELATED`   | Match using current-record value | `ORDERED_MATCHES_PER_RECORD` | Each current record has its own order and record limit  |
| `REFERENCE` | Shared reference records         | `SHARED_REFERENCE`           | The same visible rows can be used for the request group |

These package methods are not new administrator settings. Error details may record the method name,
but must not record field values.

### 2.3 Field types that can match

Publication compares the two final field types using this table. Prompt Context Builder does not
guess that text is a number, date, Boolean, or time.

| Family         | Supported final field types                   | Rule                                                                                          |
| -------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Textual scalar | String, Picklist, Combobox, Email, Phone, URL | Cross-type equality allowed; pass the already loaded field value as String                    |
| Identifier     | Id, Reference, String                         | Allowed only for a scalar value that is a valid 15- or 18-character Salesforce ID at run time |
| Integral       | Integer, Long                                 | Cross-type equality allowed after lossless widening                                           |
| Decimal        | Double, Currency, Percent                     | Cross-type equality is allowed only when the units are valid                                  |
| Boolean        | Boolean                                       | Exact type only                                                                               |
| Date           | Date                                          | Exact type only                                                                               |
| Date/time      | DateTime                                      | Exact type only                                                                               |
| Time           | Time                                          | Exact type only                                                                               |

Multi-select picklists, Base64, encrypted strings, compound fields, addresses as a whole,
geolocation as a whole, and unsupported calculated types cannot be final match fields. Date is
never changed to DateTime automatically. Text is not parsed as a number, date, Boolean, or time.

### 2.4 Null match behavior

A readable null or blank current-record value executes no source query, returns zero rows for that
source, and adds `NULL_MATCH_VALUE`. There is no configurable replacement value. Numeric zero and
Boolean false remain real values and do not use the null branch.

### 2.5 Relationship paths

The builder must offer a lazy, searchable field-path picker for current record and source match fields.
It may traverse at most `MAX_RELATIONSHIP_DEPTH` parent relationships and must use the same standard
field-path service as validation, field-access lists, query preparation, and prompt generation.

For a polymorphic relationship, version one of this increment supports only a common path: every
possible target type must expose the next relationship/final field, the field must be readable on
every target type, and all final field types must belong to the same compatibility family. Otherwise
validation returns `AMBIGUOUS_POLYMORPHIC_PATH`. Branch-specific `TYPEOF`, target-type guessing, and
choosing the first available target without telling the administrator remain excluded.

### 2.6 Bulk behavior

- Load all accepted current records for one template group with one user-mode query.
- Execute each compatible active source no more than once for that template group.
- Deduplicate equal match values before binding them.
- Preserve a mapping from one standard match value to every current record that supplied it.
- Return the same visible rows to current records that legitimately share the same match value.
- Execute a `REFERENCE` source once and reuse the read-only result for every accepted current record.
- Apply configured ordering and `maxRows` independently for each current record.
- Read one extra matching record, or use another tested method, to show the truncation warning.
- Preserve per-record failure isolation: one inaccessible or invalid current record produces no prompt for that
  current record but does not erase successful neighboring current records.
- Preserve per-prompt total row and output budgets after matching returned rows.
- Never cache source rows across transactions, users, sharing contexts, or template versions.

### 2.7 Currency behavior

In a multi-currency organization, `SUM`, `AVG`, `MIN`, or `MAX` over a Currency field is valid only
when every contributing row is constrained to one explicit `CurrencyIsoCode` equality. The currency
condition must be a mandatory condition, not one optional branch of an OR group. The configured ISO
code is included in the read-only source version and field-access list.

`COUNT` is unitless. Single-currency organizations do not require a currency condition. This
increment does not perform currency conversion and does not add grouped aggregate output.

### 2.8 Explicit non-goals

- Raw SOQL, WHERE fragments, subqueries, hints, `ALL ROWS`, `FOR UPDATE`, or execution-mode controls.
- Cross-source chaining such as source B using a row returned by source A.
- Matching with `LIKE`, ranges, negation, or a current-record value passed to `INCLUDES`.
- Transform expressions, formulas, Apex callbacks, or JavaScript applied to a match value.
- Branch-specific polymorphic paths or `TYPEOF` selected fields.
- Cross-transaction or cross-user result caching.
- Grouped aggregate output shapes or currency conversion.
- Any replacement value for a blank match field.

## 3. Red scenarios

These test cases are written and run against the current implementation before production changes.
Every test case must fail for the intended missing behavior, not because its setup is invalid. The red
result, command, test name, and observed assertion are retained in the build record.

| ID      | Scenario                                                              | Required future behavior                                                                                |
| ------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| RED-001 | Account `Industry` Picklist matches a Text field on a guidance object | Validation accepts the textual family and the visible matching guidance renders                         |
| RED-002 | Ten Accounts share three Industry values                              | One current record query and one grouped source query execute; rows map to all ten Accounts             |
| RED-003 | A reference source is used by 25 records                              | It executes once in the transaction and the same read-only visible rows serve each current record       |
| RED-004 | Matching source orders by Priority and limits to three                | Bulk execution returns the first three rows independently for every current record                      |
| RED-005 | One current record has a fourth matching ordered row                  | That current record alone receives `SOURCE_TRUNCATED`; no other current record receives a false warning |
| RED-006 | Currency SUM in a multi-currency org lacks an ISO-code boundary       | Publication fails with `MISSING_CURRENCY_BOUNDARY`                                                      |
| RED-007 | Currency SUM has mandatory `CurrencyIsoCode = 'USD'`                  | Validation and prompt generation succeed without implying conversion                                    |
| RED-008 | Blank Industry is used as the current-record match value              | No source query runs; source has zero rows and `NULL_MATCH_VALUE`                                       |
| RED-010 | Current Record Match Field picker traverses `Parent.Industry`         | Picker, saved path, publication check, field-access list, query, and prompt generation agree            |
| RED-011 | Source match picker traverses `Industry__r.Name`                      | The generated source predicate uses the standard readable/filterable path                               |
| RED-012 | Common polymorphic path is readable with the same type on all targets | Validation accepts it and prompt generation handles each target without guessing                        |
| RED-013 | Polymorphic path exists on only one possible target                   | Publication fails with `AMBIGUOUS_POLYMORPHIC_PATH`                                                     |
| RED-014 | One current record is invisible in a mixed bulk request               | That current record fails `RECORD_NOT_ACCESSIBLE`; visible neighboring records still succeed            |
| RED-015 | Match value contains quote and SOQL-looking text                      | It remains a bind value; query structure and returned data remain unchanged                             |
| RED-016 | Bulk request would read too many possible matching records            | Limit check rejects only work that does not fit, before customer-data queries                           |
| RED-017 | Source B attempts to consume source A output                          | Validation rejects it; no chained query executes                                                        |
| RED-018 | Picklist-to-Date match is configured                                  | Publication fails with `MATCH_FIELD_TYPES_DIFFER`                                                       |

Minimum red test owners:

- `PromptContextMatchFieldValidatorTest`: RED-001, RED-006 through RED-013, RED-017, RED-018.
- `PromptContextBulkPlannerTest`: RED-002 through RED-005 and RED-016.
- `PromptContextBulkServiceTest`: RED-002 through RED-005, RED-014, RED-015.
- `promptTemplateBuilder.test.js`: RED-001, RED-008 through RED-013 and the revised labels.

Red verification:

```bash
npm run test:unit -- --runInBand force-app/main/default/lwc/promptTemplateBuilder/__tests__/promptTemplateBuilder.test.js
sf apex run test --tests PromptContextMatchFieldValidatorTest,PromptContextBulkPlannerTest,PromptContextBulkServiceTest --target-org <approved-purpose-org> --wait 30 --result-format human
```

Exit gate: every RED ID has an executable failing assertion and an independently authored expected
query-count/result test case. No production behavior has changed.

## 4. Edge cases

| ID       | Scenario                                                             | Required outcome                                                                        |
| -------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| EDGE-001 | Current-record value is numeric zero                                 | Zero is a real value and is passed to the query                                         |
| EDGE-002 | Current-record value is Boolean false                                | False is a real value and is passed to the query                                        |
| EDGE-003 | Current-record text is empty or whitespace                           | Run no source query and add `NULL_MATCH_VALUE`                                          |
| EDGE-004 | Current-record text is the literal word `null`                       | Treat it as text, not Apex null                                                         |
| EDGE-005 | Two current records have the same match value                        | Query once for that value and give both current records their matching visible rows     |
| EDGE-006 | Every current record has a unique match value                        | One limited IN query is used when accepted; mapping remains exact                       |
| EDGE-007 | Match values differ only by case                                     | Use Salesforce equality behavior; do not change or remap the values in Apex             |
| EDGE-008 | Text contains apostrophe, backslash, wildcard, braces, or emoji      | Named bind preserves the literal value and query structure                              |
| EDGE-009 | A 15-character ID and its equivalent 18-character ID are supplied    | Standard ID mapping prevents duplicate or lost assignment                               |
| EDGE-010 | ID-family String contains a non-ID value                             | Return `INVALID_MATCH_VALUE` and do not create a prompt                                 |
| EDGE-011 | Parent relationship is null before reaching the current-record field | Run no source query and add `NULL_MATCH_VALUE`                                          |
| EDGE-012 | Source relationship is null                                          | Row does not match; no exception and no hidden-data inference                           |
| EDGE-013 | Formula final returns a supported scalar type                        | Use its described result type and current field value                                   |
| EDGE-014 | Formula final changes type after publication                         | Health validation marks the version unhealthy; return no prompt                         |
| EDGE-015 | Sort values tie                                                      | `Id ASC` gives each Salesforce record the same repeatable order                         |
| EDGE-016 | A source's configured limit equals one                               | Each Salesforce record receives exactly one repeatably selected row                     |
| EDGE-017 | Possible matching rows equal the record limit                        | No truncation warning                                                                   |
| EDGE-018 | Possible matching rows exceed the record limit by one                | Only the affected Salesforce record receives `SOURCE_TRUNCATED`                         |
| EDGE-019 | One current record has no matching rows but another does             | Empty/list/count behavior remains isolated per current record                           |
| EDGE-020 | Reference source returns zero rows                                   | Execute once; every current record receives the ordinary empty behavior                 |
| EDGE-021 | Reference source exceeds its configured limit                        | Execute once; every consuming current record receives the same limited rows and warning |
| EDGE-022 | A source is configured but unused by the template                    | Return the documented warning and do not query it when generating the prompt            |
| EDGE-023 | All accepted current records have null match values                  | Execute no source query                                                                 |
| EDGE-025 | Currency aggregate is COUNT                                          | No ISO-code boundary is required                                                        |
| EDGE-026 | Currency filter exists inside one branch of an OR group              | It is not a mandatory boundary; reject the aggregate                                    |
| EDGE-027 | Single-currency org uses a Currency aggregate                        | No ISO-code boundary is required                                                        |
| EDGE-028 | Common polymorphic field is inaccessible on one target type          | Reject the path as inaccessible; do not accept based on the current sample record       |
| EDGE-029 | Relationship depth equals the maximum                                | Accept when every segment is valid and readable                                         |
| EDGE-030 | Relationship depth exceeds the maximum                               | Reject before customer-data access                                                      |

Exit gate: every EDGE test case passes in focused tests, including query-count assertions where Apex
test limits expose them, and no edge case changes an ordinary access failure into empty data.

## 5. Misconfiguration scenarios

| ID      | Misconfiguration                                                         | Required finding or behavior                                                            |
| ------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| MIS-001 | `RELATED` source has no current record field                             | `MISSING_ROOT_FIELD`; publication blocked                                               |
| MIS-002 | `RELATED` source has no source match field                               | `MISSING_MATCH_FIELD`; publication blocked                                              |
| MIS-003 | Source match field cannot be used in a Salesforce filter                 | `MATCH_FIELD_NOT_FILTERABLE`; publication blocked                                       |
| MIS-004 | Current-record or source match field is inaccessible                     | `FIELD_NOT_ACCESSIBLE`; never treat missing access as an empty value                    |
| MIS-005 | Match types are outside an allowed family                                | `MATCH_FIELD_TYPES_DIFFER`                                                              |
| MIS-006 | Multi-select picklist is selected as a match field                       | `UNSUPPORTED_MATCH_FIELD_TYPE`                                                          |
| MIS-010 | Reference source retains match fields from an old draft                  | Package clears them; published version contains no hidden match                         |
| MIS-011 | Related source attempts non-equality matching                            | Apex request cannot represent it; server rejects unknown configuration                  |
| MIS-012 | Filter OR group attempts to bypass the required match                    | Generated SOQL keeps the match outside and before optional filter groups                |
| MIS-013 | Current-record path names a child relationship                           | `INVALID_FIELD_PATH`; only parent traversal is accepted                                 |
| MIS-014 | Polymorphic branch is ambiguous                                          | `AMBIGUOUS_POLYMORPHIC_PATH`                                                            |
| MIS-015 | Administrator supplies a target-type hint not proved by Describe         | Configuration rejected; the package does not guess the first target                     |
| MIS-016 | Currency aggregate lacks a mandatory ISO-code equality                   | `MISSING_CURRENCY_BOUNDARY`                                                             |
| MIS-017 | Currency aggregate filter uses invalid ISO text                          | Field-type validation blocks publication                                                |
| MIS-018 | Cross-source token is placed in a filter or match                        | `CROSS_SOURCE_CHAIN_NOT_SUPPORTED`                                                      |
| MIS-019 | Raw SOQL or WHERE text is submitted through a changed request            | Unknown Apex request fields are ignored or rejected; text never becomes executable SOQL |
| MIS-020 | Saved package method disagrees with current object and field information | Package method is recalculated; a saved method cannot control prompt generation         |
| MIS-022 | Duplicate source names would run the same query                          | Duplicate-name validation blocks publication; sources are not merged                    |
| MIS-023 | Same object is queried by two source names with different rules          | Queries and results remain independent                                                  |
| MIS-024 | Multi-record source has no order but is used by index or loop            | Fixed-order validation blocks publication                                               |

Exit gate: every MIS test case returns the exact stable code, location, and corrective message;
ordinary responses reveal no object or field name the running user cannot access.

## 6. War scenarios

War scenarios exercise combined failures and platform pressure, not only isolated validation.

| ID      | Scenario                                                                     | Required outcome                                                                         |
| ------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| WAR-001 | 200 requests, ten sources, all unique match values                           | Limit check accepts a safe number before data access; no governor exception              |
| WAR-002 | 200 requests, ten sources, all sharing one value                             | Deduplication sharply reduces query work without cross-record leakage                    |
| WAR-003 | One source has an extreme number of matches for one value                    | Record-read limit stops the work; no partial prompt is returned                          |
| WAR-004 | Several current records independently exceed per-source limits               | Warnings and selected rows remain assigned to the correct current records                |
| WAR-005 | Total per-prompt row cap is reached after matching returned rows             | Later aliases stop only for that prompt; neighboring prompts remain valid                |
| WAR-006 | Transaction starts with few queries or rows remaining                        | Service uses live remaining limits and rejects records that do not fit before queries    |
| WAR-007 | Object or field changes after publication but before bulk processing         | Validation returns a reason code and no prompt; error details contain no field values    |
| WAR-008 | Permission differs between preview author and user running the action        | User-mode access for the running user governs; preview never grants access               |
| WAR-009 | Restriction rules hide some matching rows                                    | Only visible rows participate; no hidden count or existence signal                       |
| WAR-010 | One current record is deleted after the limit check and before its query     | That record returns `RECORD_NOT_ACCESSIBLE`; neighboring records continue                |
| WAR-011 | One grouped source query fails after earlier source data loaded              | Affected prompts are all-or-none and contain no partial output or loaded values          |
| WAR-012 | A later source fails while matching rows for one Salesforce record           | That record returns no partial prompt; unrelated records can still render                |
| WAR-013 | Reference source is reused across current records with different page access | Same running-user transaction and user-mode result only; no cross-user cache exists      |
| WAR-014 | Malicious text resembles bind syntax, SOQL, merge tokens, HTML, or script    | It remains inert data and is never reparsed                                              |
| WAR-015 | Namespace-free and registered-namespace field paths are mixed                | Standard Describe resolution preserves exact installed API names                         |
| WAR-016 | Publication reads a draft while another user edits it                        | Publish uses one validated draft state and does not create a mixed version               |
| WAR-017 | Multi-currency source contains several ISO codes under an OR filter          | Aggregate is rejected before execution                                                   |
| WAR-018 | Duplicate match values combine 15-character and 18-character IDs             | Standard mapping neither loses nor leaks rows                                            |
| WAR-019 | Matching ordered rows approaches the Apex heap limit                         | Limit check includes heap and row use; processing stops before the governor exception    |
| WAR-020 | Metrics or errors include record values, query variables, rows, or prompt    | Storage rules reject them; test-value tests prove monitoring data has no customer values |

Required scale test cases include at least 1, 35, 50, 200, and 201 input records; zero, one, exact
limit, limit-plus-one, and high-number of matches source rows; all-shared and all-unique match values;
and restricted-user, namespaced, multi-currency, Batch, Queueable, and Flow contexts.

Exit gate: no WAR test case produces an unhandled governor-limit exception, partial prompt, cross-record row
assignment, access downgrade, or customer value in ordinary diagnostics.

## 7. Everyday use cases

| ID       | Use case                                                                       | Expected result                                                           |
| -------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| DAY2-001 | Account Id matches `Contact.AccountId`                                         | Visible ordered Contacts render under the source name                     |
| DAY2-002 | Account Industry Picklist matches guidance Text                                | Applicable industry guidance renders                                      |
| DAY2-003 | Account region code matches a custom metadata-like business record             | Visible limited regional reference rows render                            |
| DAY2-004 | Contact `Account.Industry` matches a policy object's Industry                  | Current-record parent field is loaded and used once                       |
| DAY2-005 | Policy `Industry__r.Name` matches Account Industry                             | Source parent path filters and selected policy fields render              |
| DAY2-006 | External key on current record matches an external-key field on another object | Rows match without a Salesforce lookup                                    |
| DAY2-007 | Owner Id matches a User Id                                                     | Visible User details render as one repeatably selected row                |
| DAY2-008 | Shared active-product guidance has no current-record dependency                | Reference source executes once per template group                         |
| DAY2-009 | Blank Industry is used for matching                                            | Empty branch/count renders and warning explains the missing match value   |
| DAY2-011 | Source returns the three highest-priority visible recommendations              | Each Salesforce record gets its own three rows in the saved order         |
| DAY2-012 | Template calculates a USD-only opportunity total                               | Currency boundary is validated and scalar aggregate renders               |
| DAY2-013 | Flow submits several records for the same template                             | Results retain input order and per-record success/failure                 |
| DAY2-014 | Batch submits a limited scope                                                  | Grouped execution reduces queries and uses the day-one API                |
| DAY2-015 | Administrator previews, publishes, and later duplicates the template           | Plain-language scope summary and read-only version fields remain accurate |

Exit gate: every everyday test case has an independently authored expected prompt, expected warning
set, query-count range, and visible admin summary.

## 8. Common processing design

```text
Published template group + accepted record IDs
  -> collect current-record fields needed by all sources
  -> one user-mode query for the current records
  -> read match values and apply null settings for each record
  -> choose how each source matches
       SELF / CHILD_DIRECT / CHILD_PATH / VALUE_MATCH
       ORDERED_MATCHES_PER_RECORD / SHARED_REFERENCE
  -> check Salesforce query, row, heap, and output limits
  -> one user-mode query for each compatible source
  -> match returned rows to each current record
  -> apply each record's order, record limit, warning, and total-row limit
  -> build the prompt for each current record, or return no partial prompt
  -> return results in request order with reason codes and value-free metrics
```

### 8.1 Required components

| Component                           | Responsibility                                                                 |
| ----------------------------------- | ------------------------------------------------------------------------------ |
| `PromptContextFieldPath`            | Validate field paths, access, and use in Salesforce filters                    |
| `PromptContextMatchFieldTypes`      | Check whether two field types can match and convert a configured null value    |
| `PromptContextSourcePlan`           | Hold selected fields, query variables, order, limits, and the row-match field  |
| `PromptContextBulkPlanner`          | Group records and sources, remove repeated values, and check Salesforce limits |
| `PromptContextBulkExecutor`         | Run user-mode queries and match returned rows to Salesforce records            |
| `PromptContextCurrencyGuard`        | Prevent Currency calculations from mixing currencies                           |
| `PromptContextService`              | Build prompts from prepared data for single-record and grouped entry points    |
| `PromptContextResourcePlanner`      | Check query, row, heap, output, and per-prompt limits                          |
| `promptTemplateBuilder` path picker | Explain matching, choose fields, and show the fixed blank-value behavior       |

Names may change during implementation only if the build record maps the final owner to every
responsibility above. Query compilation and query execution must remain separate from rendering.

### 8.2 Query forms

Single-record execution remains equivalent to:

```sql
SELECT <validated selected fields>
FROM <described source object>
WHERE <standard match path> = :matchValue
  AND (<validated administrator filters>)
ORDER BY <validated order>, Id ASC
LIMIT :overflowLimit
```

Grouped execution is equivalent to:

```sql
SELECT <validated selected fields>, <row match path>
FROM <described source object>
WHERE <standard match path> IN :matchValues
  AND (<validated administrator filters>)
ORDER BY <row match path>, <validated order>, Id ASC
LIMIT :candidateBudget
```

The query must include the row-match field even when the prompt does not display it. The service
matches returned rows before applying each record's limit. If Salesforce cannot return a reliable
row-match field, publication or execution fails with a clear reason code. The service cannot switch
to one query per record as a hidden substitute.

## 9. Delivery stages and verifiable gates

Every stage follows the repository regression-first agreement: add the focused test, prove the
expected red result against the broken implementation, apply the smallest complete change, preserve
the test, run focused checks, then run relevant gates. Salesforce commands require an identified,
approved purpose org; scratch-org creation is never implied by this specification.

### Stage 0: Agree on behavior and red tests

Work:

1. Add all RED test cases before changing production behavior.
2. Add EDGE, MIS, WAR, and DAY2 test cases as data builders or platform-only test definitions.
3. Add the complete day-one reason-code list to the central catalog.
4. Define every required day-one Apex request field and its explicit default, when a default is allowed.
5. Record the proposed metadata fields and permission-set access.

Verification:

- RED-001 through RED-018 fail for the intended missing behavior.
- Day-one Apex and LWC tests remain green before implementation tests are enabled.
- A test case-to-scenario check proves every ID in this document has an owner.

Exit gate: approved behavior table, red evidence, test-owner map, storage-field map, and no
production behavior change.

### Stage 1: Standard field paths and match types

Work:

1. Introduce one field-path service used by the picker, publication checks, field-access list, query
   preparation, and prompt generation.
2. Implement the compatibility families in section 2.3.
3. Standardize 15-character and 18-character Salesforce IDs and safe numeric conversions.
4. Implement common-path polymorphic proof; reject ambiguous or inaccessible branches.
5. Enforce the documented path-depth and blocked-type limits.

Focused verification:

- RED-001, RED-010 through RED-013, RED-018.
- EDGE-007 through EDGE-014 and EDGE-028 through EDGE-030.
- MIS-003 through MIS-006 and MIS-013 through MIS-015.
- Day-one current-record token, selected-field, filter, sort, namespace, and field-access list tests.

Exit gate: one standard path/type result drives every consumer; no consumer performs independent
relationship guessing or compatibility logic.

### Stage 2: Administrator value-match experience and persistence

Work:

1. Change the UI labels to `Match using current-record value` and `Shared reference records`.
2. Add searchable Current Record Match Field and Related Record Match Field pickers. Load field
   choices after the user selects an object or parent relationship.
3. Show a plain-language summary: `<related record field> must equal <current record field>`.
4. Show the fixed blank-value behavior in the source summary. Reference mode does not show match fields.
5. Update version verification values, comparison, duplication, rollback, health validation,
   field-access lists, permission sets, and sample setup for the two match fields.

Focused verification:

```bash
npm run test:unit -- --runInBand force-app/main/default/lwc/promptTemplateBuilder/__tests__/promptTemplateBuilder.test.js
```

- RED-001 and RED-008 through RED-013.
- MIS-010 through MIS-015.
- Keyboard, screen-reader name/description, 390-pixel responsive, stale-response, and draft-recovery
  tests for both path pickers.

Exit gate: an administrator can configure every supported path without SOQL, while server validation
remains authoritative and blank values always follow one documented rule.

### Stage 3: Blank values and single-record prompt generation

Work:

1. Treat a readable null current-record value separately from an access or object/field error.
2. Run no source query for a readable blank value.
3. Keep all query values in `Database.queryWithBinds(..., AccessLevel.USER_MODE)`.
4. Preserve the required match outside all optional filter groups.
5. Emit stable, value-free outcomes for empty, invalid, and inaccessible cases.

Focused verification:

- RED-008, RED-015, RED-017.
- EDGE-001 through EDGE-004, EDGE-008, EDGE-010, EDGE-011, EDGE-023.
- MIS-004, MIS-010 through MIS-012, MIS-018, MIS-019.
- Day-one single-record service, all-or-none result, injection, sharing, and restriction-rule tests.

Exit gate: all supported single-record matches work without raw query text, text replacement in
SOQL, or treating missing access as ordinary empty data.

### Stage 4: Load current records and prepare bulk queries

Work:

1. Group requests by exact published template version, not only mutable template ID.
2. Build the union current record selected fields once and load accepted current record IDs with one user-mode query.
3. Prepare one query description for each source.
4. Remove repeated match values while keeping every Salesforce record ID that supplied each value.
5. Prepare each shared reference source once.
6. Recalculate the limit check from grouped queries, possible returned rows, rows per prompt, Apex
   heap, and output size. `groupedQueryCount` alone is not enough.

Focused verification:

- RED-002, RED-003, RED-014, RED-016.
- EDGE-005, EDGE-006, EDGE-009, EDGE-019, EDGE-020, EDGE-023, EDGE-024.
- MIS-020, MIS-022, MIS-023.
- WAR-001, WAR-002, WAR-006, WAR-010, WAR-016, WAR-018.

Exit gate: test inspection proves one current-record query, one query description per source name,
stable request-to-result matching, and a repeatable limit check before customer-data queries.

### Stage 5: Grouped source execution and matching returned rows

Work:

1. Use `IN :matchValues` when a source can safely query several current records together.
2. Include the validated row-match field in the internal selected fields.
3. Run each prepared query once in explicit user mode.
4. Give returned rows to every current record that supplied the matching value.
5. Reuse shared reference results only in the current transaction and for the running user.
6. Keep source names independent even when two prepared queries are identical.
7. Build a complete prompt or no prompt for each record. A failure for one record does not remove
   successful results for neighboring records.

Focused verification:

- RED-002, RED-003, RED-014, RED-015.
- EDGE-005 through EDGE-010, EDGE-019 through EDGE-024.
- MIS-012, MIS-020, MIS-022, MIS-023.
- WAR-002, WAR-008 through WAR-015, WAR-018, WAR-020.

Exit gate: query counts, expected row-to-record matches, restricted-user tests, and test-value scans
prove there is no query loop, cross-record data leak, hidden record count, partial prompt, or customer
value in monitoring data.

### Stage 6: Ordered record limits and overflow warnings

Work:

1. Use `ORDERED_MATCHES_PER_RECORD` when a matching source has an order and a limit per current record.
2. Fetch a limited set of possible rows using the row-match field and saved order.
3. Apply the configured limit independently to each current record.
4. Detect limit-plus-one independently and attach warnings only to affected current records.
5. Enforce total per-prompt row caps after matching returned rows.
6. Check the highest possible row and Apex heap use before querying. Never fetch an unlimited number
   of matches.

Focused verification:

- RED-004, RED-005, RED-016.
- EDGE-015 through EDGE-018.
- MIS-024.
- WAR-003 through WAR-006, WAR-019.

Exit gate: independently authored ordered test cases match for single and bulk execution, and exact
limit versus overflow warnings are correct for every current record.

### Stage 7: Currency-safe scalar aggregates

Work:

1. Detect multi-currency capability without adding customer-data reads.
2. Identify Currency aggregate operands through Describe.
3. Prove that one mandatory, field-type-checked `CurrencyIsoCode EQ` filter applies to every contributing row.
4. Reject absent, invalid, or OR-optional currency boundaries.
5. Carry the unit into formatting context without claiming currency conversion.

Focused verification:

- RED-006 and RED-007.
- EDGE-025 through EDGE-027.
- MIS-016 and MIS-017.
- WAR-017.
- Day-one COUNT, numeric aggregate, filter-group, formatting, and access tests.

Exit gate: mixed-currency scalar aggregation cannot produce a plausible unitless result; the documented
single-currency and COUNT behavior remains unchanged within the day-one contract.

### Stage 8: Lifecycle and operational hardening

Work:

1. Update version verification values, comparisons, duplication, rollback, health checks, permission sets,
   seeded verification templates, API docs, admin guidance, architecture/security docs, exact field
   references, limits, reason codes, and navigation.
2. Require every published version to follow the day-one blank-value behavior without adding a setting.
3. Verify namespace-free and registered-namespace paths.
4. Verify Flow, Apex, Batch, Queueable, Scheduled, record-page, restricted-user, and multi-currency
   contexts.
5. Add value-free bulk measurements for the selected package method, accepted current records, query count, row count, duration,
   truncation count, and stable outcome only.
6. Run static analysis and permission-boundary checks.

Focused verification:

- All RED, EDGE, MIS, WAR, and DAY2 scenarios.
- Clean package-install test cases against an identified approved org.
- Wide and 390-pixel browser journeys for value matching, blank values, path selection, validation,
  preview, publication, and record-page generation.
- Diagnostic test values never appear in events, responses, logs, or saved health status.

Final commands:

```bash
npm run test:unit:coverage
npm run ci:gates
sf apex run test --test-level RunLocalTests --target-org <approved-purpose-org> --wait 60 --result-format human
```

Exit gate: local CI passes; required org, browser, namespace, and package evidence is recorded with
org alias/purpose, command, timestamp, run/deployment/package identifier, and exact result. Until
then, the capability remains proposed or locally verified, never described as deployed or packaged.

## 10. Traceability requirements

The implementation build record must contain one row per scenario ID and one row per stage exit
gate. Each row records:

- owning test class or browser journey;
- test case or sample-template developer key;
- red result when regression-first work applies;
- green local result;
- approved-org result when platform behavior is required;
- namespace/package result when applicable;
- final code owner and relevant behavior or reason code; and
- outcome: delivered, deferred, or rejected with rationale.

No scenario may be marked verified solely because a nearby scenario passed. Local, org, browser,
namespace, and package evidence remain distinct. Query-count improvement is demonstrated with Apex
limit deltas, not inferred from source review. Security is demonstrated with restricted-user and
sharing test cases, not an administrator-only run.

## 11. Completion definition

This increment is complete only when:

1. Every supported source uses validated Salesforce object and field information, user-mode queries,
   and query variables.
2. Picklist-to-Text Industry matching and every other allowed family have executable regression
   coverage.
3. The public bulk API performs grouped current record and source queries and has no hidden per-record query
   loop for supported shapes.
4. Ordered limits, overflow warnings, empty behavior, total-row caps, and all-or-none output remain exact
   per current record.
5. Reference data is reused only within one transaction and one running-user security context.
6. Currency aggregates cannot mix units without an explicit supported design.
7. A blank match value always runs no source query and cannot hide an access or object/field error.
8. Common polymorphic paths are proved across every target type; ambiguous branches remain rejected.
9. Raw SOQL, using one source's results to query another source, custom value-changing code, and
   system-mode customer-data access remain unavailable through Apex requests, the UI, saved settings,
   and prompt generation.
10. All scenario IDs and stage gates have recorded evidence, `npm run ci:gates` passes, and required
    Salesforce validation has passed against an identified approved org.
