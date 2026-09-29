/** Tests retry, conflict, and atomic-input behavior for Prompt Input Log saves. */
@isTest
private class PromptContextInputLogServiceTest {
  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(saved.id, rootRecord.Id);
    }
  }

  @isTest
  static void shouldReuseOneLogWhenBatchRepeatsSameInput() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputLogService.SaveRequest first = requestFor(
        'same-work',
        'Prepared prompt'
      );
      PromptContextInputLogService.SaveRequest second = requestFor(
        'same-work',
        'Prepared prompt'
      );

      Test.startTest();
      List<PromptContextInputLogService.SaveResult> results = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ first, second }
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        results.size(),
        'Both save requests should receive a result.'
      );
      Assert.isTrue(
        results[0].success,
        'The first complete input should be saved.'
      );
      Assert.isTrue(
        results[1].success,
        'An identical duplicate should reuse the save.'
      );
      Assert.areEqual(
        results[0].inputLogId,
        results[1].inputLogId,
        'Identical duplicate input should point to the same log.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'An identical batch duplicate should create only one log.'
      );
    }
  }

  @isTest
  static void shouldFailConflictingItemWhenBatchReusesKeyForDifferentInput() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputLogService.SaveRequest first = requestFor(
        'conflicting-work',
        'First prepared prompt'
      );
      PromptContextInputLogService.SaveRequest second = requestFor(
        'conflicting-work',
        'Different prepared prompt'
      );

      Test.startTest();
      List<PromptContextInputLogService.SaveResult> results = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ first, second }
      );
      Test.stopTest();

      Assert.isTrue(
        results[0].success,
        'The first complete input should be saved.'
      );
      Assert.isFalse(
        results[1].success,
        'The conflicting duplicate should fail.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.REQUEST_KEY_CONFLICT,
        results[1].reasonCode,
        'The conflict should return the stable request-key reason.'
      );
      Assert.isNull(
        results[1].inputLogId,
        'A conflicting item must not point to the saved log.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'Only the first complete input should be stored.'
      );
    }
  }

  @isTest
  static void shouldFailIncompleteInputWithoutDml() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputLogService.SaveRequest incomplete = requestFor(
        'incomplete-work',
        null
      );

      Test.startTest();
      List<PromptContextInputLogService.SaveResult> results = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ incomplete }
      );
      Test.stopTest();

      Assert.isFalse(
        results[0].success,
        'An incomplete input should fail closed.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.INPUT_LOG_SAVE_FAILED,
        results[0].reasonCode,
        'An incomplete input should return the safe save-failure reason.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'An incomplete input must not create a partial log.'
      );
    }
  }

  @isTest
  static void shouldDefaultMissingResponseIndexToInputPosition() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputLogService.SaveRequest request = requestFor(
        'default-response-index',
        'Prepared prompt'
      );
      request.responseIndex = null;

      PromptContextInputLogService.SaveResult result = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ request }
      )[0];

      Assert.isTrue(result.success);
      Assert.areEqual(0, result.responseIndex);
    }
  }

  @isTest
  static void shouldRecoverAnIdenticalRequestAfterTheLogBecomesInvisible() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    PromptContextInputLogService.SaveRequest request;
    Id originalLogId;
    System.runAs(configurator) {
      request = requestFor('invisible-retry', 'Prepared prompt');
      originalLogId = PromptContextInputLogService.save(
          new List<PromptContextInputLogService.SaveRequest>{ request }
        )[0]
        .inputLogId;
    }
    update new Prompt_Input_Log__c(
      Id = originalLogId,
      OwnerId = UserInfo.getUserId()
    );

    System.runAs(configurator) {
      PromptContextInputLogService.SaveResult retried = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ request }
      )[0];

      Assert.isTrue(retried.success, retried.message);
      Assert.areEqual(
        originalLogId,
        retried.inputLogId,
        'The user-scoped key and matching digest should recover idempotent success.'
      );
    }
  }

  @isTest
  static void shouldRejectMalformedOrUnsafeFileDetails() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      List<PromptContextInputLogService.SaveRequest> requests = new List<PromptContextInputLogService.SaveRequest>();
      PromptContextInputLogService.SaveRequest notAnArray = requestFor(
        'bad-json',
        'Prepared prompt'
      );
      notAnArray.selectedFilesJson = '{"contentVersionId":"068000000000001"}';
      requests.add(notAnArray);
      PromptContextInputLogService.SaveRequest containsUrl = requestFor(
        'unsafe-json',
        'Prepared prompt'
      );
      containsUrl.selectedFilesJson = '[{"contentVersionId":"068000000000001","fileFormat":"pdf","sizeInBytes":10,"temporaryUrl":"https://example.invalid"}]';
      requests.add(containsUrl);

      List<PromptContextInputLogService.SaveResult> results = PromptContextInputLogService.save(
        requests
      );

      Assert.areEqual(
        PromptContextReasonCodes.INVALID_FILE_SELECTION,
        results[0].reasonCode
      );
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_FILE_SELECTION,
        results[1].reasonCode
      );
      Assert.areEqual(0, [SELECT COUNT() FROM Prompt_Input_Log__c]);
    }
  }

  @isTest
  static void shouldRejectMoreThanFiveFileEntries() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputLogService.SaveRequest request = requestFor(
        'six-files',
        'Prepared prompt'
      );
      List<Object> files = new List<Object>();
      for (Integer index = 0; index < 6; index++) {
        files.add(
          new Map<String, Object>{
            'contentVersionId' => '06800000000000' + index,
            'fileFormat' => 'pdf',
            'sizeInBytes' => 10
          }
        );
      }
      request.selectedFilesJson = JSON.serialize(files);

      PromptContextInputLogService.SaveResult result = PromptContextInputLogService.save(
        new List<PromptContextInputLogService.SaveRequest>{ request }
      )[0];

      Assert.areEqual(
        PromptContextReasonCodes.TOO_MANY_FILES,
        result.reasonCode
      );
      Assert.areEqual(0, [SELECT COUNT() FROM Prompt_Input_Log__c]);
    }
  }

  private static PromptContextInputLogService.SaveRequest requestFor(
    String requestKey,
    String promptText
  ) {
    PromptContextInputLogService.SaveRequest request = new PromptContextInputLogService.SaveRequest();
    request.responseIndex = 0;
    request.requestKey = requestKey;
    request.rootRecordId = PromptContextTestDataFactory.selectRootRecord().Id;
    request.templateVersionId = [
      SELECT Id
      FROM Prompt_Template_Version__c
      LIMIT 1
    ]
    .Id;
    request.promptText = promptText;
    request.selectedFilesJson = '[]';
    return request;
  }
}
