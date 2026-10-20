# Prompt Context Builder

[![Quality](https://github.com/gkolan/prompt-context-builder/actions/workflows/quality.yml/badge.svg)](https://github.com/gkolan/prompt-context-builder/actions/workflows/quality.yml)
[![Salesforce API 67.0](https://img.shields.io/badge/Salesforce_API-67.0-0B5CAB)](./sfdx-project.json)

> Build reviewable prompt context from Salesforce records without sending customer data to an AI
> model.

> **Warning**
>
> **Active development:** This project is pre-release and may change in breaking ways without
> notice. Package contents, APIs, configuration, data models, and upgrade behavior are not yet
> stable. Use it only in development or sandbox environments, expect that updates may require
> reconfiguration or reinstallation, and do not rely on it for production workloads yet.

Prompt Context Builder lets an administrator create a reusable prompt template, choose the current
record fields and limited related data it may read, preview the result, and publish a fixed version.
Users can then generate, edit, and copy the completed plain-text prompt from a record page. Record
pages and Salesforce automation use the same access checks.

It does not call an AI model, read Salesforce File bodies, or update customer records. Flow and
Apex can explicitly save prepared prompt text plus file metadata to a private Prompt Input Log;
record-page generation remains an edit-and-copy workflow and does not save the prompt.

## Get started

[Try the prepared scratch-org demo](./docs/install/try-demo-scratch-org.md) ·
[Deploy source to a sandbox](./docs/install/README.md#deploy-the-current-source-to-a-sandbox) ·
[Create your first template](./docs/step-by-step-guide/README.md) ·
[Browse all documentation](./docs/README.md)

The current public evaluation path is source deployment. A public package installer is not
advertised until the release owner approves an exact promoted version. Package aliases and build
records are release evidence, not a promise that a version is publicly supported.

## See it in action

![Published template open in Prompt Builder](./docs/screenshots/prompt-builder-current-overview.png)

Deployed scratch-org screenshot, September 26, 2026; see
[screenshot evidence](./docs/screenshots/README.md).

The prepared demo creates the same Account and Contacts each time, along with 12 numbered templates. Nine
templates are published and runnable; two remain Draft to teach validation behavior, and one is
Inactive to demonstrate lifecycle enforcement.

| What to explore                 | What the demo proves                                                                             |
| ------------------------------- | ------------------------------------------------------------------------------------------------ |
| Merge syntax                    | Current record fields, indexed records, counts, loops, conditions, fallback text, and formatting |
| Related and reference data sets | Current-record matches and limited shared lists                                                  |
| Filters, sorting, and limits    | Field-aware rules, named groups, repeatable ordering, and separate record limits                 |
| Calculated values               | Counts, sums, averages, minimums, and maximums                                                   |
| Safe failure                    | Invalid Draft, Inactive template, empty data, and inaccessible-data behavior                     |

See the [current and historical UI evidence](./docs/screenshots/README.md) and the
[verification catalog](./specs/prompt-context-builder/11-sample-template-catalog.md) for every
prepared scenario.

## How it works

1. An administrator creates a Draft template for one Salesforce object.
2. The administrator chooses current-record fields and up to ten related data sets or calculated
   values.
3. Validation checks the prompt text, Salesforce fields, required access, record order, and limits.
4. Preview runs against a real record with the administrator's current Salesforce access.
5. Publish creates a fixed version for record pages and automation.
6. Generation reads only data visible to the running user and either returns the complete prompt
   or returns no prompt when any required part fails.

Administrators choose objects, fields, filters, sorting, and limits through Prompt Builder. The
builder creates the Salesforce searches from those choices.

```text
Account: {!record.Name fallback="Unknown account"}
Open contacts: {!related.openContacts.count}

{!#each related.openContacts as="contact"}
- {!contact.Name}: {!contact.Email fallback="No email"}
{!else}
No open contacts were found.
{!/each}
```

## Try the prepared demo

You need Git, Node.js 22, Salesforce CLI, and access to a Dev Hub that can create scratch orgs.
Creating a scratch org consumes Dev Hub capacity. Run these commands only with the Dev Hub owner's
approval, replacing `TARGET_DEV_HUB` with an authenticated alias:

```bash
git clone https://github.com/gkolan/prompt-context-builder.git
cd prompt-context-builder
npm ci
npm run ci:gates

sf org create scratch \
  --definition-file config/promptcontextbuilder-scratch-def.json \
  --target-dev-hub TARGET_DEV_HUB \
  --alias pcb-demo \
  --duration-days 7

sf project deploy start --source-dir force-app --target-org pcb-demo --wait 30
sf org assign permset --name Prompt_Context_Configure --target-org pcb-demo
npm run demo:setup-source -- --target-org pcb-demo
npm run demo:verify-source -- --target-org pcb-demo
sf org open --target-org pcb-demo --path lightning/n/Prompt_Builder
```

The verifier succeeds only when all 12 teaching templates have the expected lifecycle state and
all nine published examples generate nonblank prompts. Continue with the
[complete demo guide](./docs/install/try-demo-scratch-org.md) for expected output, UI steps,
ordinary-user verification, troubleshooting, and cleanup responsibility.

If you have a sandbox but no Dev Hub, follow [deploy source to a
sandbox](./docs/install/README.md#deploy-the-current-source-to-a-sandbox).

## What is included

| Area               | Included behavior                                                                     |
| ------------------ | ------------------------------------------------------------------------------------- |
| Template lifecycle | Draft, validate, preview, publish, compare versions, restore to Draft, and deactivate |
| Related data       | Several related or reference data sets and calculated values                          |
| Record choices     | Salesforce fields, filters, named groups, repeatable sorting, and record limits       |
| Ways to use it     | Lightning record pages, Flow, Apex, Batch, Queueable, and Scheduled Apex              |
| Data access        | Salesforce sharing and field access, with no partial prompt after a failure           |
| Version history    | Stable automation keys, fixed published versions, signatures, and scheduled checks    |
| Product checks     | Salesforce and component tests, source review, sample data, and 12 teaching templates |

For exact syntax, permissions, limits, reason codes, and API contracts, use the
[reference documentation](./docs/reference/README.md).

## Security model

The package Permission Sets authorize Prompt Context Builder features; they do not grant access to
business objects, fields, or records. Salesforce sharing, restriction rules, object access, and
field access continue to control every record the template reads. A missing permission is an
error, not a blank value, and a failed request returns no partial prompt.

Start with [security and data access](./docs/architecture/security-and-data-access.md) and
[Permission Sets](./docs/reference/permissions.md) before production evaluation.

## Documentation

| Goal                                 | Guide                                                                              |
| ------------------------------------ | ---------------------------------------------------------------------------------- |
| Decide whether the product fits      | [Start here](./docs/start-here/README.md)                                          |
| Try a prepared source deployment     | [Scratch-org demo](./docs/install/try-demo-scratch-org.md)                         |
| Deploy to an existing sandbox        | [Install](./docs/install/README.md)                                                |
| Create and publish a template        | [Administrator walkthrough](./docs/step-by-step-guide/README.md)                   |
| Configure the record-page component  | [Lightning record page](./docs/lightning-record-page/README.md)                    |
| Call from Flow or Apex               | [Flow](./docs/flow-guides/README.md) and [Apex](./docs/developer-guides/README.md) |
| Troubleshoot a safe reason code      | [Diagnostics](./docs/diagnostics/README.md)                                        |
| Review exact contracts               | [Reference](./docs/reference/README.md)                                            |
| Operate and monitor the capability   | [Production operations](./docs/production-operations/README.md)                    |
| Upgrade source or a package          | [Upgrade](./docs/install/upgrade.md)                                               |
| Remove an evaluation or installation | [Remove safely](./docs/install/uninstall.md)                                       |

## Contributing and support

- Read [Contributing](./.github/CONTRIBUTING.md) before opening a pull request.
- Use [Support](./SUPPORT.md) for safe issue-intake guidance.
- Report vulnerabilities privately under the [Security policy](./.github/SECURITY.md).
- Run `npm run ci:gates` before handing off a change.

## License

No open-source license has been selected. Before describing this project as open source, the
release owner must add the approved license and copyright holder. Until then, publication of the
source does not grant reuse rights.
