/** Tests approved service setup validation without reading credentials. */
@isTest
private class PromptContextProviderSettingsTest {
  @isTest
  static void shouldReturnACompleteActiveSetup() {
    PromptContextProviderSettings.useForTest('Approved_Bedrock');

    PromptContextProviderSettings.Settings settings = PromptContextProviderSettings.requireActive(
      'Approved_Bedrock'
    );

    Assert.areEqual('Approved_Aws_Service', settings.namedCredential);
    Assert.areEqual(5, settings.maximumFiles);
    Assert.isTrue(settings.supportsCitations);
  }

  @isTest
  static void shouldRejectMissingSetup() {
    try {
      PromptContextProviderSettings.requireActive('Missing_Setup');
      Assert.fail('A missing approved service setup must stop the request.');
    } catch (PromptContextException exceptionValue) {
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        exceptionValue.reasonCode
      );
    }
  }

  @isTest
  static void shouldRejectASetupWhoseReviewIsTooOld() {
    PromptContextProviderSettings.useForTest('Old_Review');
    PromptContextProviderSettings.settingsForTest
      .get('Old_Review')
      .lastVerifiedDate = Date.today()
      .addDays(-PromptContextContract.PROVIDER_REVIEW_MAX_AGE_DAYS - 1);

    try {
      PromptContextProviderSettings.requireActive('Old_Review');
      Assert.fail('An outdated service review must stop file preparation.');
    } catch (PromptContextException exceptionValue) {
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        exceptionValue.reasonCode
      );
    }
  }

  @isTest
  static void shouldMapEveryReviewedCustomMetadataValue() {
    Prompt_Context_Provider__mdt recordValue = new Prompt_Context_Provider__mdt(
      DeveloperName = 'Mapped_Setup',
      Active__c = true,
      Named_Credential__c = 'Approved_Aws_Service',
      Service_Path__c = '/prompt-inputs',
      Bedrock_Region__c = 'us-east-1',
      Model_Id__c = 'approved-model',
      Bedrock_Api__c = 'Converse',
      Endpoint_Class__c = 'bedrock-runtime',
      Document_Input_Supported__c = true,
      S3_Source_Supported__c = true,
      Allowed_File_Formats__c = 'pdf,txt',
      Maximum_Files__c = 5,
      Maximum_File_Bytes__c = 4500000,
      Maximum_Pdf_Pages__c = 100,
      Supports_Citations__c = true,
      Last_Verified_Date__c = Date.today(),
      Review_Reference__c = 'SEC-100'
    );

    PromptContextProviderSettings.Settings settings = PromptContextProviderSettings.mapRecord(
      recordValue
    );

    Assert.areEqual('Mapped_Setup', settings.developerName);
    Assert.areEqual(5, settings.maximumFiles);
    Assert.areEqual(4500000, settings.maximumFileBytes);
    Assert.areEqual(100, settings.maximumPdfPages);
    Assert.areEqual('SEC-100', settings.reviewReference);
  }
}
