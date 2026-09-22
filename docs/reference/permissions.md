# Permissions

## Prompt Context Generate

Assign **Permission Set: Prompt Context Generate** to people and automation that need to
read published templates and build context. It grants **Custom Permission: Prompt Context Generate**
and read access to the fixed published settings needed for prompt generation.

It does not grant access to customer objects, fields, or records. Salesforce profiles, Permission
Sets, sharing, restriction rules, and scoping rules continue to control those records.

## Prompt Context Configure

Assign **Permission Set: Prompt Context Configure** to template authors. It grants **Custom
Permission: Prompt Context Configure**, access to Prompt Builder, and create/edit/delete access to
Draft template and source records. It also grants the Generate and Diagnostics custom permissions
so authors can preview, run, and troubleshoot their templates. Published version records cannot be
edited.

Do not also assign **Prompt Context Generate** to a user who already has **Prompt Context
Configure**. Use the narrower Generate Permission Set for people and automation that only generate
prompts.

## Prompt Context Diagnostics

**Custom Permission: Prompt Context Diagnostics** allows the public bulk response to include a
short troubleshooting summary. It does not reveal field values, prompt content, Salesforce search
text, filter values, credentials, or error details. The packaged **Prompt Context Configure** Permission Set
grants this custom permission; the narrower **Prompt Context Generate** Permission Set does not.
