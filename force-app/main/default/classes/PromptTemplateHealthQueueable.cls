/**
 * Checks limited pages of fixed published versions against the current Salesforce setup without reading customer records.
 */
public with sharing class PromptTemplateHealthQueueable implements Queueable {
  private static final Integer PAGE_SIZE = 15;
  private final Id afterId;

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
    List<Prompt_Template__c> healthUpdates = new List<Prompt_Template__c>();
    for (Prompt_Template__c templateRecord : templates) {
      healthUpdates.add(buildHealthUpdate(templateRecord.Id));
    }
    if (!healthUpdates.isEmpty()) {
      Integer failures = 0;
      for (
        Database.SaveResult result : Database.update(
          healthUpdates,
          false,
          AccessLevel.USER_MODE
        )
      ) {
        if (!result.isSuccess()) {
          failures++;
        }
      }
      if (failures > 0) {
        throw new PromptContextException(
          'One or more template health results could not be saved.'
        );
      }
    }
    if (templates.size() == PAGE_SIZE) {
      System.enqueueJob(
        new PromptTemplateHealthQueueable(templates[templates.size() - 1].Id)
      );
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
      updateRecord.Last_Health_Codes__c = 'HEALTH_CHECK_ERROR';
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
