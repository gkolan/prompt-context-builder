# Use Prompt Context Builder from Flow or Apex

The public action is **Build Record Context Prompt**. It accepts an ordered request collection and
returns one response per request. Identify a published template with either its Salesforce record
Id or stable automation key, and always supply a Record Id.

## Flow

1. Assign **Prompt Context Generate** to the person whose access the Flow uses.
2. In Flow Builder, add **Action → Build Record Context Prompt**.
3. Set **Record Id** and one of **Published Template Id** or **Template Automation Key**.
4. Branch on `success` before reading `prompt`.
5. Handle `reasonCode`, inspect `warningCodes`, and retain `correlationId` for support.

Flow runs in the current transaction. A collection can contain at most 200 requests, no more than
10 distinct templates, and at most 1,000,000 prompt characters in successful responses.

## Apex

```apex
PromptContextApi.Request request = new PromptContextApi.Request();
request.templateDeveloperKey = 'account_contact_context';
request.recordId = accountId;

List<PromptContextApi.Response> responses = PromptContextApi.build(
  new List<PromptContextApi.Request>{ request }
);

PromptContextApi.Response response = responses[0];
if (response.success) {
  String prompt = response.prompt;
  if (!String.isBlank(response.warningCodes)) {
    System.debug(
      LoggingLevel.WARN,
      response.warningCodes + ': ' + response.warningMessage
    );
  }
} else {
  System.debug(LoggingLevel.WARN, response.reasonCode + ': ' + response.message);
}
```

The returned `correlationId` identifies this result for diagnostics. Do not log `prompt` in
production merely because it was returned to Apex.

`warningCodes` is a comma-separated list of stable codes. A successful response may carry warnings
when a configured source limit or the combined prompt row limit bounds the returned context.

## Bulk and asynchronous callers

Before choosing a Batch scope, load the published configuration and call
`PromptContextResourcePlanner.plan(config)`. Its `safeRecordCount` accounts for the framework's
query and row use. Leave additional capacity for the caller's own queries, DML, and callouts.

Queueable, Batch, and Scheduled Apex do not elevate record access. The executing user still needs
generation capability and read access to every required customer object and field.

See [Reason codes](../reference/reason-codes.md) and [Limits](../reference/limits.md).
