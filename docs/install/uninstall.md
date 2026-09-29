# Remove Prompt Context Builder safely

Use the removal path that matches the installation type. Removing the capability can delete stored
template configuration and published history, so obtain the data owner's approval before any
destructive action.

## Identify the installation type

| What you have                                    | Removal path                                     |
| ------------------------------------------------ | ------------------------------------------------ |
| Scratch org created for the prepared demo        | Let it expire or use the authorized scratch path |
| Prompt Context Builder in **Installed Packages** | Uninstall the unlocked package                   |
| Metadata deployed directly from `force-app`      | Use the controlled source-deployment path        |

Do not use package-uninstall instructions for source-deployed metadata. Salesforce does not track
that source as one installed package.

## Before removing any installation

1. Deactivate or update Lightning pages, Flow actions, Apex callers, and scheduled health jobs
   that depend on Prompt Context Builder.
2. Export any records that must be retained:
   - `Prompt_Template__c`
   - `Prompt_Context_Source__c`
   - `Prompt_Template_Version__c`
   - `Prompt_Context_Source_Version__c`
3. Record the source revision or installed package version.
4. Verify the export can be read independently of Prompt Context Builder.
5. Confirm who owns removal, recovery, and post-removal verification.

Template bodies and filter values can contain sensitive business instructions. Store exports under
the organization's approved retention and access controls.

## Finish a scratch-org evaluation

The prepared demo scratch org expires automatically. If the Dev Hub owner authorizes early
deletion, the person responsible for the org can run:

```bash
sf org delete scratch --target-org pcb-demo --no-prompt
```

Confirm the alias identifies the evaluation org before running the command. Deleting a scratch org
does not restore the Dev Hub's daily scratch-org creation allocation.

## Uninstall an approved package

1. In Salesforce Setup, open **Installed Packages**.
2. Select **Prompt Context Builder** and confirm the installed version.
3. Resolve every dependency Salesforce reports, including Lightning pages, Flows, and Apex callers.
4. Select **Uninstall** only after the backup and dependency review are complete.
5. Choose the organization's approved handling for package data when Salesforce presents the
   uninstall options.
6. Wait for Salesforce to report completion.

Afterward, confirm:

- **Prompt Context Builder** no longer appears in **Installed Packages**;
- no active Lightning page references **Prompt Generator**;
- no Flow references **Prepare Record Prompt Input**;
- no Apex caller references `PromptContextInputApi`; and
- no scheduled template-health job remains active.

An untested reinstall is not a proven recovery path. Validate clean reinstall and configuration
restore in a sandbox before depending on them.

## Remove a source deployment

A source deployment has no package boundary and can share dependencies with organization-owned
metadata. The safest evaluation environment is therefore a disposable scratch org or dedicated
sandbox that can expire, be deleted, or be refreshed according to the environment owner's process.

For a persistent sandbox or production org, do not delete files from the local checkout and assume
Salesforce will remove the corresponding metadata. Source deployment does not infer deletion.
Create and review a release-specific Metadata API destructive-change manifest that names the exact
components present in that org, validate it in a representative sandbox, and obtain data-owner
approval before execution.

This repository intentionally does not ship a generic destructive manifest. Such a manifest would
delete the Prompt Context custom objects and their records and could also fail when organization-
owned Lightning pages, Flows, Apex, or other metadata still reference the product.

## Verify removal

1. Confirm the app, tabs, components, Permission Sets, and APIs are unavailable through the
   intended user paths.
2. Confirm dependent automation was removed or replaced so it does not fail.
3. Confirm retained exports remain protected and readable.
4. Record the removal result separately from any later reinstall or recovery test.

For a failed or partial removal, preserve the Salesforce deployment or uninstall result and correct
the reported dependency. Do not broaden a destructive manifest or delete configuration records as
a generic retry.
