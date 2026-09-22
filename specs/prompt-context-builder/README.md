# Prompt Context Builder specification

Status: September 19 build deployed and verified; September 22 wording revision locally verified

This folder captures the implementation-ready specification and the evidence from the completed
greenfield build. Private planning transcripts are intentionally excluded from the public source
tree; the durable contracts below contain the product requirements and decisions.

## Documents

1. [`01-product-contract.md`](./01-product-contract.md): scope, terminology, configuration model,
   merge language, and runtime contract.
2. [`02-scenario-matrix.md`](./02-scenario-matrix.md): everyday, empty, invalid, adversarial,
   security, schema-change, volume, and recovery scenarios.
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
    experience, governance, typed-filter, privacy, and release-hardening increments and their gates.
11. [`11-sample-template-catalog.md`](./11-sample-template-catalog.md): maps every supported option
    family to seeded working, empty-state, boundary, lifecycle, or intentional-error examples and
    gives the repeatable verification steps.

## Governing principles

- One responsibility: build a prompt from a Salesforce record and configured record context.
- Related datasets are identified by stable aliases, not by object type.
- Configuration must be understandable without requiring manually written SOQL.
- Every customer-data read uses the running user's access.
- Empty data, inaccessible data, invalid configuration, and execution failure are distinct states.
- Rendering is deterministic, bounded, atomic, and performs no lazy queries.
- Drafts may be incomplete; only validated, published versions may generate prompts.
- No files, AI calls, AI responses, conversations, or saved analysis sessions are in scope.
