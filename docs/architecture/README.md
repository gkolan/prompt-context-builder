# Architecture

Prompt Context Builder keeps editable settings separate from fixed published versions. A new
template starts as Draft. After publication, saving editable changes leaves the template Published,
so generation continues to use the latest fixed version. The record page, Flow action, and Apex API
all use the same access checks, setup checks, Salesforce record reads, and text-building service.

```text
Prompt Builder → editable template and data sets → Preview → Published version
                                                             ↓
Record page / Flow / Apex → permission check → setup and capacity checks
                                                          ↓
             read allowed Salesforce records and selected file details
                                                          ↓
               build plain text → return it or save one private input log
```

## Generation steps

1. Confirm that the person or automation can generate prompts.
2. Find the exact published template.
3. Confirm that the Record Id belongs to the template's Salesforce object.
4. Check the prompt's field inserts and saved Salesforce fields.
5. List the required fields and calculate safe record limits.
6. Read the current record and each data set with grouped, access-aware Salesforce queries.
7. When files are enabled, confirm the separate permission and resolve only exact current versions
   linked directly to the record.
8. Apply the published file count, format, byte, and approved-service limits as one complete check.
9. Hold one fixed set of record data and file details for this request.
10. Build the text without reading more customer records.
11. Apply prompt and response limits.
12. Apply the caller's delivery choice: return the complete input or save one private Prompt Input
    Log. Return no prompt when preparation or the requested save fails.

Prompt Context Builder does not read `ContentVersion.VersionData` or call Amazon Bedrock. Those are
separate delivery responsibilities that require an approved AWS design and organization setup.

See [Data model](./data-model.md), [Security and data access](./security-and-data-access.md), and the
[Flow and Apex contract](../developer-guides/README.md).
