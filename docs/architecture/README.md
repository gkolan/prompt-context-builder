# Architecture

Prompt Context Builder keeps editable Draft settings separate from fixed published versions. The
record page, Flow action, and Apex API all use the same access checks, setup checks, Salesforce
record reads, and text-building service.

```text
Prompt Builder → Draft template and data sets → Preview → Published version
                                                          ↓
Record page / Flow / Apex → permission check → setup and capacity checks
                                                          ↓
                         read allowed Salesforce records → build plain text
```

## Generation steps

1. Confirm that the person or automation can generate prompts.
2. Find the exact published template.
3. Confirm that the Record Id belongs to the template's Salesforce object.
4. Check the prompt's field inserts and saved Salesforce fields.
5. List the required fields and calculate safe record limits.
6. Read the current record and each data set with the running user's Salesforce access.
7. Hold one fixed set of data for this request.
8. Build the text without reading more records.
9. Apply prompt and response limits.
10. Return the complete prompt with any record-limit warnings, or return no prompt when a required
    step fails.

See [Data model](./data-model.md), [Security and data access](./security-and-data-access.md), and the
[Flow and Apex contract](../developer-guides/README.md).
