# Feature catalog

| Capability         | Public behavior                                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------- |
| Template lifecycle | Draft, preview, publish, edit while live, deactivate, compare versions, and restore editable settings |
| Current record     | Fields on the current record and its related parent records                                           |
| Related data       | Separate related or reference data sets with selected fields, filters, sorting, and record limits     |
| Calculated values  | Count, sum, average, minimum, and maximum values                                                      |
| Merge language     | Current record fields, indexed records, counts, `each`, `if`, `else`, fallback text, and formatting   |
| Record-page UI     | Generate, review, edit, prefix, suffix, copy, and reset                                               |
| Automation         | One ordered, partial-failure preparation contract for Flow and Apex                                   |
| Salesforce Files   | Page through eligible Files, select up to five exact versions, and save their details                 |
| Prepared input     | Return prompt text and file details to Apex or save one private Prompt Input Log with a Request Key   |
| Version controls   | Fixed versions, version signatures, comparisons, and scheduled setup checks                           |
| Security           | Custom Permission checks and access-aware Salesforce record searches                                  |
| Troubleshooting    | Stable reason codes, request IDs, and privacy-safe Platform Event measurements                        |

## Intentional exclusions

Version 1 does not send data to an external provider, accept administrator-written Salesforce
queries (SOQL), run administrator-written code, modify customer records, read file bodies, call
Amazon Bedrock, or preserve conversations. File selection stores references to exact Salesforce
File versions; it does not store or move the file contents. An approved later process can use a
Prompt Input Log, while Batch or Queueable Apex can choose Return to Apex and own its next step.
