# Try Prompt Context Builder in a scratch org

Use this guide to create a separate Salesforce evaluation org with known Account and Contact data,
12 teaching templates, and an automated verifier. When you finish, you can inspect the Prompt
Builder, preview safe and invalid configurations, and generate context from an Account page.

The current demo deploys repository source. It does not prove installation or upgrade behavior for
a promoted package version.

## Before you begin

You need:

- Git;
- Node.js 22 with npm;
- Salesforce CLI;
- an authenticated Dev Hub that can create scratch orgs; and
- authorization from the Dev Hub owner to consume scratch-org capacity.

A Dev Hub authorizes temporary Salesforce orgs. A CLI alias is a local name for an authenticated
org. This guide uses `TARGET_DEV_HUB` for the Dev Hub and `pcb-demo` for the new scratch org.

If you have a sandbox but no Dev Hub, follow [Install and verify](./README.md) instead.

## 1. Clone and verify the source

```bash
git clone https://github.com/gkolan/prompt-context-builder.git
cd prompt-context-builder
npm ci
npm run ci:gates
```

The gate must finish successfully before deployment. It checks formatting, documentation links,
public-release hygiene, the permission boundary, namespace fixtures, LWC lint, Jest behavior, and
JavaScript coverage completeness.

## 2. Confirm the Dev Hub

If the Dev Hub is not authenticated on this computer, authenticate it with an alias chosen by the
owner:

```bash
sf org login web --set-default-dev-hub --alias TARGET_DEV_HUB
```

Confirm the selected org before consuming capacity:

```bash
sf org display --target-org TARGET_DEV_HUB
```

Do not paste the command output into a public issue because it can contain environment identifiers.

## 3. Create the evaluation org

This command creates a seven-day Developer Edition scratch org with sample data enabled:

```bash
sf org create scratch \
  --definition-file config/promptcontextbuilder-scratch-def.json \
  --target-dev-hub TARGET_DEV_HUB \
  --alias pcb-demo \
  --duration-days 7
```

Record who owns the scratch org and its expiration date. Do not create a replacement merely because
a later verification step fails; preserve the failure and correct the source or setup problem.

## 4. Deploy and assign configuration access

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org pcb-demo \
  --wait 30

sf org assign permset \
  --name Prompt_Context_Configure \
  --target-org pcb-demo
```

**Prompt Context Configure** includes generation and short troubleshooting details for the scratch-org
administrator. It does not grant access to unrelated Salesforce business data.

## 5. Seed and verify the teaching catalog

```bash
npm run demo:setup-source -- --target-org pcb-demo
npm run demo:verify-source -- --target-org pcb-demo
```

The seed is repeatable. It reuses the named demonstration records and templates, while publishing
again creates a new fixed template version as designed.

Verification succeeds only when:

- exactly 12 `Verify` templates exist;
- all nine Published templates return a nonblank prompt from their current fixed version;
- both Draft templates and the Inactive template are rejected during prompt generation;
- the intentional-error Draft reports multiple actionable validation errors; and
- only Published Account templates appear in the template picker.

The Apex output ends with:

```text
CATALOG_COMPLETE generated=9, drafts=2, inactive=1
```

## 6. Explore Prompt Builder

Open the custom tab directly:

```bash
sf org open --target-org pcb-demo --path lightning/n/Prompt_Builder
```

In **Prompt Builder**:

1. Search for `Verify`.
2. Open **Verify 01 - Merge Syntax**.
3. Preview it against **Prompt Context Verification Account**.
4. Confirm the preview shows root values, the Contact count, three ordered Contacts, fallback text
   for the blank email, and data set counts.
5. Open **Verify 07 - Empty and Fallback** and confirm its empty branches render.
6. Open **Verify 09 - Intentional Errors Draft**, select **Validate**, and confirm the errors are
   actionable. Do not publish this teaching entry.
7. Open **Verify 12 - Inactive Template** and confirm it is not offered when generating a prompt.

The [verification catalog](../../specs/prompt-context-builder/11-sample-template-catalog.md)
explains all 12 templates and the option family each one demonstrates.

## 7. Generate context on the Account page

1. Open **App Launcher → Prompt Context Builder**.
2. Open the **Accounts** tab.
3. Open **Prompt Context Verification Account**.
4. In **Prompt Generator**, choose a Published `Verify` template that targets Account.
5. Select **Generate Context**.
6. Review the generated text and data set counts.
7. Add optional Prefix or Suffix text, edit the generated text, and select **Copy Complete Prompt**.
8. Select **Start Over** and confirm the component clears the editable workspace.

The Account page included in the source is assigned to the Prompt Context Builder app. Other apps
or objects require explicit Lightning page placement and activation; follow [Configure Prompt
Generator](../lightning-record-page/README.md).

## 8. Verify the least-privilege user experience

For an available non-administrator test user:

1. Assign **Prompt Context Generate**, not **Prompt Context Configure**.
2. Grant only the Account and Contact access required by the chosen template.
3. Confirm the user can generate but cannot open Prompt Builder or change templates.
4. Remove access to one required field in this disposable environment.
5. Confirm generation fails without returning a partial prompt or field value.

Use organization-owned Permission Sets for Account, Contact, and field access. The packaged
Permission Sets authorize product features but intentionally do not broaden customer-data access.

## Expected teaching states

| Example                              | Expected state | Expected behavior                                        |
| ------------------------------------ | -------------- | -------------------------------------------------------- |
| Verify 01 - Merge Syntax             | Published      | Generates ordered Contact context                        |
| Verify 06 - Aggregate Calculations   | Published      | Generates counts, sums, averages, minimums, and maximums |
| Verify 07 - Empty and Fallback       | Published      | Renders indexed fallback and both empty branches         |
| Verify 09 - Intentional Errors Draft | Draft          | Validation reports errors and prompt generation refuses  |
| Verify 12 - Inactive Template        | Inactive       | The template picker excludes it and generation refuses   |

## If the demo does not match

| What you see                         | What to check first                                                               |
| ------------------------------------ | --------------------------------------------------------------------------------- |
| Scratch-org creation fails           | Dev Hub authorization, active scratch-org limits, and daily creation capacity     |
| Deployment fails                     | Preserve the deployment result and confirm API and feature compatibility          |
| Seed fails with an access error      | Confirm **Prompt Context Configure** is assigned to the scratch-org administrator |
| Fewer than 12 templates exist        | Rerun the idempotent setup command against the same source and org                |
| Prompt Generator has no choices      | Confirm the template is Published and its Salesforce object is Account            |
| Preview or generation denies a field | Restore the intended test user's field access; do not weaken access enforcement   |

For reason-code troubleshooting, use [Diagnostics](../diagnostics/README.md). Keep customer values,
generated prompts, credentials, session identifiers, Org IDs, generated searches, filter values,
and raw logs out of public reports.

## Finish responsibly

The scratch org expires automatically. If the Dev Hub owner authorizes early deletion, the person
responsible for the org can run:

```bash
sf org delete scratch --target-org pcb-demo --no-prompt
```

Deleting a scratch org does not restore the Dev Hub's daily creation allocation. Keep evaluation
evidence separate from production, package, and browser-verification claims.

## Next steps

- [Create a template from the beginning](../step-by-step-guide/README.md)
- [Review every related-data option](../build-templates/README.md)
- [Configure Prompt Generator](../lightning-record-page/README.md)
- [Call from Flow](../flow-guides/README.md)
- [Call from Apex](../developer-guides/README.md)
- [Review security and data access](../architecture/security-and-data-access.md)
