/** Tests the common prompt-preparation process independently of its public entry points. */
@isTest
private class PromptContextPreparationServiceTest {
  @isTest
  static void shouldKeepLaterSmallResponseAfterOnePromptExceedsPayloadLimit() {
    List<PromptContextPreparationService.Response> responses = new List<PromptContextPreparationService.Response>();
    for (String prompt : new List<String>{ '123456', 'abcdef', 'ok' }) {
      PromptContextPreparationService.Response response = new PromptContextPreparationService.Response();
      response.success = true;
      response.prompt = prompt;
      responses.add(response);
    }

    PromptContextPreparationService.enforceFlowPayloadLimit(responses, 10);

    Assert.isTrue(responses[0].success, 'The first prompt fits.');
    Assert.isFalse(responses[1].success, 'The overflowing prompt should fail.');
    Assert.areEqual(
      PromptContextReasonCodes.FLOW_PAYLOAD_LIMIT_EXCEEDED,
      responses[1].reasonCode
    );
    Assert.isTrue(
      responses[2].success,
      'A failed overflowing prompt must not consume capacity for later prompts.'
    );
  }

  @isTest
  static void shouldKeepTheTemplateVersionInTheDiagnosticSummaryOfALateFailure() {
    PromptContextAccess.setDiagnosticsForTest(true);
    PromptContextPreparationService.Response response = new PromptContextPreparationService.Response();
    response.success = true;
    response.prompt = 'too long for the limit';
    response.templateVersion = 3;

    PromptContextPreparationService.enforceFlowPayloadLimit(
      new List<PromptContextPreparationService.Response>{ response },
      5
    );

    Assert.isFalse(response.success);
    Assert.isNull(
      response.templateVersion,
      'A failed result clears success-only fields.'
    );
    Assert.isTrue(
      response.diagnosticSummary.contains('templateVersion=3'),
      'Support still needs the version that failed: ' +
      response.diagnosticSummary
    );
  }

  @isTest
  static void shouldNotInferAReasonFromMessageText() {
    Assert.areEqual(
      PromptContextReasonCodes.UNEXPECTED_ERROR,
      PromptContextPreparationService.classify(
        new PromptContextException('The record was not found.')
      ),
      'Rewording a message must never change a public reason code.'
    );
    Assert.areEqual(
      PromptContextReasonCodes.QUERY_NOT_SUPPORTED,
      PromptContextPreparationService.classify(
        PromptContextException.withReason(
          PromptContextReasonCodes.QUERY_NOT_SUPPORTED,
          'Any wording'
        )
      )
    );
  }

  @isTest
  static void shouldReportAMissingPublishedVersionAsTemplateNotFound() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c templateRecord = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      update new Prompt_Template__c(Id = templateRecord.Id, Version__c = 99);
      PromptContextPreparationService.Request request = new PromptContextPreparationService.Request();
      request.templateId = templateRecord.Id;
      request.recordId = PromptContextTestDataFactory.selectRootRecord().Id;

      PromptContextPreparationService.Response response = PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>{ request },
        'APEX'
      )[0];

      Assert.areEqual(
        PromptContextReasonCodes.TEMPLATE_NOT_FOUND,
        response.reasonCode
      );
    }
  }

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
  static void shouldBuildPromptWhenCalledThroughCommonService() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      Prompt_Template__c templateRecord = [
        SELECT Developer_Key__c
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      PromptContextPreparationService.Request request = new PromptContextPreparationService.Request();
      request.templateDeveloperKey = templateRecord.Developer_Key__c;
      request.recordId = accountRecord.Id;

      Test.startTest();
      List<PromptContextPreparationService.Response> responses = PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>{ request },
        'APEX'
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        responses.size(),
        'The service should return one ordered result per request.'
      );
      Assert.isTrue(
        responses[0].success,
        'The common service should build the prompt. Outcome: ' +
          responses[0].reasonCode +
          ', message: ' +
          responses[0].message
      );
      Assert.areEqual(
        PromptContextReasonCodes.SUCCESS,
        responses[0].reasonCode,
        'A successful request should retain the existing reason code.'
      );
      Assert.isNotNull(
        responses[0].prompt,
        'A successful result should contain the complete prompt.'
      );
    }
  }

  @isTest
  static void shouldGenerateFromThePublicationWithoutReadingTheDraft() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      // The only Published template is the one setupData published; the root fixture stays Draft.
      Prompt_Template__c templateRecord = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        LIMIT 1
      ];
      // A half-finished draft data set that cannot be read must not affect the fixed publication.
      insert new Prompt_Context_Source__c(
        Prompt_Template__c = templateRecord.Id,
        Reference_Name__c = 'halfEdited',
        Source_Mode__c = 'RELATED',
        Result_Mode__c = 'RECORDS',
        Filter_Group_Join__c = 'AND',
        Filters_JSON__c = '{ not json'
      );
      PromptContextPreparationService.Request request = new PromptContextPreparationService.Request();
      request.templateId = templateRecord.Id;
      request.recordId = accountRecord.Id;

      Test.startTest();
      PromptContextPreparationService.Response response = PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>{ request },
        'APEX'
      )[0];
      Test.stopTest();

      Assert.isTrue(
        response.success,
        'Generation must read only the publication: ' +
          response.reasonCode +
          ' ' +
          response.message
      );
      Assert.areEqual(1, response.templateVersion);
    }
  }

  @isTest
  static void shouldReturnInvalidRequestWhenRequestItemIsNull() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Test.startTest();
      List<PromptContextPreparationService.Response> responses = PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>{ null },
        'APEX'
      );
      Test.stopTest();

      Assert.areEqual(
        1,
        responses.size(),
        'A null item should still receive an ordered result.'
      );
      Assert.isFalse(
        responses[0].success,
        'A null request item must not produce a prompt.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_REQUEST,
        responses[0].reasonCode,
        'The service should preserve the stable invalid-request code.'
      );
      Assert.isNull(
        responses[0].prompt,
        'An invalid request must return no partial prompt.'
      );
    }
  }

  @isTest
  static void shouldRejectRequestWhenGenerationPermissionIsMissing() {
    PromptContextAccess.setGenerateForTest(false);

    Test.startTest();
    try {
      PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>(),
        'APEX'
      );
      Assert.fail('The common service must require generation permission.');
    } catch (PromptContextAccess.AuthorizationException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        expected.reasonCode,
        'The service should preserve the authorization reason code.'
      );
    }
    Test.stopTest();
  }
}
