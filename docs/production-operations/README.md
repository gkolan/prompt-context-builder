# Operate Prompt Context Builder

## Schedule the nightly jobs

Two optional jobs keep templates and saved input in order:

| Job                                | What it does                                               | Who schedules it                             |
| ---------------------------------- | ---------------------------------------------------------- | -------------------------------------------- |
| Prompt Template Health - Daily 2AM | Checks every published version against the current setup   | A user with **Prompt Context Configure**     |
| Prompt Input Log Purge - Daily 3AM | Deletes Prompt Input Logs past their **Retain Until** date | A user with **Prompt Context Process Input** |

To schedule a job:

1. Sign in as the user the job should run as. The job uses that user's access every night.
2. Open **Developer Console**, then choose **Debug → Open Execute Anonymous Window**.
3. Enter `PromptContextSchedules.scheduleHealthCheckDaily();` or
   `PromptContextSchedules.scheduleInputPurgeDaily();`, then select **Execute**.
4. In Setup, open **Scheduled Jobs** and confirm the job name and next run time.

Running the command again keeps the existing job. To stop a job, delete it from **Scheduled Jobs**.
A scheduled job does not block deploying Prompt Context Builder updates.

## Monitor template health

Published templates can drift when fields are removed, types change, packages are uninstalled, or
access changes. The health job, or `scripts/apex/runPromptHealth.apex` run once, updates each
template's last checked time, status, version, and reason codes. It does not generate or store
customer prompts.

The check uses the access of the user who scheduled it. **Healthy** means that user can read every
required field; it does not prove that the people who generate prompts can. Schedule the job as an
integration user whose access matches those people, and test generation as a real user after access
changes.

## Retain and purge saved input

Each Prompt Input Log stores a complete copy of the prepared prompt, including record values, until
its **Retain Until** date, 30 days after it is saved. The purge job deletes only the logs its user
can see and delete, so schedule it as a user whose sharing covers every saved log, or delete expired
logs according to your organization's retention process.

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
6. Restore an earlier published version into the editable settings when the current design must be
   revised. The current fixed publication stays available until the restored settings are published.

Do not expose generated searches, filter values, prompt content, or inaccessible field names to
people who use the templates.

## Deactivate safely

Deactivate a template to stop new generation without deleting its version history. Update Flow and
Apex callers that use its automation key before removing a template from service. Test the recovery
path in a sandbox before a production change.
