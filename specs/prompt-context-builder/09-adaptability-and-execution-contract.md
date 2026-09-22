# Adaptability and execution contract

## Recommended architecture

The application uses one security and generation path for Lightning, Apex, Flow, Batch, Queueable,
and Scheduled Apex. Entry points may adapt transport shapes, but they must not implement a second
query or rendering engine.

```text
LWC / Flow / Apex / Batch / Queueable / Scheduled
                     |
              PromptContextApi
                     |
      authorization + published snapshot load
                     |
          validation + resource planning
                     |
        USER_MODE query compilation/execution
                     |
              deterministic renderer
                     |
         ordered per-record responses
```

This is the recommended pattern because security, row limits, version selection, failure codes,
and rendering cannot drift between channels. The engine is stateless and makes no customer-record
writes.

## Flow

Flow uses the invocable action **Build Record Context Prompt**. Supply one request per record with
`Record Id` and either `Published Template Id` or the deployment-stable `Template Developer Key`.

The action preserves input order and returns one response per input. One inaccessible or invalid
record does not discard successful neighbors. Each response contains `success`, `reasonCode`, safe
message, warning codes and explanation, prompt, version identifiers, and a privacy-safe correlation
ID. One transaction supports
at most 200 requests and 10 distinct templates. The resource planner can return
`TRANSACTION_BUDGET_EXCEEDED` before a record would exceed transaction capacity. The combined Flow
prompt payload is also bounded.

## Batch, Queueable, and Scheduled Apex

These contexts call `PromptContextApi.build(requests)` from their own `execute` method and persist,
send, or otherwise handle returned prompts according to the consuming business process. This
library deliberately does not persist prompts, publish prompt-bearing platform events, or invent a
generic result object because that would silently expand retention and privacy scope.

Batch scope must be set from `PromptContextResourcePlanner.plan(config).safeRecordCount`, capped by
the consumer's own DML/callout work. Queueable work should split larger inputs before enqueueing.
Scheduled Apex should enqueue Batch or Queueable work instead of processing a large collection in
the scheduler transaction. Consumers must assign `Prompt_Context_Generate`; running in async Apex
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
- Privacy-safe correlation IDs and separately authorized, 200-character, value-free diagnostic
  summaries.
- Searchable Name/Id keyset pagination: bounded template summaries first, selected details second;
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

The dependency order matters because the application overrides an object record page and the
configure permission set references the application. The separate page fixture is required because
Salesforce component descriptors use `c:` in a namespace-free org and the registered prefix in a
namespaced org.
