/** Tests the stable bulk/Flow response contract and per-record failure isolation. */
@isTest
private class PromptContextInputApiTest {
  private class SensitiveTestException extends Exception {
  }

  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    PromptContextTestDataFactory.createRestrictedGeneratorUser();
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
  static void shouldPreserveOrderAndIsolateInvalidItems() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      insert new Prompt_Context_Source__c(
        Prompt_Template__c = accountRecord.Id,
        Reference_Name__c = 'Beta',
        Related_Object__c = 'bea@example.com',
        Source_Mode__c = 'RELATED',
        Result_Mode__c = 'RECORDS',
        Filter_Group_Join__c = 'AND'
      );
      Prompt_Template__c templateRecord = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      PromptContextInputApi.Request goodRequest = new PromptContextInputApi.Request();
      goodRequest.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      goodRequest.templateId = templateRecord.Id;
      goodRequest.recordId = accountRecord.Id;
      PromptContextInputApi.Request invalidRequest = new PromptContextInputApi.Request();
      invalidRequest.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      invalidRequest.templateId = templateRecord.Id;

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ goodRequest, invalidRequest }
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        responses.size(),
        'Every input must have one ordered response.'
      );
      Assert.isTrue(
        responses[0].success,
        'The valid record should build independently.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.SUCCESS,
        responses[0].reasonCode,
        'A successful request should return the stable success code.'
      );
      Assert.isNotNull(
        responses[0].prompt,
        'Successful results should contain the prompt.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.SOURCE_TRUNCATED,
        responses[0].warningCodes,
        'Successful limited results must expose warning codes to Flow and Apex callers.'
      );
      Assert.isTrue(
        responses[0].warningMessage.contains('Only the first 2 were included.'),
        'Successful limited results must explain the warning without changing the success outcome.'
      );
      Assert.isFalse(
        responses[1].success,
        'A malformed item must fail without failing its neighbor.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_REQUEST,
        responses[1].reasonCode,
        'A request without a record should fail as an invalid request.'
      );
      Assert.isNull(
        responses[1].warningCodes,
        'Failed results must not retain successful-generation warnings.'
      );
      Assert.isNotNull(
        responses[0].correlationId,
        'Every result should be traceable without logging prompt data.'
      );
    }
  }

  @isTest
  static void shouldResolvePublishedTemplateByStableDeveloperKey() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      PromptContextInputApi.Request request = new PromptContextInputApi.Request();
      request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      request.templateDeveloperKey = templateRecord.Developer_Key__c;
      request.recordId = accountRecord.Id;

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        responses.size(),
        'One request should return one result.'
      );
      Assert.isTrue(
        responses[0].success,
        'A stable developer key should resolve a published template.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.SUCCESS,
        responses[0].reasonCode,
        'A key-based request should return the stable success code.'
      );
      Assert.isNotNull(
        responses[0].prompt,
        'A successful result should contain prompt text.'
      );
      Assert.areEqual(
        PromptContextContract.CONTRACT_VERSION,
        responses[0].contractVersion,
        'The result should expose the current contract version.'
      );
    }
  }

  @isTest
  static void shouldCreateNoLogWhenReturningToApex() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForDelivery(
        PromptContextInputApi.RETURN_TO_APEX,
        null
      );

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.isTrue(results[0].success, 'Return to Apex should prepare input.');
      Assert.isNull(
        results[0].inputLogId,
        'Return to Apex must not create a Prompt Input Log.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'Return to Apex must leave saved-input storage unchanged.'
      );
    }
  }

  @isTest
  static void shouldSaveOneCompleteLogWhenSaveRequested() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'save-one-complete-input'
      );

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.isTrue(results[0].success, 'Save to log should succeed.');
      Assert.isNotNull(results[0].inputLogId, 'The saved log ID is required.');
      Prompt_Input_Log__c savedLog = [
        SELECT
          Source_Record_Id__c,
          Prompt_Template_Version__c,
          Prompt_Text__c,
          Selected_Files_JSON__c,
          Input_Format_Version__c,
          Status__c,
          Attempt_Count__c
        FROM Prompt_Input_Log__c
        WHERE Id = :results[0].inputLogId
      ];
      Assert.areEqual(
        String.valueOf(request.recordId),
        savedLog.Source_Record_Id__c,
        'The log should identify the source record.'
      );
      Assert.isNotNull(
        savedLog.Prompt_Template_Version__c,
        'Exact template version is required.'
      );
      Assert.areEqual(
        results[0].prompt,
        savedLog.Prompt_Text__c,
        'The log should store the exact prepared prompt.'
      );
      Assert.areEqual(
        '[]',
        savedLog.Selected_Files_JSON__c,
        'A request without files should store an empty managed file list.'
      );
      Assert.areEqual(
        PromptContextContract.INPUT_FORMAT_VERSION,
        savedLog.Input_Format_Version__c,
        'The log should identify its input format.'
      );
      Assert.areEqual(
        'Ready',
        savedLog.Status__c,
        'A new log should be ready.'
      );
      Assert.areEqual(
        0,
        savedLog.Attempt_Count__c,
        'A new log should have no attempts.'
      );
    }
  }

  @isTest
  static void shouldSaveExactSelectedFileDetailsThroughTheCommonEntry() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      List<ContentVersion> files = PromptContextTestDataFactory.createLinkedFiles(
        accountRecord.Id,
        2,
        'txt'
      );
      PromptContextProviderSettings.useForTest('Approved_Bedrock');
      PromptContextAccess.setSendFilesForTest(true);
      PromptContextDTO.TemplateConfig fileConfig = PromptContextTestDataFactory.createTwoSourceConfig();
      fileConfig.name = 'Account Context With Files';
      fileConfig.fileInputMode = 'USER_SELECT';
      fileConfig.maxFiles = 5;
      fileConfig.allowedFileFormats = 'pdf,txt';
      fileConfig.providerProfileKey = 'Approved_Bedrock';
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        fileConfig
      );
      PromptTemplateService.publish(saved.id, accountRecord.Id);
      PromptContextInputApi.Request request = new PromptContextInputApi.Request();
      request.deliveryChoice = PromptContextInputApi.SAVE_TO_LOG;
      request.requestKey = 'save-two-exact-files';
      request.templateId = saved.id;
      request.recordId = accountRecord.Id;
      request.selectedContentVersionIds = new List<Id>{
        files[1].Id,
        files[0].Id
      };

      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );

      Assert.isTrue(results[0].success, results[0].message);
      Prompt_Input_Log__c savedLog = [
        SELECT Selected_Files_JSON__c
        FROM Prompt_Input_Log__c
        WHERE Id = :results[0].inputLogId
      ];
      List<Object> selected = (List<Object>) JSON.deserializeUntyped(
        savedLog.Selected_Files_JSON__c
      );
      Assert.areEqual(2, selected.size());
      Assert.areEqual(
        String.valueOf(files[1].Id),
        (String) ((Map<String, Object>) selected[0]).get('contentVersionId'),
        'The Prompt Input Log must preserve the selected exact-version order.'
      );
    }
  }

  @isTest
  static void shouldReuseLogWhenSameRequestIsRetried() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request firstRequest = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'repeat-same-input'
      );
      PromptContextInputApi.Request secondRequest = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'repeat-same-input'
      );

      Test.startTest();
      List<PromptContextInputApi.Result> firstResults = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ firstRequest }
      );
      List<PromptContextInputApi.Result> secondResults = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ secondRequest }
      );
      Test.stopTest();

      Assert.areEqual(
        firstResults[0].inputLogId,
        secondResults[0].inputLogId,
        'The same request key and input should reuse the original log.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'A safe retry should reuse the original log.'
      );
    }
  }

  @isTest
  static void shouldKeepTheTemplateVersionInTheDiagnosticSummaryOfASaveConflict() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextAccess.setDiagnosticsForTest(true);
      PromptContextInputApi.Request firstRequest = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'reused-for-other-input'
      );
      PromptContextInputApi.Request otherInput = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'reused-for-other-input'
      );
      // Templates are also Prompt_Template__c records, so the published one is a different root.
      otherInput.recordId = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ]
      .Id;

      Test.startTest();
      PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ firstRequest }
      );
      PromptContextInputApi.Result conflict = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ otherInput }
      )[0];
      Test.stopTest();

      Assert.areEqual(
        PromptContextReasonCodes.REQUEST_KEY_CONFLICT,
        conflict.reasonCode
      );
      Assert.isTrue(
        conflict.diagnosticSummary.contains('templateVersion=1'),
        'Support still needs the version that failed: ' +
        conflict.diagnosticSummary
      );
    }
  }

  @isTest
  static void shouldAcceptADeliveryChoiceInAnyLetterCase() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request saved = requestForDelivery(
        ' save_to_log ',
        'any-case-save'
      );
      PromptContextInputApi.Request returned = requestForDelivery(
        'Return_To_Apex',
        null
      );

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ saved, returned }
      );
      Test.stopTest();

      Assert.isTrue(results[0].success, results[0].reasonCode);
      Assert.isNotNull(results[0].inputLogId, 'The save choice must save.');
      Assert.isTrue(results[1].success, results[1].reasonCode);
      Assert.isNull(results[1].inputLogId, 'The return choice must not save.');
    }
  }

  @isTest
  static void shouldRejectRequestWhenDeliveryChoiceIsMissing() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForDelivery(null, null);

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.isFalse(results[0].success, 'Missing delivery choice must fail.');
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_DELIVERY_CHOICE,
        results[0].reasonCode,
        'A missing delivery choice should return a stable reason code.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'An invalid delivery choice must not create a log.'
      );
    }
  }

  @isTest
  static void shouldPreserveRequestIdentityWhenDeliveryPreflightFails() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        null
      );
      request.templateId = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ]
      .Id;

      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );

      Assert.areEqual(
        PromptContextReasonCodes.REQUEST_KEY_REQUIRED,
        results[0].reasonCode,
        'The preflight failure should retain its stable reason.'
      );
      Assert.areEqual(
        request.templateId,
        results[0].templateId,
        'Flow must be able to correlate the failure to its template.'
      );
      Assert.areEqual(
        request.recordId,
        results[0].recordId,
        'Flow must be able to correlate the failure to its record.'
      );
    }
  }

  @isTest
  static void shouldRejectSaveWhenSavePermissionIsMissing() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      PromptContextAccess.setSaveInputForTest(false);
      PromptContextInputApi.Request request = requestForDelivery(
        PromptContextInputApi.SAVE_TO_LOG,
        'not-authorized-to-save'
      );

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.isFalse(results[0].success, 'Save permission must be separate.');
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        results[0].reasonCode,
        'A user without save permission should receive a safe authorization result.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'A denied save request must not create a log.'
      );
    }
  }

  @isTest
  static void shouldRejectGenerationWithoutCapability() {
    PromptContextAccess.setGenerateForTest(false);
    try {
      PromptContextInputApi.prepare(new List<PromptContextInputApi.Request>());
      Assert.fail('Generation must require the explicit custom permission.');
    } catch (PromptContextAccess.AuthorizationException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        expected.reasonCode,
        'The authorization exception should expose only the stable reason code.'
      );
    }
  }

  @isTest
  static void shouldReturnRecordAccessReasonWithoutFailingNeighbor() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      PromptContextInputApi.Request missing = new PromptContextInputApi.Request();
      missing.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      missing.templateDeveloperKey = templateRecord.Developer_Key__c;
      missing.recordId = PromptContextTestDataFactory.missingRootRecordId();
      PromptContextInputApi.Request valid = new PromptContextInputApi.Request();
      valid.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      valid.templateDeveloperKey = templateRecord.Developer_Key__c;
      valid.recordId = accountRecord.Id;

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ missing, valid }
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        responses.size(),
        'Both records should receive a result.'
      );
      Assert.isFalse(
        responses[0].success,
        'The inaccessible record should fail.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE,
        responses[0].reasonCode,
        'The inaccessible record should return the stable access reason.'
      );
      Assert.isTrue(
        responses[1].success,
        'The accessible neighbor should still succeed.'
      );
    }
  }

  @isTest
  static void shouldRejectCollectionsAboveTheHardLimit() {
    PromptContextAccess.setGenerateForTest(true);
    List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
    for (
      Integer index = 0;
      index <= PromptContextContract.MAX_RECORDS_PER_REQUEST;
      index++
    ) {
      requests.add(new PromptContextInputApi.Request());
    }
    try {
      PromptContextInputApi.prepare(requests);
      Assert.fail(
        'The hard request limit must be enforced before record queries.'
      );
    } catch (PromptContextException expected) {
      Assert.isTrue(
        expected.getMessage().contains('at most'),
        'The hard-limit message should explain the maximum request size.'
      );
    }
  }

  @isTest
  static void shouldFailClosedForInaccessibleRootRecord() {
    User restrictedUser = PromptContextTestDataFactory.createRestrictedGeneratorUser();
    String developerKey = [
      SELECT Developer_Key__c
      FROM Prompt_Template__c
      WHERE Status__c = 'Published'
      LIMIT 1
    ]
    .Developer_Key__c;
    Id accountId = PromptContextTestDataFactory.missingRootRecordId();
    System.runAs(restrictedUser) {
      PromptContextInputApi.Request request = new PromptContextInputApi.Request();
      request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      request.templateDeveloperKey = developerKey;
      request.recordId = accountId;

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        responses.size(),
        'One request should return one result.'
      );
      Assert.isFalse(
        responses[0].success,
        'An inaccessible root record should fail closed.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE,
        responses[0].reasonCode,
        'Missing record access should return the stable record-access reason.'
      );
      Assert.isNull(
        responses[0].prompt,
        'A failed result must not expose prompt text.'
      );
    }
  }

  @isTest
  static void shouldAdmitOnlyTheBulkRecordsThatFitTransactionCapacity() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      List<Prompt_Template__c> accounts = PromptContextTestDataFactory.createRootRecords(
        35
      );
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
      for (Prompt_Template__c accountRecord : accounts) {
        PromptContextInputApi.Request request = new PromptContextInputApi.Request();
        request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
        request.templateDeveloperKey = templateRecord.Developer_Key__c;
        request.recordId = accountRecord.Id;
        requests.add(request);
      }

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
        requests
      );
      Test.stopTest();

      Integer successCount = 0;
      Assert.areEqual(
        requests.size(),
        responses.size(),
        'Every bulk request should receive an ordered result.'
      );
      for (Integer index = 0; index < responses.size(); index++) {
        Assert.areEqual(
          requests[index].recordId,
          responses[index].recordId,
          'Each response should stay aligned with its input record.'
        );
        if (responses[index].success) {
          successCount++;
        }
      }
      Assert.areEqual(
        requests.size(),
        successCount,
        'A 35-record request should use grouped reads and prepare every visible record.'
      );
    }
  }

  @isTest
  static void shouldGateBoundedDiagnosticsAndHideUnexpectedErrorDetails() {
    PromptContextAccess.setGenerateForTest(true);
    PromptContextInputApi.Request invalidRequest = new PromptContextInputApi.Request();
    invalidRequest.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;

    PromptContextAccess.setDiagnosticsForTest(false);
    List<PromptContextInputApi.Result> ordinaryResponses = PromptContextInputApi.prepare(
      new List<PromptContextInputApi.Request>{ invalidRequest }
    );
    PromptContextAccess.setDiagnosticsForTest(true);
    List<PromptContextInputApi.Result> diagnosticResponses = PromptContextInputApi.prepare(
      new List<PromptContextInputApi.Request>{ invalidRequest }
    );

    Assert.isNull(
      ordinaryResponses[0].diagnosticSummary,
      'Generation permission alone must not expose diagnostics.'
    );
    Assert.isTrue(
      diagnosticResponses[0].diagnosticSummary.contains('INVALID_REQUEST'),
      'Authorized diagnostics should contain a stable outcome only.'
    );
    Assert.isTrue(
      diagnosticResponses[0].diagnosticSummary.length() <= 200,
      'Diagnostics should remain bounded.'
    );
    Assert.areEqual(
      Label.PCB_Generation_Failed,
      PromptContextTrace.safeMessage(
        new SensitiveTestException('CANARY_CUSTOMER_VALUE')
      ),
      'Unexpected exception text must never escape.'
    );
    Assert.isFalse(
      diagnosticResponses[0]
        .diagnosticSummary.contains('CANARY_CUSTOMER_VALUE'),
      'Diagnostics must not include exception or customer values.'
    );
  }

  private static PromptContextInputApi.Request requestForDelivery(
    String deliveryChoice,
    String requestKey
  ) {
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.templateDeveloperKey = [
      SELECT Developer_Key__c
      FROM Prompt_Template__c
      WHERE Status__c = 'Published'
      LIMIT 1
    ]
    .Developer_Key__c;
    request.recordId = PromptContextTestDataFactory.selectRootRecord().Id;
    request.deliveryChoice = deliveryChoice;
    request.requestKey = requestKey;
    return request;
  }
}
