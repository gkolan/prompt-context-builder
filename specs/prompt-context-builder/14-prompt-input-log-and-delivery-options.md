# Prompt Input Log and delivery choices

Status: Implemented in local source and validated in `pcb-package-test`. The common public entry,
two delivery choices, private Prompt Input Log, exact selected-file list, safe repeated saves,
verification checks, claim expiry, retry limit, uncertain-outcome handling, and retention cleanup
have Apex coverage. The increment was deployed to `pcb-package-test` in job
`0AfRL00000i7CCn0AM`; it has not been browser-verified or package-verified.

Day-one rule: every caller and stored input must satisfy this complete contract. There is no deprecated
API, migration layer, old response shape, or upgrade path to preserve.

## 1. Outcome

Prompt Context Builder prepares one complete input for each Salesforce record. The caller chooses one
action:

- **Save to Prompt Input Log** (`SAVE_TO_LOG`) saves the prepared input for approved later processing.
- **Return to Apex** (`RETURN_TO_APEX`) returns the prepared input without creating package records.

There is no third destination-registration choice. Batch, Queueable, Scheduled Apex, and other approved
code use **Return to Apex** when they own the next action. An organization-approved later worker can
process saved Prompt Input Logs through the tested lifecycle service. The current package does not
include an Amazon Bedrock callout worker.

Preparation always happens through `PromptContextPreparationService`. Saving cannot change the prepared
text, query more customer data, select another template version, or add files.

## 2. One public entry

`PromptContextInputApi` is the only public preparation API. Apex calls `prepare()`. Flow calls the one
invocable method `prepareForFlow()`. Both methods use the same private mapping, preparation, and delivery
path.

Each request contains:

| Field                  | Required | Purpose                                                |
| ---------------------- | -------- | ------------------------------------------------------ |
| `templateId`           | Either   | Published Prompt Template ID                           |
| `templateDeveloperKey` | Either   | Stable Automation Key used when an ID is not supplied  |
| `recordId`             | Yes      | Current Salesforce record                              |
| `deliveryChoice`       | Yes      | `SAVE_TO_LOG` or `RETURN_TO_APEX`                      |
| `requestKey`           | For save | Caller key used to recognize an intentional safe retry |

Each result preserves request order and contains the preparation outcome, safe reason code, warnings,
prepared text when successful, exact template-version ID, and Prompt Input Log ID when one was saved.

Missing or unsupported delivery choices fail before template or customer-data queries. Save requests
without the separate Save Prompt Input permission or a Request Key fail before preparation.

## 3. Prepared input boundary

The common preparation result contains:

- current record ID;
- exact published template-version ID;
- complete prepared text;
- ordered selected Salesforce File details;
- stable warning codes;
- contract and syntax information used during preparation; and
- a value-free request ID for support.

Prepared input is independent of Amazon Bedrock. It does not contain provider profiles, S3 locations,
temporary URLs, credentials, provider receipts, or provider responses.

The selected file list is `[]` when files are disabled or none are selected. When files are enabled,
the server builds the list from exact visible `ContentVersionId` values. Callers cannot submit their
own file JSON through the public API.

## 4. Prompt Input Log

### 4.1 One private object

The data model contains one object only:

| Object                | Label            | Sharing |
| --------------------- | ---------------- | ------- |
| `Prompt_Input_Log__c` | Prompt Input Log | Private |

There is no file child object. File details are stored in one managed Long Text Area because the list is
ordered, limited to five entries, and is not an administrator reporting dimension.

Implemented fields:

| Field                         | Type              | Purpose                                                    |
| ----------------------------- | ----------------- | ---------------------------------------------------------- |
| `Request_Key__c`              | Text, unique      | User-specific verification value for an intentional retry  |
| `Input_Verification_Value__c` | Text 64           | Confirms record, template version, text, files, and format |
| `Source_Record_Id__c`         | Text 18           | Salesforce record used to prepare the input                |
| `Prompt_Template_Version__c`  | Required lookup   | Exact `Prompt_Template_Version__c`                         |
| `Prompt_Text__c`              | Long Text Area    | Complete prepared text                                     |
| `Selected_Files_JSON__c`      | Long Text Area    | Ordered details for zero through five exact file versions  |
| `Input_Format_Version__c`     | Text              | Saved-input format version                                 |
| `Status__c`                   | Restricted choice | Ready, Processing, Sent, Failed, Cancelled, or Expired     |
| `Available_At__c`             | Date/Time         | Earliest processing or retry time                          |
| `Processing_Expires_At__c`    | Date/Time         | Recovery boundary for interrupted processing               |
| `Attempt_Count__c`            | Number            | Delivery attempts, excluding preparation and save          |
| `Last_Reason_Code__c`         | Text              | Stable processing failure code only                        |
| `Retain_Until__c`             | Date/Time         | Governed deletion time                                     |

Standard Salesforce fields provide the record ID, owner, creator, creation time, and last-modified time.
The schema does not duplicate those values.

The log does not store a delivery choice because every log was necessarily created through
`SAVE_TO_LOG`. It does not store file count or total bytes because those values are validated from the
managed file list. It does not store template number or fingerprint because the exact template-version
lookup owns those values.

### 4.2 Managed file list

`Selected_Files_JSON__c` contains an array with at most five entries:

```json
[
  {
    "order": 1,
    "contentVersionId": "068...",
    "fileName": "Proposal.pdf",
    "fileFormat": "pdf",
    "sizeInBytes": 248120
  }
]
```

The field never contains file bytes, extracted text, `ContentDocumentLink` IDs, S3 locations, temporary
URLs, credentials, or provider responses. The exact `ContentVersionId` prevents a later upload from
silently replacing the selected version. Execution reloads the version and rechecks its direct
`ContentDocumentLink` to the source record.

### 4.3 Safe repeated requests

The save service hashes the running user ID with the caller's Request Key before storage. The raw caller
key is not stored. This prevents two users from discovering or colliding on each other's keys.

For a repeated stored key:

- the same input verification value returns the existing Prompt Input Log ID;
- a different verification value fails `REQUEST_KEY_CONFLICT`; and
- an invisible record cannot be disclosed through an error or returned ID.

The verification value covers the source record ID, exact template-version ID, prepared text, managed
file list, and input-format version.

### 4.4 Status and retry

```text
Ready -> Processing -> Sent
Ready -> Processing -> Failed
Ready -> Cancelled
Ready | Failed -> Expired
```

A temporary failure records a stable reason and later `Available_At__c`, then returns the record to
**Ready**. There are no separate Claimed, Delivering, Retryable Failure, or Final Failure values.
`Processing_Expires_At__c` permits recovery when a worker stops unexpectedly.

## 5. Permissions and data handling

- Generate Prompt Context is required for both delivery choices.
- Save Prompt Input is additionally required for `SAVE_TO_LOG`.
- Prompt Input Logs use private internal and external sharing.
- Saving uses user-mode DML and field permissions.
- Template administration alone does not grant access to saved customer data unless its Permission Set
  explicitly includes Save Prompt Input.
- Debug logs, measurements, Platform Events, and error details must not contain prompt text, filenames,
  record values, raw Request Keys, or managed file JSON.
- Platform Encryption, data classification, auditing, regional rules, backups, legal hold, and data
  subject requests require an organization decision before production use.

## 6. Red scenarios

These tests are created before production behavior. Each test must fail for the named missing behavior,
not because its setup is invalid.

| ID       | Red scenario                                             | Required green result                                                     |
| -------- | -------------------------------------------------------- | ------------------------------------------------------------------------- |
| IRED-001 | `RETURN_TO_APEX` prepares a valid input                  | Prompt returned; zero Prompt Input Logs created                           |
| IRED-002 | `SAVE_TO_LOG` prepares a valid input                     | Exactly one complete Prompt Input Log created                             |
| IRED-003 | Save request contains three verified file versions       | One log contains three ordered managed entries; no child records          |
| IRED-004 | Sixth file is selected                                   | Complete request fails `TOO_MANY_FILES`; no log created                   |
| IRED-005 | Delivery choice is blank or unsupported                  | `INVALID_DELIVERY_CHOICE` before customer-data queries                    |
| IRED-006 | Save permission is missing                               | `NOT_AUTHORIZED`; no prompt or log                                        |
| IRED-007 | Save Request Key is blank                                | `REQUEST_KEY_REQUIRED`; no prompt or log                                  |
| IRED-008 | Same user retries same key and same prepared input       | Existing log ID returned; count remains one                               |
| IRED-009 | Same user retries same key with different prepared input | `REQUEST_KEY_CONFLICT`; original log unchanged                            |
| IRED-010 | Two valid save requests run together                     | Two results map to the correct logs in original request order             |
| IRED-011 | One log insert fails in a mixed request                  | Neighboring inserts can succeed; failed result contains no partial prompt |
| IRED-012 | Exact template version cannot be resolved                | Preparation fails; no log is saved                                        |
| IRED-013 | Public API attempts to accept caller-managed file JSON   | API contract test fails; only the trusted file service supplies it        |

Minimum owners:

- `PromptContextInputApiTest`: IRED-001, IRED-002, IRED-005 through IRED-010, IRED-012.
- `PromptContextInputLogServiceTest`: IRED-008 through IRED-011.
- `PromptContextFileSelectionServiceTest`: IRED-003, IRED-004, IRED-013.
- `check-input-log-contract.mjs`: one object, exact minimal fields, two choices, and app boundaries.

Verification:

```bash
npm run check:input-log
sf apex run test --tests PromptContextInputApiTest,PromptContextInputLogServiceTest,PromptContextFileSelectionServiceTest --target-org <approved-purpose-org> --wait 30 --result-format human
```

## 7. Edge cases

| ID        | Scenario                                                | Required result                                                    |
| --------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| IEDGE-001 | Null request item                                       | One ordered `INVALID_DELIVERY_CHOICE` result                       |
| IEDGE-002 | Empty request collection                                | Empty result and no DML                                            |
| IEDGE-003 | Maximum accepted request collection                     | Ordered results without per-record DML                             |
| IEDGE-004 | One request over the collection limit                   | Complete call rejected before customer-data queries                |
| IEDGE-005 | Prompt is exactly the maximum size                      | Saved or returned unchanged                                        |
| IEDGE-006 | Prompt exceeds the maximum by one character             | `PROMPT_TOO_LONG`; no log                                          |
| IEDGE-007 | No selected files                                       | Managed file value is exactly `[]`                                 |
| IEDGE-008 | Exactly five selected files                             | Five ordered entries accepted                                      |
| IEDGE-009 | Two files have the same filename                        | Exact version IDs and order remain distinct                        |
| IEDGE-010 | New Salesforce File version appears after preparation   | Saved exact version remains unchanged                              |
| IEDGE-011 | Selected version is deleted before processing           | Processing fails exact file; no latest-version fallback            |
| IEDGE-012 | Request Key differs only by case                        | Case-insensitive stored-key behavior remains documented and tested |
| IEDGE-013 | Request Key contains surrounding spaces                 | Trim once before user-specific hashing                             |
| IEDGE-014 | Two inputs use the same Request Key in one call         | Reuse only when verification values match                          |
| IEDGE-015 | Warning list is empty                                   | Blank warning field; success unchanged                             |
| IEDGE-016 | Retention date crosses daylight-saving or year boundary | Date/Time comparison remains exact                                 |
| IEDGE-017 | Processing expires while another worker starts          | One worker wins the tested claim operation                         |
| IEDGE-018 | Log reaches retry maximum                               | Status becomes Failed; no further automatic retry                  |

## 8. Misconfiguration scenarios

| ID       | Misconfiguration                                   | Required result                                                   |
| -------- | -------------------------------------------------- | ----------------------------------------------------------------- |
| IMIS-001 | Save permission exists without Generate permission | Public API remains unavailable or returns `NOT_AUTHORIZED`        |
| IMIS-002 | Object create access is missing                    | `INPUT_LOG_SAVE_FAILED`; no system-mode fallback                  |
| IMIS-003 | One required field lacks edit permission           | `INPUT_LOG_SAVE_FAILED`; no partial log                           |
| IMIS-004 | Template-version lookup would be deleted           | Restrict deletion or fail without clearing the lookup             |
| IMIS-005 | File JSON is not an array                          | Reject before saving or processing                                |
| IMIS-006 | File JSON has more than five entries               | `TOO_MANY_FILES`                                                  |
| IMIS-007 | File entry omits exact `ContentVersionId`          | `INVALID_FILE_SELECTION`                                          |
| IMIS-008 | File entry contains bytes or a temporary URL       | Contract/security test fails                                      |
| IMIS-009 | Status contains an unapproved value                | Restricted picklist rejects it                                    |
| IMIS-010 | Retention date is absent                           | Insert rejected; no ordinary default outside the approved service |
| IMIS-011 | Worker queries logs without field checks           | Security test fails                                               |
| IMIS-012 | Documentation claims files are stored in the log   | Documentation gate fails; only file details are stored            |
| IMIS-013 | App exposes a direct Prompt Data Set tab           | Repository contract fails                                         |
| IMIS-014 | App overrides Account View or adds Account/Contact | Repository contract fails                                         |

## 9. War scenarios

| ID       | Scenario                                                    | Required result                                                         |
| -------- | ----------------------------------------------------------- | ----------------------------------------------------------------------- |
| IWAR-001 | 200 save requests arrive in one transaction                 | Preparation stays within limits; logs insert in one partial-success DML |
| IWAR-002 | Two transactions race on the same Request Key               | Unique key permits one record; loser safely reloads or fails            |
| IWAR-003 | Attacker guesses another user's raw Request Key             | User-specific stored value prevents discovery or reuse                  |
| IWAR-004 | User loses source-record access after log creation          | Saved copy remains private; processing follows approved log policy      |
| IWAR-005 | User loses file access before processing                    | Exact file recheck fails; no elevated fallback                          |
| IWAR-006 | Worker stops after claiming but before provider call        | Processing expiry allows safe recovery                                  |
| IWAR-007 | Worker stops after an uncertain provider call               | No automatic retry without a safe repeated-request guarantee            |
| IWAR-008 | Input is changed after its verification value is stored     | Verification fails before delivery                                      |
| IWAR-009 | Prompt or filename reaches a debug log or measurement event | Test-value scan fails                                                   |
| IWAR-010 | Retention cleanup overlaps processing                       | Active, unexpired processing is not deleted                             |
| IWAR-011 | Required template version is removed                        | Restrict relationship blocks removal                                    |
| IWAR-012 | File JSON approaches Long Text Area limit                   | Five-entry serializer rejects oversized metadata                        |
| IWAR-013 | Malicious filename contains control characters              | Saved display value and delivery name follow separate validation rules  |
| IWAR-014 | Mixed save and return choices contain one malformed request | Per-record outcomes remain ordered and isolated                         |

## 10. Everyday use cases

| ID       | Use case                                    | Expected behavior                                            |
| -------- | ------------------------------------------- | ------------------------------------------------------------ |
| IDAY-001 | Record-page action needs prompt immediately | `RETURN_TO_APEX`; no log                                     |
| IDAY-002 | Batch class owns its next action            | `RETURN_TO_APEX`; Batch receives ordered prepared inputs     |
| IDAY-003 | Approved worker will send input later       | `SAVE_TO_LOG`; one Ready log returned                        |
| IDAY-004 | User selects two Salesforce Files           | One log contains two ordered exact-version entries           |
| IDAY-005 | Scheduled retry uses the same Request Key   | Existing unchanged log is reused                             |
| IDAY-006 | Administrator reviews a failure             | Stable reason, attempts, status, and dates are reportable    |
| IDAY-007 | Retention date passes                       | Cleanup deletes the private log according to approved policy |

## 11. Build stages and verification

### Stage 1: Repository contract

1. Add `check-input-log-contract.mjs`.
2. Run it before production metadata exists and retain the expected red output.
3. Add it to `npm run ci:gates`.

Exit gate: the check proves one object, exact required fields, no file child/destination metadata, two
delivery choices, and no Account-specific app behavior.

### Stage 2: Minimal metadata and permissions

1. Add the private Prompt Input Log object and documented fields.
2. Add Save Prompt Input Custom Permission and Permission Set.
3. Use user-mode DML and exact field access.
4. Do not add a Prompt Input Log tab until an authorized administrator journey requires one.

Exit gate: metadata validation passes and a user without Save Prompt Input cannot insert a log.

### Stage 3: Common public API

1. Replace the temporary pre-release API with `PromptContextInputApi`.
2. Route Apex and Flow through `PromptContextPreparationService`.
3. Validate delivery choice, permission, and Request Key before customer-data queries.
4. Prove `RETURN_TO_APEX` creates no package records.

Exit gate: focused Apex tests and `check-common-entry.mjs` pass.

### Stage 4: Saving and repeated requests

1. Resolve the exact published template-version ID during preparation.
2. Create the verification value from the exact prepared input.
3. Hash the running user with the caller Request Key before storage.
4. Query existing visible logs once and insert new logs once with partial-success results.
5. Return the existing ID only for the same verification value.

Exit gate: save, retry, conflict, mixed-result, CRUD, field-access, and sharing tests pass.

### Stage 5: Salesforce Files

1. Implement the trusted file picker and exact-version checks from specification 13.
2. Serialize zero through five file-detail entries in a repeatable order.
3. Reject caller-written file JSON, six files, oversized metadata, and any bytes or URLs.
4. Recheck each exact version and direct record link before provider delivery.

Exit gate: file red, edge, misconfiguration, and war tests pass without a child object.

### Stage 6: Worker and retention

1. Claim eligible Ready logs in limited pages.
2. Set Processing and a short processing expiry.
3. Verify the input and exact files before sending.
4. Save only stable status, attempt, and reason information.
5. Delete eligible expired logs in limited Batch scopes.

Exit gate: concurrency, uncertain outcome, recovery, retry, and retention tests pass.

### Stage 7: Full evidence

1. Run focused Apex tests in an identified approved org.
2. Run Code Analyzer on every changed Apex class.
3. Run `npm run ci:gates`.
4. Run Salesforce validation without deployment.
5. Keep local, org, browser, package, and provider evidence separate.

## 12. Completion criteria

This feature is complete only when:

1. `PromptContextInputApi` is the sole public preparation API.
2. Only `SAVE_TO_LOG` and `RETURN_TO_APEX` are accepted.
3. Return to Apex creates no package records.
4. Save creates one complete private Prompt Input Log.
5. Selected file details live in one managed field with a hard five-file limit.
6. No file child or destination-registration object exists.
7. Safe retries reuse only the same user's identical prepared input.
8. Missing permissions, DML errors, sharing failures, retention errors, and unsafe diagnostics stop
   processing with an explicit failure.
9. All red, edge, misconfiguration, war, and everyday scenarios have executable evidence.
10. Local gates and required approved-org validation pass without claiming unrun evidence.
