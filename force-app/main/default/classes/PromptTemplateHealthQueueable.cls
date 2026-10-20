/**
 * Checks limited pages of fixed published versions against the current Salesforce setup without reading customer records.
 */
public with sharing class PromptTemplateHealthQueueable implements Queueable, Finalizer {
  private static final Integer PAGE_SIZE = 15;
  private final Id afterId;
  /** Cursor for the next page once a full page was read; the finalizer uses it after a failure. */
  private Id nextAfterId;

  /** Creates the first health-validation page. */
  public PromptTemplateHealthQueueable() {
    this(null);
  }

  /**
   * Creates a health-validation page after a stable Id cursor.
   * @param afterId Last processed template Id, or null for the first page
   */
  public PromptTemplateHealthQueueable(Id afterId) {
    this.afterId = afterId;
  }

  /**
   * Checks one limited page and starts the next page when required.
   * @param context Queueable execution context
   */
  public void execute(QueueableContext context) {
    PromptContextAccess.requireConfigure();
    List<Prompt_Template__c> templates = PromptContextSelector.selectPublishedTemplatePage(
      afterId,
      PAGE_SIZE
    );
    if (templates.size() == PAGE_SIZE) {
      nextAfterId = templates[templates.size() - 1].Id;
    }
    System.attachFinalizer(this);
    List<Prompt_Template__c> healthUpdates = new List<Prompt_Template__c>();
    for (Prompt_Template__c templateRecord : templates) {
      healthUpdates.add(buildHealthUpdate(templateRecord.Id));
    }
    if (!healthUpdates.isEmpty()) {
      // Health fields are package-owned; templates the scheduler cannot edit are skipped.
      PromptTemplateService.writeLifecycle(healthUpdates, false);
    }
    if (nextAfterId != null) {
      System.enqueueJob(new PromptTemplateHealthQueueable(nextAfterId));
    }
  }

  /**
   * Continues the nightly chain past a page that failed unexpectedly, such as on a governor limit,
   * so later templates are still checked. The failed page keeps its previous health values.
   * @param context Finalizer details for the page that just ran
   */
  public void execute(FinalizerContext context) {
    if (
      context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION &&
      nextAfterId != null
    ) {
      System.enqueueJob(new PromptTemplateHealthQueueable(nextAfterId));
    }
  }

  private static Prompt_Template__c buildHealthUpdate(Id templateId) {
    Prompt_Template__c updateRecord = new Prompt_Template__c(
      Id = templateId,
      Last_Health_Checked_At__c = System.now()
    );
    try {
      PromptContextDTO.TemplateConfig header = PromptTemplateService.getTemplate(
        templateId
      );
      PromptContextDTO.TemplateConfig published = PromptTemplateService.getPublishedConfig(
        header
      );
      PromptContextDTO.TemplateHealth health = PromptTemplateGovernanceService.checkHealth(
        published
      );
      updateRecord.Last_Health_Status__c = health.isValid
        ? 'Healthy'
        : 'Unhealthy';
      updateRecord.Last_Health_Codes__c = joinCodes(health.messages);
      updateRecord.Last_Health_Version__c = published.version;
    } catch (Exception ignoredConfigurationFailure) {
      updateRecord.Last_Health_Status__c = 'Error';
      updateRecord.Last_Health_Codes__c = PromptContextReasonCodes.HEALTH_CHECK_ERROR;
    }
    return updateRecord;
  }

  private static String joinCodes(List<PromptContextDTO.Message> messages) {
    Set<String> codes = new Set<String>();
    for (PromptContextDTO.Message message : messages) {
      if (message != null && !String.isBlank(message.code)) {
        codes.add(message.code);
      }
    }
    if (codes.isEmpty()) {
      return 'OK';
    }
    List<String> sortedCodes = new List<String>(codes);
    sortedCodes.sort();
    String result = String.join(sortedCodes, ',');
    return result.length() <= 255 ? result : result.substring(0, 255);
  }
}
