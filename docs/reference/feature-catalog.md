# Feature catalog

| Capability         | Public behavior                                                                                     |
| ------------------ | --------------------------------------------------------------------------------------------------- |
| Template lifecycle | Draft, preview, publish, deactivate, compare versions, and restore a version to a new Draft         |
| Current record     | Fields on the current record and its related parent records                                         |
| Related data       | Separate related or reference data sets with selected fields, filters, sorting, and record limits   |
| Calculated values  | Count, sum, average, minimum, and maximum values                                                    |
| Merge language     | Current record fields, indexed records, counts, `each`, `if`, `else`, fallback text, and formatting |
| Record-page UI     | Generate, review, edit, prefix, suffix, copy, and reset                                             |
| Automation         | One ordered, partial-failure contract for Flow and Apex                                             |
| Version controls   | Fixed versions, version signatures, comparisons, and scheduled setup checks                         |
| Security           | Custom Permission checks and access-aware Salesforce record searches                                |
| Troubleshooting    | Stable reason codes, request IDs, and privacy-safe Platform Event measurements                      |

## Intentional exclusions

Version 1 does not call a model, accept administrator-written Salesforce queries (SOQL), run
administrator-written code, write customer
records, save generated prompts, read files or attachments, or preserve conversations.
