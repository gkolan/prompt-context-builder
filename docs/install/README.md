# Install and verify Prompt Context Builder

Use this guide to deploy the current source to a Salesforce sandbox and prove the experience with
an administrator and an ordinary user. When you finish, the administrator can build and publish a
template, and the ordinary user can generate context from a record page without receiving template
configuration access.

> Looking for a separate prepared environment? The [scratch-org demo](./try-demo-scratch-org.md)
> creates known records and templates and verifies their expected results.

## Choose an evaluation path

| Your environment                | Use this path                                                                                |
| ------------------------------- | -------------------------------------------------------------------------------------------- |
| Dev Hub with scratch-org access | [Try the prepared demo](./try-demo-scratch-org.md)                                           |
| Existing Salesforce sandbox     | [Deploy the current source](#deploy-the-current-source-to-a-sandbox)                         |
| Public package installation     | Wait for an approved promoted version; see [package versions](./choose-a-package-version.md) |

The repository contains tested package-build evidence, but it does not currently advertise a
public package installer. A package alias in `sfdx-project.json` does not establish that a version
is promoted, supported, or approved for an external installation.

## Before you begin

You need:

- Git;
- Node.js 22 with npm;
- Salesforce CLI with the Code Analyzer plugin (`sf plugins install code-analyzer`), which
  `npm run ci:gates` runs;
- a Salesforce sandbox where you may deploy metadata and Apex;
- permission to assign Permission Sets and edit Lightning record pages; and
- an authenticated CLI alias for the target sandbox.

Prompt Context Builder uses Salesforce API version 67.0. Confirm that the destination org supports
the metadata in this source checkout before treating it as a deployment candidate.

Authenticate to a sandbox and confirm the target before deployment:

```bash
sf org login web --instance-url https://test.salesforce.com --alias pcb-sandbox
sf org display --target-org pcb-sandbox
```

`sf org display` helps prevent deploying to the wrong org. Do not include its authentication or
Org ID output in public issues.

## Deploy the current source to a sandbox

Clone the repository and run its complete local gate:

```bash
git clone https://github.com/gkolan/prompt-context-builder.git
cd prompt-context-builder
npm ci
npm run ci:gates
```

Deploy only after the local gate passes:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org pcb-sandbox \
  --wait 30
```

Deployment success proves Salesforce accepted the source. It does not prove the user journey,
record access, or package-upgrade behavior.

## Assign the intended access

Assign **Prompt Context Configure** only to template authors:

```bash
sf org assign permset \
  --name Prompt_Context_Configure \
  --target-org pcb-sandbox
```

Assign **Prompt Context Generate** to people who generate prompts, either through Setup or with
their username:

```bash
sf org assign permset \
  --name Prompt_Context_Generate \
  --target-org pcb-sandbox \
  --on-behalf-of USERNAME
```

Configuration access already includes generation and short troubleshooting details. Do not also assign the
Generate Permission Set to a configuration user. Neither Permission Set grants access to Account,
Contact, or other business data; add organization-owned data access separately.

See [Permission Sets](../reference/permissions.md) for the complete boundary.

## Create a small verification template

Choose a sandbox Account with at least one Contact, then follow [Create and publish a prompt
template](../step-by-step-guide/README.md). That guide identifies the required Account and Contact
fields and the exact template and source settings.

For a broader teaching catalog, run the repeatable seed and verifier. The seed creates demonstration
records and template configuration, so read it before running it in a shared sandbox:

```bash
npm run demo:setup-source -- --target-org pcb-sandbox
npm run demo:verify-source -- --target-org pcb-sandbox
```

Successful verification ends with `CATALOG_COMPLETE generated=9, drafts=2, inactive=1` in the Apex
execution log.

## Verify the Lightning experience

1. Open **App Launcher → Prompt Context Builder**.
2. Open **Prompt Builder** as a user with **Prompt Context Configure**.
3. Open a Draft, validate it, preview it against a readable record, and publish it.
4. Open a matching record in the **Prompt Context Builder** app. The included Account page already
   contains **Prompt Generator** for Account evaluation.
5. Choose the published template and select **Generate record context**.
6. Confirm the generated text and data set counts match records visible to that user.
7. Repeat as a user with **Prompt Context Generate** but without one required field. Expect an
   access failure and no partial prompt.

For another object or app, follow [Configure Prompt Generator](../lightning-record-page/README.md)
to add and activate the component on the intended Lightning record page.

## You are ready to continue when

- the local gate and Salesforce deployment both pass;
- the configuration user can validate, preview, and publish;
- a person with generation access can generate from the intended record page;
- inaccessible required data fails without returning a partial prompt; and
- the exact source revision and target environment are recorded privately with the evaluation
  evidence.

## If the result is not what you expected

| What you see                               | What to check first                                                                 |
| ------------------------------------------ | ----------------------------------------------------------------------------------- |
| Deployment rejects API version or metadata | Confirm the destination supports API 67.0 and preserve the deployment result        |
| Prompt Builder is unavailable              | Confirm deployment succeeded and assign **Prompt Context Configure**                |
| Prompt Generator is absent                 | Open the included app's Account page or activate the component on the intended page |
| No template can be selected                | Publish a template whose Salesforce object matches the record page object           |
| Generation returns an access error         | Check the current record, object, and field access; do not weaken the template      |
| Demo verification fails                    | Keep the Apex output and compare the source revision, seed, and verifier together   |

Use [Diagnostics](../diagnostics/README.md) for reason-code troubleshooting. Do not publish prompt
content, customer values, session details, Org IDs, generated searches, filter values, or raw
production logs.

## Next steps

- [Try the complete prepared demo](./try-demo-scratch-org.md)
- [Configure the record-page component](../lightning-record-page/README.md)
- [Call from Flow](../flow-guides/README.md)
- [Call from Apex or asynchronous code](../developer-guides/README.md)
- [Upgrade](./upgrade.md)
- [Uninstall](./uninstall.md)
