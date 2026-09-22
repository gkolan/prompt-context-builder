# Data model

| Object                             | Purpose                             | Lifecycle                                      |
| ---------------------------------- | ----------------------------------- | ---------------------------------------------- |
| `Prompt_Template__c`               | Editable template and Draft prompt  | Created, previewed, published, and deactivated |
| `Prompt_Context_Source__c`         | Editable data set settings          | Belongs to a Draft template                    |
| `Prompt_Template_Version__c`       | Fixed published template version    | Created at publish time                        |
| `Prompt_Context_Source_Version__c` | Fixed published data set settings   | Created with its template version              |
| `Prompt_Context_Metric__e`         | Privacy-safe generation measurement | Published after generation attempts            |

`Developer_Key__c` is the stable automation identity. Record IDs identify individual Salesforce
records and can differ between environments. A published version records its contract version,
prompt language version, version number, publication time, and version signature.

Generated prompts and customer values are not stored in these objects or in the measurement event.
