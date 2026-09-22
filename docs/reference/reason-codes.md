# Result reason codes and warnings

Every Flow and Apex response has `success`, `reasonCode`, and a safe message. A failed item has no
prompt. Neighboring valid items can still succeed. A successful limited result keeps
`reasonCode = SUCCESS` and reports non-blocking conditions separately in `warningCodes` and
`warningMessage`.

## Response reason codes

| Code                          | Meaning                                                         | Caller action                                                           |
| ----------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `SUCCESS`                     | Prompt built                                                    | Use or save the returned prompt according to your process               |
| `INVALID_REQUEST`             | Template identity or Record Id is missing or invalid            | Correct the request                                                     |
| `NOT_AUTHORIZED`              | Caller cannot generate prompts                                  | Assign the generation Permission Set to the intended user or automation |
| `TEMPLATE_NOT_FOUND`          | Template identity did not resolve                               | Check the Id or stable automation key                                   |
| `TEMPLATE_NOT_PUBLISHED`      | Template is not available for prompt generation                 | Publish an approved Draft                                               |
| `TEMPLATE_VERSION_AMBIGUOUS`  | More than one version matched an identity                       | Correct the stored configuration                                        |
| `INVALID_CONFIGURATION`       | Prompt text, Salesforce setup, or data set settings are invalid | Validate and republish the template                                     |
| `RECORD_NOT_ACCESSIBLE`       | Current record is absent, mismatched, or not visible            | Check the Record Id and sharing                                         |
| `OBJECT_NOT_ACCESSIBLE`       | A required object is not readable                               | Grant intended object access or remove the source                       |
| `FIELD_NOT_ACCESSIBLE`        | A required field is not readable                                | Grant intended field access or remove the field                         |
| `TRANSACTION_BUDGET_EXCEEDED` | Available Salesforce processing capacity is insufficient        | Reduce scope or use Batch Apex                                          |
| `FLOW_GROUP_LIMIT_EXCEEDED`   | More than ten templates were requested                          | Group the transaction by template                                       |
| `FLOW_PAYLOAD_LIMIT_EXCEEDED` | Successful prompts exceed the response budget                   | Reduce scope or use Batch Apex                                          |
| `PROMPT_TOO_LONG`             | Completed prompt exceeds 20,000 characters                      | Reduce template or data set size                                        |
| `UNEXPECTED_ERROR`            | An unexpected failure occurred                                  | Keep the request ID and ask an administrator to investigate             |

## Successful prompt warning codes

Warnings do not make the response fail and do not remove the prompt. Multiple codes are returned
as a comma-separated `warningCodes` value; their safe explanations are combined in
`warningMessage`.

| Code                     | Meaning                                                                | Caller action                                                  |
| ------------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------- |
| `NULL_CORRELATION_VALUE` | Related data could not match because its current-record value is blank | Supply data or revise the data set                             |
| `SOURCE_TRUNCATED`       | More records matched than the data set permits                         | Narrow filters or raise the data set limit within the maximum  |
| `TOTAL_ROW_LIMIT`        | A later data set reached the combined prompt record limit              | Reduce data set limits or move the most important data earlier |
