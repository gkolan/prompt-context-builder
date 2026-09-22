# Prompt Context Builder documentation

Prompt Context Builder assembles plain-text prompt context from a Salesforce record and explicitly
configured data sets. Salesforce sharing still controls which records are available. The product
does not call an AI model, save generated prompts, or update customer records.

## New here? Follow these steps

1. [Understand what the product does](./start-here/README.md).
2. [Try the prepared scratch-org demo](./install/try-demo-scratch-org.md), or
   [deploy source to a sandbox](./install/README.md).
3. [Create and publish a template](./step-by-step-guide/README.md).
4. [Configure the record-page generator](./lightning-record-page/README.md).
5. [Operate and monitor it](./production-operations/README.md).

## Pick your task

| Area                                                       | Use it when you want to…                                             |
| ---------------------------------------------------------- | -------------------------------------------------------------------- |
| [Start here](./start-here/README.md)                       | Decide whether Prompt Context Builder fits the requirement           |
| [Install](./install/README.md)                             | Choose a demo, sandbox source deployment, or approved package path   |
| [Prepared demo](./install/try-demo-scratch-org.md)         | Create known records and templates and verify their expected results |
| [Upgrade](./install/upgrade.md)                            | Upgrade source or an approved package and verify the transition      |
| [Remove](./install/uninstall.md)                           | Remove a demo, package, or source deployment through the safe path   |
| [Build templates](./build-templates/README.md)             | Choose related data, calculations, filters, sorting, and fields      |
| [Step-by-step guide](./step-by-step-guide/README.md)       | Build, preview, publish, and verify a template                       |
| [Lightning record page](./lightning-record-page/README.md) | Configure the Prompt Generator component                             |
| [Frequently asked questions](./faqs/README.md)             | Resolve common product and security questions                        |
| [Production operations](./production-operations/README.md) | Monitor health, recover safely, and manage lifecycle                 |
| [Flow guides](./flow-guides/README.md)                     | Call the action safely and handle every result                       |
| [Developer guides](./developer-guides/README.md)           | Call the bulk API from Apex and asynchronous code                    |
| [Diagnostics](./diagnostics/README.md)                     | Troubleshoot safely with reason codes and request IDs                |
| [Architecture](./architecture/README.md)                   | Understand execution, data, security, and trust boundaries           |
| [Reference](./reference/README.md)                         | Look up syntax, limits, permissions, result codes, and API contracts |
| [Contributing](./contributing/README.md)                   | Change and verify the source or documentation                        |
| [Quality gates](./quality-gates/README.md)                 | See the evidence required before a change is ready                   |

## Important behavior

- Generation uses the running user's object, field, and record access.
- A fallback handles a readable null value; it never bypasses missing access.
- Related data and reference lists include only records visible to the current user.
- Published versions cannot be changed. Editing continues in a draft.
- A failed request returns no partial prompt.

For exact behavior, start with the [feature catalog](./reference/feature-catalog.md) and
[security boundary](./architecture/security-and-data-access.md).
