/** Test-only Batch Apex consumer for the public prompt-context API. */
@isTest
public class PromptContextBatchTestHarness implements Database.Batchable<Account> {
  private String developerKey;
  private Id recordId;

  public PromptContextBatchTestHarness(String developerKey, Id recordId) {
    this.developerKey = developerKey;
    this.recordId = recordId;
  }

  public Iterable<Account> start(Database.BatchableContext context) {
    return new List<Account>{ new Account(Id = recordId) };
  }

  public void execute(Database.BatchableContext context, List<Account> scope) {
    Assert.areEqual(1, scope.size());
    PromptContextApi.Request request = new PromptContextApi.Request();
    request.templateDeveloperKey = developerKey;
    request.recordId = scope[0].Id;
    List<PromptContextApi.Response> responses = PromptContextApi.build(
      new List<PromptContextApi.Request>{ request }
    );
    Assert.areEqual(1, responses.size());
    Assert.isTrue(responses[0].success, responses[0].message);
    Assert.isNotNull(responses[0].prompt);
  }

  public void finish(Database.BatchableContext context) {
  }
}
