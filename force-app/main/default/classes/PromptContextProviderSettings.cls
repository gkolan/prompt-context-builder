/** Reads and validates approved provider and model settings without exposing credentials. */
public with sharing class PromptContextProviderSettings {
  @TestVisible
  private static Map<String, Settings> settingsForTest;

  public class Settings {
    public String developerName;
    public Boolean active;
    public String namedCredential;
    public String servicePath;
    public String region;
    public String modelId;
    public String bedrockApi;
    public String endpointClass;
    public Boolean documentInputSupported;
    public Boolean s3SourceSupported;
    public String allowedFileFormats;
    public Integer maximumFiles;
    public Integer maximumFileBytes;
    public Boolean supportsCitations;
    public Integer maximumPdfPages;
    public Date lastVerifiedDate;
    public String reviewReference;
  }

  /** Returns one active and structurally complete setup or stops publication and execution. */
  public static Settings requireActive(String developerName) {
    Settings settings = settingsForTest?.get(developerName);
    if (settings == null) {
      Prompt_Context_Provider__mdt recordValue = Prompt_Context_Provider__mdt.getInstance(
        developerName
      );
      if (recordValue != null) {
        settings = mapRecord(recordValue);
      }
    }
    if (
      settings == null ||
      settings.active != true ||
      String.isBlank(settings.namedCredential) ||
      String.isBlank(settings.servicePath) ||
      !settings.servicePath.startsWith('/') ||
      String.isBlank(settings.region) ||
      String.isBlank(settings.modelId) ||
      settings.bedrockApi != 'Converse' ||
      settings.endpointClass != 'bedrock-runtime' ||
      settings.documentInputSupported != true ||
      settings.s3SourceSupported != true ||
      settings.maximumFiles == null ||
      settings.maximumFiles < 1 ||
      settings.maximumFiles > PromptContextContract.MAX_SELECTED_FILES ||
      settings.maximumFileBytes == null ||
      settings.maximumFileBytes < 1 ||
      settings.maximumFileBytes > PromptContextContract.MAX_FILE_BYTES ||
      String.isBlank(settings.allowedFileFormats) ||
      (settings.maximumPdfPages != null &&
      settings.maximumPdfPages < 1) ||
      settings.lastVerifiedDate == null ||
      settings.lastVerifiedDate > Date.today() ||
      settings.lastVerifiedDate <
      Date.today()
        .addDays(-PromptContextContract.PROVIDER_REVIEW_MAX_AGE_DAYS) ||
      String.isBlank(settings.reviewReference)
    ) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The approved service setup is missing, inactive, or incomplete.'
      );
    }
    return settings;
  }

  @TestVisible
  private static void useForTest(String developerName) {
    Settings settings = new Settings();
    settings.developerName = developerName;
    settings.active = true;
    settings.namedCredential = 'Approved_Aws_Service';
    settings.servicePath = '/prompt-inputs';
    settings.region = 'us-east-1';
    settings.modelId = 'approved-model';
    settings.bedrockApi = 'Converse';
    settings.endpointClass = 'bedrock-runtime';
    settings.documentInputSupported = true;
    settings.s3SourceSupported = true;
    settings.allowedFileFormats = 'pdf,txt';
    settings.maximumFiles = 5;
    settings.maximumFileBytes = PromptContextContract.MAX_FILE_BYTES;
    settings.supportsCitations = true;
    settings.maximumPdfPages = 100;
    settings.lastVerifiedDate = Date.today();
    settings.reviewReference = 'Test approval';
    settingsForTest = new Map<String, Settings>{ developerName => settings };
  }

  @TestVisible
  private static Settings mapRecord(Prompt_Context_Provider__mdt recordValue) {
    Settings settings = new Settings();
    settings.developerName = recordValue.DeveloperName;
    settings.active = recordValue.Active__c;
    settings.namedCredential = recordValue.Named_Credential__c;
    settings.servicePath = recordValue.Service_Path__c;
    settings.region = recordValue.Bedrock_Region__c;
    settings.modelId = recordValue.Model_Id__c;
    settings.bedrockApi = recordValue.Bedrock_Api__c;
    settings.endpointClass = recordValue.Endpoint_Class__c;
    settings.documentInputSupported = recordValue.Document_Input_Supported__c;
    settings.s3SourceSupported = recordValue.S3_Source_Supported__c;
    settings.allowedFileFormats = recordValue.Allowed_File_Formats__c;
    settings.maximumFiles = recordValue.Maximum_Files__c == null
      ? null
      : Integer.valueOf(recordValue.Maximum_Files__c);
    settings.maximumFileBytes = recordValue.Maximum_File_Bytes__c == null
      ? null
      : Integer.valueOf(recordValue.Maximum_File_Bytes__c);
    settings.supportsCitations = recordValue.Supports_Citations__c;
    settings.maximumPdfPages = recordValue.Maximum_Pdf_Pages__c == null
      ? null
      : Integer.valueOf(recordValue.Maximum_Pdf_Pages__c);
    settings.lastVerifiedDate = recordValue.Last_Verified_Date__c;
    settings.reviewReference = recordValue.Review_Reference__c;
    return settings;
  }

  private PromptContextProviderSettings() {
  }
}
