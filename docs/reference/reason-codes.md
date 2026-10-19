# Result reason codes and warnings

Every Flow and Apex response has `success`, `reasonCode`, and a safe message. A failed item has no
prompt. Neighboring valid items can still succeed. A successful limited result keeps
`reasonCode = SUCCESS` and reports non-blocking conditions separately in `warningCodes` and
`warningMessage`.

## Response reason codes

| Code                          | Meaning                                                          | Caller action                                                           |
| ----------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `SUCCESS`                     | Prompt built                                                     | Use or save the returned prompt according to your process               |
| `INVALID_REQUEST`             | Template identity or Record Id is missing or invalid             | Correct the request                                                     |
| `INVALID_DELIVERY_CHOICE`     | Delivery Choice is missing or unsupported                        | Select `RETURN_TO_APEX` or `SAVE_TO_LOG`                                |
| `NOT_AUTHORIZED`              | Caller cannot generate prompts                                   | Assign the generation Permission Set to the intended user or automation |
| `REQUEST_KEY_REQUIRED`        | A save request has no Request Key                                | Supply a stable key for the unit of work                                |
| `REQUEST_KEY_CONFLICT`        | The same key was reused for different prepared input             | Stop the retry and investigate the caller's key choice                  |
| `INPUT_LOG_SAVE_FAILED`       | The prepared input could not be saved                            | Keep the request ID and ask an administrator to investigate             |
| `INPUT_LOG_STATE_CHANGED`     | Another action changed the saved input state                     | Reload the record before deciding the next action                       |
| `INPUT_VERIFICATION_FAILED`   | Stored input no longer matches its verification value            | Stop processing and investigate the record change                       |
| `DELIVERY_OUTCOME_UNCERTAIN`  | A later service may have accepted the request                    | Do not retry automatically                                              |
| `DELIVERY_RETRY_LIMIT`        | Saved input reached three processing attempts                    | Investigate before creating new work                                    |
| `FILES_NOT_ENABLED`           | File IDs were supplied to a template with files disabled         | Remove the IDs or publish a file-enabled template                       |
| `FILE_REQUIRED`               | The template requires at least one eligible file                 | Link or select an allowed Salesforce File                               |
| `INVALID_FILE_SELECTION`      | Stored file details are malformed or contain an unapproved key   | Recreate the prepared input through the public entry                    |
| `TOO_MANY_FILES`              | User selection exceeds the effective limit, never more than five | Select fewer files                                                      |
| `TOO_MANY_LINKED_FILES`       | More than 500 linked files would need inspection                 | Narrow the record's linked-file collection                              |
| `FILE_TOO_LARGE`              | One selected version exceeds the effective byte limit            | Use a smaller file                                                      |
| `TOTAL_FILE_BYTES_EXCEEDED`   | Selected versions exceed 22,500,000 bytes together               | Reduce file count or size                                               |
| `UNSUPPORTED_FILE_TYPE`       | A selected file format is not in the approved intersection       | Select an allowed format                                                |
| `FILE_NOT_LINKED_TO_RECORD`   | An exact version lacks a visible direct link to the record       | Link the file directly or select another file                           |
| `FILE_VERSION_STALE`          | Exact saved version details no longer match                      | Refresh and prepare the input again                                     |
| `FILE_SECURITY_REJECTED`      | File metadata fails a required safety rule                       | Replace the file                                                        |
| `TEMPLATE_NOT_FOUND`          | Template identity did not resolve                                | Check the Id or stable automation key                                   |
| `TEMPLATE_NOT_PUBLISHED`      | Template is not available for prompt generation                  | Publish an approved Draft                                               |
| `TEMPLATE_VERSION_AMBIGUOUS`  | More than one version matched an identity                        | Correct the stored configuration                                        |
| `INVALID_CONFIGURATION`       | Prompt text, Salesforce setup, or data set settings are invalid  | Validate and republish the template                                     |
| `RECORD_NOT_ACCESSIBLE`       | Current record is absent, mismatched, or not visible             | Check the Record Id and sharing                                         |
| `OBJECT_NOT_ACCESSIBLE`       | A required object is not readable                                | Grant intended object access or remove the source                       |
| `FIELD_NOT_ACCESSIBLE`        | A required field, or a field a formula uses, is not readable     | Grant intended field access or remove the field                         |
| `INVALID_MATCH_VALUE`         | A current-record value cannot use the source match field type    | Choose compatible Salesforce fields or correct the record value         |
| `MISSING_CURRENCY_BOUNDARY`   | A multi-currency calculation lacks one required ISO code         | Add a required Currency ISO Code equals rule                            |
| `TRANSACTION_BUDGET_EXCEEDED` | Available Salesforce processing capacity is insufficient         | Reduce scope or use Batch Apex                                          |
| `FLOW_GROUP_LIMIT_EXCEEDED`   | More than ten templates were requested                           | Group the transaction by template                                       |
| `FLOW_PAYLOAD_LIMIT_EXCEEDED` | Successful prompts exceed the response budget                    | Reduce scope or use Batch Apex                                          |
| `PROMPT_TOO_LONG`             | Completed prompt exceeds 20,000 characters                       | Reduce template or data set size, or add `maxLength` to long fields     |
| `DRAFT_CHANGED`               | Someone saved the draft after the editor loaded it               | Reload the template, then reapply the edits                             |
| `FORMULA_INPUT_NOT_VERIFIED`  | A formula field's inputs cannot be checked for access            | Use one-type relationships or a stored field                            |
| `UNEXPECTED_ERROR`            | An unexpected failure occurred                                   | Keep the request ID and ask an administrator to investigate             |

## Successful prompt warning codes

Warnings do not make the response fail and do not remove the prompt. Multiple codes are returned
as a comma-separated `warningCodes` value; their safe explanations are combined in
`warningMessage`.

| Code               | Meaning                                                                | Caller action                                                  |
| ------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------- |
| `NULL_MATCH_VALUE` | Related data could not match because its current-record value is blank | Supply data or revise the data set                             |
| `SOURCE_TRUNCATED` | More records matched than the data set permits                         | Narrow filters or raise the data set limit within the maximum  |
| `TOTAL_ROW_LIMIT`  | A later data set reached the combined prompt record limit              | Reduce data set limits or move the most important data earlier |
| `FIELD_TRUNCATED`  | A `maxLength` attribute shortened at least one value                   | Raise the `maxLength` value if the prompt needs more text      |
