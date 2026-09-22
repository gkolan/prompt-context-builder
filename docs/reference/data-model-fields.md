# Configuration and operational fields

Prompt Builder is the supported place to create and edit templates. This reference explains stored
fields for reporting, backup, review, and integrations. Editing fields marked as managed can create
an invalid Draft and never bypasses Salesforce checks.

## Prompt Template (`Prompt_Template__c`)

| Field label                 | API name                    | Purpose                                                            |
| --------------------------- | --------------------------- | ------------------------------------------------------------------ |
| Automation Key              | `Developer_Key__c`          | Stable automation identity generated on first save                 |
| Description                 | `Description__c`            | Administrator-facing intent and usage notes                        |
| Salesforce Object           | `Root_Object__c`            | Salesforce object used by the current record                       |
| Prompt Text                 | `Template_Body__c`          | Draft merge-language text                                          |
| Status                      | `Status__c`                 | `Draft`, `Published`, or `Inactive`                                |
| Published Version           | `Version__c`                | Current published version number                                   |
| Published Version Signature | `Fingerprint__c`            | SHA-256 identity of the published configuration                    |
| Last Published              | `Published_At__c`           | Publication timestamp                                              |
| Last Setup Check Result     | `Last_Health_Status__c`     | `Healthy`, `Unhealthy`, or `Error` from the latest scheduled check |
| Last Setup Check            | `Last_Health_Checked_At__c` | Latest scheduled-check timestamp                                   |
| Last Check Details          | `Last_Health_Codes__c`      | Saved results from the latest setup check                          |
| Last Checked Version        | `Last_Health_Version__c`    | Published version checked by the scheduled job                     |

## Prompt Data Set (`Prompt_Context_Source__c`)

| Field label                | API name                 | Purpose                                                |
| -------------------------- | ------------------------ | ------------------------------------------------------ |
| Prompt Template            | `Prompt_Template__c`     | Template that owns this data set                       |
| Reference Name             | `Reference_Name__c`      | Alias used by merge syntax                             |
| Records to Include         | `Source_Mode__c`         | `RELATED` or `REFERENCE`                               |
| Result Type                | `Result_Mode__c`         | Records or one calculated value                        |
| Related Object             | `Related_Object__c`      | Salesforce object read for this data set               |
| Current Record Match Field | `Root_Field__c`          | Current-record value used for matching                 |
| Related Record Match Field | `Correlation_Field__c`   | Queried-object field matched to the current record     |
| Prompt Fields              | `Selected_Fields__c`     | Fields included in the prompt                          |
| Filter Settings (Managed)  | `Filters_JSON__c`        | Saved filter rules managed by Prompt Builder           |
| How Filter Groups Combine  | `Filter_Group_Join__c`   | `AND` or `OR` between named groups                     |
| Sort Settings (Managed)    | `Sort_JSON__c`           | Saved sorting choices managed by Prompt Builder        |
| Maximum Records            | `Max_Rows__c`            | Per-data-set record limit; default 10                  |
| Calculation                | `Aggregate_Operation__c` | Count, sum, average, minimum, or maximum               |
| Field to Calculate         | `Aggregate_Field__c`     | Field used for a calculation other than count          |
| Order                      | `Sequence__c`            | Order used to process data sets                        |
| Include This Data Set      | `Active__c`              | Whether validation and generation include the data set |

## Published versions

`Prompt_Template_Version__c` stores the Salesforce object, prompt text, version number, version
key, contract version, syntax version, published version signature, and publication time.
`Prompt_Context_Source_Version__c` stores the corresponding fixed data set settings. Validation
rules prevent changes after
publication. Restore creates a new Draft without changing published history.

## Prompt Generation Measurement (`Prompt_Context_Metric__e`)

| Field label           | API name                   | Content                               |
| --------------------- | -------------------------- | ------------------------------------- |
| Channel               | `Channel__c`               | Entry point such as Flow or Apex      |
| Outcome Code          | `Outcome_Code__c`          | Stable result reason code             |
| Duration Milliseconds | `Duration_Milliseconds__c` | End-to-end elapsed time               |
| Template ID           | `Template_Id__c`           | Template identity when available      |
| Template Version      | `Template_Version__c`      | Published version when available      |
| Request ID            | `Correlation_Id__c`        | Privacy-safe identity for one request |

The event never contains a Record Id, customer field value, generated prompt, Salesforce search,
or filter value.
