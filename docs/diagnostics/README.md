# Troubleshoot prompt generation

Use this guide when the record-page component, Flow action, or Apex API cannot build the expected
prompt. Diagnostics identify the request and result without revealing prompt content, record
values, generated searches, or filter values.

## Capture safe evidence

Record these values from the failed response or the calling automation:

- `reasonCode`
- `message`
- request ID (`correlationId`)
- template automation key and published version
- channel: record page, Flow, or Apex
- whether the failure affects one record or every record

Do not copy Salesforce session IDs, access tokens, full customer records, prompt text, debug logs
containing customer values, or generated query details into an issue.

## Diagnose in order

1. Confirm the template is **Published**, is healthy, and matches the record's object.
2. Confirm the runner has the **Prompt Context Generate** Permission Set.
3. Verify the person can read the current record and every object and field in the template's
   required field access list.
4. Compare `reasonCode` with the [reason-code reference](../reference/reason-codes.md).
5. Preview the same published settings with an equivalent user in a sandbox before changing
   production settings.
6. If Salesforce fields or template settings changed, restore the earlier published version to a
   Draft, correct it, preview it, and publish a new fixed version.

An access failure must remain a failure. Do not remove a required field merely to turn inaccessible
data into blank output unless the business requirement also changed.

## Diagnostic permission

The **Prompt Context Configure** Permission Set includes the **Prompt Context Diagnostics** Custom
Permission. When present, Flow and Apex responses can include `diagnosticSummary`, capped at 200
characters. It contains contract version, syntax version, stable outcome code, and template version
when available. Generation permission alone does not expose it.

## Operational events

`Prompt_Context_Metric__e` publishes operation details without customer values for accepted
requests. The event contains the entry point, result code, duration, template identity and version,
and request ID.
Platform Events are messages and do not provide permanent history. A Flow, Apex trigger, or
integration must subscribe if the organization needs retained operational records.

Metric publication is best effort and never changes prompt success. Absence of an event therefore
does not prove that generation did not run.

For ongoing monitoring, see [Production operations](../production-operations/README.md).
