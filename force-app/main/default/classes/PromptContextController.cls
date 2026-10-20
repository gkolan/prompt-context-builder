/**
 * Thin Lightning controller for configuring, previewing, publishing, and generating record-context prompts.
 */
public with sharing class PromptContextController {
  /**
   * @return Accessible queryable object choices
   */
  @AuraEnabled(cacheable=true)
  public static List<PromptContextDTO.Option> getObjectOptions() {
    try {
      PromptContextAccess.requireConfigure();
      return PromptContextSchema.getObjectOptions();
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param objectApiName Object API name
   * @return Readable supported field choices
   */
  @AuraEnabled(cacheable=true)
  public static List<PromptContextDTO.Option> getFieldOptions(
    String objectApiName
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptContextSchema.getFieldOptions(objectApiName);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Returns one limited template catalog page in a consistent Name and Id order. */
  @AuraEnabled
  public static PromptContextDTO.TemplateSummaryPage getTemplateSummaryPage(
    String searchText,
    Integer pageSize,
    String afterName,
    Id afterId
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateService.getTemplateSummaryPage(
        searchText,
        pageSize,
        afterName,
        afterId
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param templateId Template Id
   * @return Complete editable template configuration
   */
  @AuraEnabled
  public static PromptContextDTO.TemplateConfig getTemplate(Id templateId) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateService.getTemplate(templateId);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Returns the current setup check and the required field access saved at publication. */
  @AuraEnabled
  public static PromptContextDTO.TemplateHealth checkTemplateHealth(
    String configJson
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateGovernanceService.checkHealth(
        parseConfig(configJson)
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (JSONException exceptionValue) {
      throw safeException(Label.PCB_Invalid_Configuration);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Returns fixed published versions, newest first. */
  @AuraEnabled
  public static List<PromptContextDTO.VersionSummary> getTemplateVersions(
    Id templateId
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateGovernanceService.getVersions(templateId);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Returns a limited comparison of two fixed versions without record values. */
  @AuraEnabled
  public static PromptContextDTO.VersionComparison compareTemplateVersions(
    Id templateId,
    Integer fromVersion,
    Integer toVersion
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateGovernanceService.compareVersions(
        templateId,
        fromVersion,
        toVersion
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Copies a fixed published version into the editable draft the editor loaded. */
  @AuraEnabled
  public static PromptContextDTO.TemplateConfig restoreTemplateVersion(
    Id templateId,
    Integer versionNumber,
    Integer draftRevision
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateGovernanceService.restoreVersionAsDraft(
        templateId,
        versionNumber,
        draftRevision
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param configJson Serialized template configuration
   * @return Saved configuration
   */
  @AuraEnabled
  public static PromptContextDTO.TemplateConfig saveDraft(String configJson) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateService.saveDraft(parseConfig(configJson));
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (JSONException exceptionValue) {
      throw safeException(Label.PCB_Invalid_Configuration);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param configJson Serialized template configuration
   * @return Validation result with all actionable messages
   */
  @AuraEnabled
  public static PromptContextDTO.ValidationResult validateConfig(
    String configJson
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptContextService.validate(parseConfig(configJson));
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (JSONException exceptionValue) {
      throw safeException(Label.PCB_Invalid_Configuration);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param configJson Serialized template configuration, saved or unsaved
   * @param recordId Sample current-record Id
   * @return Preview result
   */
  @AuraEnabled
  public static PromptContextDTO.PromptResult preview(
    String configJson,
    Id recordId
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptContextService.generate(parseConfig(configJson), recordId);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (JSONException exceptionValue) {
      throw safeException(Label.PCB_Invalid_Configuration);
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param templateId Stored template Id
   * @param sampleRecordId Required sample current-record Id
   * @param draftRevision Draft revision the publisher reviewed
   * @return Successful publish preview
   */
  @AuraEnabled
  public static PromptContextDTO.PromptResult publish(
    Id templateId,
    Id sampleRecordId,
    Integer draftRevision
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateService.publish(
        templateId,
        sampleRecordId,
        draftRevision
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param templateId Template to remove from prompt-generation choices
   * @return Inactive template configuration
   */
  @AuraEnabled
  public static PromptContextDTO.TemplateConfig deactivateTemplate(
    Id templateId
  ) {
    try {
      PromptContextAccess.requireConfigure();
      return PromptTemplateService.deactivate(templateId);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param rootObject Salesforce object API name for the current record
   * @return Published templates available for generation
   */
  @AuraEnabled(cacheable=true)
  public static List<PromptContextDTO.TemplateChoice> getPublishedTemplates(
    String rootObject
  ) {
    try {
      PromptContextAccess.requireGenerate();
      return PromptTemplateService.getPublishedChoices(rootObject);
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /** Returns eligible Salesforce Files directly linked to the current record. */
  @AuraEnabled
  public static PromptContextDTO.FileChoicePage getEligibleFiles(
    Id templateId,
    Id recordId,
    String afterTitle,
    Id afterId
  ) {
    try {
      PromptContextAccess.requireGenerate();
      PromptContextDTO.TemplateConfig header = PromptTemplateService.getRuntimeHeader(
        templateId
      );
      if (header.status != 'Published') {
        throw new PromptContextException(
          'Only a published template can list Salesforce Files.'
        );
      }
      return PromptContextFilePolicy.getFileChoices(
        PromptTemplateService.getPublishedConfig(header),
        recordId,
        afterTitle,
        afterId
      );
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      throw safeException(Label.PCB_Access_Denied);
    } catch (PromptContextException exceptionValue) {
      throw safeException(exceptionValue.getMessage());
    } catch (Exception exceptionValue) {
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  /**
   * @param templateId Published template Id
   * @param recordId Current Salesforce record Id
   * @return Generated prompt
   */
  @AuraEnabled
  public static PromptContextDTO.PromptResult generatePrompt(
    Id templateId,
    Id recordId,
    List<Id> selectedContentVersionIds
  ) {
    Long startedAtMilliseconds = Datetime.now().getTime();
    try {
      PromptContextPreparationService.Request request = new PromptContextPreparationService.Request();
      request.templateId = templateId;
      request.recordId = recordId;
      request.selectedContentVersionIds = selectedContentVersionIds;
      PromptContextPreparationService.Response response = PromptContextPreparationService.execute(
        new List<PromptContextPreparationService.Request>{ request },
        'LWC'
      )[0];
      if (!response.success) {
        throw safeException(response.message);
      }
      PromptContextDTO.PromptResult result = new PromptContextDTO.PromptResult();
      result.prompt = response.prompt;
      result.contractVersion = response.contractVersion;
      result.syntaxVersion = response.syntaxVersion;
      result.fingerprint = response.fingerprint;
      result.templateVersion = response.templateVersion;
      result.sourceRecordCounts = response.sourceRecordCounts;
      result.messages = response.messages;
      result.accessManifest = response.accessManifest;
      result.selectedFilesJson = response.selectedFilesJson;
      return result;
    } catch (AuraHandledException exceptionValue) {
      throw exceptionValue;
    } catch (PromptContextAccess.AuthorizationException exceptionValue) {
      publishControllerFailureMetric(
        templateId,
        PromptContextReasonCodes.NOT_AUTHORIZED,
        startedAtMilliseconds
      );
      throw safeException(Label.PCB_Access_Denied);
    } catch (Exception exceptionValue) {
      publishControllerFailureMetric(
        templateId,
        PromptContextReasonCodes.UNEXPECTED_ERROR,
        startedAtMilliseconds
      );
      throw safeException(Label.PCB_Generation_Failed);
    }
  }

  private static void publishControllerFailureMetric(
    Id templateId,
    String reasonCode,
    Long startedAtMilliseconds
  ) {
    PromptContextMetrics.Signal signal = new PromptContextMetrics.Signal();
    signal.channel = 'LWC';
    signal.outcomeCode = reasonCode;
    signal.startedAtMilliseconds = startedAtMilliseconds;
    signal.templateId = templateId;
    signal.correlationId = PromptContextTrace.newCorrelationId();
    PromptContextMetrics.publishOne(signal);
  }

  private static PromptContextDTO.TemplateConfig parseConfig(
    String configJson
  ) {
    if (String.isBlank(configJson)) {
      throw new PromptContextException('A template configuration is required.');
    }
    PromptContextDTO.TemplateConfig config = (PromptContextDTO.TemplateConfig) JSON.deserialize(
      configJson,
      PromptContextDTO.TemplateConfig.class
    );
    // Drafts always use the current grammar; only stored publications keep an older version.
    config.syntaxVersion = PromptContextContract.SYNTAX_VERSION;
    return config;
  }

  private static AuraHandledException safeException(String message) {
    return new AuraHandledException(message);
  }
}
