/** Tests the stable bulk/Flow response contract and per-record failure isolation. */
@isTest
private class PromptContextApiTest {
  private class SensitiveTestException extends Exception {
  }

  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    PromptContextTestDataFactory.createRestrictedGeneratorUser();
    System.runAs(configurator) {
      Account accountRecord = PromptContextTestDataFactory.createAccount(true);
      PromptContextTestDataFactory.createContacts(accountRecord.Id, true);
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(saved.id, accountRecord.Id);
    }
  }

  @isTest
  static void shouldPreserveOrderAndIsolateInvalidItems() {
    User configurator = [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      Prompt_Template__c templateRecord = [
        SELECT Id
        FROM Prompt_Template__c
        LIMIT 1
      ];
      PromptContextApi.Request goodRequest = new PromptContextApi.Request();
      goodRequest.templateId = templateRecord.Id;
      goodRequest.recordId = accountRecord.Id;
      PromptContextApi.Request invalidRequest = new PromptContextApi.Request();
      invalidRequest.templateId = templateRecord.Id;

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.build(
        new List<PromptContextApi.Request>{ goodRequest, invalidRequest }
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
        responses[0].reasonCode
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
        responses[1].reasonCode
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
    User configurator = [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        LIMIT 1
      ];
      PromptContextApi.Request request = new PromptContextApi.Request();
      request.templateDeveloperKey = templateRecord.Developer_Key__c;
      request.recordId = accountRecord.Id;

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.build(
        new List<PromptContextApi.Request>{ request }
      );
      Test.stopTest();

      Assert.areEqual(1, responses.size());
      Assert.isTrue(
        responses[0].success,
        'A stable developer key should resolve a published template.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.SUCCESS,
        responses[0].reasonCode
      );
      Assert.isNotNull(responses[0].prompt);
      Assert.areEqual(
        PromptContextContract.CONTRACT_VERSION,
        responses[0].contractVersion
      );
    }
  }

  @isTest
  static void shouldRejectGenerationWithoutCapability() {
    PromptContextAccess.setGenerateForTest(false);
    try {
      PromptContextApi.build(new List<PromptContextApi.Request>());
      Assert.fail('Generation must require the explicit custom permission.');
    } catch (PromptContextAccess.AuthorizationException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        expected.reasonCode
      );
    }
  }

  @isTest
  static void shouldReturnRecordAccessReasonWithoutFailingNeighbor() {
    User configurator = [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        LIMIT 1
      ];
      PromptContextApi.Request missing = new PromptContextApi.Request();
      missing.templateDeveloperKey = templateRecord.Developer_Key__c;
      missing.recordId = Id.valueOf('001000000000000AAA');
      PromptContextApi.Request valid = new PromptContextApi.Request();
      valid.templateDeveloperKey = templateRecord.Developer_Key__c;
      valid.recordId = accountRecord.Id;

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.build(
        new List<PromptContextApi.Request>{ missing, valid }
      );
      Test.stopTest();

      Assert.areEqual(2, responses.size());
      Assert.isFalse(responses[0].success);
      Assert.areEqual(
        PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE,
        responses[0].reasonCode
      );
      Assert.isTrue(responses[1].success);
    }
  }

  @isTest
  static void shouldRejectCollectionsAboveTheHardLimit() {
    PromptContextAccess.setGenerateForTest(true);
    List<PromptContextApi.Request> requests = new List<PromptContextApi.Request>();
    for (
      Integer index = 0;
      index <= PromptContextContract.MAX_RECORDS_PER_REQUEST;
      index++
    ) {
      requests.add(new PromptContextApi.Request());
    }
    try {
      PromptContextApi.build(requests);
      Assert.fail(
        'The hard request limit must be enforced before record queries.'
      );
    } catch (PromptContextException expected) {
      Assert.isTrue(expected.getMessage().contains('at most'));
    }
  }

  @isTest
  static void shouldFailClosedForRestrictedBusinessObjectAccess() {
    User restrictedUser = [SELECT Id FROM User WHERE Alias = 'pcbmin' LIMIT 1];
    String developerKey = [
      SELECT Developer_Key__c
      FROM Prompt_Template__c
      LIMIT 1
    ]
    .Developer_Key__c;
    Id accountId = [SELECT Id FROM Account LIMIT 1].Id;
    System.runAs(restrictedUser) {
      PromptContextApi.Request request = new PromptContextApi.Request();
      request.templateDeveloperKey = developerKey;
      request.recordId = accountId;

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.build(
        new List<PromptContextApi.Request>{ request }
      );
      Test.stopTest();

      Assert.areEqual(1, responses.size());
      Assert.isFalse(responses[0].success);
      Assert.areEqual(
        PromptContextReasonCodes.OBJECT_NOT_ACCESSIBLE,
        responses[0].reasonCode
      );
      Assert.isNull(responses[0].prompt);
    }
  }

  @isTest
  static void shouldAdmitOnlyTheBulkRecordsThatFitTransactionCapacity() {
    User configurator = [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
    System.runAs(configurator) {
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        LIMIT 1
      ];
      List<Account> accounts = new List<Account>();
      for (Integer index = 0; index < 35; index++) {
        accounts.add(new Account(Name = 'Bulk prompt ' + index));
      }
      insert accounts;
      List<PromptContextApi.Request> requests = new List<PromptContextApi.Request>();
      for (Account accountRecord : accounts) {
        PromptContextApi.Request request = new PromptContextApi.Request();
        request.templateDeveloperKey = templateRecord.Developer_Key__c;
        request.recordId = accountRecord.Id;
        requests.add(request);
      }

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.build(
        requests
      );
      Test.stopTest();

      Integer successCount = 0;
      Integer budgetCount = 0;
      Assert.areEqual(requests.size(), responses.size());
      for (Integer index = 0; index < responses.size(); index++) {
        Assert.areEqual(requests[index].recordId, responses[index].recordId);
        if (responses[index].success) {
          successCount++;
        } else if (
          responses[index].reasonCode ==
          PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED
        ) {
          budgetCount++;
        }
      }
      Assert.isTrue(successCount > 0, 'The safe prefix should be processed.');
      Assert.isTrue(
        budgetCount > 0,
        'Excess records should fail explicitly before governor failure.'
      );
      Assert.areEqual(requests.size(), successCount + budgetCount);
    }
  }

  @isTest
  static void shouldGateBoundedDiagnosticsAndHideUnexpectedErrorDetails() {
    PromptContextAccess.setGenerateForTest(true);
    PromptContextApi.Request invalidRequest = new PromptContextApi.Request();

    PromptContextAccess.setDiagnosticsForTest(false);
    List<PromptContextApi.Response> ordinaryResponses = PromptContextApi.build(
      new List<PromptContextApi.Request>{ invalidRequest }
    );
    PromptContextAccess.setDiagnosticsForTest(true);
    List<PromptContextApi.Response> diagnosticResponses = PromptContextApi.build(
      new List<PromptContextApi.Request>{ invalidRequest }
    );

    Assert.isNull(
      ordinaryResponses[0].diagnosticSummary,
      'Generation permission alone must not expose diagnostics.'
    );
    Assert.isTrue(
      diagnosticResponses[0].diagnosticSummary.contains('INVALID_REQUEST'),
      'Authorized diagnostics should contain a stable outcome only.'
    );
    Assert.isTrue(diagnosticResponses[0].diagnosticSummary.length() <= 200);
    Assert.areEqual(
      Label.PCB_Generation_Failed,
      PromptContextTrace.safeMessage(
        new SensitiveTestException('CANARY_CUSTOMER_VALUE')
      ),
      'Unexpected exception text must never escape.'
    );
    Assert.isFalse(
      diagnosticResponses[0].diagnosticSummary.contains('CANARY_CUSTOMER_VALUE')
    );
  }
}
