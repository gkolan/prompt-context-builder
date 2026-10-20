# Build prompt context from Flow

This guide is for a Salesforce Flow administrator who needs a published Prompt Context Builder
template to prepare input for one or more Salesforce records. The Flow can receive the text directly
or save a private Prompt Input Log for later work.

## Before you start

- Publish a template for the object represented by each input Record Id.
- Assign **Prompt Context Generate** to the person whose access the Flow uses.
- Also assign **Prompt Context Save Input** when the Flow saves a Prompt Input Log.
- Confirm that user can read every configured object, field, and record.
- Obtain either the published template's Salesforce record Id or its stable automation key from
  **Prompt Builder**. Prefer the automation key in a Flow that moves between orgs.

## Add the action

1. Open the Flow in **Setup → Flows → Flow Builder**.
2. Add an **Action** element.
3. Select **Prepare Record Prompt Input**.
4. Set **Record Id** from the current record or loop item.
5. Set either **Template Automation Key** or **Published Template Id**. Do not set both unless your
   Flow intentionally uses the Id as the authoritative identity.
6. Set **Delivery Choice** to `RETURN_TO_APEX` or `SAVE_TO_LOG`.
7. For `SAVE_TO_LOG`, set **Request Key** to a stable value for that unit of work.
8. Store the action output and branch on **Success** before reading **Prompt** or **Input Log Id**.

A successful result has `reasonCode = SUCCESS`. It can also contain a comma-separated
`warningCodes` value and a safe `warningMessage` when configured row bounds limited the context.
The prompt remains usable, but the Flow should decide whether that limited data is acceptable.

## Inputs

| Flow input                  | Required | Meaning                                                      |
| --------------------------- | -------- | ------------------------------------------------------------ |
| **Record Id**               | Yes      | Record whose object must match the published template        |
| **Template Automation Key** | One of   | Stable template identity recommended for deployed automation |
| **Published Template Id**   | One of   | Environment-specific Salesforce Id of the published template |
| **Delivery Choice**         | Yes      | `RETURN_TO_APEX` or `SAVE_TO_LOG`; case does not matter      |
| **Request Key**             | For save | Stable caller key used to make a retry safe                  |

Delivery Choice matches the API value regardless of case and surrounding spaces. A label such as
`Save to log` returns
`INVALID_DELIVERY_CHOICE`; the action reports it as a failed result and does not fault the Flow.

Existing Process Builder processes call this same action with the same inputs. Salesforce no longer
allows new processes, so build new automation in Flow.

## Outputs

| Flow output         | Use                                                                    |
| ------------------- | ---------------------------------------------------------------------- |
| `success`           | Branch before reading the prompt                                       |
| `reasonCode`        | Stable outcome or failure classification                               |
| `message`           | Safe explanation for the primary outcome                               |
| `warningCodes`      | Comma-separated successful-result warnings                             |
| `warningMessage`    | Safe explanation of successful-result warnings                         |
| `prompt`            | Generated text; null when the item failed                              |
| `inputLogId`        | Saved Prompt Input Log Id; null when input was returned to Apex        |
| `templateVersionId` | Exact published template version used                                  |
| `templateVersion`   | Fixed published version used                                           |
| `contractVersion`   | Public response contract version                                       |
| `syntaxVersion`     | Merge-language version                                                 |
| `correlationId`     | Privacy-safe request ID to retain for troubleshooting                  |
| `diagnosticSummary` | Short technical details when the runner has troubleshooting permission |

## Bulk limits and fault handling

One invocation accepts at most 200 requests and 10 distinct templates. Successful prompts in one
Flow response are limited to 1,000,000 combined characters. The resource planner can return
`TRANSACTION_BUDGET_EXCEEDED` for later records before Salesforce governor limits would be crossed.

When some records have many more related records than a data set's maximum, preparation runs extra
grouped queries so every record still gets its own complete rows. If those queries would exceed the
transaction's capacity, every request for that template returns `TRANSACTION_BUDGET_EXCEEDED`; no
prompt is returned with records missing. Reduce the collection size or the data set's maximum
records.

The response order matches the request order. One failed record does not discard successful
neighbors. For each response:

1. Branch on `success`.
2. On success, inspect `warningCodes` before using `prompt`.
3. On failure, route `reasonCode`, `message`, and `correlationId` to the Flow's controlled error
   handling path. Do not log prompt or customer field values.

See [Reason codes and warnings](../reference/reason-codes.md), [Limits](../reference/limits.md), and
[Troubleshoot generation](../diagnostics/README.md).
