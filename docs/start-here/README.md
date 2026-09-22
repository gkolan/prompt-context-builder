# Start with Prompt Context Builder

Use Prompt Context Builder when a Salesforce user needs a repeatable block of record context that
they can review and copy into an AI tool or another process. The product retrieves only configured
Salesforce data and returns plain text; it does not send that text to a model.

## What an administrator configures

A template has one Salesforce object, a template body, and up to ten related data sets. Each data
set can include:

- **Records related to the current record:** match a field on another object to a field on the
  current record.
- **A reference list:** include a limited set of records without matching the current record.
- **Selected records:** include the fields you choose from each record.
- **One calculated value:** include a count, sum, average, minimum, or maximum.

Administrators choose fields, filters, sorting, and limits in Prompt Builder. The builder creates
the Salesforce searches from those choices.

## Lifecycle

1. Create or edit a Draft template.
2. Validate its prompt text, Salesforce fields, required access, order, and limits.
3. Preview it against a real record with the current user's access.
4. Publish a fixed version that cannot be edited.
5. Generate context from a record page, Flow, or Apex.
6. Deactivate a template when it must no longer run.

## Choose the next guide

- Administrator: [Create and publish a template](../step-by-step-guide/README.md).
- Record-page owner: [Configure Prompt Generator](../lightning-record-page/README.md).
- Flow or Apex developer: [Developer guides](../developer-guides/README.md).
- Security reviewer: [Security and data access](../architecture/security-and-data-access.md).
- Operator: [Production operations](../production-operations/README.md).
