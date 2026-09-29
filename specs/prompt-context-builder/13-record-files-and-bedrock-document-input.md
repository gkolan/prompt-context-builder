# Send Salesforce Files with a prompt to Amazon Bedrock

Status: Partly implemented, Salesforce-validated, and deployed to `pcb-package-test` in job
`0AfRL00000i7CCn0AM`. Template settings, reviewed provider settings, the separate file permission,
direct-link discovery, paged exact-version selection, clear five-file and byte limits, the
record-page picker, and managed Prompt Input Log file details are in source. Prompt Context Builder
still does not read file bodies, upload files to AWS, scan files, call Amazon Bedrock, show provider
responses, or perform AWS cleanup. Stages 5 through 8 require the Stage 0 security approval and
organization-specific AWS service described below.

Day-one rule: every template and request must satisfy this complete contract. There are no older file
settings, response shapes, migration defaults, or upgrade paths to preserve.

## 1. Outcome

An authorized user can select supported Salesforce Files that are directly linked to the current
record. Prompt Context Builder sends those exact file versions and the generated prompt to an
approved Amazon Bedrock model. The feature uses a separate Custom Permission, approved provider and
model settings, clear user confirmation, and temporary encrypted storage in AWS. Any failed check
stops the complete request.

The system never drops, replaces, truncates, compresses, converts, or summarizes a file without
returning a clear error. It does not
make a provider request fit. If the request exceeds a count, size, format, page, permission, security,
Salesforce, model, or provider limit, the complete request fails with a reason code. Checks that can
run in Salesforce finish before the provider call.

Files remain Salesforce Files. The product does not create legacy Attachments, copy file bytes into
prompt text, store file bytes in a custom object or Platform Event, or save the provider response as
a conversation.

## 2. Verified Amazon Bedrock baseline

This baseline was verified against official AWS documentation on September 24, 2026. Provider and
model limits can change, so a release owner must reverify the source links before implementation and
every release that changes the provider and model settings.

Amazon Bedrock Converse and ConverseStream have these rules:

- One message can contain no more than five documents.
- Each document can be no larger than 4.5 MB.
- A message containing a document block must also contain a text block.
- Images and documents can appear only in a message whose role is `user`.
- The document formats declared by `DocumentBlock` are `pdf`, `csv`, `doc`, `docx`, `xls`, `xlsx`,
  `html`, `txt`, and `md`.
- A document source can use bytes, text, structured content, or an S3 location; S3 support depends on
  the selected model.
- A Bedrock document name is provider input and has a restricted character set. This product
  sends generated neutral names and never sends the Salesforce filename as the Bedrock document
  name.

Authoritative sources:

- [Bedrock runtime Message API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Message.html)
- [Bedrock runtime DocumentBlock API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_DocumentBlock.html)
- [Bedrock runtime DocumentSource API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_DocumentSource.html)
- [Bedrock Converse API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Converse.html)
- [Bedrock inference restrictions](https://docs.aws.amazon.com/bedrock/latest/userguide/inference-api-restrictions.html)
- [Bedrock model and API compatibility](https://docs.aws.amazon.com/bedrock/latest/userguide/models-api-compatibility.html)

The package uses these safety limits:

| Limit                             | Proposed value                        | Rule                                                                            |
| --------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------- |
| Documents per call                | 5                                     | Hard ceiling; six fails `TOO_MANY_FILES`                                        |
| Bytes per document                | 4,500,000                             | Conservative 4.5 MB interpretation; no rounding up                              |
| Total temporary document bytes    | 22,500,000                            | Five documents at the package byte ceiling                                      |
| Supported formats                 | pdf,csv,doc,docx,xls,xlsx,html,txt,md | Formats supported by both this package and the selected Bedrock model settings  |
| File-version selection lifetime   | 5 minutes                             | One-time authorization expires after this period                                |
| Temporary S3 object lifetime      | 60 minutes                            | Delete immediately after completion; bucket policy removes any remaining object |
| Files returned in one picker page | 50                                    | Return the next page through server-side paging and show when more files exist  |
| Maximum linked files inspected    | 500                                   | Higher counts fail safely or require narrower server-side filtering             |

Active provider and model settings may lower count, byte, format, or page limits. They cannot raise
a package limit. A future AWS increase requires an approved behavior change, Salesforce limit
evidence, tests, and release evidence before the package limit changes.

## 3. Supported behavior

### 3.1 File source

Version one supports Salesforce Files represented by `ContentDocument`, `ContentVersion`, and a
direct `ContentDocumentLink` whose `LinkedEntityId` is the current record ID.

The following sources are excluded:

- legacy `Attachment` records;
- files inferred from a parent, child, feed, library, email, related record, or another source;
- external URLs or remote file references;
- files linked only after elevated or system-mode lookup;
- files uploaded directly to the browser for one call without first becoming a Salesforce
  File on the current record;
- Content Notes unless a later format-specific design proves their handling;
- images, audio, and video as document input;
- file content produced by another configured source.

### 3.2 Exact version pinning

The picker displays eligible current versions, but selection pins an exact `ContentVersionId`,
`ContentDocumentId`, byte size, format, and checksum/version marker. Execution revalidates the same
version and direct current record link. It never substitutes a newer latest version after confirmation.

If a new version is uploaded after selection, the user can refresh and select it. If the selected
version is deleted, unlinked, changed, quarantined, or becomes inaccessible, the request fails
as one all-or-none operation. The product does not fall back to another version.

### 3.3 Selection modes

The template draft and published template version store one file setting:

| Mode           | Behavior                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------- |
| `DISABLED`     | No picker, file query, temporary AWS upload, or document blocks                                         |
| `USER_SELECT`  | User running the action selects zero through the configured maximum from eligible directly linked files |
| `ALL_ELIGIBLE` | Eligible directly linked files are ordered deterministically and selected up to the effective limit     |

`ALL_ELIGIBLE` chooses the first eligible current versions in deterministic order up to the effective
limit. `USER_SELECT` prevents a sixth selection in the UI and
the server independently rejects a tampered request containing six.

Template configuration includes:

| Apex request property   | Proposed Salesforce field   | What it stores                                                         |
| ----------------------- | --------------------------- | ---------------------------------------------------------------------- |
| `fileInputMode`         | `File_Input_Mode__c`        | `DISABLED`, `USER_SELECT`, or `ALL_ELIGIBLE`                           |
| `maxFiles`              | `Maximum_Files__c`          | Integer 1 through 5; null only when disabled                           |
| `requireAtLeastOneFile` | `Require_File__c`           | Blocks call when no eligible/selected file exists                      |
| `allowedFileFormats`    | `Allowed_File_Formats__c`   | Formats allowed by both the package and selected model                 |
| `providerProfileKey`    | `Provider_Profile_Key__c`   | Developer name of active Bedrock provider and model settings           |
| `citationsEnabled`      | `File_Citations_Enabled__c` | Requests document citations only when the selected model supports them |

The draft and published template-version objects both store these fields. Publication checks,
version comparison, duplication, rollback, health checks, field-access lists, Permission Sets, and
sample data include them.

### 3.4 Provider and model settings

An org-specific `Prompt_Context_Provider__mdt` Custom Metadata record stores approved
Bedrock settings:

- stable developer key;
- Bedrock region;
- exact model or inference-profile identifier;
- approved API, initially `Converse`;
- endpoint class, initially `bedrock-runtime`;
- document-input support;
- S3 document-source support;
- supported document formats;
- maximum document count, capped at five;
- maximum bytes per document, capped at 4,500,000;
- optional model-specific PDF page limit;
- citation support;
- active status;
- last verified date;
- source documentation version or review reference.

Credentials, AWS secrets, session tokens, temporary file URLs, bucket names that disclose system
details, and IAM policies are not stored in Custom Metadata. Salesforce uses Named Credentials and
AWS uses least-privilege IAM roles. Publication fails if the selected provider and model settings are inactive,
unverified, internally inconsistent, or broader than package limits.

### 3.5 Clear failure and all-or-none behavior

Any selected-file failure prevents the Bedrock call. The product returns no partial model
request and does not continue with fewer files. The response identifies the safe display name and
the corrective action when disclosure is authorized. Ordinary diagnostics use only stable reason
codes, counts, sizes, stages, and support IDs that contain no customer values.

At minimum, the stable reason-code catalog adds:

| Code                            | Meaning                                                                             |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| `FILES_NOT_ENABLED`             | Request supplied files for a template whose file mode is disabled                   |
| `FILE_REQUIRED`                 | Policy requires a file but none is eligible or selected                             |
| `TOO_MANY_FILES`                | Selected or automatically eligible count exceeds package, template, or provider cap |
| `FILE_TOO_LARGE`                | One selected version exceeds the effective byte cap                                 |
| `TOTAL_FILE_BYTES_EXCEEDED`     | Combined temporary file bytes exceed the package request cap                        |
| `UNSUPPORTED_FILE_TYPE`         | Extension/format is outside the package or active model intersection                |
| `FILE_TYPE_MISMATCH`            | Extension, MIME evidence, or content signature disagree                             |
| `FILE_NOT_LINKED_TO_RECORD`     | Selected file lacks a direct visible link to the current record                     |
| `FILE_NOT_ACCESSIBLE`           | Running user cannot read the selected link, document, version, or bytes             |
| `FILE_VERSION_STALE`            | Version identity, size, or checksum marker no longer matches confirmation           |
| `FILE_SECURITY_REJECTED`        | Malware, decompression, password, or content security validation rejected the file  |
| `FILE_SCAN_UNAVAILABLE`         | Required scanning could not produce an authoritative result                         |
| `MODEL_DOCUMENTS_UNSUPPORTED`   | Selected model cannot accept documents                                              |
| `MODEL_S3_SOURCE_UNSUPPORTED`   | Selected model cannot use the required temporary S3 document source                 |
| `MODEL_FILE_LIMIT_EXCEEDED`     | Selected model settings have a lower file-count limit                               |
| `MODEL_FILE_SIZE_EXCEEDED`      | Selected model settings have a lower file-size limit                                |
| `MODEL_PDF_PAGE_LIMIT_EXCEEDED` | Selected PDF exceeds the model-specific page limit                                  |
| `FILE_UPLOAD_FAILED`            | One or more exact versions could not be uploaded to temporary AWS storage           |
| `FILE_UPLOAD_EXPIRED`           | One-time upload permission or temporary S3 object expired                           |
| `BEDROCK_FILE_REQUEST_REJECTED` | Bedrock rejected the validated document request                                     |
| `FILE_CLEANUP_FAILED`           | Required immediate cleanup failed and compensating expiration remains pending       |

No code may convert these failures into an ordinary no-file prompt or retry without files.

### 3.6 Security and privacy

- `Prompt_Context_Generate` does not grant permission to send files outside Salesforce.
- A new `Prompt_Context_Send_Files` custom permission authorizes the file-bearing operation.
- The running user must have current record-record access and Salesforce Files access through ordinary
  Salesforce sharing and file visibility.
- Metadata and byte reads use explicit user-mode operations wherever Salesforce supports them and
  sharing-aware Apex everywhere.
- The UI shows that selected files leave Salesforce and names Amazon Bedrock/AWS as the destination
  before confirmation.
- File bytes are encrypted while moving and while stored in the approved AWS account.
- Temporary S3 objects use unpredictable keys, block public access, deny unencrypted transfer, and
  expire automatically within 60 minutes.
- Presigned URLs and temporary AWS credentials never appear in browser-visible responses, logs,
  Platform Events, diagnostics, or custom objects.
- File bytes, extracted text, and provider responses are absent from logs, metrics, Platform Events,
  exception messages, and persistent run records. Generated prompt text may persist only in the
  separately governed [Prompt Input Log](./14-prompt-input-log-and-delivery-options.md) when the caller
  explicitly selects `SAVE_TO_LOG`; it remains prohibited from operational metrics and file-run
  records.
- The AWS file service receives only the exact selected version grants, template/version identity, neutral
  document names, format, size, checksum marker, generated prompt, provider and model settings, and a
  support ID that contains no customer values.
- Document contents and filenames are untrusted model input. The generated prompt labels documents
  as data, but the product does not claim that labeling eliminates prompt injection.
- Salesforce filenames are shown to authorized users in the UI; Bedrock receives neutral names such
  as `Document 1 [A1B2C3]` that satisfy its name grammar.
- A deletion failure creates an operations alert. The S3 automatic deletion rule remains required.

### 3.7 How files move from Salesforce to Bedrock

The product does not assemble five large Base64 documents in one synchronous Apex transaction.
Queueable Apex uploads one exact file version per transaction:

1. Apex validates template, current record, permission, selected metadata, provider and model settings, and count before
   reading any file bytes.
2. Apex creates a short-lived file-run record containing IDs and status. It does not contain file
   contents or the prompt. A separately authorized Prompt Input Log can
   supply the exact prompt under specification 14 without copying it into file-run state.
3. An approved AWS file service returns one temporary S3 upload permission for each exact file version.
4. A Queueable chain processes one file per transaction, revalidates access and version identity,
   reads one `ContentVersion.VersionData`, and uploads the Blob without Base64 text conversion.
5. The AWS file service validates object size, checksum, signature/MIME, malware status, decompression risk,
   password protection, and model-specific page limits.
6. After every file reaches `READY`, the AWS file service creates one Bedrock user-role message containing the
   generated prompt text block and up to five S3-backed document blocks with neutral names.
7. The AWS file service calls the selected active model and returns the limited response to the
   initiating user surface.
8. The AWS file service deletes temporary S3 objects after success or failure. The S3 bucket's
   automatic deletion rule removes any remaining object within 60 minutes.
9. The file run retains only limited operational status until expiration. It does not retain prompt
   text, file bytes, extracted content, or provider response. An explicitly selected Prompt Input Log
   is a separate business record governed by specification 14.

The implementation must prove the maximum single-file heap and callout behavior in an approved org.
If 4,500,000 bytes cannot be transported with required safety margin, the package cap is lowered to the
largest proved safe value. The UI and provider and model settings expose the effective lower cap. The system
does not advertise the AWS maximum when the Salesforce file transfer cannot safely reach it.

### 3.8 File-run statuses

The file run uses these statuses:

```text
VALIDATING
  -> UPLOADING
  -> SCANNING
  -> READY
  -> INVOKING
  -> SUCCEEDED

Any unfinished status
  -> FAILED
  -> CLEANING
  -> CLEANED | CLEANUP_ATTENTION

VALIDATING or UPLOADING
  -> EXPIRED
  -> CLEANING
```

Retries are safe to repeat by run ID plus exact ContentVersion ID. A retry cannot create an additional
Bedrock call after a final provider receipt. User cancellation before `INVOKING` prevents
provider call and starts cleanup. Cancellation after provider acceptance cannot claim that the
provider did no work.

## 4. Red scenarios

These tests are written and run against the current implementation before production behavior is
added. Each failure must demonstrate the missing capability or missing guard, not invalid test case
setup. Red commands, assertions, and results are retained in the build record.

| ID       | Scenario                                                      | Required future result                                                                        |
| -------- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| FRED-001 | One readable PDF is directly linked to the Account            | User selects it; exact version is uploaded temporarily and one Bedrock document block is sent |
| FRED-002 | Five supported files are selected                             | All five are sent in one user-role message with the generated text block                      |
| FRED-003 | Six supported files are selected through a changed request    | Entire request fails `TOO_MANY_FILES`; no temporary upload or Bedrock call occurs             |
| FRED-004 | `ALL_ELIGIBLE` matches six linked files                       | The first files in deterministic order are selected up to the effective limit                 |
| FRED-005 | One selected file is 4,500,001 bytes                          | Entire request fails `FILE_TOO_LARGE` before byte transfer                                    |
| FRED-006 | Selected file format is PNG                                   | Entire request fails `UNSUPPORTED_FILE_TYPE`                                                  |
| FRED-007 | Selected file is linked to another record only                | Entire request fails `FILE_NOT_LINKED_TO_RECORD`                                              |
| FRED-008 | Running user sees the record but not the file                 | Entire request fails `FILE_NOT_ACCESSIBLE`; no elevated fallback occurs                       |
| FRED-009 | New file version is uploaded after user confirmation          | Exact selected version is used or request fails stale; newer version is never substituted     |
| FRED-010 | Selected version is deleted before temporary upload           | Entire request fails; any temporary copies of the other files are deleted                     |
| FRED-011 | Selected model does not support document input                | Publication or call fails `MODEL_DOCUMENTS_UNSUPPORTED`                                       |
| FRED-012 | Selected model does not support S3 document sources           | Publication or call fails `MODEL_S3_SOURCE_UNSUPPORTED`; Apex byte fallback is absent         |
| FRED-013 | Bedrock request contains document blocks without a text block | Bedrock request test fails; production builder always supplies generated prompt text          |
| FRED-014 | Bedrock request places files in an assistant-role message     | Bedrock request test fails; production builder uses user role                                 |
| FRED-015 | Salesforce filename contains model instructions               | UI shows authorized name; Bedrock receives a generated neutral name                           |
| FRED-016 | Required malware scan is unavailable                          | Entire request fails `FILE_SCAN_UNAVAILABLE`; no call occurs                                  |
| FRED-017 | One of five temporary S3 objects fails upload                 | No Bedrock call; successful sibling uploads are deleted                                       |
| FRED-018 | Temporary S3 objects remain after a successful call           | Immediate cleanup test fails; S3 automatic deletion is verified separately                    |
| FRED-019 | User lacks `Prompt_Context_Send_Files`                        | File metadata and sending files outside Salesforce operations fail `NOT_AUTHORIZED`           |
| FRED-020 | Template has file policy `DISABLED`                           | Text-only generation succeeds with the documented day-one response fields                     |

Minimum red test owners:

- `PromptContextFilePolicyTest`: FRED-003 through FRED-006, FRED-011 through FRED-014, FRED-019.
- `PromptContextFileSelectorTest`: FRED-001, FRED-002, FRED-007 through FRED-010, FRED-015.
- `PromptContextFileUploadTest`: FRED-005, FRED-008 through FRED-010, FRED-016 through FRED-018.
- `PromptContextBedrockRequestTest`: FRED-002, FRED-011 through FRED-015, FRED-017.
- `promptGenerator.test.js`: FRED-001 through FRED-006, FRED-009, FRED-015, FRED-019, FRED-020.

Red verification:

```bash
npm run test:unit -- --runInBand force-app/main/default/lwc/promptGenerator/__tests__/promptGenerator.test.js
sf apex run test --tests PromptContextFilePolicyTest,PromptContextFileSelectorTest,PromptContextFileUploadTest,PromptContextBedrockRequestTest --target-org <approved-purpose-org> --wait 30 --result-format human
```

Exit gate: every FRED scenario has a failing executable assertion and proves zero provider
invocations for locally detectable invalid requests.

## 5. Edge cases

| ID        | Scenario                                                              | Required outcome                                                                        |
| --------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| FEDGE-001 | Zero files selected and files are optional                            | Text-only execution succeeds                                                            |
| FEDGE-002 | Zero files selected and a file is required                            | `FILE_REQUIRED`; no call                                                                |
| FEDGE-003 | Exactly five files selected                                           | Accepted when every lower template/model limit also permits five                        |
| FEDGE-004 | Template maximum is three and user selects four                       | `TOO_MANY_FILES`; package cap of five does not override lower template cap              |
| FEDGE-005 | Model maximum is two and user selects three                           | `MODEL_FILE_LIMIT_EXCEEDED`                                                             |
| FEDGE-006 | File is exactly 4,500,000 bytes                                       | Accepted only after file transfer safety margin is proved                               |
| FEDGE-007 | File is zero bytes                                                    | Rejected as invalid content                                                             |
| FEDGE-008 | Five files total exactly 22,500,000 bytes                             | Accepted only when each file and file transfer limit pass                               |
| FEDGE-009 | Filename has emoji, control characters, repeated spaces, or 201 chars | UI safely renders it; neutral Bedrock name remains valid                                |
| FEDGE-010 | Two files have the same Salesforce title and extension                | ContentVersion identity keeps selections distinct                                       |
| FEDGE-011 | Same ContentDocument is linked twice through unexpected metadata      | Deduplicate by exact ContentDocument/Version identity                                   |
| FEDGE-012 | File is linked to current record and another record                   | Direct visible current record link is sufficient; no other record metadata is disclosed |
| FEDGE-013 | User confirms version 3 while version 4 becomes latest                | Version 3 remains pinned when still accessible and unchanged                            |
| FEDGE-014 | File is unlinked after confirmation but before byte read              | `FILE_NOT_LINKED_TO_RECORD`; no call                                                    |
| FEDGE-015 | File type uses uppercase or mixed-case extension                      | Normalize extension for comparison; preserve display name                               |
| FEDGE-016 | Extension is absent                                                   | Reject unless an explicitly supported, securely detected format rule is added           |
| FEDGE-017 | MIME says PDF but signature is not PDF                                | `FILE_TYPE_MISMATCH`                                                                    |
| FEDGE-018 | Valid PDF is password protected                                       | `FILE_SECURITY_REJECTED` unless later approved provider rules support it                |
| FEDGE-019 | PDF page count equals model-specific cap                              | Accepted                                                                                |
| FEDGE-020 | PDF exceeds model-specific cap by one page                            | `MODEL_PDF_PAGE_LIMIT_EXCEEDED`                                                         |
| FEDGE-021 | DOCX is internally a ZIP container                                    | Scanner applies decompression and nested-entry limits                                   |
| FEDGE-022 | TXT/MD/HTML declares an invalid character encoding                    | Reject it, or convert it only under approved fixed character-encoding rules             |
| FEDGE-023 | CSV contains formula-like cells                                       | Treated as document data; never executed by the product                                 |
| FEDGE-024 | File contents include prompt instructions                             | Contents remain untrusted data; no claim of full prompt-injection prevention            |
| FEDGE-025 | Salesforce filename changes after confirmation                        | Pinned version and neutral name preserve request identity; safe UI may show stale state |
| FEDGE-026 | File checksum repeats across two selected records                     | Do not reuse a temporary copy across records without proof for the same authorized user |
| FEDGE-027 | Citations requested but selected model does not support them          | Publication fails; the call does not disable citations without an error                 |
| FEDGE-028 | Bedrock returns citations using neutral document names                | UI maps them to authorized display names in memory without persisting the map           |
| FEDGE-029 | User cancels before the provider call                                 | Upload stops, cleanup runs, and no provider call occurs                                 |
| FEDGE-030 | User cancels after provider acceptance                                | UI reports cancellation timing honestly and starts cleanup                              |

Exit gate: every FEDGE test passes at the exact count, byte, page, identity, and expiration limits.
No test trusts a file based only on its name.

## 6. Misconfiguration scenarios

| ID       | Misconfiguration                                              | Required finding or behavior                                             |
| -------- | ------------------------------------------------------------- | ------------------------------------------------------------------------ |
| FMIS-001 | File mode is enabled without a provider and model settings    | Publication blocked with `MISSING_PROVIDER_PROFILE`                      |
| FMIS-002 | Provider and model settings is inactive or beyond review age  | Publication blocked with `PROVIDER_PROFILE_UNAVAILABLE`                  |
| FMIS-003 | Configured maximum is zero, negative, or above five           | Publication blocked with `INVALID_FILE_LIMIT`                            |
| FMIS-004 | Allowed format list is empty while a file is required         | Publication blocked                                                      |
| FMIS-005 | Allowed format is outside package support                     | Publication blocked with `UNSUPPORTED_FILE_TYPE`                         |
| FMIS-006 | Template permits a format that the selected model rejects     | Publication is blocked; allowed formats are not changed without an error |
| FMIS-007 | Provider and model settings claim a document count above five | Settings are invalid; package hard cap remains five                      |
| FMIS-008 | Provider and model settings claim bytes above 4,500,000       | Settings are invalid; package hard cap remains conservative              |
| FMIS-009 | Provider and model settings have no S3 source support         | Settings cannot be used by this file upload design                       |
| FMIS-010 | Citations enabled on unsupported model                        | Publication blocked                                                      |
| FMIS-011 | `DISABLED` policy retains old file settings                   | Normalization clears inactive settings before fingerprint/publication    |
| FMIS-012 | Request supplies ContentDocumentId without ContentVersionId   | Request rejected; exact version is mandatory                             |
| FMIS-013 | Request supplies version details not returned by picker       | Server reloads and rejects unauthorized or outdated details              |
| FMIS-014 | Selected file belongs to a different current record           | `FILE_NOT_LINKED_TO_RECORD`                                              |
| FMIS-015 | Request mixes current record IDs or template versions         | Stable request validation rejects it                                     |
| FMIS-016 | AWS file service bucket permits public access                 | Environment validation blocks activation                                 |
| FMIS-017 | Bucket lacks required encryption or automatic deletion        | Environment check blocks activation                                      |
| FMIS-018 | IAM role can read arbitrary Salesforce or S3 objects          | Security validation fails least-privilege gate                           |
| FMIS-019 | Named credential or endpoint is missing                       | Health check fails; prompt generation returns no result                  |
| FMIS-020 | Temporary file URL is returned to the browser                 | Security test fails                                                      |
| FMIS-021 | Provider service sends file bytes when S3 is required         | Bedrock request test fails; do not fall back to an unsafe Apex heap      |
| FMIS-022 | Document block uses the Salesforce filename                   | Bedrock request test fails; a neutral name is required                   |
| FMIS-023 | Document block is placed in a system or assistant message     | Bedrock request test fails                                               |
| FMIS-024 | Message with files lacks the generated text block             | Bedrock request test fails                                               |
| FMIS-025 | Template version has no file policy                           | Publication is invalid; `DISABLED` must be stored explicitly             |

Exit gate: each FMIS test case returns an exact stable code, safe location, and corrective action;
no configuration error triggers a file-byte read or provider call.

## 7. War scenarios

| ID       | Scenario                                                                     | Required outcome                                                                                            |
| -------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| FWAR-001 | Record has 10,000 linked files                                               | Picker remains limited; server does not scan or return the full collection                                  |
| FWAR-002 | `ALL_ELIGIBLE` encounters 500-plus eligible files                            | Inspects only the limited candidate set and selects deterministically up to the effective limit             |
| FWAR-003 | Five 4.5 MB files run near async heap/callout limits                         | One-file transactions stay within proved safety margin or package cap is lowered                            |
| FWAR-004 | ZIP-based Office document expands to extreme size                            | Scanner rejects decompression bomb before Bedrock call                                                      |
| FWAR-005 | File contains malware with a supported extension                             | `FILE_SECURITY_REJECTED`; every file uploaded for that request is removed                                   |
| FWAR-006 | Scanner times out after several files pass                                   | `FILE_SCAN_UNAVAILABLE`; no partial call                                                                    |
| FWAR-007 | File access is revoked between validation and byte read                      | Revalidation fails; no integration-user bypass                                                              |
| FWAR-008 | Current-record access is revoked during upload                               | Remaining work stops and cleanup begins                                                                     |
| FWAR-009 | Provider and model settings is deactivated during a run                      | Pre-call revalidation stops the run; accepted provider call is not duplicated                               |
| FWAR-010 | Bedrock throttles or times out                                               | Limited retry uses repeated request protection; final status gives a clear error and temporary files expire |
| FWAR-011 | Bedrock accepts request but callback is lost                                 | Saved receipt and request key prevent a second provider call                                                |
| FWAR-012 | Cleanup API fails after provider success                                     | Result reports cleanup attention; S3 automatic deletion still removes the objects                           |
| FWAR-013 | Callback is replayed, forged, or out of order                                | Signature, nonce, run state, and expiry validation reject it                                                |
| FWAR-014 | Presigned upload is reused for another object                                | One-time key, content length, checksum, and expiry constraints reject it                                    |
| FWAR-015 | Caller submits an S3 URI or external URL as a selected file                  | Apex request rejects it; AWS file service accepts only keys it issued                                       |
| FWAR-016 | Filename and document body both contain prompt injection                     | Neutral name and data labeling apply; output is still treated as untrusted model text                       |
| FWAR-017 | Restricted user tries to preview settings or send files outside Salesforce   | Separate permissions and user-mode reads deny access                                                        |
| FWAR-018 | Two users send the same record and files at the same time                    | File runs, permissions, S3 keys, results, and cleanup remain separate                                       |
| FWAR-019 | Deployment begins with active file runs                                      | Release runbook drains work first; any expired run is cleaned up                                            |
| FWAR-020 | Region/model no longer supports document input                               | Health check disables new runs; existing request fails explicitly before call                               |
| FWAR-021 | Metrics or logs receive test file text, bytes, filename, prompt, or response | Privacy test rejects the field and test-value scans find no disclosure                                      |
| FWAR-022 | S3 automatic deletion or block-public-access setting changes                 | Scheduled environment check blocks new file runs                                                            |
| FWAR-023 | Salesforce transaction rolls back after S3 upload                            | Compensating cleanup uses run identity and orphan monitor                                                   |
| FWAR-024 | User closes browser during file upload                                       | Server-side work continues or expires under the saved rule; no S3 object is left indefinitely               |
| FWAR-025 | Five files pass local rules but provider returns validation error            | `BEDROCK_FILE_REQUEST_REJECTED`; no text-only retry and full cleanup                                        |

Required pressure test cases cover one, five, and six files; zero bytes, exact byte cap, and cap plus
one; 1, 50, 500, and 10,000 linked-file metadata rows; concurrent users; revoked sharing; scanner,
AWS file service, S3, callback, and Bedrock failures; namespace-free and registered-namespace packages; and
all supported formats.

Exit gate: no FWAR scenario causes file loss without an error, a duplicate provider call, public access, a
cross-user data leak, an unlimited file-list query, an unhandled governor-limit exception, or saved
file or model content outside an authorized Prompt Input Log.

## 8. Everyday use cases

| ID       | Use case                                                       | Expected result                                                                    |
| -------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| FDAY-001 | User adds one PDF to an Account and selects it                 | Prompt and exact PDF version are submitted together                                |
| FDAY-002 | User adds a DOCX proposal and XLSX pricing sheet               | Both supported files appear in fixed picker order and can be selected              |
| FDAY-003 | User selects five attached documents                           | UI shows `5 of 5`; request succeeds when all lower limits pass                     |
| FDAY-004 | Record has six files and template uses `USER_SELECT`           | User chooses at most five; sixth selection is blocked with clear help              |
| FDAY-005 | Record has six eligible files and template uses `ALL_ELIGIBLE` | Request selects deterministically up to the effective limit                        |
| FDAY-006 | Optional file template runs on a record with no files          | Text-only result succeeds with no file transfer                                    |
| FDAY-007 | Required file template runs on a record with no files          | `FILE_REQUIRED` explains the corrective action                                     |
| FDAY-008 | User uploads a new version, refreshes picker, and confirms it  | New exact version is uploaded; old selection is not reused without confirmation    |
| FDAY-009 | Administrator limits template to PDF and DOCX                  | Picker labels other linked files as ineligible without exposing content            |
| FDAY-010 | User lacks access to one linked document                       | Inaccessible file is absent; forged selection fails without existence disclosure   |
| FDAY-011 | Bedrock response includes document citations                   | Authorized UI maps neutral citations to selected display names for that response   |
| FDAY-012 | User cancels while files are uploading                         | No provider call; cleanup status is visible                                        |
| FDAY-013 | File is too large                                              | UI and API report exact allowed maximum; file is not uploaded to AWS               |
| FDAY-014 | Sixth file is added after preview in `ALL_ELIGIBLE` mode       | Execution re-evaluates the ordered eligible set and keeps the effective limit      |
| FDAY-015 | Template has files disabled                                    | No file queries, file permissions, uploads, or provider settings affect generation |

Exit gate: every FDAY test case has independently authored expected UI state, selected exact version
IDs, provider request shape, stable status/reason code, call count, and cleanup result.

## 9. How file processing works

```text
Current record + published template version
  -> user-mode query for direct ContentDocumentLink and ContentVersion records
  -> return one page of eligible files
  -> user selection or ALL_ELIGIBLE rule
  -> confirm exact versions and ask before files leave Salesforce
  -> check permissions and count, size, format, provider, and model limits
  -> create short-lived file-run record
  -> Queueable Apex uploads one file per transaction
       recheck current record, direct link, version, access, and size
       upload Blob to one encrypted S3 key issued for that file
  -> AWS file service scans the file and checks model rules
  -> Bedrock user message
       generated prompt text block
       0..5 S3-backed document blocks with neutral names
  -> return provider response to the authorized page or caller
  -> delete temporary files; S3 rule removes anything left after 60 minutes
  -> save status and metrics without customer values
```

### 9.1 Required components

| Component                            | Responsibility                                                                  |
| ------------------------------------ | ------------------------------------------------------------------------------- |
| `PromptContextFilePolicy`            | Template policy, effective provider limits, formats, and publication validation |
| `PromptContextFileSelector`          | Limited direct-link summaries and exact-version authorization                   |
| `PromptContextFileRun`               | Status, expiration, cancellation, repeated request keys, and safe messages      |
| `PromptContextFileUploadQueueable`   | Recheck and upload one Salesforce File per transaction                          |
| `PromptContextAwsFileServiceClient`  | Named Credential calls without returning secrets or temporary URLs              |
| `PromptContextBedrockRequestBuilder` | User-role text plus neutral S3-backed document blocks                           |
| `PromptContextFileCleanup`           | Delete temporary files, retry deletion, and alert operations                    |
| `promptGenerator` file picker        | Eligibility, selection count, consent, progress, cancellation, and errors       |
| Provider settings health service     | Check model, region, API, and AWS security settings                             |

Final names may change only when the build record maps each responsibility to one clear code owner.
File selection, upload, provider request creation, provider call, cleanup, and prompt building remain
separate responsibilities.

### 9.2 File details returned to the browser

The browser receives metadata required for an informed selection and nothing from file bodies:

```text
contentDocumentId
contentVersionId
displayTitle
extension
contentSize
versionNumber
lastModifiedDate
eligibilityStatus
ineligibilityReasonCode
selectionToken
```

`selectionToken` is short-lived, integrity-protected, scoped to user, current record ID, template version,
exact file version, size, format, and expiry. The server still revalidates every claim; the token is
not a substitute for authorization.

## 10. Delivery stages and verifiable gates

Every stage follows the repository regression-first agreement. Add the focused test, prove the
expected red result on the broken implementation, implement the smallest complete behavior,
preserve the regression, run focused checks, and run the relevant gates. Salesforce/AWS commands
require identified approved environments. This specification does not authorize scratch-org,
bucket, IAM role, named credential, provider and model setting, or package creation.

### Stage 0: Confirm provider rules and approve files leaving Salesforce

Work:

1. Reverify every AWS source in section 2 and record date, reviewer, model, region, and API.
2. Approve Salesforce-to-AWS data flow, controller/processor ownership, retention, region, encryption,
   incident response, and acceptable file classifications.
3. Approve the AWS file service, bucket, KMS key, IAM role, Named Credential, scanner, callback, and
   cleanup design.
4. Fix package caps at or below the lowest proved Salesforce, AWS file service, Bedrock, and model limit.
5. Decide whether a page may show a provider response without saving it. Saving responses remains excluded.

Verification:

- Security review covers Salesforce sharing, files leaving Salesforce, temporary AWS storage,
  instructions hidden in files, malware, callbacks, provider retention, and cleanup.
- A data-flow diagram identifies every system and where encryption is required.
- Security owner signs the exact allowed formats and classifications.
- No infrastructure is provisioned before approval.

Exit gate: approved architecture/security decision record and current provider capability evidence.

### Stage 1: Agree on behavior and red tests

Work:

1. Add FRED-001 through FRED-020 before production changes.
2. Add FEDGE, FMIS, FWAR, and FDAY test cases or platform-only test definitions.
3. Add stable reason codes and versioned Apex request shapes.
4. Define every required day-one template and response field; do not add migration defaults.
5. Define test services that count uploads, scans, provider calls, and cleanup operations.

Verification:

- Every FRED test fails for its intended missing capability or guard.
- Day-one text-only Apex and LWC suites remain green.
- Scenario-owner validation proves every ID in this specification has an executable or environment
  verification owner.

Exit gate: red evidence, test-case inventory, behavior review, and no production behavior changes.

### Stage 2: Template file settings and provider settings

Work:

1. Add draft/version file-policy metadata and provider-and-model Custom Metadata.
2. Add permissions and a Custom Permission for sending files outside Salesforce.
3. Update Apex request mapping, validation, published-version checks, comparison, duplication,
   rollback, health checks, field-access lists, and safe error details.
4. Validate hard caps and package/model/template intersections.
5. Require every published version to store an explicit file policy.

Focused verification:

- FRED-003 through FRED-006, FRED-011 through FRED-014, FRED-019, FRED-020.
- FEDGE-001 through FEDGE-008 and FEDGE-027.
- FMIS-001 through FMIS-011 and FMIS-025.

Exit gate: no invalid or outdated provider and model settings can publish a file-enabled version;
text-only behavior matches the documented day-one result fields.

### Stage 3: Limited user-mode file discovery and selection

Work:

1. Query direct visible `ContentDocumentLink` records with ordered server-side paging. Read one extra
   record to show when another page is available.
2. Resolve current eligible `ContentVersion` summaries without querying VersionData.
3. Apply allowed formats and effective byte/count limits to eligibility.
4. Issue short-lived selection tokens scoped to user/current record/template/exact version.
5. Implement strict `USER_SELECT` limits and deterministic limited selection for `ALL_ELIGIBLE`.
6. Revalidate direct link, exact version, access, format, size, and token at confirmation.

Focused verification:

- FRED-001 through FRED-010, FRED-015, FRED-019.
- FEDGE-001 through FEDGE-017 and FEDGE-025.
- FMIS-012 through FMIS-015.
- FWAR-001, FWAR-002, FWAR-007, FWAR-008, FWAR-017, FWAR-018.

Exit gate: picker and server agree on exact eligible versions, six always fails when all six are
selected/required, and metadata discovery never reads file bytes.

### Stage 4: Accessible and explicit record-page experience

Work:

1. Add file-policy controls to the template builder with provider/count/size/format explanations.
2. Add a paginated generator picker with selected count, size, eligibility, refresh, and clear actions.
3. Show a confirmation that names Amazon Bedrock/AWS and lists the files that will leave Salesforce.
4. Disable the sixth selection while retaining a visible explanation; server remains authoritative.
5. Add progress stages, cancellation, outdated-version recovery, and clear final errors.
6. Ensure keyboard, screen reader, focus, responsive, localization, and reduced-motion behavior.

Focused verification:

```bash
npm run test:unit -- --runInBand force-app/main/default/lwc/promptGenerator/__tests__/promptGenerator.test.js
```

- FRED-001 through FRED-006, FRED-009, FRED-015, FRED-019, FRED-020.
- FDAY-001 through FDAY-015.
- Automated accessibility assertions and deployed wide/390-pixel browser journeys.

Exit gate: user can identify exactly what will leave Salesforce, cannot accidentally select six,
and receives one corrective error without an omitted file.

### Stage 5: Upload one file at a time

Work:

1. Implement the versioned status rules, expiry, cancellation, and repeated request protection.
2. Authorize the AWS file service through a Named Credential without returning temporary AWS access
   details to the browser.
3. Upload one exact `ContentVersion.VersionData` Blob per Queueable transaction without converting it
   to Base64 text.
4. Revalidate permission, current record link, version, size, and run state before each byte read.
5. Enforce content-length, checksum, one-time key, encryption, and expiry on every upload.
6. Prove heap and callout safety margin at limit sizes; lower the package cap when proof requires it.

Focused verification:

- FRED-005, FRED-007 through FRED-010, FRED-017, FRED-019.
- FEDGE-006 through FEDGE-018, FEDGE-025, FEDGE-026, FEDGE-029, FEDGE-030.
- FMIS-016 through FMIS-021.
- FWAR-003, FWAR-007, FWAR-008, FWAR-013 through FWAR-015, FWAR-018, FWAR-023, FWAR-024.

Exit gate: approved-org evidence proves the safe maximum file size, access to the exact version,
one-file transaction limits, safe repeated uploads, and no exposed credentials or temporary URLs.

### Stage 6: Scanning and model-specific validation

Work:

1. Validate extension, MIME evidence, signature, content length, and checksum.
2. Scan malware and enforce decompression/nested-entry limits for Office containers.
3. Detect password-protected/corrupt documents and supported text encodings.
4. Count PDF pages when the selected model settings include a limit.
5. Require authoritative scan completion for every file before `READY`.
6. Delete every temporary sibling file after a rejection or unavailable scan.

Focused verification:

- FRED-006, FRED-016 through FRED-018.
- FEDGE-016 through FEDGE-024.
- FWAR-004 through FWAR-006.
- Scanner vendor test corpus with clean, malicious, corrupt, encrypted, and decompression-bomb files.

Exit gate: no unscanned, mismatched, corrupt, password-protected, malicious, or model-oversize file
can reach Bedrock.

### Stage 7: Bedrock request construction and call

Work:

1. Construct one `user` message with the generated prompt as a text block.
2. Add zero through five document blocks using exact temporary S3 locations, supported formats, neutral
   names, optional context, and validated citation settings.
3. Validate the selected provider and model settings again immediately before the call.
4. Set provider timeouts and attempt limits. Save the request key and provider receipt to prevent a
   second call for accepted work.
5. Reject provider validation errors without retrying as text-only or a smaller file set.
6. Return the response and citation mapping to the authorized page or caller without saving it.

Focused verification:

- FRED-001 through FRED-005, FRED-011 through FRED-015, FRED-017.
- FEDGE-003 through FEDGE-005, FEDGE-019, FEDGE-020, FEDGE-027, FEDGE-028.
- FMIS-021 through FMIS-024.
- FWAR-009 through FWAR-011, FWAR-016, FWAR-020, FWAR-025.

Exit gate: captured provider requests contain one text block, no more than five documents, user role,
neutral names, exact supported formats, approved S3 locations, and one call per run.

### Stage 8: Cleanup, operations, and disclosure-safe evidence

Work:

1. Delete temporary S3 objects immediately after every final path.
2. Retry cleanup independently and surface `CLEANUP_ATTENTION` without exposing file data.
3. Test S3 automatic deletion, encryption, block-public-access, and checks for files left behind.
4. Store/publish only run ID, stage, stable reason, counts, total bytes, timing, template/version ID,
   provider-and-model settings key, and cleanup state.
5. Add scheduled provider/infrastructure health checks that read no customer file content.
6. Add test-value scans for bytes, extracted text, filenames, prompts, responses, secrets, and URLs.

Focused verification:

- FRED-017 and FRED-018.
- FEDGE-029 and FEDGE-030.
- FMIS-016 through FMIS-020.
- FWAR-010 through FWAR-014 and FWAR-020 through FWAR-024.

Exit gate: every temporary S3 object is deleted or covered by a verified 60-minute automatic deletion
rule. Alerts identify cleanup work without containing customer content or secrets.

### Stage 9: Full security, platform, package, and documentation verification

Work:

1. Update supported behavior, administrator guide, exact reference, data flow, security,
   permissions, limits, reason codes, operations, privacy, FAQs, developer API, and navigation.
2. Verify full-access and restricted users, file visibility variants, sharing changes, namespace-free
   and registered-namespace packages, and clean installation.
3. Verify all nine formats against the exact approved Bedrock model and region.
4. Verify one/five/six files and size/page limits in approved Salesforce and AWS environments.
5. Run static analysis, dependency/security scans, local gates, org tests, browser journeys, AWS file service
   integration tests, AWS policy checks, and cleanup evidence.

Final commands include:

```bash
npm run test:unit:coverage
npm run ci:gates
sf apex run test --test-level RunLocalTests --target-org <approved-purpose-org> --wait 60 --result-format human
```

External verification must record the approved environment, Salesforce org alias/purpose, AWS
account class, region, model identifier or inference-profile identifier, API, test time, run IDs, request counts, temporary
object counts, cleanup results, and redacted provider outcomes.

Exit gate: every FRED, FEDGE, FMIS, FWAR, and FDAY scenario has evidence; local CI passes; required
Salesforce, AWS, browser, namespace, and clean package-install evidence passes. Until then, the
feature remains proposed or partially verified and is never described as deployed.

## 11. Traceability requirements

The implementation build record contains one row per scenario and stage exit gate. Each row records:

- test class, AWS file service test, policy assertion, or browser journey owner;
- current record/file test case identities using noncustomer test data;
- expected and observed upload, scanning, Bedrock-call, and cleanup counts;
- red result for regression-first work;
- green local result;
- approved Salesforce/AWS environment result;
- namespace/package/clean-install result when applicable;
- final code owner, reason code, and file-run format version; and
- outcome: delivered, deferred, or rejected with rationale.

Count, byte, page, heap, callout, timeout, retry, and cleanup claims require measured evidence.
Security requires restricted-user, direct-link, revoked-access, forged-request, public-access, and
test-value test cases. Source review alone is not verification.

## 12. Completion definition

This increment is complete only when:

1. Files come only from direct visible Salesforce File links on the current record.
2. The exact confirmed ContentVersion is pinned and revalidated; another version is never substituted.
3. Six selected or automatically eligible files fail with `TOO_MANY_FILES` before upload or provider call.
4. No file exceeds the effective package, template, file transfer, model, or provider limit.
5. Only approved formats reach temporary AWS storage and every temporary file passes the required security and model
   validation.
6. Bedrock receives one user-role message with the generated text block and no more than five neutral,
   S3-backed document blocks.
7. A single file failure prevents the entire provider request; there is no smaller-set or text-only
   fallback.
8. Sending files outside Salesforce requires a separate Custom Permission, visible confirmation,
   user-mode access checks, and active reviewed provider and model settings.
9. File contents, extracted text, provider responses, secrets, and temporary file URLs do not enter saved
   operational records or error details. Prompt text and authorized file names may be saved only
   in an explicitly requested, permission-controlled Prompt Input Log under specification 14.
10. Temporary S3 objects are deleted after every final status. A verified S3 rule deletes anything
    left after 60 minutes.
11. Text-only templates follow the documented day-one generation behavior.
12. All scenario IDs and stage gates have recorded evidence, `npm run ci:gates` passes, and required
    Salesforce/AWS/package validation has passed against identified approved environments.
