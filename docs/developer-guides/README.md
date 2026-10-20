# Use Prompt Context Builder from Flow or Apex

The public action is **Prepare Record Prompt Input**. It accepts an ordered request collection and
returns one result per request. Identify a published template with either its Salesforce record Id
or stable automation key, always supply a Record Id, and choose whether to return or save the
prepared input.

## Flow

1. Assign **Prompt Context Generate** to the person whose access the Flow uses. Also assign
   **Prompt Context Save Input** when the Flow saves a Prompt Input Log.
2. In Flow Builder, add **Action → Prepare Record Prompt Input**.
3. Set **Record Id**, **Delivery Choice**, and one of **Published Template Id** or **Template
   Automation Key**.
4. When **Delivery Choice** is `SAVE_TO_LOG`, supply a stable **Request Key** for that unit of work.
5. Branch on `success` before reading `prompt` or `inputLogId`.
6. Handle `reasonCode`, inspect `warningCodes`, and retain `correlationId` for support.

Flow runs in the current transaction. A collection can contain at most 200 requests, no more than
10 distinct templates, and at most 1,000,000 prompt characters in successful responses.

## Apex

```apex
PromptContextInputApi.Request request = new PromptContextInputApi.Request();
request.templateDeveloperKey = 'account_contact_context';
request.recordId = accountId;
request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;

List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
  new List<PromptContextInputApi.Request>{ request }
);

PromptContextInputApi.Result response = responses[0];
if (response.success) {
  String prompt = response.prompt;
}
```

For `SAVE_TO_LOG`, set `request.deliveryChoice = PromptContextInputApi.SAVE_TO_LOG` and provide a
caller-generated `request.requestKey`. A successful result contains `inputLogId`; its `prompt` is
cleared if the save fails. The same user, Request Key, and prepared input safely reuse the original
log. Reusing that key for different input fails with `REQUEST_KEY_CONFLICT`.

The returned `correlationId` identifies this result for diagnostics. Do not log `prompt`, Request
Keys, or customer values in production.

For a file-enabled published template, assign **Prompt Context Send Files** and provide exact current
Salesforce File version IDs in `request.selectedContentVersionIds`. A successful result returns the
server-built `selectedFilesJson`. Callers cannot provide their own file JSON. The same managed value
is stored when Delivery Choice is `SAVE_TO_LOG`.

The file list contains metadata only. `PromptContextInputApi` does not read file bodies or call an
external service. Code that chooses `RETURN_TO_APEX` owns any later approved action. Code that chooses
`SAVE_TO_LOG` can use `PromptContextInputLifecycle` to claim and update saved work.
`claimAvailable` returns the longest-waiting logs first.

`warningCodes` is a comma-separated list of stable codes. A successful response may carry warnings
when a configured source limit or the combined prompt row limit bounds the returned context.

## Bulk and asynchronous callers

Before choosing a Batch scope, load the published configuration and call
`PromptContextResourcePlanner.plan(config)`. Its `safeRecordCount` accounts for grouped record
queries, the candidate and calculation queries used by calculated sources, file queries, and row
use. `groupedQueryCount` is the number of framework queries planned for the collection, and
`plannedRowsPerRecord` is the conservative per-record row estimate. Leave additional capacity for
the caller's own queries, DML, and callouts.

Queueable, Batch, and Scheduled Apex do not elevate record access. The executing user still needs
generation capability and read access to every required customer object and field.

Every entry point checks the user Salesforce runs the transaction as. A record-triggered Flow runs as
the person who saved the record. Some automation runs as a different user, for example the
Automated Process user for some event-driven Flows, or the user who scheduled a job. That user needs
the Prompt Context Permission Sets and record access; otherwise the request returns
`NOT_AUTHORIZED` or an access reason. Confirm the running user for each Flow type in the target org
before relying on it.

## Supported invocation contexts

Every context calls the same preparation service, so authorization, user-mode data access, limits,
and reason codes are identical. The table names the Apex tests that exercise each context.

| Context                         | Entry point                                        | Exercised by                                                                                 |
| ------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Synchronous Apex                | `PromptContextInputApi.prepare`                    | `PromptContextInputApiTest`, `PromptContextEntryPointContractTest`                           |
| Flow action (any Flow type)     | **Prepare Record Prompt Input** (`prepareForFlow`) | `PromptContextEntryPointContractTest`; real Flow runtime in `PromptContextFlowRuntimeTest`   |
| Autolaunched Flow               | Same action                                        | `PromptContextFlowRuntimeTest` (output variables and Return/Save delivery)                   |
| Record-triggered Flow, bulk DML | Same action                                        | `PromptContextFlowRuntimeTest` (one 50-record insert saves 50 logs)                          |
| Lightning record page           | `PromptContextController.generatePrompt`           | `PromptContextControllerTest`, `PromptContextEntryPointContractTest`                         |
| Queueable Apex                  | `prepare` from `execute`                           | `PromptContextExecutionContextTest`; 50-record save in `PromptContextEntryPointContractTest` |
| Batch Apex                      | `prepare` from `execute`                           | Full 200-record scope in `PromptContextEntryPointContractTest`                               |
| Scheduled Apex                  | `prepare` from `execute`                           | `PromptContextExecutionContextTest`                                                          |

Screen Flows and Process Builder use the same invocable action and request contract. Salesforce no
longer allows new Process Builder processes; build new automation in Flow. Neither a Screen Flow nor
a Process Builder process is exercised by an automated test, because Apex tests cannot run a screen
or create a process.

`PromptContextFlowRuntimeTest` and its two test-only Flows live in `integration-tests/flow-runtime`;
`PromptContextFormulaFieldTest`, its test-only formula fields, and its permission set live in
`integration-tests/formula-fixtures`. `PromptContextRestrictedUserTest` in `integration-tests/security`
runs generation, publishing, and lifecycle writes as a minimum-access user who holds only the package
Permission Sets, so Salesforce enforces sharing, object access, and field access for real. It creates
that user inside the test, Salesforce rolls it back, and it needs one free Salesforce user license.
Include all three directories when validating against an org; none is packaged.

See [Reason codes](../reference/reason-codes.md) and [Limits](../reference/limits.md).
