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

Two narrow package-owned operations use system mode without reading customer records: publication
creates immutable version snapshots after configuration authorization and validation, and an
idempotent save may recover an exact user-scoped request-key collision after user-mode insert fails.
The collision path reads only the log Id, hashed request key, and verification digest, and returns a
match only after the digest agrees. Neither exception can widen prompt data access.

Selecting Salesforce Files is another separate boundary. It requires Prompt Context Send Files.
File discovery and confirmation read only versions the running user can access and require a direct
`ContentDocumentLink` to the current record. The selected list pins exact version IDs, order, format,
size, version number, and last-modified time. It never stores file contents.

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

## Files and external delivery

The package fails the complete request when file permission, direct-link access, a user selection,
size, format, or approved service settings do not pass. A user-selected request never silently drops
files. **All eligible** deterministically selects the first eligible current versions up to the
effective template/provider limit.

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
