# Security and data access

The completed prompt can contain only Salesforce data readable by the person or automation running
the request.

## Authorization and data access are separate

Custom Permissions allow prompt generation, configuration, and detailed troubleshooting. They do
not grant customer-record access. Salesforce record reads use the running user's access and
sharing-aware Apex, so object access, field access, sharing, restriction rules, and scoping rules
remain effective.

Saving prepared input is a separate authorization boundary. It requires Prompt Context Save Input,
uses user-mode DML, and writes to a private Prompt Input Log. A missing permission fails the request;
it is never treated as an ordinary blank value.

Three narrow package-owned operations use system mode without reading customer records:

- Publication creates immutable version snapshots after configuration authorization and validation.
- One lifecycle writer sets a template's status, published version, version signature, draft
  revision, and health fields. No Permission Set lets a person edit those fields, so an author cannot
  republish an inactive template, switch to an older version, or mark a template Healthy from the
  standard record page. Before writing, the writer runs a user-mode update with no field changes on
  the same rows, which succeeds only when the person can edit that template.
- An idempotent save may recover an exact user-scoped request-key collision after user-mode insert
  fails. The collision path reads only the log Id, hashed request key, and verification digest, and
  returns a match only after the digest agrees.

None of these exceptions can widen prompt data access. The publish, save, deactivate, and lifecycle
services authorize Prompt Context Configure themselves before any system-mode write, so a caller
cannot reach them by bypassing the Lightning controller. `npm run check:apex-surface` pins every
exception by class and count. It also rejects any other `without sharing` class, production
`Test.isRunningTest()` branch, query or DML without an explicit access mode, and entry class that
does not call `PromptContextAccess`. `npm run check:permissions` rejects any Permission Set that
grants edit access to a lifecycle field or Delete on Prompt Template. Both gates are source scans.
They do not replace Apex tests or security review.

Generation reads only a template's header (name, automation key, status, and version number) and
its fixed published version. People with only Prompt Context Generate cannot read unpublished draft
text or draft data sets.

Access failures stop the request without a partial prompt. People without the Prompt Context
Diagnostics permission see only the generic access message, so a failure never tells them which
object or field is hidden. Troubleshooting users see the exact name.

Formula fields are checked more strictly than Salesforce checks them. Under syntax version 2, every
field a formula uses must be readable by the running person, so a formula cannot reveal a hidden
value. See [Formula fields](../reference/merge-syntax.md#formula-fields).

Selecting Salesforce Files is another separate boundary. It requires Prompt Context Send Files.
File discovery and confirmation read only versions the running user can access and require a direct
`ContentDocumentLink` to the current record. The selected list pins exact version IDs, order, format,
size, version number, and last-modified time. It never stores file contents.

## Saved prompt text is a copy

A Prompt Input Log stores the prepared prompt as plain text. That text keeps the record values the
saving user could read when it was prepared; it is not checked again against the source record's
sharing or field access. Anyone who can read the log can read those values, including users above
the owner in the role hierarchy and users with View All on the object. Review **Grant Access Using
Hierarchies** for Prompt Input Log in Sharing Settings, share logs with a separate worker user only
through an explicit sharing rule, and schedule the purge job described in
[Production operations](../production-operations/README.md).

The log's Input Verification Value is a checksum of the stored input. It catches accidental edits;
someone who can edit both the text and the checksum can change them together.

## Record text can contain instructions

Field values reach the model exactly as people wrote them. A Case description or email body can
include text aimed at the model, such as "ignore the instructions above." Merge syntax inside a
value is never run, but the model still reads the words. Keep your own instructions first, place
customer-written fields inside clearly labeled delimiters, and tell the model to treat that section
as data. Validation warns with `SENSITIVE_FIELD_REVIEW` when a template prints a long text field.
See [Build prompt templates](../build-templates/README.md#keep-customer-text-separate-from-instructions).

## Safe Salesforce searches

- Objects, fields, and relationships must exist in Salesforce and be available to the running user.
- Filter values keep their Salesforce field types.
- Filter rules, sorting choices, blank placement, and calculations come from fixed choices.
- The current-record match is always required alongside optional filter groups.
- Administrators never write Salesforce queries (SOQL).
- Each data set and the complete request have firm record and character limits.
- Field-value matching can use a field such as Industry without a Salesforce lookup relationship.
  The current-record field and source field must have compatible Salesforce data types.

## Stop safely when access is missing

A readable blank value can remain blank or use configured fallback text. A required field that is unavailable
or no longer exists is different: generation stops. Errors, measurements, and troubleshooting
details exclude customer values and prompt content. Completed text is never treated as a new field
instruction or active HTML.

## Template sharing

Internal users with Prompt Context Configure can edit any template: internal sharing is Public
Read/Write. External sharing is Private, so Experience Cloud users see a template only when a
sharing rule or manual share grants it, and the record-page component offers them nothing else.

## Files and external delivery

The package fails the complete request when file permission, direct-link access, a user selection,
size, format, or approved service settings do not pass. A user-selected request never silently drops
files. **Include all eligible Files** deterministically selects the first eligible current versions
up to the effective template/provider limit.

The current source does not read file bodies, upload to AWS, or call Amazon Bedrock. Before an
organization adds that later process, its security owner must approve the AWS account, region,
encryption, scanning, retention, cleanup, model, Named Credential, and allowed file classifications.

## Reference data warning

A Reference data set intentionally omits the current-record match and can return any matching
records visible to the running user. Use it only for limited shared data such as policy text or
product guidance. Sharing, object access, field access, sorting, and record limits still apply.

## Security verification

Test at least current-record denial, current-record field denial, data set object denial, data set
field denial, filter and sorting field denial, sharing-limited records, a Record Id for the wrong
object, text that resembles a Salesforce query, and output-limit failure. Each denial must return
no partial prompt.
