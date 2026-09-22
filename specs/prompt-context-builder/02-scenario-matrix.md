# Scenario matrix

## Outcome vocabulary

| Outcome         | Meaning                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------- |
| SUCCESS         | A complete bounded prompt is returned                                                       |
| EMPTY           | A valid, visible source has zero rows or a readable field is null; template rules handle it |
| DRAFT_ERROR     | Draft may save, but publish is blocked                                                      |
| WARNING         | Configuration may publish after review                                                      |
| ACCESS_DENIED   | Runtime access cannot support a truthful prompt; no prompt is returned                      |
| CONFIG_INVALID  | Published configuration or schema is invalid; no prompt is returned                         |
| LIMIT_EXCEEDED  | Safe row/query/character budget cannot be honored; no prompt is returned                    |
| EXECUTION_ERROR | An unexpected platform/query failure occurred; no prompt is returned                        |

## A. Everyday scenarios

| ID      | Scenario                                                          | Expected outcome                                               |
| ------- | ----------------------------------------------------------------- | -------------------------------------------------------------- |
| DAY-001 | Template uses one root text field                                 | SUCCESS; readable value is inserted                            |
| DAY-002 | Template uses several root fields                                 | SUCCESS; one planned root load supplies all values             |
| DAY-003 | Template uses `record.Owner.Name`                                 | SUCCESS when relationship and field are readable               |
| DAY-004 | Parent lookup is null                                             | EMPTY; fallback or blank is rendered                           |
| DAY-005 | One related source returns one row                                | SUCCESS; indexed value and loop both use the same cached row   |
| DAY-006 | One related source returns several rows                           | SUCCESS in configured stable order                             |
| DAY-007 | Related source returns zero visible rows                          | EMPTY; `else` renders and count is zero                        |
| DAY-008 | Optional readable field is null                                   | EMPTY; fallback renders when configured                        |
| DAY-009 | Same source appears in several template locations                 | SUCCESS; source executes once                                  |
| DAY-010 | Two sources query Contact with different filters                  | SUCCESS; aliases and results remain independent                |
| DAY-011 | Two sources query Contact with different order and limits         | SUCCESS; each preserves its own contract                       |
| DAY-012 | Root record has primary and secondary lookups to Contact          | SUCCESS; relationship paths remain distinct                    |
| DAY-013 | Template uses Account, Contact, Opportunity, and Case sources     | SUCCESS within the total resource plan                         |
| DAY-014 | Related source uses a parent field such as `Contact.Account.Name` | SUCCESS when selected and readable                             |
| DAY-015 | Junction object is the source                                     | SUCCESS; selected parent paths render from junction rows       |
| DAY-016 | Same display label is edited after publishing                     | SUCCESS; stable reference name remains unchanged               |
| DAY-017 | Repeated field token appears ten times                            | SUCCESS; value is resolved once and rendered repeatedly        |
| DAY-018 | Field value is numeric zero                                       | SUCCESS; `0` renders and does not trigger fallback             |
| DAY-019 | Field value is Boolean false                                      | SUCCESS; formatted false renders and does not trigger fallback |
| DAY-020 | Field value is literal text `null`                                | SUCCESS; literal text renders and is not treated as Apex null  |

## B. Multiple-source and ordering scenarios

| ID      | Scenario                                                     | Expected outcome                                                               |
| ------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| ORD-001 | `recentContacts[0]` uses CreatedDate descending              | SUCCESS; newest visible row renders                                            |
| ORD-002 | `oldestContacts[0]` uses CreatedDate ascending               | SUCCESS; oldest visible row renders                                            |
| ORD-003 | Two rows tie on CreatedDate                                  | SUCCESS; automatic Id tiebreaker makes order stable                            |
| ORD-004 | Indexed token has no authored order                          | DRAFT_ERROR unless query is provably single-row                                |
| ORD-005 | Loop source has no authored order                            | DRAFT_ERROR for repeatable version 1 rendering                                 |
| ORD-006 | Source has `LIMIT 1` but no order                            | DRAFT_ERROR; one arbitrary row is not a business definition                    |
| ORD-007 | Source filters by exact Id and returns at most one record    | SUCCESS without order                                                          |
| ORD-008 | Ungrouped aggregate returns one row                          | SUCCESS without order                                                          |
| ORD-009 | Grouped aggregate is iterated without order                  | DRAFT_ERROR                                                                    |
| ORD-010 | Grouped aggregate is ordered by grouped field/alias          | SUCCESS when all referenced aliases are valid                                  |
| ORD-011 | Requested index equals configured maximum                    | DRAFT_ERROR because zero-based index is unreachable                            |
| ORD-012 | Requested index exists in configuration but not current data | EMPTY; token fallback or blank applies                                         |
| ORD-013 | Identical source referenced through two aliases              | SUCCESS; semantic aliases remain independent even if execution is deduplicated |
| ORD-014 | One alias is renamed in a draft                              | SUCCESS only after every reference is updated atomically                       |
| ORD-015 | One alias is renamed in a published version                  | CONFIG_INVALID operation; create a new version instead                         |

## C. Template misconfiguration scenarios

| ID      | Scenario                                                     | Expected outcome                                  |
| ------- | ------------------------------------------------------------ | ------------------------------------------------- |
| TMP-001 | Flat token `{!Name}`                                         | DRAFT_ERROR with `{!record.Name}` suggestion      |
| TMP-002 | Unknown namespace                                            | DRAFT_ERROR                                       |
| TMP-003 | Unknown related reference name                               | DRAFT_ERROR naming the missing source             |
| TMP-004 | Unknown root or related field                                | DRAFT_ERROR                                       |
| TMP-005 | Field is valid but not exposed by related source             | DRAFT_ERROR                                       |
| TMP-006 | Missing closing brace                                        | DRAFT_ERROR with source position                  |
| TMP-007 | Stray reserved brace                                         | DRAFT_ERROR                                       |
| TMP-008 | `each` block missing its close                               | DRAFT_ERROR                                       |
| TMP-009 | Closing block without opener                                 | DRAFT_ERROR                                       |
| TMP-010 | Blocks close out of order                                    | DRAFT_ERROR                                       |
| TMP-011 | Duplicate `else`                                             | DRAFT_ERROR                                       |
| TMP-012 | Loop alias used after block closes                           | DRAFT_ERROR                                       |
| TMP-013 | Nested loop reuses active alias                              | DRAFT_ERROR with replacement suggestion           |
| TMP-014 | Unknown attribute                                            | DRAFT_ERROR                                       |
| TMP-015 | Repeated attribute                                           | DRAFT_ERROR                                       |
| TMP-016 | Unquoted attribute                                           | DRAFT_ERROR                                       |
| TMP-017 | Currency format applied to Checkbox                          | DRAFT_ERROR                                       |
| TMP-018 | Fallback applied to readable null text                       | SUCCESS                                           |
| TMP-019 | Valid configured source is unused                            | WARNING                                           |
| TMP-020 | Selected related field is unused                             | WARNING                                           |
| TMP-021 | Record data itself contains a merge token                    | SUCCESS; data remains literal and is not reparsed |
| TMP-022 | Template contains Unicode, emoji, accents, or RTL text       | SUCCESS without corruption                        |
| TMP-023 | Direct typing and picker insertion produce equivalent syntax | SUCCESS and identical parsed shape                |

## D. Related-source misconfiguration scenarios

| ID       | Scenario                                             | Expected outcome                                                      |
| -------- | ---------------------------------------------------- | --------------------------------------------------------------------- |
| SRC-001  | Duplicate reference name                             | DRAFT_ERROR                                                           |
| SRC-002  | Label contains spaces                                | SUCCESS; generated reference name is valid                            |
| SRC-003  | Reference name contains invalid characters           | DRAFT_ERROR or automatic normalization before first save              |
| SRC-004  | Reference name is reserved                           | DRAFT_ERROR with suggestion                                           |
| SRC-005  | Related object does not exist                        | DRAFT_ERROR                                                           |
| SRC-006  | Correlation field does not exist                     | DRAFT_ERROR                                                           |
| SRC-007  | Correlation does not lead to root record             | DRAFT_ERROR                                                           |
| SRC-008  | Optional OR filter could bypass correlation          | Builder still emits `correlation AND (filters)`; escape is impossible |
| SRC-009  | Text operator applied to Date                        | DRAFT_ERROR                                                           |
| SRC-010  | Filter value cannot convert to field type            | DRAFT_ERROR                                                           |
| SRC-011  | Sort field is not sortable                           | DRAFT_ERROR                                                           |
| SRC-012  | Maximum records is zero or negative                  | DRAFT_ERROR                                                           |
| SRC-013  | Maximum exceeds framework cap                        | DRAFT_ERROR                                                           |
| SRC-014  | Incomplete source is saved                           | Draft saves; publish is blocked                                       |
| SRC-015  | Inactive source is referenced                        | DRAFT_ERROR                                                           |
| SRC-016  | Source references another source result              | DRAFT_ERROR                                                           |
| SRC-017  | Related-mode source is not correlated to root record | DRAFT_ERROR                                                           |
| SRC-017A | Bounded source intentionally uses Reference mode     | WARNING; visible rows may generate within security and row limits     |
| SRC-018  | Unsupported child subquery requested                 | DRAFT_ERROR in version 1                                              |
| SRC-019  | Unsupported polymorphic path requested               | DRAFT_ERROR in version 1                                              |
| SRC-020  | Custom namespaced object and field are valid         | SUCCESS with exact API names preserved                                |

## E. Empty and missing-data scenarios

| ID      | Scenario                                                | Expected outcome                |
| ------- | ------------------------------------------------------- | ------------------------------- |
| EMP-001 | No visible related rows                                 | EMPTY; `else` renders           |
| EMP-002 | No visible related rows and no `else`                   | SUCCESS with empty block output |
| EMP-003 | Readable field is null with fallback                    | EMPTY; fallback renders         |
| EMP-004 | Readable field is null without fallback                 | EMPTY; blank renders            |
| EMP-005 | Parent relationship is null                             | EMPTY, not ACCESS_DENIED        |
| EMP-006 | Requested index is absent and fallback exists           | EMPTY; fallback renders         |
| EMP-007 | Requested index is absent without fallback              | EMPTY; blank renders            |
| EMP-008 | Bare count source returns aggregate row containing zero | SUCCESS; numeric zero renders   |
| EMP-009 | Related `.count` sees zero rows                         | SUCCESS; zero renders           |
| EMP-010 | Field is inaccessible                                   | ACCESS_DENIED, never EMPTY      |
| EMP-011 | Record is invisible                                     | ACCESS_DENIED, never EMPTY      |
| EMP-012 | Field was removed                                       | CONFIG_INVALID, never EMPTY     |

## F. Field-type and formatting scenarios

| ID      | Scenario                                                    | Expected outcome                                                   |
| ------- | ----------------------------------------------------------- | ------------------------------------------------------------------ |
| FMT-001 | Number with default formatting                              | SUCCESS using current locale                                       |
| FMT-002 | Currency in single-currency org                             | SUCCESS using currency formatting                                  |
| FMT-003 | Currency in multicurrency org                               | SUCCESS only with an available currency basis/code                 |
| FMT-004 | Percentage                                                  | SUCCESS with explicit stored-to-display semantics                  |
| FMT-005 | Date                                                        | SUCCESS using current locale                                       |
| FMT-006 | DateTime                                                    | SUCCESS using current locale and timezone                          |
| FMT-007 | Rich Text                                                   | SUCCESS after conversion to inert plain text                       |
| FMT-008 | Long Text near prompt budget                                | WARNING during authoring; runtime hard limit remains enforced      |
| FMT-009 | Encrypted String                                            | DRAFT_ERROR; excluded even when decryptable                        |
| FMT-010 | Blob/Base64                                                 | DRAFT_ERROR                                                        |
| FMT-011 | Compound Address                                            | DRAFT_ERROR for whole compound or SUCCESS for supported components |
| FMT-012 | Geolocation                                                 | SUCCESS only through explicit latitude/longitude components        |
| FMT-013 | Formula with supported result type                          | SUCCESS                                                            |
| FMT-014 | Formula cannot evaluate or underlying access is unavailable | ACCESS_DENIED or EXECUTION_ERROR; never misleading blank           |

## G. Security and adversarial scenarios

| ID      | Scenario                                                     | Expected outcome                                                                                 |
| ------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| SEC-001 | User lacks root-object read access                           | ACCESS_DENIED                                                                                    |
| SEC-002 | User lacks root-field read access                            | ACCESS_DENIED                                                                                    |
| SEC-003 | User lacks related-object read access                        | ACCESS_DENIED                                                                                    |
| SEC-004 | User lacks selected related-field access                     | ACCESS_DENIED                                                                                    |
| SEC-005 | User lacks access to a filter field                          | ACCESS_DENIED before source execution                                                            |
| SEC-006 | User lacks access to a sort field                            | ACCESS_DENIED before source execution                                                            |
| SEC-007 | Root record is hidden by sharing                             | ACCESS_DENIED                                                                                    |
| SEC-008 | Related records are filtered by sharing/restriction rules    | SUCCESS with visible rows only; no hidden count disclosed                                        |
| SEC-009 | Zero rows may mean hidden records exist                      | EMPTY with visible-scope wording only                                                            |
| SEC-010 | Caller supplies Contact ID to Account template               | ACCESS_DENIED or CONFIG_INVALID request; no query proceeds                                       |
| SEC-011 | Filter value contains quote and SOQL text                    | SUCCESS as a typed bind value; structure is unchanged                                            |
| SEC-012 | Caller supplies object or field name as text                 | Rejected unless it matches a server-side described allowlist                                     |
| SEC-013 | Query asks for SYSTEM_MODE                                   | DRAFT_ERROR                                                                                      |
| SEC-014 | Query asks for FOR UPDATE or ALL ROWS                        | DRAFT_ERROR                                                                                      |
| SEC-015 | Query contains DML keyword                                   | DRAFT_ERROR                                                                                      |
| SEC-016 | Record text contains HTML or script                          | SUCCESS as inert plain text; nothing executes                                                    |
| SEC-017 | Record text contains template syntax                         | SUCCESS as literal output; no second parse                                                       |
| SEC-018 | Record text contains AI-directed instructions                | SUCCESS as clearly delimited untrusted context; no claim of complete prompt-injection prevention |
| SEC-019 | Error occurs after sensitive values load                     | No prompt/value/stack trace is exposed in ordinary diagnostics                                   |
| SEC-020 | Completed prompt could be logged                             | Forbidden; verification detects no prompt logging                                                |
| SEC-021 | Completed prompt could enter cross-user cache                | Forbidden in version 1                                                                           |
| SEC-022 | Elevated query is proposed to distinguish hidden from absent | Forbidden                                                                                        |

## H. Limits, performance, and consistency scenarios

| ID      | Scenario                                          | Expected outcome                                                                                        |
| ------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| LIM-001 | Source explicitly requests five and returns five  | SUCCESS; intentional bounded subset                                                                     |
| LIM-002 | Unbounded match exceeds framework cap             | LIMIT_EXCEEDED using cap-plus-one detection                                                             |
| LIM-003 | Total rows across sources exceed transaction plan | LIMIT_EXCEEDED before unsafe rendering                                                                  |
| LIM-004 | Too many sources would exceed SOQL budget         | DRAFT_ERROR at publish or LIMIT_EXCEEDED before data access                                             |
| LIM-005 | Token count exceeds configured maximum            | DRAFT_ERROR                                                                                             |
| LIM-006 | Block nesting exceeds configured maximum          | DRAFT_ERROR                                                                                             |
| LIM-007 | Relationship depth exceeds configured maximum     | DRAFT_ERROR                                                                                             |
| LIM-008 | Completed prompt exceeds character/byte limit     | LIMIT_EXCEEDED; no clipped prompt                                                                       |
| LIM-009 | Repeated source token could cause N+1 queries     | SUCCESS; static plan executes source once                                                               |
| LIM-010 | Many rows include unused selected columns         | WARNING; projection should be minimized before publish                                                  |
| LIM-011 | Records change between source queries             | One transaction provides best-effort consistency; contract does not claim historical snapshot isolation |
| LIM-012 | Two requests run concurrently                     | Each uses its own user, record, version, and in-memory context                                          |

## I. Schema-change and recovery scenarios

| ID      | Scenario                                         | Expected outcome                                                |
| ------- | ------------------------------------------------ | --------------------------------------------------------------- |
| REC-001 | Referenced field is deleted after publish        | CONFIG_INVALID at runtime; deactivate and revise template       |
| REC-002 | Referenced object is removed with a package      | CONFIG_INVALID                                                  |
| REC-003 | Field type changes and format is no longer valid | CONFIG_INVALID                                                  |
| REC-004 | Relationship API path changes                    | CONFIG_INVALID                                                  |
| REC-005 | Running permissions change after publish         | ACCESS_DENIED at runtime; structural template remains published |
| REC-006 | Published source no longer sortable              | CONFIG_INVALID                                                  |
| REC-007 | Template is deactivated                          | Runtime refuses new generation; history remains                 |
| REC-008 | Draft fixes invalid published version            | New version must validate and preview before publication        |
| REC-009 | Unexpected query/platform error                  | EXECUTION_ERROR with correlation ID and no prompt contents      |
| REC-010 | Browser closes or resets                         | Client-side generated prompt and context are cleared            |

## J. Configuration usability scenarios

| ID     | Scenario                                     | Expected outcome                                                           |
| ------ | -------------------------------------------- | -------------------------------------------------------------------------- |
| UX-001 | Field is inserted from picker                | Complete valid token is inserted                                           |
| UX-002 | Related list is inserted                     | Complete `each`/`else` block is inserted                                   |
| UX-003 | First related record is inserted             | Source order requirement is created or explained                           |
| UX-004 | Source label changes                         | References remain valid                                                    |
| UX-005 | Source has validation error                  | Message uses display label and gives corrective action                     |
| UX-006 | Generated SOQL is needed for troubleshooting | Available in collapsed read-only detail                                    |
| UX-007 | Draft has errors                             | Draft saves; Publish remains disabled with issue list                      |
| UX-008 | Preview succeeds                             | Four areas show template, retrieved context summary, output, and findings  |
| UX-009 | Preview has zero related rows                | Plain-language visible-record explanation is shown                         |
| UX-010 | Access manifest has missing access           | Missing object/field is clearly marked without showing a value             |
| UX-011 | Automatic Id tiebreaker is added             | Information message explains it                                            |
| UX-012 | Warning is acknowledged                      | Publication records that validation completed; warnings remain inspectable |
