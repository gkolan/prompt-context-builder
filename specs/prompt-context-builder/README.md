# Prompt Context Builder specification

Status: September 19 build deployed and verified; September 22 wording revision locally verified

This folder contains the product requirements, build plans, and verification records. Private
planning notes are not included.

## Documents

1. [`01-product-contract.md`](./01-product-contract.md): scope, terminology, configuration model,
   merge language, and prompt-generation behavior.
2. [`02-scenario-matrix.md`](./02-scenario-matrix.md): everyday, empty, invalid, adversarial,
   security, object-and-field-change, volume, and recovery scenarios.
3. [`03-security-contract.md`](./03-security-contract.md): authorization, CRUD/FLS, sharing,
   query safety, diagnostics, and output handling.
4. [`04-step-by-step-execution.md`](./04-step-by-step-execution.md): ordered delivery plan with
   prerequisites, outputs, and acceptance gates.
5. [`05-traceability.md`](./05-traceability.md): maps every stated requirement to its durable
   specification section and planned verification.
6. [`06-build-record.md`](./06-build-record.md): records final version-one decisions, delivered
   security controls, execution results, deployment IDs, and seeded demonstration data.
7. [`07-hardening-extensibility-and-ui.md`](./07-hardening-extensibility-and-ui.md): defines query
   scope, advanced user journeys, red scenarios, scalability boundaries, UI hardening, and the
   completion checklist for the expanded build.
8. [`08-quality-security-and-architecture-review.md`](./08-quality-security-and-architecture-review.md):
   records the Well-Architected, CRUD/FLS, LWS, WCAG, SLDS, and static-analysis review.
9. [`09-adaptability-and-execution-contract.md`](./09-adaptability-and-execution-contract.md):
   defines the shared Flow/Apex/Batch contract and extension guardrails.
10. [`10-improvement-roadmap.md`](./10-improvement-roadmap.md): records the accepted administrator
    experience, governance, field-type filter, privacy, and release-readiness work and its checks.
11. [`11-sample-template-catalog.md`](./11-sample-template-catalog.md): maps every supported option
    family to seeded working, empty-state, boundary, lifecycle, or intentional-error examples and
    gives the repeatable verification steps.
12. [`12-match-records-by-field-value-and-bulk-processing.md`](./12-match-records-by-field-value-and-bulk-processing.md):
    explains how an administrator can match a field on the current Salesforce record to a field on
    another object, including Industry or Region. It also covers bulk requests, record limits,
    Currency fields, red tests, and verification at each stage. This feature is proposed.
13. [`13-record-files-and-bedrock-document-input.md`](./13-record-files-and-bedrock-document-input.md):
    explains how a user selects Salesforce Files linked to the current record and sends up to five
    supported files with the prompt to Amazon Bedrock. It covers exact file versions, clear failures,
    temporary AWS storage, scanning, cleanup, red tests, and verification at each stage. This feature
    is proposed.
14. [`14-prompt-input-log-and-delivery-options.md`](./14-prompt-input-log-and-delivery-options.md):
    explains the one common preparation service used by Apex, Flow, Lightning, Batch, Queueable,
    Scheduled Apex, and future entry points. A caller can save the prepared input to a Prompt Input
    Log, return it to Apex, or send it to a registered destination. It also covers provider delivery,
    retention, red tests, and verification at each stage. This feature is proposed.
15. [`15-common-entry-build-record.md`](./15-common-entry-build-record.md): records the first local
    build increment for the common prompt-preparation service, including the failing boundary check,
    passing local evidence, analyzer result, and work that remains unavailable.

## Governing principles

- One responsibility: build a prompt from a Salesforce record and configured record context.
- Related record groups use stable source names, not object type alone.
- Configuration must be understandable without requiring manually written SOQL.
- Every customer-data read uses the running user's access.
- Empty data, inaccessible data, invalid configuration, and execution failure are distinct states.
- The same inputs produce the same prompt. Limits are checked before queries, and a failed record
  never returns a partial prompt.
- Drafts may be incomplete; only validated, published versions may generate prompts.
- The delivered version does not include files, external-provider calls, provider responses, conversations, or
  saved analysis sessions. Documents 12 through 14 describe proposed additions.

## Writing language

- Write for a junior Salesforce administrator first.
- Use Salesforce labels such as Custom Permission, Permission Set, Custom Metadata, Flow, Batch Apex,
  Queueable Apex, and Salesforce Files.
- Describe the action before showing an Apex class, API name, reason code, or AWS term.
- Use "match fields," "prepared input," "delivery choice," and "registered destination" in prose.
- Replace software-design shorthand with the Salesforce action or record an administrator sees.
