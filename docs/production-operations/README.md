# Operate Prompt Context Builder

## Monitor template health

Published templates can drift when fields are removed, types change, packages are uninstalled, or
access changes. Run `PromptTemplateHealthSchedulable` on an approved schedule or execute
`scripts/apex/runPromptHealth.apex` manually after reviewing its target scope.

Health checks update the template's last checked time, status, version, and reason codes. They do
not generate or store customer prompts.

## Monitor generation

`Prompt_Context_Metric__e` contains channel, outcome code, duration, template identity/version, and
request ID. It intentionally contains no record values or prompt content. Platform Events are
messages, not permanent history; subscribe and persist only the operational fields your process
requires.

## Respond to failures

1. Capture the reason code and request ID (`correlationId` in an API response).
2. Confirm the template is Published and healthy.
3. Verify the runner has the generation Permission Set.
4. Verify object, field, and record access for the complete required field list.
5. Preview with the same record and an equivalent user before changing template settings.
6. Restore an earlier published version to a new Draft when the current design must be revised.

Do not expose generated searches, filter values, prompt content, or inaccessible field names to
people who use the templates.

## Deactivate safely

Deactivate a template to stop new generation without deleting its version history. Update Flow and
Apex callers that use its automation key before removing a template from service. Test the recovery
path in a sandbox before a production change.
