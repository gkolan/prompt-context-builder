/** Test-only Batch Apex caller that saves prompt input for every record in its scope. */
@isTest
public class PromptContextSaveBatchTestHarness implements Database.Batchable<Id> {
  private String templateKey;
  private List<Id> recordIds;

  public PromptContextSaveBatchTestHarness(
    String templateKey,
    List<Id> recordIds
  ) {
    this.templateKey = templateKey;
    this.recordIds = recordIds;
  }

  public Iterable<Id> start(Database.BatchableContext context) {
    return recordIds;
  }

  public void execute(Database.BatchableContext context, List<Id> scope) {
    saveAll(templateKey, scope, 'batch:');
  }

  public void finish(Database.BatchableContext context) {
  }

  /** Saves one input per record with a per-record request key and asserts each succeeds. */
  public static void saveAll(
    String templateKey,
    List<Id> recordIds,
    String keyPrefix
  ) {
    List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
    for (Id recordId : recordIds) {
      PromptContextInputApi.Request request = new PromptContextInputApi.Request();
      request.templateDeveloperKey = templateKey;
      request.recordId = recordId;
      request.deliveryChoice = PromptContextInputApi.SAVE_TO_LOG;
      request.requestKey = keyPrefix + recordId;
      requests.add(request);
    }
    for (
      PromptContextInputApi.Result result : PromptContextInputApi.prepare(
        requests
      )
    ) {
      Assert.isTrue(
        result.success,
        keyPrefix + ' item failed: ' + result.reasonCode + ' ' + result.message
      );
    }
  }
}
