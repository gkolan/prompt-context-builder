/**
 * Reads a limited amount of Salesforce data with the running user's access and builds a complete prompt.
 */
public with sharing class PromptContextService {
  /**
   * Checks prompt text, Salesforce fields, access, and limits without reading business records.
   * @param config Complete template configuration
   * @return Actionable validation result
   */
  public static PromptContextDTO.ValidationResult validate(
    PromptContextDTO.TemplateConfig config
  ) {
    return PromptContextValidator.validate(config);
  }

  /**
   * Generates a prompt from an already loaded and validated configuration.
   * @param config Template configuration
   * @param recordId Current Salesforce record Id
   * @return Complete prompt result with counts and warnings, or no prompt on failure
   */
  public static PromptContextDTO.PromptResult generate(
    PromptContextDTO.TemplateConfig config,
    Id recordId
  ) {
    if (recordId == null) {
      throw new PromptContextException(
        'Choose a sample record before generating a prompt.'
      );
    }
    PromptContextDTO.ValidationResult validation = validate(config);
    if (!validation.isValid) {
      throw PromptContextException.withReason(
        PromptContextValidationMessages.reason(validation.messages),
        PromptContextValidationMessages.joinErrors(validation.messages)
      );
    }

    RuntimeContext runtime = loadRuntimeContext(config, recordId);
    String prompt = PromptTemplateLanguage.render(
      config.templateBody,
      runtime.rootRecord,
      runtime.relatedByAlias,
      runtime.aggregateByAlias
    );
    if (prompt.length() > PromptContextContract.MAX_PROMPT_CHARACTERS) {
      throw new PromptContextException(
        'The generated prompt is longer than 20,000 characters. Reduce fields, rows, or template text.'
      );
    }

    PromptContextDTO.PromptResult result = new PromptContextDTO.PromptResult();
    result.prompt = prompt;
    result.contractVersion = config.contractVersion ??
      PromptContextContract.CONTRACT_VERSION;
    result.syntaxVersion = config.syntaxVersion ??
      PromptContextContract.SYNTAX_VERSION;
    result.fingerprint = config.fingerprint;
    result.templateVersion = config.version;
    result.sourceRecordCounts = runtime.countsByAlias;
    result.messages.addAll(runtime.messages);
    return result;
  }

  private static RuntimeContext loadRuntimeContext(
    PromptContextDTO.TemplateConfig config,
    Id recordId
  ) {
    Set<String> rootFields = PromptTemplateLanguage.getRootFieldPaths(
      config.templateBody
    );
    rootFields.add('Id');
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (
        source != null &&
        source.active != false &&
        source.sourceMode != 'REFERENCE'
      ) {
        rootFields.add(source.rootField);
      }
    }
    List<String> canonicalRootFields = new List<String>();
    for (String fieldPath : rootFields) {
      canonicalRootFields.add(
        PromptContextSchema.requireReadableFieldPath(
          config.rootObject,
          fieldPath
        )
      );
    }
    canonicalRootFields.sort();
    String rootQuery =
      'SELECT ' +
      String.join(canonicalRootFields, ', ') +
      ' FROM ' +
      config.rootObject +
      ' WHERE Id = :recordId LIMIT 1';
    List<SObject> rootRecords = PromptContextSelector.selectDynamic(
      rootQuery,
      new Map<String, Object>{ 'recordId' => recordId }
    );
    if (rootRecords.isEmpty()) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE,
        Label.PCB_Access_Denied
      );
    }

    RuntimeContext runtime = new RuntimeContext(rootRecords[0]);
    List<PromptContextDTO.SourceConfig> activeSources = new List<PromptContextDTO.SourceConfig>();
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source != null && source.active != false) {
        activeSources.add(source);
      }
    }
    activeSources.sort();
    loadRelatedAtIndex(activeSources, 0, runtime, config.templateBody);
    return runtime;
  }

  private static void loadRelatedAtIndex(
    List<PromptContextDTO.SourceConfig> sources,
    Integer index,
    RuntimeContext runtime,
    String templateBody
  ) {
    if (index >= sources.size()) {
      return;
    }
    PromptContextDTO.SourceConfig source = sources[index];
    PromptContextSourceStrategy sourceStrategy = PromptContextSourceStrategies.forMode(
      source.sourceMode
    );
    Object correlationValue = sourceStrategy.getCorrelationValue(
      source,
      runtime.rootRecord
    );
    if (sourceStrategy.requiresCorrelation() && correlationValue == null) {
      if (source.resultMode == 'AGGREGATE') {
        runtime.aggregateByAlias.put(source.referenceName, null);
      } else {
        runtime.relatedByAlias.put(source.referenceName, new List<SObject>());
      }
      runtime.countsByAlias.put(source.referenceName, 0);
      runtime.messages.add(
        new PromptContextDTO.Message(
          'WARNING',
          PromptContextReasonCodes.NULL_MATCH_VALUE,
          'Data set ' + source.referenceName,
          'The current record match field is blank, so this data set has no records.'
        )
      );
      loadRelatedAtIndex(sources, index + 1, runtime, templateBody);
      return;
    }
    if (source.resultMode == 'AGGREGATE') {
      PromptContextQuery.Plan candidateQuery = PromptContextQuery.buildAggregateCandidates(
        source,
        correlationValue,
        PromptContextContract.MAX_AGGREGATE_INPUT_ROWS + 1
      );
      List<SObject> candidates = PromptContextSelector.selectDynamic(
        candidateQuery.soql,
        candidateQuery.binds
      );
      if (candidates.size() > PromptContextContract.MAX_AGGREGATE_INPUT_ROWS) {
        throw PromptContextException.withReason(
          PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED,
          'A calculated data set matches too many records. Narrow its filters before generating.'
        );
      }
      Set<Id> candidateIds = new Map<Id, SObject>(candidates).keySet();
      Object aggregateValue = source.aggregateOperation == 'COUNT' ? 0 : null;
      if (!candidateIds.isEmpty()) {
        PromptContextQuery.Plan aggregateQuery = PromptContextQuery.buildAggregate(
          source,
          correlationValue,
          candidateIds
        );
        List<SObject> aggregateRows = PromptContextSelector.selectDynamic(
          aggregateQuery.soql,
          aggregateQuery.binds
        );
        aggregateValue = aggregateRows.isEmpty()
          ? aggregateValue
          : aggregateRows[0].get('metric');
      }
      runtime.aggregateByAlias.put(source.referenceName, aggregateValue);
      runtime.countsByAlias.put(source.referenceName, 1);
      loadRelatedAtIndex(sources, index + 1, runtime, templateBody);
      return;
    }

    Integer remainingRows =
      PromptContextContract.MAX_ROWS_PER_PROMPT - runtime.totalRows;
    if (remainingRows <= 0) {
      runtime.relatedByAlias.put(source.referenceName, new List<SObject>());
      runtime.countsByAlias.put(source.referenceName, 0);
      runtime.messages.add(
        new PromptContextDTO.Message(
          'WARNING',
          PromptContextReasonCodes.TOTAL_ROW_LIMIT,
          'Data set ' + source.referenceName,
          'The prompt reached its 200-record limit before adding this data set.'
        )
      );
      loadRelatedAtIndex(sources, index + 1, runtime, templateBody);
      return;
    }
    Integer effectiveLimit = Math.min(source.maxRows, remainingRows);
    PromptContextQuery.Plan query = PromptContextQuery.build(
      source,
      correlationValue,
      templateBody,
      effectiveLimit + 1
    );
    List<SObject> records = PromptContextSelector.selectDynamic(
      query.soql,
      query.binds
    );
    if (records.size() > effectiveLimit) {
      records.remove(records.size() - 1);
      runtime.messages.add(
        new PromptContextDTO.Message(
          'WARNING',
          PromptContextReasonCodes.SOURCE_TRUNCATED,
          'Data set ' + source.referenceName,
          'More records matched than the configured limit. Only the first ' +
            effectiveLimit +
            ' were included.'
        )
      );
    }
    runtime.relatedByAlias.put(source.referenceName, records);
    runtime.countsByAlias.put(source.referenceName, records.size());
    runtime.totalRows += records.size();
    loadRelatedAtIndex(sources, index + 1, runtime, templateBody);
  }

  private class RuntimeContext {
    private SObject rootRecord;
    private Map<String, List<SObject>> relatedByAlias = new Map<String, List<SObject>>();
    private Map<String, Object> aggregateByAlias = new Map<String, Object>();
    private Map<String, Integer> countsByAlias = new Map<String, Integer>();
    private List<PromptContextDTO.Message> messages = new List<PromptContextDTO.Message>();
    private Integer totalRows = 0;

    private RuntimeContext(SObject rootRecord) {
      this.rootRecord = rootRecord;
    }
  }
}
