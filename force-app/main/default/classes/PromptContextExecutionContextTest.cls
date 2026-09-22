/** Verifies that every supported automation context uses the shared public API. */
@isTest
private class PromptContextExecutionContextTest {
  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
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
  static void shouldBuildFromFlowEntryPoint() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextApi.Request request = requestForTestData();

      Test.startTest();
      List<PromptContextApi.Response> responses = PromptContextApi.buildForFlow(
        new List<PromptContextApi.Request>{ request }
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
      PromptContextApi.Request request = requestForTestData();
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
      PromptContextApi.Request request = requestForTestData();
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
      PromptContextApi.Request request = requestForTestData();
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
    return [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
  }

  private static PromptContextApi.Request requestForTestData() {
    PromptContextApi.Request request = new PromptContextApi.Request();
    request.templateDeveloperKey = [
      SELECT Developer_Key__c
      FROM Prompt_Template__c
      LIMIT 1
    ]
    .Developer_Key__c;
    request.recordId = [SELECT Id FROM Account LIMIT 1].Id;
    return request;
  }

  private static void assertSuccessfulBuild(String developerKey, Id recordId) {
    PromptContextApi.Request request = new PromptContextApi.Request();
    request.templateDeveloperKey = developerKey;
    request.recordId = recordId;
    List<PromptContextApi.Response> responses = PromptContextApi.build(
      new List<PromptContextApi.Request>{ request }
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
