# Build prompt context from Flow

This guide is for a Salesforce Flow administrator who needs a published Prompt Context Builder
template to produce text for one or more Salesforce records. The action builds text only. The Flow
decides whether to display, send, or store the returned prompt.

## Before you start

- Publish a template for the object represented by each input Record Id.
- Assign **Prompt Context Generate** to the person whose access the Flow uses.
- Confirm that user can read every configured object, field, and record.
- Obtain either the published template's Salesforce record Id or its stable automation key from
  **Prompt Builder**. Prefer the automation key in a Flow that moves between orgs.

## Add the action

1. Open the Flow in **Setup → Flows → Flow Builder**.
2. Add an **Action** element.
3. Select **Build Record Context Prompt**.
4. Set **Record Id** from the current record or loop item.
5. Set either **Template Automation Key** or **Published Template Id**. Do not set both unless your
   Flow intentionally uses the Id as the authoritative identity.
6. Store the action output and branch on **Success** before reading **Prompt**.

A successful result has `reasonCode = SUCCESS`. It can also contain a comma-separated
`warningCodes` value and a safe `warningMessage` when configured row bounds limited the context.
The prompt remains usable, but the Flow should decide whether that limited data is acceptable.

## Inputs

| Flow input                  | Required | Meaning                                                      |
| --------------------------- | -------- | ------------------------------------------------------------ |
| **Record Id**               | Yes      | Record whose object must match the published template        |
| **Template Automation Key** | One of   | Stable template identity recommended for deployed automation |
| **Published Template Id**   | One of   | Environment-specific Salesforce Id of the published template |

## Outputs

| Flow output         | Use                                                                    |
| ------------------- | ---------------------------------------------------------------------- |
| `success`           | Branch before reading the prompt                                       |
| `reasonCode`        | Stable outcome or failure classification                               |
| `message`           | Safe explanation for the primary outcome                               |
| `warningCodes`      | Comma-separated successful-result warnings                             |
| `warningMessage`    | Safe explanation of successful-result warnings                         |
| `prompt`            | Generated text; null when the item failed                              |
| `templateVersion`   | Fixed published version used                                           |
| `contractVersion`   | Public response contract version                                       |
| `syntaxVersion`     | Merge-language version                                                 |
| `correlationId`     | Privacy-safe request ID to retain for troubleshooting                  |
| `diagnosticSummary` | Short technical details when the runner has troubleshooting permission |

## Bulk limits and fault handling

One invocation accepts at most 200 requests and 10 distinct templates. Successful prompts in one
Flow response are limited to 1,000,000 combined characters. The resource planner can return
`TRANSACTION_BUDGET_EXCEEDED` for later records before Salesforce governor limits would be crossed.

The response order matches the request order. One failed record does not discard successful
neighbors. For each response:

1. Branch on `success`.
2. On success, inspect `warningCodes` before using `prompt`.
3. On failure, route `reasonCode`, `message`, and `correlationId` to the Flow's controlled error
   handling path. Do not log prompt or customer field values.

See [Reason codes and warnings](../reference/reason-codes.md), [Limits](../reference/limits.md), and
[Troubleshoot generation](../diagnostics/README.md).
