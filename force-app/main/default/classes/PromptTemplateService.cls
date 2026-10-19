/**
 * Coordinates template persistence, loading, publishing, and generation.
 */
public with sharing class PromptTemplateService {
  /** Loads one limited page in a consistent order without loading prompt text or data sets. */
  public static PromptContextDTO.TemplateSummaryPage getTemplateSummaryPage(
    String searchText,
    Integer requestedPageSize,
    String afterName,
    Id afterId
  ) {
    Integer pageSize = Math.max(
      1,
      Math.min(
        requestedPageSize ?? PromptContextContract.DEFAULT_TEMPLATE_PAGE_SIZE,
        PromptContextContract.MAX_TEMPLATE_PAGE_SIZE
      )
    );
    List<Prompt_Template__c> records = PromptContextSelector.selectTemplateSummaryPage(
      searchText,
      pageSize,
      afterName,
      afterId
    );
    PromptContextDTO.TemplateSummaryPage page = new PromptContextDTO.TemplateSummaryPage();
    page.hasMore = records.size() > pageSize;
    while (records.size() > pageSize) {
      records.remove(records.size() - 1);
    }
    for (Prompt_Template__c templateRecord : records) {
      page.items.add(mapTemplateSummary(templateRecord));
    }
    if (page.hasMore && !records.isEmpty()) {
      Prompt_Template__c lastRecord = records[records.size() - 1];
      page.nextName = lastRecord.Name;
      page.nextId = lastRecord.Id;
    }
    return page;
  }

  private static PromptContextDTO.TemplateSummary mapTemplateSummary(
    Prompt_Template__c templateRecord
  ) {
    PromptContextDTO.TemplateSummary summary = new PromptContextDTO.TemplateSummary();
    summary.id = templateRecord.Id;
    summary.developerKey = templateRecord.Developer_Key__c;
    summary.name = templateRecord.Name;
    summary.description = templateRecord.Description__c;
    summary.rootObject = templateRecord.Root_Object__c;
    summary.status = templateRecord.Status__c;
    summary.version = Integer.valueOf(templateRecord.Version__c ?? 0);
    summary.publishedAt = templateRecord.Published_At__c;
    summary.lastHealthStatus = templateRecord.Last_Health_Status__c;
    summary.lastHealthCheckedAt = templateRecord.Last_Health_Checked_At__c;
    return summary;
  }

  /**
   * Loads one complete template configuration.
   * @param templateId Template Id
   * @return Template configuration
   * @throws PromptContextException when the record is unavailable
   */
  public static PromptContextDTO.TemplateConfig getTemplate(Id templateId) {
    Prompt_Template__c templateRecord = PromptContextSelector.selectTemplateById(
      templateId
    );
    if (templateRecord == null) {
      throw new PromptContextException(
        'The requested template was not found or is not accessible.'
      );
    }
    return mapTemplate(
      templateRecord,
      PromptContextSelector.selectSourcesByTemplate(templateId)
    );
  }

  /**
   * Saves a draft and replaces its child source configuration atomically.
   * @param config Editable template configuration
   * @return Reloaded saved configuration
   */
  public static PromptContextDTO.TemplateConfig saveDraft(
    PromptContextDTO.TemplateConfig config
  ) {
    requireSavable(config);
    String persistedStatus = 'Draft';
    if (config.id != null) {
      Prompt_Template__c existingTemplate = PromptContextSelector.selectTemplateById(
        config.id
      );
      if (existingTemplate == null) {
        throw new PromptContextException(
          'The requested template was not found or is not accessible.'
        );
      }
      persistedStatus = existingTemplate.Status__c ?? 'Draft';
    }
    Savepoint savepointValue = Database.setSavepoint();
    try {
      Prompt_Template__c templateRecord = new Prompt_Template__c(
        Id = config.id,
        Name = config.name.trim(),
        Description__c = config.description,
        Root_Object__c = config.rootObject,
        Template_Body__c = config.templateBody,
        File_Input_Mode__c = config.fileInputMode ?? 'DISABLED',
        Maximum_Files__c = config.maxFiles,
        Require_File__c = config.requireAtLeastOneFile == true,
        Allowed_File_Formats__c = config.allowedFileFormats,
        Provider_Profile_Key__c = config.providerProfileKey,
        File_Citations_Enabled__c = config.fileCitationsEnabled == true,
        Status__c = persistedStatus
      );
      if (config.id == null) {
        templateRecord.Developer_Key__c = String.isBlank(config.developerKey)
          ? generateDeveloperKey(config.name)
          : config.developerKey.trim();
        Database.SaveResult[] results = Database.insert(
          new List<Prompt_Template__c>{ templateRecord },
          true,
          AccessLevel.USER_MODE
        );
        templateRecord.Id = results[0].getId();
      } else {
        Database.update(
          new List<Prompt_Template__c>{ templateRecord },
          true,
          AccessLevel.USER_MODE
        );
        List<Prompt_Context_Source__c> existingSources = PromptContextSelector.selectSourcesByTemplate(
          config.id
        );
        if (!existingSources.isEmpty()) {
          Database.delete(existingSources, true, AccessLevel.USER_MODE);
        }
      }

      List<Prompt_Context_Source__c> sourceRecords = new List<Prompt_Context_Source__c>();
      for (
        PromptContextDTO.SourceConfig source : config.sources ??
          new List<PromptContextDTO.SourceConfig>()
      ) {
        sourceRecords.add(mapSourceForSave(templateRecord.Id, source));
      }
      if (!sourceRecords.isEmpty()) {
        Database.insert(sourceRecords, true, AccessLevel.USER_MODE);
      }
      return getTemplate(templateRecord.Id);
    } catch (DmlException exceptionValue) {
      Database.rollback(savepointValue);
      throw new PromptContextException(
        'The draft could not be saved: ' + exceptionValue.getDmlMessage(0)
      );
    } catch (SecurityException exceptionValue) {
      Database.rollback(savepointValue);
      throw new PromptContextException(Label.PCB_Access_Denied);
    }
  }

  /**
   * Validates and previews a stored template, then publishes that exact configuration.
   * @param templateId Template Id
   * @param sampleRecordId Current Salesforce record used for the required successful preview
   * @return Preview generated from the published configuration
   */
  public static PromptContextDTO.PromptResult publish(
    Id templateId,
    Id sampleRecordId
  ) {
    // The version writes below use system mode, so this service authorizes them itself.
    PromptContextAccess.requireConfigure();
    if (sampleRecordId == null) {
      throw new PromptContextException(Label.PCB_Publish_Requires_Preview);
    }
    PromptContextDTO.TemplateConfig config = getTemplate(templateId);
    PromptContextDTO.TemplateHealth health = PromptTemplateGovernanceService.checkHealth(
      config
    );
    if (!health.isValid) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template has problems with its Salesforce fields or access. Select Validate and correct them before publishing.'
      );
    }
    PromptContextDTO.PromptResult preview = PromptContextService.generate(
      config,
      sampleRecordId
    );
    preview.accessManifest = health.accessManifest;
    preview.messages.addAll(health.accessManifest.warnings);
    String fingerprint = createFingerprint(config);
    Integer nextVersion = config.publishedAt == null
      ? 1
      : (config.version ?? 0) + 1;
    Datetime publishedAt = System.now();
    Savepoint savepointValue = Database.setSavepoint();
    try {
      Prompt_Template_Version__c versionRecord = new Prompt_Template_Version__c(
        Prompt_Template__c = templateId,
        Version_Key__c = config.developerKey + ':' + nextVersion,
        Version_Number__c = nextVersion,
        Syntax_Version__c = PromptContextContract.SYNTAX_VERSION,
        Contract_Version__c = PromptContextContract.CONTRACT_VERSION,
        Root_Object__c = config.rootObject,
        Template_Body__c = config.templateBody,
        File_Input_Mode__c = config.fileInputMode ?? 'DISABLED',
        Maximum_Files__c = config.maxFiles,
        Require_File__c = config.requireAtLeastOneFile == true,
        Allowed_File_Formats__c = config.allowedFileFormats,
        Provider_Profile_Key__c = config.providerProfileKey,
        File_Citations_Enabled__c = config.fileCitationsEnabled == true,
        Fingerprint__c = fingerprint,
        Published_At__c = publishedAt
      );
      Database.SaveResult[] versionResults = Database.insert(
        new List<Prompt_Template_Version__c>{ versionRecord },
        true,
        AccessLevel.SYSTEM_MODE
      );
      versionRecord.Id = versionResults[0].getId();
      List<Prompt_Context_Source_Version__c> sourceVersions = new List<Prompt_Context_Source_Version__c>();
      for (
        PromptContextDTO.SourceConfig source : config.sources ??
          new List<PromptContextDTO.SourceConfig>()
      ) {
        sourceVersions.add(mapSourceVersion(versionRecord.Id, source));
      }
      if (!sourceVersions.isEmpty()) {
        Database.insert(sourceVersions, true, AccessLevel.SYSTEM_MODE);
      }
      Database.update(
        new List<Prompt_Template__c>{
          new Prompt_Template__c(
            Id = templateId,
            Status__c = 'Published',
            Version__c = nextVersion,
            Fingerprint__c = fingerprint,
            Published_At__c = publishedAt
          )
        },
        true,
        AccessLevel.USER_MODE
      );
    } catch (DmlException exceptionValue) {
      Database.rollback(savepointValue);
      throw new PromptContextException(
        'The template passed preview but could not be published. Check edit access.'
      );
    } catch (SecurityException exceptionValue) {
      Database.rollback(savepointValue);
      throw new PromptContextException(Label.PCB_Access_Denied);
    }
    preview.fingerprint = fingerprint;
    preview.templateVersion = nextVersion;
    preview.syntaxVersion = PromptContextContract.SYNTAX_VERSION;
    preview.contractVersion = PromptContextContract.CONTRACT_VERSION;
    return preview;
  }

  /**
   * Returns published template choices for a record object.
   * @param rootObject Salesforce object API name for the current record
   * @return Lightweight choices
   */
  public static List<PromptContextDTO.TemplateChoice> getPublishedChoices(
    String rootObject
  ) {
    PromptContextSchema.requireReadableObject(rootObject);
    List<PromptContextDTO.TemplateChoice> choices = new List<PromptContextDTO.TemplateChoice>();
    for (
      Prompt_Template__c templateRecord : PromptContextSelector.selectPublishedTemplates(
        rootObject
      )
    ) {
      PromptContextDTO.TemplateChoice choice = new PromptContextDTO.TemplateChoice();
      choice.id = templateRecord.Id;
      choice.name = templateRecord.Name;
      choice.description = templateRecord.Description__c;
      choice.version = Integer.valueOf(templateRecord.Version__c);
      choice.fileInputMode = templateRecord.File_Input_Mode__c ?? 'DISABLED';
      choice.maxFiles = templateRecord.Maximum_Files__c == null
        ? null
        : Integer.valueOf(templateRecord.Maximum_Files__c);
      if (choice.fileInputMode != 'DISABLED') {
        PromptContextProviderSettings.Settings provider = PromptContextProviderSettings.requireActive(
          templateRecord.Provider_Profile_Key__c
        );
        choice.maxFiles = Math.min(
          choice.maxFiles ?? PromptContextContract.MAX_SELECTED_FILES,
          provider.maximumFiles
        );
      }
      choice.requireAtLeastOneFile = templateRecord.Require_File__c;
      choice.allowedFileFormats = templateRecord.Allowed_File_Formats__c;
      choices.add(choice);
    }
    return choices;
  }

  /**
   * Generates a prompt from a published template.
   * @param templateId Published template Id
   * @param recordId Current Salesforce record Id
   * @return Generated prompt result
   */
  public static PromptContextDTO.PromptResult generatePublished(
    Id templateId,
    Id recordId
  ) {
    PromptContextDTO.TemplateConfig header = getTemplate(templateId);
    if (header.status != 'Published') {
      throw new PromptContextException(
        'Only a published template can generate a record-page prompt.'
      );
    }
    PromptContextDTO.TemplateConfig publishedConfig = getPublishedConfig(
      header
    );
    return PromptContextService.generate(publishedConfig, recordId);
  }

  /**
   * Removes a template from prompt-generation choices without deleting its settings.
   * @param templateId Template Id
   * @return Reloaded inactive configuration
   */
  public static PromptContextDTO.TemplateConfig deactivate(Id templateId) {
    if (getTemplate(templateId).status == 'Inactive') {
      return getTemplate(templateId);
    }
    try {
      Database.update(
        new List<Prompt_Template__c>{
          new Prompt_Template__c(Id = templateId, Status__c = 'Inactive')
        },
        true,
        AccessLevel.USER_MODE
      );
      return getTemplate(templateId);
    } catch (DmlException exceptionValue) {
      throw new PromptContextException(
        'The template could not be deactivated. Check edit access.'
      );
    } catch (SecurityException exceptionValue) {
      throw new PromptContextException(Label.PCB_Access_Denied);
    }
  }

  private static void requireSavable(PromptContextDTO.TemplateConfig config) {
    if (
      config == null ||
      String.isBlank(config.name) ||
      String.isBlank(config.rootObject)
    ) {
      throw new PromptContextException(
        'Template name and Salesforce object are required to save a draft.'
      );
    }
    PromptContextSchema.requireReadableObject(config.rootObject);
    PromptContextFilePolicy.validateConfiguration(config);
    Set<String> aliases = new Set<String>();
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source == null || String.isBlank(source.referenceName)) {
        continue;
      }
      String normalizedAlias = source.referenceName.toLowerCase();
      if (aliases.contains(normalizedAlias)) {
        throw new PromptContextException(
          'Every data set reference name must be unique.'
        );
      }
      aliases.add(normalizedAlias);
    }
  }

  private static PromptContextDTO.TemplateConfig mapTemplate(
    Prompt_Template__c templateRecord,
    List<Prompt_Context_Source__c> sourceRecords
  ) {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.id = templateRecord.Id;
    config.developerKey = templateRecord.Developer_Key__c;
    config.name = templateRecord.Name;
    config.description = templateRecord.Description__c;
    config.rootObject = templateRecord.Root_Object__c;
    config.templateBody = templateRecord.Template_Body__c;
    config.status = templateRecord.Status__c;
    config.version = Integer.valueOf(templateRecord.Version__c ?? 0);
    config.fingerprint = templateRecord.Fingerprint__c;
    config.publishedAt = templateRecord.Published_At__c;
    config.lastHealthStatus = templateRecord.Last_Health_Status__c;
    config.lastHealthCheckedAt = templateRecord.Last_Health_Checked_At__c;
    config.lastHealthCodes = templateRecord.Last_Health_Codes__c;
    config.lastHealthVersion = templateRecord.Last_Health_Version__c == null
      ? null
      : Integer.valueOf(templateRecord.Last_Health_Version__c);
    config.fileInputMode = templateRecord.File_Input_Mode__c ?? 'DISABLED';
    config.maxFiles = templateRecord.Maximum_Files__c == null
      ? null
      : Integer.valueOf(templateRecord.Maximum_Files__c);
    config.requireAtLeastOneFile = templateRecord.Require_File__c;
    config.allowedFileFormats = templateRecord.Allowed_File_Formats__c;
    config.providerProfileKey = templateRecord.Provider_Profile_Key__c;
    config.fileCitationsEnabled = templateRecord.File_Citations_Enabled__c;
    config.syntaxVersion = PromptContextContract.SYNTAX_VERSION;
    config.contractVersion = PromptContextContract.CONTRACT_VERSION;
    for (Prompt_Context_Source__c sourceRecord : sourceRecords) {
      config.sources.add(mapSource(sourceRecord));
    }
    return config;
  }

  private static PromptContextDTO.SourceConfig mapSource(
    Prompt_Context_Source__c sourceRecord
  ) {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.id = sourceRecord.Id;
    source.referenceName = sourceRecord.Reference_Name__c;
    source.sourceMode = sourceRecord.Source_Mode__c;
    source.resultMode = sourceRecord.Result_Mode__c;
    source.aggregateOperation = sourceRecord.Aggregate_Operation__c;
    source.aggregateField = sourceRecord.Aggregate_Field__c;
    source.relatedObject = sourceRecord.Related_Object__c;
    source.correlationField = sourceRecord.Correlation_Field__c;
    source.rootField = sourceRecord.Root_Field__c;
    source.selectedFields = splitFields(sourceRecord.Selected_Fields__c);
    source.filters = String.isBlank(sourceRecord.Filters_JSON__c)
      ? new List<PromptContextDTO.FilterRule>()
      : (List<PromptContextDTO.FilterRule>) JSON.deserialize(
          sourceRecord.Filters_JSON__c,
          List<PromptContextDTO.FilterRule>.class
        );
    source.filterGroupJoin = sourceRecord.Filter_Group_Join__c ?? 'AND';
    source.sorts = String.isBlank(sourceRecord.Sort_JSON__c)
      ? new List<PromptContextDTO.SortRule>()
      : (List<PromptContextDTO.SortRule>) JSON.deserialize(
          sourceRecord.Sort_JSON__c,
          List<PromptContextDTO.SortRule>.class
        );
    source.maxRows = Integer.valueOf(sourceRecord.Max_Rows__c ?? 10);
    source.sequence = Integer.valueOf(sourceRecord.Sequence__c ?? 1);
    source.active = sourceRecord.Active__c;
    return source;
  }

  private static Prompt_Context_Source__c mapSourceForSave(
    Id templateId,
    PromptContextDTO.SourceConfig source
  ) {
    return new Prompt_Context_Source__c(
      Prompt_Template__c = templateId,
      Reference_Name__c = source.referenceName,
      Source_Mode__c = source.sourceMode ?? 'RELATED',
      Result_Mode__c = source.resultMode ?? 'RECORDS',
      Aggregate_Operation__c = source.aggregateOperation,
      Aggregate_Field__c = source.aggregateField,
      Related_Object__c = source.relatedObject,
      Correlation_Field__c = source.correlationField,
      Root_Field__c = source.rootField,
      Selected_Fields__c = String.join(
        source.selectedFields ?? new List<String>(),
        ','
      ),
      Filters_JSON__c = JSON.serialize(
        source.filters ?? new List<PromptContextDTO.FilterRule>()
      ),
      Filter_Group_Join__c = source.filterGroupJoin ?? 'AND',
      Sort_JSON__c = JSON.serialize(
        source.sorts ?? new List<PromptContextDTO.SortRule>()
      ),
      Max_Rows__c = source.maxRows ?? 10,
      Sequence__c = source.sequence ?? 1,
      Active__c = source.active != false
    );
  }

  private static Prompt_Context_Source_Version__c mapSourceVersion(
    Id templateVersionId,
    PromptContextDTO.SourceConfig source
  ) {
    return new Prompt_Context_Source_Version__c(
      Prompt_Template_Version__c = templateVersionId,
      Reference_Name__c = source.referenceName,
      Source_Mode__c = source.sourceMode ?? 'RELATED',
      Result_Mode__c = source.resultMode ?? 'RECORDS',
      Aggregate_Operation__c = source.aggregateOperation,
      Aggregate_Field__c = source.aggregateField,
      Related_Object__c = source.relatedObject,
      Correlation_Field__c = source.correlationField,
      Root_Field__c = source.rootField,
      Selected_Fields__c = String.join(
        source.selectedFields ?? new List<String>(),
        ','
      ),
      Filters_JSON__c = JSON.serialize(
        source.filters ?? new List<PromptContextDTO.FilterRule>()
      ),
      Filter_Group_Join__c = source.filterGroupJoin ?? 'AND',
      Sort_JSON__c = JSON.serialize(
        source.sorts ?? new List<PromptContextDTO.SortRule>()
      ),
      Max_Rows__c = source.maxRows ?? 10,
      Sequence__c = source.sequence ?? 1,
      Active__c = source.active != false
    );
  }

  public static PromptContextDTO.TemplateConfig getPublishedConfig(
    PromptContextDTO.TemplateConfig header
  ) {
    return getPublishedConfig(header, header.version);
  }

  /** Loads one exact fixed publication for review and restore. */
  public static PromptContextDTO.TemplateConfig getPublishedConfig(
    PromptContextDTO.TemplateConfig header,
    Integer versionNumber
  ) {
    Prompt_Template_Version__c versionRecord = PromptContextSelector.selectPublishedVersion(
      header.id,
      versionNumber
    );
    if (versionRecord == null) {
      throw new PromptContextException(
        'The published template version was not found or is not accessible.'
      );
    }
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.id = header.id;
    config.publishedVersionId = versionRecord.Id;
    config.developerKey = header.developerKey;
    config.name = header.name;
    config.description = header.description;
    config.rootObject = versionRecord.Root_Object__c;
    config.templateBody = versionRecord.Template_Body__c;
    config.status = 'Published';
    config.version = Integer.valueOf(versionRecord.Version_Number__c);
    config.syntaxVersion = Integer.valueOf(versionRecord.Syntax_Version__c);
    config.contractVersion = versionRecord.Contract_Version__c;
    config.fingerprint = versionRecord.Fingerprint__c;
    config.publishedAt = versionRecord.Published_At__c;
    config.fileInputMode = versionRecord.File_Input_Mode__c ?? 'DISABLED';
    config.maxFiles = versionRecord.Maximum_Files__c == null
      ? null
      : Integer.valueOf(versionRecord.Maximum_Files__c);
    config.requireAtLeastOneFile = versionRecord.Require_File__c;
    config.allowedFileFormats = versionRecord.Allowed_File_Formats__c;
    config.providerProfileKey = versionRecord.Provider_Profile_Key__c;
    config.fileCitationsEnabled = versionRecord.File_Citations_Enabled__c;
    for (
      Prompt_Context_Source_Version__c sourceRecord : PromptContextSelector.selectPublishedSources(
        versionRecord.Id
      )
    ) {
      config.sources.add(mapSourceVersion(sourceRecord));
    }
    return config;
  }

  private static PromptContextDTO.SourceConfig mapSourceVersion(
    Prompt_Context_Source_Version__c sourceRecord
  ) {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.id = sourceRecord.Id;
    source.referenceName = sourceRecord.Reference_Name__c;
    source.sourceMode = sourceRecord.Source_Mode__c;
    source.resultMode = sourceRecord.Result_Mode__c;
    source.aggregateOperation = sourceRecord.Aggregate_Operation__c;
    source.aggregateField = sourceRecord.Aggregate_Field__c;
    source.relatedObject = sourceRecord.Related_Object__c;
    source.correlationField = sourceRecord.Correlation_Field__c;
    source.rootField = sourceRecord.Root_Field__c;
    source.selectedFields = splitFields(sourceRecord.Selected_Fields__c);
    source.filters = String.isBlank(sourceRecord.Filters_JSON__c)
      ? new List<PromptContextDTO.FilterRule>()
      : (List<PromptContextDTO.FilterRule>) JSON.deserialize(
          sourceRecord.Filters_JSON__c,
          List<PromptContextDTO.FilterRule>.class
        );
    source.filterGroupJoin = sourceRecord.Filter_Group_Join__c ?? 'AND';
    source.sorts = String.isBlank(sourceRecord.Sort_JSON__c)
      ? new List<PromptContextDTO.SortRule>()
      : (List<PromptContextDTO.SortRule>) JSON.deserialize(
          sourceRecord.Sort_JSON__c,
          List<PromptContextDTO.SortRule>.class
        );
    source.maxRows = Integer.valueOf(sourceRecord.Max_Rows__c ?? 10);
    source.sequence = Integer.valueOf(sourceRecord.Sequence__c ?? 1);
    source.active = sourceRecord.Active__c;
    return source;
  }

  private static String generateDeveloperKey(String templateName) {
    String baseValue = templateName.trim()
      .toLowerCase()
      .replaceAll('[^a-z0-9]+', '_');
    while (baseValue.startsWith('_')) {
      baseValue = baseValue.substring(1);
    }
    while (baseValue.endsWith('_')) {
      baseValue = baseValue.substring(0, baseValue.length() - 1);
    }
    if (String.isBlank(baseValue)) {
      baseValue = 'prompt_template';
    }
    if (baseValue.length() > 78) {
      baseValue = baseValue.substring(0, 78);
    }
    String suffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128))
      .substring(0, 12);
    return baseValue + '_' + suffix;
  }

  private static List<String> splitFields(String fieldText) {
    List<String> fields = new List<String>();
    if (String.isBlank(fieldText)) {
      return fields;
    }
    for (String fieldName : fieldText.split(',')) {
      if (!String.isBlank(fieldName)) {
        fields.add(fieldName.trim());
      }
    }
    return fields;
  }

  private static String createFingerprint(
    PromptContextDTO.TemplateConfig config
  ) {
    PromptContextDTO.TemplateConfig normalized = (PromptContextDTO.TemplateConfig) JSON.deserialize(
      JSON.serialize(config),
      PromptContextDTO.TemplateConfig.class
    );
    normalized.fingerprint = null;
    normalized.publishedAt = null;
    normalized.id = null;
    normalized.publishedVersionId = null;
    normalized.developerKey = null;
    normalized.name = null;
    normalized.description = null;
    normalized.status = null;
    normalized.version = null;
    normalized.lastHealthStatus = null;
    normalized.lastHealthCheckedAt = null;
    normalized.lastHealthCodes = null;
    normalized.lastHealthVersion = null;
    for (PromptContextDTO.SourceConfig source : normalized.sources) {
      source.id = null;
    }
    normalized.sources.sort();
    Blob digest = Crypto.generateDigest(
      'SHA-256',
      Blob.valueOf(JSON.serialize(normalized))
    );
    return EncodingUtil.convertToHex(digest);
  }
}
