# Security and data access

The completed prompt can contain only Salesforce data readable by the person or automation running
the request.

## Authorization and data access are separate

Custom Permissions allow prompt generation, configuration, and detailed troubleshooting. They do
not grant customer-record access. Salesforce record reads use the running user's access and
sharing-aware Apex, so object access, field access, sharing, restriction rules, and scoping rules
remain effective.

## Safe Salesforce searches

- Objects, fields, and relationships must exist in Salesforce and be available to the running user.
- Filter values keep their Salesforce field types.
- Filter rules, sorting choices, blank placement, and calculations come from fixed choices.
- The current-record match is always required alongside optional filter groups.
- Administrators never write Salesforce queries (SOQL).
- Each data set and the complete request have firm record and character limits.

## Stop safely when access is missing

A readable blank value can remain blank or use fallback text. A required field that is unavailable
or no longer exists is different: generation stops. Errors, measurements, and troubleshooting
details exclude customer values and prompt content. Completed text is never treated as a new field
instruction or active HTML.

## Reference data warning

A Reference data set intentionally omits the current-record match and can return any matching
records visible to the running user. Use it only for limited shared data such as policy text or
product guidance. Sharing, object access, field access, sorting, and record limits still apply.

## Security verification

Test at least current-record denial, current-record field denial, data set object denial, data set
field denial, filter and sorting field denial, sharing-limited records, a Record Id for the wrong
object, text that resembles a Salesforce query, and output-limit failure. Each denial must return
no partial prompt.
