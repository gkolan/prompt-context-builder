/** Builds prompts for one published template with grouped, sharing-aware Salesforce queries. */
public with sharing class PromptContextBulkService {
  /** One record's isolated generation outcome. */
  public class Outcome {
    public Id recordId;
    public PromptContextDTO.PromptResult result;
    public String reasonCode;
    public String message;

    public Boolean isSuccess() {
      return result != null;
    }
  }

  /** Generates aligned outcomes with grouped queries; calculations use a limited candidate query first. */
  public static List<Outcome> generate(
    PromptContextDTO.TemplateConfig config,
    List<Id> recordIds
  ) {
    PromptContextDTO.ValidationResult validation = PromptContextService.validate(
      config
    );
    if (!validation.isValid) {
      throw PromptContextException.withReason(
        PromptContextValidationMessages.reason(validation.messages),
        PromptContextValidationMessages.joinErrors(validation.messages)
      );
    }
    List<Id> safeIds = recordIds ?? new List<Id>();
    Map<Id, RuntimeContext> runtimeById = loadRoots(config, safeIds);
    List<PromptContextDTO.SourceConfig> activeSources = activeSources(config);
    for (PromptContextDTO.SourceConfig source : activeSources) {
      loadSource(config, source, runtimeById);
    }
    List<Outcome> outcomes = new List<Outcome>();
    for (Id recordId : safeIds) {
      Outcome outcome = new Outcome();
      outcome.recordId = recordId;
      RuntimeContext runtime = runtimeById.get(recordId);
      if (runtime == null) {
        outcome.reasonCode = PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE;
        outcome.message = Label.PCB_Access_Denied;
      } else {
        try {
          PromptTemplateLanguage.RenderOutput rendered = PromptTemplateLanguage.render(
            config.templateBody,
            runtime.rootRecord,
            runtime.relatedByAlias,
            runtime.aggregateByAlias,
            config.syntaxVersion
          );
          String prompt = rendered.text;
          if (prompt.length() > PromptContextContract.MAX_PROMPT_CHARACTERS) {
            outcome.reasonCode = PromptContextReasonCodes.PROMPT_TOO_LONG;
            outcome.message = 'The generated prompt is longer than 20,000 characters. Reduce fields, records, or template text.';
          } else {
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
            if (rendered.truncated) {
              result.messages.add(PromptContextService.truncationWarning());
            }
            outcome.result = result;
          }
        } catch (Exception renderException) {
          outcome.reasonCode = renderReason(renderException);
          outcome.message = PromptContextTrace.safeMessage(renderException);
        }
      }
      outcomes.add(outcome);
    }
    return outcomes;
  }

  private static Map<Id, RuntimeContext> loadRoots(
    PromptContextDTO.TemplateConfig config,
    List<Id> recordIds
  ) {
    Set<String> fields = PromptContextSchema.addCurrencyCodePaths(
      config.rootObject,
      PromptTemplateLanguage.getRootFieldPaths(config.templateBody)
    );
    fields.add('Id');
    for (PromptContextDTO.SourceConfig source : activeSources(config)) {
      if (source.sourceMode != 'REFERENCE') {
        fields.add(source.rootField);
      }
    }
    List<String> canonicalFields = new List<String>();
    for (String fieldPath : fields) {
      canonicalFields.add(
        PromptContextSchema.requireReadableFieldPath(
          config.rootObject,
          fieldPath
        )
      );
    }
    canonicalFields.sort();
    Set<Id> requestedIds = new Set<Id>(recordIds);
    List<SObject> roots = requestedIds.isEmpty()
      ? new List<SObject>()
      : PromptContextSelector.selectDynamic(
          'SELECT ' +
            String.join(canonicalFields, ', ') +
            ' FROM ' +
            config.rootObject +
            ' WHERE Id IN :recordIds ORDER BY Id',
          new Map<String, Object>{ 'recordIds' => requestedIds }
        );
    Map<Id, RuntimeContext> runtimeById = new Map<Id, RuntimeContext>();
    for (SObject rootRecord : roots) {
      runtimeById.put(
        (Id) rootRecord.get('Id'),
        new RuntimeContext(rootRecord)
      );
    }
    return runtimeById;
  }

  private static void loadSource(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.SourceConfig source,
    Map<Id, RuntimeContext> runtimeById
  ) {
    if (source.sourceMode == 'REFERENCE') {
      loadReferenceSource(config, source, runtimeById);
      return;
    }
    Map<String, Object> valueByKey = new Map<String, Object>();
    Map<Id, String> keyByRecordId = new Map<Id, String>();
    for (Id recordId : runtimeById.keySet()) {
      Object value = getPathValue(
        runtimeById.get(recordId).rootRecord,
        source.rootField
      );
      if (isBlankMatch(value)) {
        addNullMatch(runtimeById.get(recordId), source);
        continue;
      }
      String key = matchKey(value);
      valueByKey.put(key, value);
      keyByRecordId.put(recordId, key);
    }
    if (valueByKey.isEmpty()) {
      return;
    }
    if (source.resultMode == 'AGGREGATE') {
      loadGroupedAggregate(source, runtimeById, keyByRecordId, valueByKey);
    } else {
      loadGroupedRecords(
        config,
        source,
        runtimeById,
        keyByRecordId,
        valueByKey
      );
    }
  }

  private static void loadGroupedRecords(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.SourceConfig source,
    Map<Id, RuntimeContext> runtimeById,
    Map<Id, String> keyByRecordId,
    Map<String, Object> valueByKey
  ) {
    Integer perValueLimit = Math.min(
      source.maxRows,
      PromptContextContract.MAX_ROWS_PER_SOURCE
    );
    Integer candidateLimit = valueByKey.size() * (perValueLimit + 1);
    Integer remainingRows = Math.max(
      0,
      Limits.getLimitQueryRows() -
        Limits.getQueryRows() -
        PromptContextContract.QUERY_ROW_HEADROOM
    );
    if (candidateLimit + 1 > remainingRows) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED,
        'This request could read too many matching records. Reduce the record collection or the data set record limit.'
      );
    }
    PromptContextQuery.Plan plan = PromptContextQuery.buildBulk(
      source,
      requireTypedValues(source, valueByKey.values()),
      config.templateBody,
      candidateLimit + 1
    );
    List<SObject> rows = PromptContextSelector.selectDynamic(
      plan.soql,
      plan.binds
    );
    Map<String, List<SObject>> rowsByKey = new Map<String, List<SObject>>();
    for (SObject row : rows) {
      String key = matchKey(getPathValue(row, source.correlationField));
      if (!rowsByKey.containsKey(key)) {
        rowsByKey.put(key, new List<SObject>());
      }
      rowsByKey.get(key).add(row);
    }
    for (Id recordId : runtimeById.keySet()) {
      if (!keyByRecordId.containsKey(recordId)) {
        continue;
      }
      RuntimeContext runtime = runtimeById.get(recordId);
      List<SObject> matches = rowsByKey.get(keyByRecordId.get(recordId));
      matches = matches == null ? new List<SObject>() : matches.clone();
      Integer available = Math.max(
        0,
        PromptContextContract.MAX_ROWS_PER_PROMPT - runtime.totalRows
      );
      Integer effectiveLimit = Math.min(perValueLimit, available);
      Boolean truncated = matches.size() > effectiveLimit;
      while (matches.size() > effectiveLimit) {
        matches.remove(matches.size() - 1);
      }
      runtime.relatedByAlias.put(source.referenceName, matches);
      runtime.countsByAlias.put(source.referenceName, matches.size());
      runtime.totalRows += matches.size();
      if (truncated) {
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
    }
  }

  private static void loadGroupedAggregate(
    PromptContextDTO.SourceConfig source,
    Map<Id, RuntimeContext> runtimeById,
    Map<Id, String> keyByRecordId,
    Map<String, Object> valueByKey
  ) {
    PromptContextQuery.Plan candidatePlan = PromptContextQuery.buildAggregateBulkCandidates(
      source,
      requireTypedValues(source, valueByKey.values()),
      PromptContextContract.MAX_AGGREGATE_INPUT_ROWS + 1
    );
    List<SObject> candidates = PromptContextSelector.selectDynamic(
      candidatePlan.soql,
      candidatePlan.binds
    );
    requireAggregateCapacity(candidates);
    Set<Id> candidateIds = new Map<Id, SObject>(candidates).keySet();
    Map<String, Object> aggregateByKey = new Map<String, Object>();
    if (!isGroupableMatch(source)) {
      // Salesforce cannot GROUP BY this match field, so calculate from the rows already read.
      aggregateByKey = calculateByKey(source, candidates);
    } else if (!candidateIds.isEmpty()) {
      PromptContextQuery.Plan plan = PromptContextQuery.buildAggregateBulk(
        source,
        requireTypedValues(source, valueByKey.values()),
        candidateIds
      );
      for (
        SObject row : PromptContextSelector.selectDynamic(plan.soql, plan.binds)
      ) {
        aggregateByKey.put(matchKey(row.get('groupKey')), row.get('metric'));
      }
    }
    for (Id recordId : runtimeById.keySet()) {
      if (!keyByRecordId.containsKey(recordId)) {
        continue;
      }
      RuntimeContext runtime = runtimeById.get(recordId);
      Object aggregateValue = aggregateByKey.get(keyByRecordId.get(recordId));
      if (aggregateValue == null && source.aggregateOperation == 'COUNT') {
        aggregateValue = 0;
      }
      runtime.aggregateByAlias.put(source.referenceName, aggregateValue);
      runtime.countsByAlias.put(source.referenceName, 1);
    }
  }

  private static Boolean isGroupableMatch(
    PromptContextDTO.SourceConfig source
  ) {
    return PromptContextSchema.getTerminalFieldDescription(
        source.relatedObject,
        source.correlationField
      )
      .isGroupable();
  }

  /** Calculates COUNT, SUM, AVG, MIN, or MAX per match value with SOQL null semantics. */
  @TestVisible
  private static Map<String, Object> calculateByKey(
    PromptContextDTO.SourceConfig source,
    List<SObject> candidates
  ) {
    String correlationField = PromptContextSchema.requireReadableFieldPath(
      source.relatedObject,
      source.correlationField
    );
    String calculatedField = source.aggregateOperation == 'COUNT'
      ? null
      : PromptContextSchema.requireReadableFieldPath(
          source.relatedObject,
          source.aggregateField
        );
    Map<String, List<Object>> valuesByKey = new Map<String, List<Object>>();
    Map<String, Integer> rowsByKey = new Map<String, Integer>();
    for (SObject candidate : candidates) {
      String key = matchKey(getPathValue(candidate, correlationField));
      rowsByKey.put(key, (rowsByKey.get(key) ?? 0) + 1);
      if (!valuesByKey.containsKey(key)) {
        valuesByKey.put(key, new List<Object>());
      }
      Object value = calculatedField == null
        ? null
        : getPathValue(candidate, calculatedField);
      if (value != null) {
        valuesByKey.get(key).add(value);
      }
    }
    Map<String, Object> resultByKey = new Map<String, Object>();
    for (String key : rowsByKey.keySet()) {
      resultByKey.put(
        key,
        source.aggregateOperation == 'COUNT'
          ? rowsByKey.get(key)
          : calculate(source.aggregateOperation, valuesByKey.get(key))
      );
    }
    return resultByKey;
  }

  private static Object calculate(String operation, List<Object> values) {
    if (values.isEmpty()) {
      return null;
    }
    if (operation == 'SUM' || operation == 'AVG') {
      Decimal total = 0;
      for (Object value : values) {
        total += (Decimal) value;
      }
      // SOQL AVG returns a double, so divide the same way to print identical digits.
      return operation == 'SUM'
        ? (Object) total
        : (Object) (total.doubleValue() / values.size());
    }
    Object selected = values[0];
    for (Object value : values) {
      if (
        operation == 'MIN' ? isLess(value, selected) : isLess(selected, value)
      ) {
        selected = value;
      }
    }
    return selected;
  }

  private static Boolean isLess(Object left, Object right) {
    if (left instanceof Date) {
      return (Date) left < (Date) right;
    }
    if (left instanceof Datetime) {
      return (Datetime) left < (Datetime) right;
    }
    return (Decimal) left < (Decimal) right;
  }

  private static void loadReferenceSource(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.SourceConfig source,
    Map<Id, RuntimeContext> runtimeById
  ) {
    if (source.resultMode == 'AGGREGATE') {
      PromptContextQuery.Plan candidatePlan = PromptContextQuery.buildAggregateCandidates(
        source,
        null,
        PromptContextContract.MAX_AGGREGATE_INPUT_ROWS + 1
      );
      List<SObject> candidates = PromptContextSelector.selectDynamic(
        candidatePlan.soql,
        candidatePlan.binds
      );
      requireAggregateCapacity(candidates);
      Set<Id> candidateIds = new Map<Id, SObject>(candidates).keySet();
      Object value = source.aggregateOperation == 'COUNT' ? 0 : null;
      if (!candidateIds.isEmpty()) {
        PromptContextQuery.Plan plan = PromptContextQuery.buildAggregate(
          source,
          null,
          candidateIds
        );
        List<SObject> rows = PromptContextSelector.selectDynamic(
          plan.soql,
          plan.binds
        );
        value = rows.isEmpty() ? value : rows[0].get('metric');
      }
      for (RuntimeContext runtime : runtimeById.values()) {
        runtime.aggregateByAlias.put(source.referenceName, value);
        runtime.countsByAlias.put(source.referenceName, 1);
      }
      return;
    }
    PromptContextQuery.Plan plan = PromptContextQuery.build(
      source,
      null,
      config.templateBody,
      source.maxRows + 1
    );
    List<SObject> rows = PromptContextSelector.selectDynamic(
      plan.soql,
      plan.binds
    );
    Boolean sourceTruncated = rows.size() > source.maxRows;
    if (sourceTruncated) {
      rows.remove(rows.size() - 1);
    }
    for (RuntimeContext runtime : runtimeById.values()) {
      List<SObject> availableRows = rows.clone();
      Integer remaining = Math.max(
        0,
        PromptContextContract.MAX_ROWS_PER_PROMPT - runtime.totalRows
      );
      Boolean promptTruncated = availableRows.size() > remaining;
      while (availableRows.size() > remaining) {
        availableRows.remove(availableRows.size() - 1);
      }
      runtime.relatedByAlias.put(source.referenceName, availableRows);
      runtime.countsByAlias.put(source.referenceName, availableRows.size());
      runtime.totalRows += availableRows.size();
      if (sourceTruncated || promptTruncated) {
        runtime.messages.add(
          new PromptContextDTO.Message(
            'WARNING',
            PromptContextReasonCodes.SOURCE_TRUNCATED,
            'Data set ' + source.referenceName,
            'More records matched than the configured limit. Only the first ' +
              availableRows.size() +
              ' were included.'
          )
        );
      }
    }
  }

  private static void requireAggregateCapacity(List<SObject> candidates) {
    if (candidates.size() > PromptContextContract.MAX_AGGREGATE_INPUT_ROWS) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED,
        'A calculated data set matches too many records. Narrow its filters before generating.'
      );
    }
  }

  private static void addNullMatch(
    RuntimeContext runtime,
    PromptContextDTO.SourceConfig source
  ) {
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
  }

  private static List<PromptContextDTO.SourceConfig> activeSources(
    PromptContextDTO.TemplateConfig config
  ) {
    List<PromptContextDTO.SourceConfig> sources = new List<PromptContextDTO.SourceConfig>();
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source != null && source.active != false) {
        sources.add(source);
      }
    }
    sources.sort();
    return sources;
  }

  private static Object getPathValue(SObject recordValue, String fieldPath) {
    List<String> segments = fieldPath.split('\\.');
    SObject current = recordValue;
    for (Integer index = 0; index < segments.size() - 1; index++) {
      current = current.getSObject(segments[index]);
      if (current == null) {
        return null;
      }
    }
    return current.get(segments[segments.size() - 1]);
  }

  private static Boolean isBlankMatch(Object value) {
    return value == null ||
      (value instanceof String && String.isBlank((String) value));
  }

  @TestVisible
  private static String matchKey(Object value) {
    if (value == null) {
      return '';
    }
    if (value instanceof Decimal) {
      String decimalKey = String.valueOf(value);
      while (decimalKey.contains('.') && decimalKey.endsWith('0')) {
        decimalKey = decimalKey.substring(0, decimalKey.length() - 1);
      }
      return decimalKey.endsWith('.')
        ? decimalKey.substring(0, decimalKey.length() - 1)
        : decimalKey;
    }
    String key = String.valueOf(value);
    return key.toLowerCase();
  }

  private static Object typedValues(
    PromptContextDTO.SourceConfig source,
    List<Object> values
  ) {
    Schema.DisplayType fieldType = PromptContextSchema.getTerminalFieldDescription(
        source.relatedObject,
        source.correlationField
      )
      .getType();
    if (
      fieldType == Schema.DisplayType.Id ||
      fieldType == Schema.DisplayType.Reference
    ) {
      Set<Id> typed = new Set<Id>();
      for (Object value : values) {
        typed.add((Id) value);
      }
      return typed;
    }
    if (
      fieldType == Schema.DisplayType.Currency ||
      fieldType == Schema.DisplayType.Double ||
      fieldType == Schema.DisplayType.Integer ||
      fieldType == Schema.DisplayType.Long ||
      fieldType == Schema.DisplayType.Percent
    ) {
      Set<Decimal> typed = new Set<Decimal>();
      for (Object value : values) {
        typed.add(Decimal.valueOf(String.valueOf(value)));
      }
      return typed;
    }
    if (fieldType == Schema.DisplayType.Date) {
      Set<Date> typed = new Set<Date>();
      for (Object value : values) {
        typed.add((Date) value);
      }
      return typed;
    }
    if (fieldType == Schema.DisplayType.Datetime) {
      Set<Datetime> typed = new Set<Datetime>();
      for (Object value : values) {
        typed.add((Datetime) value);
      }
      return typed;
    }
    if (fieldType == Schema.DisplayType.Boolean) {
      Set<Boolean> typed = new Set<Boolean>();
      for (Object value : values) {
        typed.add((Boolean) value);
      }
      return typed;
    }
    Set<String> typed = new Set<String>();
    for (Object value : values) {
      typed.add(String.valueOf(value));
    }
    return typed;
  }

  private static Object requireTypedValues(
    PromptContextDTO.SourceConfig source,
    List<Object> values
  ) {
    try {
      return typedValues(source, values);
    } catch (Exception exceptionValue) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_MATCH_VALUE,
        'A current record match value cannot be used with the source match field.'
      );
    }
  }

  private static String renderReason(Exception exceptionValue) {
    if (exceptionValue instanceof PromptContextException) {
      String reasonCode = ((PromptContextException) exceptionValue).reasonCode;
      if (!String.isBlank(reasonCode)) {
        return reasonCode;
      }
    }
    return PromptContextReasonCodes.INVALID_CONFIGURATION;
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

  private PromptContextBulkService() {
  }
}
