# Adaptability and execution contract

## Recommended architecture

The application uses one security and generation path for Lightning, Apex, Flow, Batch, Queueable,
and Scheduled Apex. Entry points may map their public request fields, but they must not implement a second
query or rendering engine.

```text
LWC / Flow / Apex / Batch / Queueable / Scheduled
                     |
              PromptContextInputApi
                     |
      authorization + published snapshot load
                     |
          validation + resource planning
                     |
        USER_MODE query compilation/execution
                     |
              deterministic renderer
                     |
        delivery choice: return or save
                     |
   ordered results / private Prompt Input Log
```

This is the recommended pattern because security, row limits, version selection, failure codes,
and rendering cannot drift between channels. Preparation never modifies the source customer
record. `RETURN_TO_APEX` performs no package DML; `SAVE_TO_LOG` writes the complete input to the
private `Prompt_Input_Log__c` object.

## Flow

Flow uses the invocable action **Prepare Record Prompt Input**. Supply one request per record with
`Record Id`, `Delivery Choice`, and either `Published Template Id` or the deployment-stable
`Template Automation Key`. `SAVE_TO_LOG` also requires a stable caller `Request Key` and the Prompt
Context Save Input permission.

The action preserves input order and returns one response per input. One inaccessible or invalid
record does not discard successful neighbors. Each response contains `success`, `reasonCode`, safe
message, warning codes and explanation, prompt, version identifiers, and a privacy-safe request
ID. One transaction supports
at most 200 requests and 10 distinct templates. The resource planner can return
`TRANSACTION_BUDGET_EXCEEDED` before a record would exceed transaction capacity. The combined Flow
prompt request data is also limited.

## Batch, Queueable, and Scheduled Apex

These contexts call `PromptContextInputApi.prepare(requests)` from their own `execute` method. A
caller that wants to handle the prepared prompt itself chooses `RETURN_TO_APEX`. A caller that wants
the package to retain a complete unit of later work chooses `SAVE_TO_LOG`; a successful result then
contains `inputLogId`. There is no registered destination type or custom callback. A later batch
class can query the log or use the returned result according to its business process.

Batch scope must be set from `PromptContextResourcePlanner.plan(config).safeRecordCount`, capped by
the consumer's own DML/callout work. Queueable work should split larger inputs before enqueueing.
Scheduled Apex should enqueue Batch or Queueable work instead of processing a large collection in
the scheduler transaction. Consumers must assign `Prompt_Context_Generate`; saving also requires
`Prompt_Context_Save_Input`. Running in async Apex
never bypasses CRUD, FLS, sharing, restriction rules, or template authorization.

## Adaptability borrowed from Record Health Check

- Central contract constants and stable, additive reason codes.
- Stable template developer keys instead of environment-specific record IDs.
- Immutable published template/source snapshots selected by exact version.
- Transaction-scoped Describe caching.
- Shared bulk API and grouped Flow requests.
- Resource admission before customer-record reads.
- Deterministic query ordering and overflow probes.
- Per-record failures preserve successful neighboring records.
- Privacy-safe request IDs and separately authorized, 200-character, value-free diagnostic
  summaries.
- Searchable Name/Id paging: return limited template summaries first and selected details second;
  stale search responses are discarded and loaded pages are de-duplicated.
- Explicit source-scope and result-mode boundaries; the delivered aggregate result is scalar and
  cannot be treated as a record collection.

## Extension rules

A new source type must provide a typed configuration and strategy and add validator, projection,
resource-planning, security, UI-help, and scenario coverage together. It may not accept raw SOQL.
Grouped aggregate, polymorphic, chained, or external sources require distinct result schemas and
cannot be smuggled into existing scopes or result modes. Contract changes are additive within version `1.0`; a
breaking request/response or merge-language change requires a new contract or syntax version.

## Namespaced regression procedure

The production project and unlocked package remain namespace-free. Namespace regression uses a
short-lived scratch org associated with the already registered `rhc` namespace; it does not move
package ownership or assign `rhc` as this product's permanent identity.

Run the regression from an isolated checkout:

1. Change only that checkout's `sfdx-project.json` namespace from an empty string to `rhc`.
2. Create the scratch org from `config/promptcontextbuilder-namespaced-scratch-def.json` against
   `rhc-dev-hub`.
3. Deploy Apex classes, labels, permissions, objects, tabs, and LWC bundles first.
4. Deploy the integration-only FlexiPage under `integration-tests/namespaced`, whose component
   descriptor is `rhc:promptGenerator`.
5. Deploy the Lightning application and permission sets after the page dependency exists.
6. Run all local Apex tests with code coverage and confirm returned class names carry the `rhc`
   prefix.
7. Restore the project namespace to an empty string before any namespace-free package operation.
8. Run `npm run check:namespace-fixtures`; it fails if either descriptor or the shipping namespace
   state drifts.

The integration-only page verifies the registered component prefix without adding an Account page
override to the shipping application. The separate fixture is required because Salesforce
component descriptors use `c:` in a namespace-free org and the registered prefix in a namespaced
org.
