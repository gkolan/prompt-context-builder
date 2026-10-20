# Permissions

## Prompt Context Generate

Assign **Permission Set: Prompt Context Generate** to people and automation that need to
read published templates and build context. It grants **Custom Permission: Prompt Context Generate**
and read access to the fixed published settings needed for prompt generation. It does not grant
read access to unpublished draft template text or draft data sets.

It does not grant access to customer objects, fields, or records. Salesforce profiles, Permission
Sets, sharing, restriction rules, and scoping rules continue to control those records.

## Prompt Context Save Input

Assign **Permission Set: Prompt Context Save Input** together with **Prompt Context Generate** when
a person or automation chooses **Save to Prompt Input Log**. It grants **Custom Permission: Prompt
Context Save Input** and create/read access to the private Prompt Input Log and its managed fields.

Saving fails with `NOT_AUTHORIZED` when this permission is missing. The package does not turn that
failure into a blank value, and **Return to Apex** does not require this permission.

## Prompt Context Send Files

Assign **Permission Set: Prompt Context Send Files** only to people and automation allowed to select
Salesforce Files for prepared input. It grants **Custom Permission: Prompt Context Send Files**. The
running user must still be able to read each exact file version and its direct link to the current
record.

This permission does not send a file outside Salesforce by itself. The current package selects and
stores file details only. Any later delivery requires a separately approved service and its own
security review.

## Prompt Context Process Input

Assign **Permission Set: Prompt Context Process Input** to the user that claims, completes, retries,
and removes Prompt Input Logs. It grants **Custom Permission: Prompt Context Process Input** and the
private-object access needed by `PromptContextInputLifecycle`.

Do not use this Permission Set as general record access. The worker receives only the Prompt Input
Logs visible to its Salesforce user, and changed stored input fails its checksum before processing.
The same Permission Set lets its user schedule the nightly purge of expired logs.

## Prompt Context Configure

Assign **Permission Set: Prompt Context Configure** to template authors. It grants **Custom
Permission: Prompt Context Configure**, access to Prompt Builder, create/edit access to template
records, and create/edit/delete access to their draft data sets. Status, published version, version
signature, draft revision, and health fields are read-only; Prompt Builder's Publish, Deactivate,
and Save actions and the scheduled health check set them. The Permission Set does not grant Delete
on templates: deactivate a template to retire it and keep its version history. It also grants the
Generate and Diagnostics custom permissions
so authors can preview, run, save, and troubleshoot their templates. It includes Prompt Input Log
create/read access for saving prepared input, but it does not grant edit or delete access to those
logs and does not grant Send Files or Process Input. Published version records are read-only to the
author; validated package service code creates them during publication.

Do not also assign **Prompt Context Generate** to a user who already has **Prompt Context
Configure**. Use the narrower Generate Permission Set for people and automation that only generate
prompts.

## Prompt Context Diagnostics

**Custom Permission: Prompt Context Diagnostics** allows the public bulk response to include a
short troubleshooting summary. It does not reveal field values, prompt content, Salesforce search
text, filter values, credentials, or error details. The packaged **Prompt Context Configure** Permission Set
grants this custom permission; the narrower **Prompt Context Generate** Permission Set does not.
