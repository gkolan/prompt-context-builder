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
| Prompt Text                 | `Template_Body__c`          | Editable merge-language text                                       |
| Status                      | `Status__c`                 | `Draft`, `Published`, or `Inactive`                                |
| Published Version           | `Version__c`                | Current published version number                                   |
| Published Version Signature | `Fingerprint__c`            | SHA-256 identity of the published configuration                    |
| Last Published              | `Published_At__c`           | Publication timestamp                                              |
| Last Setup Check Result     | `Last_Health_Status__c`     | `Healthy`, `Unhealthy`, or `Error` from the latest scheduled check |
| Last Setup Check            | `Last_Health_Checked_At__c` | Latest scheduled-check timestamp                                   |
| Last Check Details          | `Last_Health_Codes__c`      | Saved results from the latest setup check                          |
| Last Checked Version        | `Last_Health_Version__c`    | Published version checked by the scheduled job                     |
| File Input Mode             | `File_Input_Mode__c`        | Disabled, user selection, or all eligible directly linked files    |
| Maximum Files               | `Maximum_Files__c`          | Template file limit from one through five                          |
| Require File                | `Require_File__c`           | Whether preparation must include at least one eligible file        |
| Allowed File Formats        | `Allowed_File_Formats__c`   | Comma-separated formats approved for this template                 |
| Approved Service Setup      | `Provider_Profile_Key__c`   | Developer name of the reviewed Prompt Context Provider setup       |
| File Citations              | `File_Citations_Enabled__c` | Whether the reviewed service and model allow document citations    |

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
key, contract version, syntax version, published version signature, publication time, and the six
file settings listed above.
`Prompt_Context_Source_Version__c` stores the corresponding fixed data set settings. Validation
rules prevent changes after publication. Restore copies one fixed version into the editable fields
without changing published history or taking the current published version offline.

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

## Prompt Input Log (`Prompt_Input_Log__c`)

This private object is created only for `SAVE_TO_LOG`. Package code manages these fields; automation
should read the public API result instead of assembling log records directly.

| Field label              | API name                      | Purpose                                                                |
| ------------------------ | ----------------------------- | ---------------------------------------------------------------------- |
| Request Key              | `Request_Key__c`              | User-scoped hash used to make the save retry-safe                      |
| Input Verification Value | `Input_Verification_Value__c` | Hash used to detect a reused key with different input                  |
| Source Record ID         | `Source_Record_Id__c`         | Source Salesforce record Id, stored without a polymorphic lookup       |
| Prompt Template Version  | `Prompt_Template_Version__c`  | Exact published version used                                           |
| Prepared Prompt Text     | `Prompt_Text__c`              | Complete prepared prompt                                               |
| Selected Files           | `Selected_Files_JSON__c`      | Managed JSON list for zero through five exact Salesforce File versions |
| Input Format Version     | `Input_Format_Version__c`     | Stored-input format; currently `1`                                     |
| Status                   | `Status__c`                   | `Ready`, `Processing`, `Sent`, `Failed`, `Cancelled`, or `Expired`     |
| Available At             | `Available_At__c`             | Earliest time a later worker may claim the log                         |
| Processing Expires At    | `Processing_Expires_At__c`    | Time an unfinished processing claim expires                            |
| Attempt Count            | `Attempt_Count__c`            | Number of later processing attempts; starts at `0`                     |
| Last Reason Code         | `Last_Reason_Code__c`         | Stable outcome from the latest processing attempt                      |
| Retain Until             | `Retain_Until__c`             | Retention boundary; defaults to 30 days after creation                 |

## Prompt Context Provider (`Prompt_Context_Provider__mdt`)

This Custom Metadata Type holds an organization-approved service and model setup. The package ships
the type, not an active organization-specific record.

| Field label                | API name                      | Purpose                                                   |
| -------------------------- | ----------------------------- | --------------------------------------------------------- |
| Active                     | `Active__c`                   | Allows a published file-enabled template to use the setup |
| Named Credential           | `Named_Credential__c`         | Name of the approved Salesforce Named Credential          |
| Service Path               | `Service_Path__c`             | Relative path on the approved AWS service                 |
| Bedrock Region             | `Bedrock_Region__c`           | Approved AWS Region                                       |
| Model ID                   | `Model_Id__c`                 | Exact model or inference profile                          |
| Bedrock Request Type       | `Bedrock_Api__c`              | Approved request type; currently Converse                 |
| AWS Service Name           | `Endpoint_Class__c`           | Required value `bedrock-runtime`                          |
| Document Input Supported   | `Document_Input_Supported__c` | Confirms that the model accepts documents                 |
| Amazon S3 Source Supported | `S3_Source_Supported__c`      | Confirms that the model accepts temporary S3 locations    |
| Allowed File Formats       | `Allowed_File_Formats__c`     | Formats confirmed for the model                           |
| Maximum Files              | `Maximum_Files__c`            | Model limit, capped by the package at five                |
| Maximum File Bytes         | `Maximum_File_Bytes__c`       | Model limit, capped by the package at 4,500,000           |
| Maximum PDF Pages          | `Maximum_Pdf_Pages__c`        | Optional approved per-file PDF page limit                 |
| Supports Citations         | `Supports_Citations__c`       | Confirms document citation support                        |
| Last Verified Date         | `Last_Verified_Date__c`       | Date an owner confirmed the settings                      |
| Review Reference           | `Review_Reference__c`         | Approval or change record for the settings                |

The record never stores AWS secrets, file contents, prompts, temporary locations, or responses.
