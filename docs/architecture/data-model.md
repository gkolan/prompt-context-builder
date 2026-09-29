# Data model

| Object                             | Purpose                                | Lifecycle                                                     |
| ---------------------------------- | -------------------------------------- | ------------------------------------------------------------- |
| `Prompt_Template__c`               | Editable template settings             | Created, previewed, published, edited, and deactivated        |
| `Prompt_Context_Source__c`         | Editable data set settings             | Belongs to the editable template                              |
| `Prompt_Template_Version__c`       | Fixed published template version       | Created at publish time                                       |
| `Prompt_Context_Source_Version__c` | Fixed published data set settings      | Created with its template version                             |
| `Prompt_Input_Log__c`              | Complete prepared input for later work | Created only when the caller chooses Save to Prompt Input Log |
| `Prompt_Context_Metric__e`         | Privacy-safe generation measurement    | Published after generation attempts                           |

`Developer_Key__c` is the stable automation identity. Record IDs identify individual Salesforce
records and can differ between environments. A published version records its contract version,
prompt language version, version number, publication time, and version signature.

`Prompt_Input_Log__c` is private and intentionally stores the prepared prompt. It identifies the
source record as text, points to the exact published template version, and keeps selected Salesforce
File references as one managed JSON list. It does not copy file bodies. The list contains zero
through five ordered entries and pins each selected `ContentVersionId`.

The caller chooses `RETURN_TO_APEX` to avoid package DML or `SAVE_TO_LOG` to create the log. A
user-scoped, hashed Request Key makes retries safe without exposing the caller's raw key. The
measurement event never stores prompt text, file references, or customer values.

`Prompt_Context_Provider__mdt` stores administrator-reviewed service and model limits used by a
file-enabled template. It contains no password, token, temporary URL, file body, prompt, or provider
response. The setup names a Salesforce Named Credential, but this package does not include or create
that credential.
