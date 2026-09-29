/** Test-only Batch Apex consumer for the public prompt-context API. */
@isTest
public class PromptContextBatchTestHarness implements Database.Batchable<Prompt_Template__c> {
  private String developerKey;
  private Id recordId;

  public PromptContextBatchTestHarness(String developerKey, Id recordId) {
    this.developerKey = developerKey;
    this.recordId = recordId;
  }

  public Iterable<Prompt_Template__c> start(Database.BatchableContext context) {
    return new List<Prompt_Template__c>{
      new Prompt_Template__c(Id = recordId)
    };
  }

  public void execute(
    Database.BatchableContext context,
    List<Prompt_Template__c> scope
  ) {
    Assert.areEqual(1, scope.size());
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
    request.templateDeveloperKey = developerKey;
    request.recordId = scope[0].Id;
    List<PromptContextInputApi.Result> responses = PromptContextInputApi.prepare(
      new List<PromptContextInputApi.Request>{ request }
    );
    Assert.areEqual(1, responses.size());
    Assert.isTrue(responses[0].success, responses[0].message);
    Assert.isNotNull(responses[0].prompt);
  }

  public void finish(Database.BatchableContext context) {
  }
}
