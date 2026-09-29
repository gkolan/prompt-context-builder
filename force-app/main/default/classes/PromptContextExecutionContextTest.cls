/** Verifies that every supported automation context uses the shared public API. */
@isTest
private class PromptContextExecutionContextTest {
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
  static void shouldBuildFromFlowEntryPoint() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForTestData();

      Test.startTest();
      List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepareForFlow(
        new List<PromptContextInputApi.Request>{ request }
      );
      Test.stopTest();

      Assert.areEqual(1, responses.size());
      Assert.isTrue(responses[0].success);
      Assert.isNotNull(responses[0].prompt);
    }
  }

  @isTest
  static void shouldBuildFromQueueableContext() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForTestData();
      Test.startTest();
      System.enqueueJob(
        new ApiQueueable(request.templateDeveloperKey, request.recordId)
      );
      Test.stopTest();
    }
  }

  @isTest
  static void shouldBuildFromBatchContext() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForTestData();
      Test.startTest();
      Database.executeBatch(
        new PromptContextBatchTestHarness(
          request.templateDeveloperKey,
          request.recordId
        ),
        1
      );
      Test.stopTest();
    }
  }

  @isTest
  static void shouldBuildFromScheduledContext() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextInputApi.Request request = requestForTestData();
      Test.startTest();
      System.schedule(
        'Prompt Context API scheduled test',
        '0 0 0 1 1 ? 2099',
        new ApiScheduled(request.templateDeveloperKey, request.recordId)
      );
      Test.stopTest();
    }
  }

  private static User getConfigurator() {
    return PromptContextTestDataFactory.createConfiguratorUser();
  }

  private static PromptContextInputApi.Request requestForTestData() {
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
    request.templateDeveloperKey = [
      SELECT Developer_Key__c
      FROM Prompt_Template__c
      WHERE Status__c = 'Published'
      LIMIT 1
    ]
    .Developer_Key__c;
    request.recordId = PromptContextTestDataFactory.selectRootRecord().Id;
    return request;
  }

  private static void assertSuccessfulBuild(String developerKey, Id recordId) {
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
    request.templateDeveloperKey = developerKey;
    request.recordId = recordId;
    List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
      new List<PromptContextInputApi.Request>{ request }
    );
    Assert.areEqual(1, responses.size());
    Assert.isTrue(responses[0].success, responses[0].message);
    Assert.isNotNull(responses[0].prompt);
  }

  private class ApiQueueable implements Queueable {
    private String developerKey;
    private Id recordId;

    private ApiQueueable(String developerKey, Id recordId) {
      this.developerKey = developerKey;
      this.recordId = recordId;
    }

    public void execute(QueueableContext context) {
      assertSuccessfulBuild(developerKey, recordId);
    }
  }

  private class ApiScheduled implements Schedulable {
    private String developerKey;
    private Id recordId;

    private ApiScheduled(String developerKey, Id recordId) {
      this.developerKey = developerKey;
      this.recordId = recordId;
    }

    public void execute(SchedulableContext context) {
      assertSuccessfulBuild(developerKey, recordId);
    }
  }
}
