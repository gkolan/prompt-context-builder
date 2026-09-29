/** Tests exact Salesforce File selection and hard all-or-none limits. */
@isTest
private class PromptContextFilePolicyTest {
  @TestSetup
  static void setupData() {
    PromptContextTestDataFactory.createRootRecord(true);
  }

  @isTest
  static void shouldReturnEmptySelectionWhenFilesAreDisabled() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = disabledConfig();

    Test.startTest();
    PromptContextFilePolicy.Selection selection = PromptContextFilePolicy.selectFiles(
      config,
      accountRecord.Id,
      new List<Id>()
    );
    Test.stopTest();

    Assert.areEqual(
      '[]',
      selection.selectedFilesJson,
      'Disabled file input should return an empty managed list.'
    );
    Assert.isTrue(
      selection.files.isEmpty(),
      'Disabled file input should select no files.'
    );
  }

  @isTest
  static void shouldFailLoudlyWhenSixFilesAreSelected() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    List<ContentVersion> versions = PromptContextTestDataFactory.createLinkedFiles(
      accountRecord.Id,
      6,
      'txt'
    );
    List<Id> versionIds = new List<Id>();
    for (ContentVersion versionRecord : versions) {
      versionIds.add(versionRecord.Id);
    }
    PromptContextAccess.setSendFilesForTest(true);

    Test.startTest();
    try {
      PromptContextFilePolicy.selectFiles(
        enabledConfig(5),
        accountRecord.Id,
        versionIds
      );
      Assert.fail('Six selected files must stop the complete request.');
    } catch (PromptContextException exceptionValue) {
      Assert.areEqual(
        PromptContextReasonCodes.TOO_MANY_FILES,
        exceptionValue.reasonCode,
        'The hard five-file limit should use the stable reason code.'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void shouldSerializeExactLinkedVersionsInRequestOrder() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    List<ContentVersion> versions = PromptContextTestDataFactory.createLinkedFiles(
      accountRecord.Id,
      2,
      'txt'
    );
    PromptContextAccess.setSendFilesForTest(true);

    Test.startTest();
    PromptContextFilePolicy.Selection selection = PromptContextFilePolicy.selectFiles(
      enabledConfig(5),
      accountRecord.Id,
      new List<Id>{ versions[1].Id, versions[0].Id }
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      selection.files.size(),
      'Both directly linked versions should be selected.'
    );
    Assert.areEqual(
      versions[1].Id,
      selection.files[0].contentVersionId,
      'The managed list must preserve request order.'
    );
    Assert.isTrue(
      selection.selectedFilesJson.contains(
        String.valueOf(versions[0].ContentDocumentId)
      ),
      'The managed list should contain the exact ContentDocument Id.'
    );
  }

  @isTest
  static void shouldRejectAFileLinkedToAnotherRecord() {
    Prompt_Template__c sourceRecord = PromptContextTestDataFactory.selectRootRecord();
    Prompt_Template__c otherRecord = PromptContextTestDataFactory.createRootRecord(
      true
    );
    ContentVersion versionRecord = PromptContextTestDataFactory.createLinkedFiles(
      otherRecord.Id,
      1,
      'txt'
    )[0];
    PromptContextAccess.setSendFilesForTest(true);

    Test.startTest();
    try {
      PromptContextFilePolicy.selectFiles(
        enabledConfig(5),
        sourceRecord.Id,
        new List<Id>{ versionRecord.Id }
      );
      Assert.fail(
        'A file without a direct current-record link must be rejected.'
      );
    } catch (PromptContextException exceptionValue) {
      Assert.areEqual(
        PromptContextReasonCodes.FILE_NOT_LINKED_TO_RECORD,
        exceptionValue.reasonCode,
        'The direct-link failure should use the stable reason code.'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void shouldChooseAllEligibleFilesAfterInspectingTheCollection() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextTestDataFactory.createLinkedFiles(accountRecord.Id, 5, 'png');
    PromptContextTestDataFactory.createLinkedFiles(accountRecord.Id, 1, 'txt');
    PromptContextAccess.setSendFilesForTest(true);
    PromptContextDTO.TemplateConfig config = enabledConfig(5);
    config.fileInputMode = 'ALL_ELIGIBLE';

    PromptContextFilePolicy.Selection selection = PromptContextFilePolicy.selectFiles(
      config,
      accountRecord.Id,
      new List<Id>()
    );

    Assert.areEqual(
      1,
      selection.files.size(),
      'All Eligible should count only files allowed by the published settings.'
    );
    Assert.areEqual('txt', selection.files[0].fileFormat);
  }

  @isTest
  static void shouldChooseTheFirstLimitedAllEligibleFiles() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextTestDataFactory.createLinkedFiles(accountRecord.Id, 6, 'txt');
    PromptContextAccess.setSendFilesForTest(true);
    PromptContextDTO.TemplateConfig config = enabledConfig(5);
    config.fileInputMode = 'ALL_ELIGIBLE';

    PromptContextFilePolicy.Selection selection = PromptContextFilePolicy.selectFiles(
      config,
      accountRecord.Id,
      new List<Id>()
    );

    Assert.areEqual(
      5,
      selection.files.size(),
      'All Eligible should deterministically include files up to the published limit.'
    );
  }

  @isTest
  static void shouldPageEligibleFilesWithStableCursor() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextTestDataFactory.createLinkedFiles(accountRecord.Id, 51, 'txt');
    PromptContextAccess.setSendFilesForTest(true);

    Test.startTest();
    PromptContextDTO.FileChoicePage firstPage = PromptContextFilePolicy.getFileChoices(
      enabledConfig(5),
      accountRecord.Id,
      null,
      null
    );
    PromptContextDTO.FileChoicePage secondPage = PromptContextFilePolicy.getFileChoices(
      enabledConfig(5),
      accountRecord.Id,
      firstPage.nextTitle,
      firstPage.nextId
    );
    Test.stopTest();

    Assert.areEqual(50, firstPage.items.size());
    Assert.isTrue(firstPage.hasMore);
    Assert.isNotNull(firstPage.nextTitle);
    Assert.isNotNull(firstPage.nextId);
    Assert.areEqual(1, secondPage.items.size());
    Assert.isFalse(secondPage.hasMore);
  }

  @isTest
  static void shouldRejectASelectedFileVersionThatIsNoLongerLatest() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.createRootRecord(
      true
    );
    ContentVersion original = PromptContextTestDataFactory.createLinkedFiles(
      accountRecord.Id,
      1,
      'txt'
    )[0];
    insert new ContentVersion(
      ContentDocumentId = original.ContentDocumentId,
      Title = 'Replacement',
      PathOnClient = 'replacement.txt',
      VersionData = Blob.valueOf('new content')
    );
    PromptContextAccess.setSendFilesForTest(true);

    try {
      PromptContextFilePolicy.selectFiles(
        enabledConfig(5),
        accountRecord.Id,
        new List<Id>{ original.Id }
      );
      Assert.fail('A stale exact ContentVersion must not be delivered.');
    } catch (PromptContextException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.FILE_VERSION_STALE,
        expected.reasonCode
      );
    }
  }

  @isTest
  static void shouldUseProviderFileCountAsAnEffectiveLowerLimit() {
    PromptContextDTO.TemplateConfig config = enabledConfig(5);
    PromptContextProviderSettings.settingsForTest
      .get('Approved_Bedrock')
      .maximumFiles = 2;

    PromptContextFilePolicy.validateConfiguration(config);

    Assert.areEqual(
      2,
      PromptContextProviderSettings.settingsForTest
        .get('Approved_Bedrock')
        .maximumFiles,
      'A lower approved-service limit should narrow execution without invalidating the template.'
    );
  }

  private static PromptContextDTO.TemplateConfig disabledConfig() {
    return new PromptContextDTO.TemplateConfig();
  }

  private static PromptContextDTO.TemplateConfig enabledConfig(
    Integer maxFiles
  ) {
    PromptContextProviderSettings.useForTest('Approved_Bedrock');
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.fileInputMode = 'USER_SELECT';
    config.maxFiles = maxFiles;
    config.allowedFileFormats = 'pdf,txt';
    config.providerProfileKey = 'Approved_Bedrock';
    return config;
  }
}
