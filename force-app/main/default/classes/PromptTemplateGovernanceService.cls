/**
 * Provides privacy-safe setup checks, required field access, and fixed published versions.
 */
public with sharing class PromptTemplateGovernanceService {
  private static final Integer MAX_COMPARISON_CHANGES = 100;
  private static final Set<Schema.DisplayType> CONTACT_DATA_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Address,
    Schema.DisplayType.Email,
    Schema.DisplayType.Location,
    Schema.DisplayType.Phone
  };

  /**
   * Validates settings against the current Salesforce setup and returns required field access.
   * @param config Editable settings or a fixed published version
   * @return Current health result without querying customer records
   */
  public static PromptContextDTO.TemplateHealth checkHealth(
    PromptContextDTO.TemplateConfig config
  ) {
    PromptContextDTO.TemplateHealth health = new PromptContextDTO.TemplateHealth();
    PromptContextDTO.ValidationResult validation = PromptContextValidator.validate(
      config
    );
    health.isValid = validation.isValid;
    health.messages.addAll(validation.messages);
    if (config != null) {
      try {
        health.accessManifest = buildAccessManifest(config);
        health.messages.addAll(health.accessManifest.warnings);
      } catch (PromptContextException exceptionValue) {
        health.isValid = false;
        health.messages.add(
          new PromptContextDTO.Message(
            'ERROR',
            exceptionValue.reasonCode ??
              PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
            'Required field access',
            exceptionValue.getMessage()
          )
        );
      }
    }
    return health;
  }

  /**
   * Lists required field access without retrieving record values.
   * @param config Template configuration
   * @return Sorted required-field list and data-sensitivity warnings
   */
  public static PromptContextDTO.AccessManifest buildAccessManifest(
    PromptContextDTO.TemplateConfig config
  ) {
    if (config == null || String.isBlank(config.rootObject)) {
      throw new PromptContextException(
        'A template and Salesforce object are required.'
      );
    }
    PromptContextDTO.AccessManifest manifest = new PromptContextDTO.AccessManifest();
    Set<String> itemKeys = new Set<String>();
    for (
      String fieldPath : PromptTemplateLanguage.getRootFieldPaths(
        config.templateBody
      )
    ) {
      addManifestItem(
        manifest,
        itemKeys,
        config.rootObject,
        fieldPath,
        null,
        'Prompt value'
      );
    }
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source == null || source.active == false) {
        continue;
      }
      if (source.sourceMode != 'REFERENCE') {
        addManifestItem(
          manifest,
          itemKeys,
          config.rootObject,
          source.rootField,
          source.referenceName,
          'Current record match'
        );
        addManifestItem(
          manifest,
          itemKeys,
          source.relatedObject,
          source.correlationField,
          source.referenceName,
          'Related match'
        );
      }
      for (String fieldPath : source.selectedFields ?? new List<String>()) {
        addManifestItem(
          manifest,
          itemKeys,
          source.relatedObject,
          fieldPath,
          source.referenceName,
          'Prompt value'
        );
      }
      if (
        source.resultMode == 'AGGREGATE' &&
        !String.isBlank(source.aggregateField)
      ) {
        addManifestItem(
          manifest,
          itemKeys,
          source.relatedObject,
          source.aggregateField,
          source.referenceName,
          'Calculation'
        );
      }
      for (
        PromptContextDTO.FilterRule filter : source.filters ??
          new List<PromptContextDTO.FilterRule>()
      ) {
        if (filter != null && !String.isBlank(filter.fieldName)) {
          addManifestItem(
            manifest,
            itemKeys,
            source.relatedObject,
            filter.fieldName,
            source.referenceName,
            'Filter'
          );
        }
      }
      for (
        PromptContextDTO.SortRule sortRule : source.sorts ??
          new List<PromptContextDTO.SortRule>()
      ) {
        if (sortRule != null && !String.isBlank(sortRule.fieldName)) {
          addManifestItem(
            manifest,
            itemKeys,
            source.relatedObject,
            sortRule.fieldName,
            source.referenceName,
            'Sort'
          );
        }
      }
    }
    manifest.items.sort();
    return manifest;
  }

  /** Returns fixed published versions, newest first. */
  public static List<PromptContextDTO.VersionSummary> getVersions(
    Id templateId
  ) {
    requireTemplate(templateId);
    List<PromptContextDTO.VersionSummary> summaries = new List<PromptContextDTO.VersionSummary>();
    for (
      Prompt_Template_Version__c versionRecord : PromptContextSelector.selectPublishedVersions(
        templateId
      )
    ) {
      PromptContextDTO.VersionSummary summary = new PromptContextDTO.VersionSummary();
      summary.id = versionRecord.Id;
      summary.versionNumber = Integer.valueOf(versionRecord.Version_Number__c);
      summary.publishedAt = versionRecord.Published_At__c;
      summary.fingerprint = versionRecord.Fingerprint__c;
      summaries.add(summary);
    }
    return summaries;
  }

  /** Compares two fixed published versions without exposing record values. */
  public static PromptContextDTO.VersionComparison compareVersions(
    Id templateId,
    Integer fromVersion,
    Integer toVersion
  ) {
    PromptContextDTO.TemplateConfig header = requireTemplate(templateId);
    PromptContextDTO.TemplateConfig beforeConfig = getVersionConfig(
      header,
      fromVersion
    );
    PromptContextDTO.TemplateConfig afterConfig = getVersionConfig(
      header,
      toVersion
    );
    PromptContextDTO.VersionComparison comparison = new PromptContextDTO.VersionComparison();
    comparison.fromVersion = fromVersion;
    comparison.toVersion = toVersion;
    compareValue(
      comparison,
      'Salesforce object',
      beforeConfig.rootObject,
      afterConfig.rootObject
    );
    compareValue(
      comparison,
      'Prompt text signature',
      beforeConfig.templateBody,
      afterConfig.templateBody
    );
    compareValue(
      comparison,
      'File input mode',
      beforeConfig.fileInputMode,
      afterConfig.fileInputMode
    );
    compareValue(
      comparison,
      'Maximum files',
      beforeConfig.maxFiles,
      afterConfig.maxFiles
    );
    compareValue(
      comparison,
      'Required file setting',
      beforeConfig.requireAtLeastOneFile,
      afterConfig.requireAtLeastOneFile
    );
    compareValue(
      comparison,
      'Allowed file formats',
      beforeConfig.allowedFileFormats,
      afterConfig.allowedFileFormats
    );
    compareValue(
      comparison,
      'Provider profile',
      beforeConfig.providerProfileKey,
      afterConfig.providerProfileKey
    );
    compareValue(
      comparison,
      'File citations',
      beforeConfig.fileCitationsEnabled,
      afterConfig.fileCitationsEnabled
    );
    compareSources(comparison, beforeConfig.sources, afterConfig.sources);
    if (comparison.changes.isEmpty()) {
      comparison.changes.add('No configuration differences were found.');
    }
    return comparison;
  }

  /**
   * Copies a fixed published version into the editable draft while preserving the stable template key.
   */
  public static PromptContextDTO.TemplateConfig restoreVersionAsDraft(
    Id templateId,
    Integer versionNumber
  ) {
    PromptContextDTO.TemplateConfig header = requireTemplate(templateId);
    PromptContextDTO.TemplateConfig restored = getVersionConfig(
      header,
      versionNumber
    );
    restored.id = templateId;
    restored.developerKey = header.developerKey;
    restored.name = header.name;
    restored.description = header.description;
    restored.status = 'Draft';
    restored.version = header.version;
    restored.fingerprint = null;
    restored.publishedAt = null;
    return PromptTemplateService.saveDraft(restored);
  }

  private static PromptContextDTO.TemplateConfig requireTemplate(
    Id templateId
  ) {
    if (templateId == null) {
      throw new PromptContextException('Choose a template first.');
    }
    return PromptTemplateService.getTemplate(templateId);
  }

  private static PromptContextDTO.TemplateConfig getVersionConfig(
    PromptContextDTO.TemplateConfig header,
    Integer versionNumber
  ) {
    if (versionNumber == null || versionNumber < 1) {
      throw new PromptContextException('Choose a published version.');
    }
    return PromptTemplateService.getPublishedConfig(header, versionNumber);
  }

  private static void addManifestItem(
    PromptContextDTO.AccessManifest manifest,
    Set<String> itemKeys,
    String objectApiName,
    String fieldPath,
    String sourceAlias,
    String usage
  ) {
    if (String.isBlank(objectApiName) || String.isBlank(fieldPath)) {
      return;
    }
    String canonicalPath = PromptContextSchema.requireReadableFieldPath(
      objectApiName,
      fieldPath
    );
    String key = String.join(
      new List<String>{
        objectApiName.toLowerCase(),
        canonicalPath.toLowerCase(),
        (sourceAlias ?? '').toLowerCase(),
        usage.toLowerCase()
      },
      '|'
    );
    if (itemKeys.contains(key)) {
      return;
    }
    itemKeys.add(key);
    Schema.DescribeFieldResult description = PromptContextSchema.getTerminalFieldDescription(
      objectApiName,
      canonicalPath
    );
    PromptContextDTO.AccessManifestItem item = new PromptContextDTO.AccessManifestItem();
    item.objectApiName = objectApiName;
    item.fieldPath = canonicalPath;
    item.sourceAlias = sourceAlias;
    item.usage = usage;
    item.dataType = String.valueOf(description.getType());
    if (description.isEncrypted()) {
      item.sensitivity = 'Encrypted';
    } else if (CONTACT_DATA_TYPES.contains(description.getType())) {
      item.sensitivity = 'Contact data';
    }
    manifest.items.add(item);
    if (!String.isBlank(item.sensitivity)) {
      manifest.warnings.add(
        new PromptContextDTO.Message(
          'WARNING',
          'SENSITIVE_FIELD_REVIEW',
          (String.isBlank(sourceAlias)
            ? 'Current record'
            : 'Data set ' + sourceAlias),
          canonicalPath +
            ' is classified as ' +
            item.sensitivity +
            '. Confirm that prompt use is appropriate.'
        )
      );
    }
  }

  private static void compareValue(
    PromptContextDTO.VersionComparison comparison,
    String label,
    Object beforeValue,
    Object afterValue
  ) {
    if (String.valueOf(beforeValue) != String.valueOf(afterValue)) {
      addChange(comparison, label + ' changed.');
    }
  }

  private static void compareSources(
    PromptContextDTO.VersionComparison comparison,
    List<PromptContextDTO.SourceConfig> beforeSources,
    List<PromptContextDTO.SourceConfig> afterSources
  ) {
    Map<String, PromptContextDTO.SourceConfig> beforeByAlias = byAlias(
      beforeSources
    );
    Map<String, PromptContextDTO.SourceConfig> afterByAlias = byAlias(
      afterSources
    );
    Set<String> aliases = new Set<String>();
    aliases.addAll(beforeByAlias.keySet());
    aliases.addAll(afterByAlias.keySet());
    List<String> sortedAliases = new List<String>(aliases);
    sortedAliases.sort();
    for (String alias : sortedAliases) {
      if (!beforeByAlias.containsKey(alias)) {
        addChange(comparison, 'Data set ' + alias + ' was added.');
      } else if (!afterByAlias.containsKey(alias)) {
        addChange(comparison, 'Data set ' + alias + ' was removed.');
      } else if (
        comparableSource(beforeByAlias.get(alias)) !=
        comparableSource(afterByAlias.get(alias))
      ) {
        addChange(comparison, 'Data set ' + alias + ' changed.');
      }
    }
  }

  private static String comparableSource(PromptContextDTO.SourceConfig source) {
    PromptContextDTO.SourceConfig normalized = (PromptContextDTO.SourceConfig) JSON.deserialize(
      JSON.serialize(source),
      PromptContextDTO.SourceConfig.class
    );
    normalized.id = null;
    return JSON.serialize(normalized);
  }

  private static Map<String, PromptContextDTO.SourceConfig> byAlias(
    List<PromptContextDTO.SourceConfig> sources
  ) {
    Map<String, PromptContextDTO.SourceConfig> result = new Map<String, PromptContextDTO.SourceConfig>();
    for (
      PromptContextDTO.SourceConfig source : sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source != null && !String.isBlank(source.referenceName)) {
        result.put(source.referenceName.toLowerCase(), source);
      }
    }
    return result;
  }

  private static void addChange(
    PromptContextDTO.VersionComparison comparison,
    String changeText
  ) {
    if (comparison.changes.size() < MAX_COMPARISON_CHANGES) {
      comparison.changes.add(changeText);
    }
  }
}
