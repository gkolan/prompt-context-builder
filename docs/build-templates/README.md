# Build prompt templates

Use Prompt Builder to choose a limited amount of Salesforce data for plain-text prompts. Start with the
[complete first-template walkthrough](../step-by-step-guide/README.md), then use this page to choose
the right related-data design.

## Choose a data set

| Requirement                                   | Records to include | Result type          |
| --------------------------------------------- | ------------------ | -------------------- |
| Contacts for the current Account              | Related            | Records              |
| Visible policy records shared across Accounts | Reference          | Records              |
| Count of open Cases for the current Account   | Related            | One calculated value |
| Maximum visible product discount              | Reference          | One calculated value |

Related data sets require a **Current record field** and **Related record match field**. Reference
data sets omit that match and can include any matching records the person can access.

## Configure record results

1. Enter a unique **Reference name**. The template uses this name when you insert the data.
2. Choose the Salesforce object and the fields the prompt can use.
3. For related records, choose current-record and related-record fields that hold the same kind of
   value.
4. Add filters that match the selected field types. Conditions inside one named group use `AND`;
   choose `AND` or `OR` between
   groups.
5. Add up to three business sort fields. Salesforce uses `Id` last when records otherwise have the
   same order.
6. Start with 10 maximum records and increase the number only when the prompt needs more.
7. Insert a field, count, repeat block, or conditional block into the template body.

The result count is the number of records the person can access within the chosen limit. It is not
a count of every record in the Salesforce org.

## Configure one calculated value

Choose **One calculated value**, then select `COUNT`, `SUM`, `AVG`, `MIN`, or `MAX`. `COUNT` does not
use a calculation field. The other calculations require a field that supports that calculation and
that the person can access. Calculated data sets do not use selected output fields, sorting,
positions, or repeat blocks.

Insert the result as `{!aggregate.reference_name.value}`.

## Validate before publishing

Validation checks the inserted fields and blocks, Salesforce fields, matching fields, filter rules,
sorting, record order, limits, and required field access. Preview then builds the Draft with a real
record and the current person's access. Publishing requires a successful preview and creates a
fixed version that cannot be edited.

See [Merge syntax](../reference/merge-syntax.md), [Limits](../reference/limits.md), and
[Security and data access](../architecture/security-and-data-access.md).
