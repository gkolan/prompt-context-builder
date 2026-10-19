/**
 * Compiles one validated related source into deterministic bind-variable SOQL.
 */
public with sharing class PromptContextQuery {
  private static final Map<String, String> COMPARISON_OPERATORS = new Map<String, String>{
    'EQ' => '=',
    'NE' => '!=',
    'GT' => '>',
    'GTE' => '>=',
    'LT' => '<',
    'LTE' => '<=',
    'CONTAINS' => 'LIKE',
    'STARTS_WITH' => 'LIKE'
  };
  private static final Pattern DATE_LITERAL_WITH_AMOUNT = Pattern.compile(
    '^([A-Z_]+):([0-9]{1,4})$'
  );

  /** A prepared Salesforce query and its typed filter values. */
  public class Plan {
    public String soql { get; private set; }
    public Map<String, Object> binds { get; private set; }

    /**
     * @param soql Compiled query
     * @param binds Bind values
     */
    public Plan(String soql, Map<String, Object> binds) {
      this.soql = soql;
      this.binds = binds;
    }
  }

  /**
   * Builds a related-data query from validated Salesforce object and field names and typed values.
   * @param source Source configuration
   * @param correlationValue Current-record value matched by the related record field
   * @param templateBody Template used to determine required fields
   * @param queryLimit Record limit including one extra record used to detect more matches
   * @return Compiled query plan
   */
  public static Plan build(
    PromptContextDTO.SourceConfig source,
    Object correlationValue,
    String templateBody,
    Integer queryLimit
  ) {
    Set<String> fields = new Set<String>{ 'Id' };
    fields.addAll(source.selectedFields ?? new List<String>());
    Map<String, Set<String>> dependencies = PromptTemplateLanguage.getRelatedFieldPaths(
      templateBody
    );
    if (dependencies.containsKey(source.referenceName)) {
      fields.addAll(dependencies.get(source.referenceName));
    }
    PromptContextSchema.addCurrencyCodePaths(source.relatedObject, fields);
    List<String> canonicalFields = new List<String>();
    for (String fieldPath : fields) {
      canonicalFields.add(
        PromptContextSchema.requireReadableFieldPath(
          source.relatedObject,
          fieldPath
        )
      );
    }
    canonicalFields.sort();

    Map<String, Object> binds = new Map<String, Object>{
      'rowLimit' => queryLimit
    };
    List<String> conditions = buildConditions(source, correlationValue, binds);
    return new Plan(
      'SELECT ' +
        String.join(canonicalFields, ', ') +
        ' FROM ' +
        source.relatedObject +
        (conditions.isEmpty()
          ? ''
          : ' WHERE ' + String.join(conditions, ' AND ')) +
        buildOrderBy(source) +
        ' LIMIT :rowLimit',
      binds
    );
  }

  /** Builds one limited query for all match values in a bulk request. */
  public static Plan buildBulk(
    PromptContextDTO.SourceConfig source,
    Object correlationValues,
    String templateBody,
    Integer queryLimit
  ) {
    Set<String> fields = selectedFields(source, templateBody);
    fields.add(source.correlationField);
    List<String> canonicalFields = canonicalFields(
      source.relatedObject,
      fields
    );
    Map<String, Object> binds = new Map<String, Object>{
      'correlationValues' => correlationValues,
      'rowLimit' => queryLimit
    };
    String correlationField = PromptContextSchema.requireReadableFieldPath(
      source.relatedObject,
      source.correlationField
    );
    List<String> conditions = new List<String>{
      correlationField + ' IN :correlationValues'
    };
    conditions.addAll(buildFilterConditions(source, binds));
    return new Plan(
      'SELECT ' +
        String.join(canonicalFields, ', ') +
        ' FROM ' +
        source.relatedObject +
        ' WHERE ' +
        String.join(conditions, ' AND ') +
        ' ORDER BY ' +
        correlationField +
        ' ASC, ' +
        buildOrderByClauses(source) +
        ' LIMIT :rowLimit',
      binds
    );
  }

  /** Builds one grouped aggregate query for all match values in a bulk request. */
  public static Plan buildAggregateBulk(
    PromptContextDTO.SourceConfig source,
    Object correlationValues,
    Set<Id> aggregateRecordIds
  ) {
    String correlationField = PromptContextSchema.requireReadableFieldPath(
      source.relatedObject,
      source.correlationField
    );
    String expression = aggregateExpression(source);
    Map<String, Object> binds = new Map<String, Object>{
      'correlationValues' => correlationValues,
      'aggregateRecordIds' => aggregateRecordIds
    };
    List<String> conditions = new List<String>{
      correlationField + ' IN :correlationValues',
      'Id IN :aggregateRecordIds'
    };
    conditions.addAll(buildFilterConditions(source, binds));
    return new Plan(
      'SELECT ' +
        correlationField +
        ' groupKey, ' +
        expression +
        ' metric FROM ' +
        source.relatedObject +
        ' WHERE ' +
        String.join(conditions, ' AND ') +
        ' GROUP BY ' +
        correlationField,
      binds
    );
  }

  /** Builds one limited calculated value from the same safe data set settings. */
  public static Plan buildAggregate(
    PromptContextDTO.SourceConfig source,
    Object correlationValue,
    Set<Id> aggregateRecordIds
  ) {
    String expression = aggregateExpression(source);
    Map<String, Object> binds = new Map<String, Object>{
      'aggregateRecordIds' => aggregateRecordIds
    };
    List<String> conditions = buildConditions(source, correlationValue, binds);
    conditions.add('Id IN :aggregateRecordIds');
    return new Plan(
      'SELECT ' +
        expression +
        ' metric FROM ' +
        source.relatedObject +
        (conditions.isEmpty()
          ? ''
          : ' WHERE ' + String.join(conditions, ' AND ')),
      binds
    );
  }

  /** Selects a limited Id set before one calculated value can scan matching records. */
  public static Plan buildAggregateCandidates(
    PromptContextDTO.SourceConfig source,
    Object correlationValue,
    Integer queryLimit
  ) {
    Map<String, Object> binds = new Map<String, Object>{
      'rowLimit' => queryLimit
    };
    List<String> conditions = buildConditions(source, correlationValue, binds);
    return new Plan(
      'SELECT Id FROM ' +
        source.relatedObject +
        (conditions.isEmpty()
          ? ''
          : ' WHERE ' + String.join(conditions, ' AND ')) +
        ' ORDER BY Id LIMIT :rowLimit',
      binds
    );
  }

  /** Selects a limited grouped Id set before bulk calculations run. */
  public static Plan buildAggregateBulkCandidates(
    PromptContextDTO.SourceConfig source,
    Object correlationValues,
    Integer queryLimit
  ) {
    String correlationField = PromptContextSchema.requireReadableFieldPath(
      source.relatedObject,
      source.correlationField
    );
    Map<String, Object> binds = new Map<String, Object>{
      'correlationValues' => correlationValues,
      'rowLimit' => queryLimit
    };
    List<String> conditions = new List<String>{
      correlationField + ' IN :correlationValues'
    };
    conditions.addAll(buildFilterConditions(source, binds));
    return new Plan(
      'SELECT Id, ' +
        correlationField +
        ' FROM ' +
        source.relatedObject +
        ' WHERE ' +
        String.join(conditions, ' AND ') +
        ' ORDER BY ' +
        correlationField +
        ' ASC, Id ASC LIMIT :rowLimit',
      binds
    );
  }

  private static String aggregateExpression(
    PromptContextDTO.SourceConfig source
  ) {
    if (source.aggregateOperation == 'COUNT') {
      return 'COUNT(Id)';
    }
    return source.aggregateOperation +
      '(' +
      PromptContextSchema.requireReadableFieldPath(
        source.relatedObject,
        source.aggregateField
      ) +
      ')';
  }

  private static Set<String> selectedFields(
    PromptContextDTO.SourceConfig source,
    String templateBody
  ) {
    Set<String> fields = new Set<String>{ 'Id' };
    fields.addAll(source.selectedFields ?? new List<String>());
    Map<String, Set<String>> dependencies = PromptTemplateLanguage.getRelatedFieldPaths(
      templateBody
    );
    if (dependencies.containsKey(source.referenceName)) {
      fields.addAll(dependencies.get(source.referenceName));
    }
    return PromptContextSchema.addCurrencyCodePaths(
      source.relatedObject,
      fields
    );
  }

  private static List<String> canonicalFields(
    String objectName,
    Set<String> fields
  ) {
    List<String> values = new List<String>();
    for (String fieldPath : fields) {
      values.add(
        PromptContextSchema.requireReadableFieldPath(objectName, fieldPath)
      );
    }
    values.sort();
    return values;
  }

  private static List<String> buildConditions(
    PromptContextDTO.SourceConfig source,
    Object correlationValue,
    Map<String, Object> binds
  ) {
    List<String> conditions = new List<String>();
    if (source.sourceMode != 'REFERENCE') {
      String correlationField = PromptContextSchema.requireReadableFieldPath(
        source.relatedObject,
        source.correlationField
      );
      binds.put('correlationValue', correlationValue);
      conditions.add(correlationField + ' = :correlationValue');
    }
    conditions.addAll(buildFilterConditions(source, binds));
    return conditions;
  }

  private static List<String> buildFilterConditions(
    PromptContextDTO.SourceConfig source,
    Map<String, Object> binds
  ) {
    List<String> conditions = new List<String>();
    if (String.isNotBlank(source.filterLogic)) {
      List<String> orderedConditions = new List<String>();
      Integer logicIndex = 0;
      for (PromptContextDTO.FilterRule filter : source.filters) {
        orderedConditions.add(
          buildFilter(source.relatedObject, filter, logicIndex, binds)
        );
        logicIndex++;
      }
      conditions.add(
        PromptContextFilterLogic.parse(
            source.filterLogic,
            orderedConditions.size()
          )
          .toSoql(orderedConditions)
      );
      return conditions;
    }
    Integer filterIndex = 0;
    Map<String, List<String>> conditionsByGroup = new Map<String, List<String>>();
    List<String> groupOrder = new List<String>();
    for (
      PromptContextDTO.FilterRule filter : source.filters ??
        new List<PromptContextDTO.FilterRule>()
    ) {
      String groupName = String.isBlank(filter.groupName)
        ? 'default'
        : filter.groupName.toLowerCase();
      if (!conditionsByGroup.containsKey(groupName)) {
        conditionsByGroup.put(groupName, new List<String>());
        groupOrder.add(groupName);
      }
      conditionsByGroup
        .get(groupName)
        .add(buildFilter(source.relatedObject, filter, filterIndex, binds));
      filterIndex++;
    }
    List<String> filterGroups = new List<String>();
    for (String groupName : groupOrder) {
      filterGroups.add(
        '(' + String.join(conditionsByGroup.get(groupName), ' AND ') + ')'
      );
    }
    if (!filterGroups.isEmpty()) {
      conditions.add(
        '(' +
          String.join(
            filterGroups,
            ' ' + (source.filterGroupJoin ?? 'AND') + ' '
          ) +
          ')'
      );
    }

    return conditions;
  }

  private static String buildFilter(
    String objectApiName,
    PromptContextDTO.FilterRule filter,
    Integer filterIndex,
    Map<String, Object> binds
  ) {
    String fieldName = PromptContextSchema.requireReadableFieldPath(
      objectApiName,
      filter.fieldName
    );
    if (filter.operator == 'IS_NULL') {
      return fieldName + ' = null';
    }
    if (filter.operator == 'NOT_NULL') {
      return fieldName + ' != null';
    }
    String bindName = 'filter' + filterIndex;
    if (filter.operator == 'IN' || filter.operator == 'NOT_IN') {
      binds.put(bindName, convertList(objectApiName, fieldName, filter.value));
      return fieldName +
        (filter.operator == 'IN' ? ' IN :' : ' NOT IN :') +
        bindName;
    }
    String literal = dateLiteral(objectApiName, fieldName, filter.value);
    if (literal != null) {
      // The literal is rebuilt from an allowlist and a whole number up to 4,000, never copied from input.
      return fieldName +
        ' ' +
        COMPARISON_OPERATORS.get(filter.operator) +
        ' ' +
        literal;
    }
    Object typedValue = convertValue(objectApiName, fieldName, filter.value);
    if (filter.operator == 'CONTAINS') {
      typedValue = '%' + escapeLikeValue(String.valueOf(typedValue)) + '%';
    } else if (filter.operator == 'STARTS_WITH') {
      typedValue = escapeLikeValue(String.valueOf(typedValue)) + '%';
    }
    binds.put(bindName, typedValue);
    return fieldName +
      ' ' +
      COMPARISON_OPERATORS.get(filter.operator) +
      ' :' +
      bindName;
  }

  /**
   * Returns the canonical Salesforce date literal for a Date or Date/Time filter value.
   * @param objectApiName Object that owns the field
   * @param fieldPath Field path
   * @param value Saved filter value such as LAST_N_DAYS:30
   * @return Canonical literal, or null when the value is not a supported literal
   */
  public static String dateLiteral(
    String objectApiName,
    String fieldPath,
    String value
  ) {
    if (String.isBlank(value)) {
      return null;
    }
    Schema.DisplayType fieldType = PromptContextSchema.getTerminalFieldDescription(
        objectApiName,
        fieldPath
      )
      .getType();
    if (
      fieldType != Schema.DisplayType.Date &&
      fieldType != Schema.DisplayType.Datetime
    ) {
      return null;
    }
    String normalized = value.trim().toUpperCase();
    if (PromptContextContract.DATE_LITERALS.contains(normalized)) {
      return normalized;
    }
    Matcher withAmount = DATE_LITERAL_WITH_AMOUNT.matcher(normalized);
    if (
      withAmount.matches() &&
      PromptContextContract.DATE_LITERALS_WITH_AMOUNT.contains(
        withAmount.group(1)
      )
    ) {
      Integer amount = Integer.valueOf(withAmount.group(2));
      if (
        amount >= 1 &&
        amount <= PromptContextContract.MAX_DATE_LITERAL_AMOUNT
      ) {
        return withAmount.group(1) + ':' + amount;
      }
    }
    return null;
  }

  /**
   * Converts a comma-separated IN value into a typed bind list.
   * @param objectApiName Object that owns the field
   * @param fieldPath Field path
   * @param value Comma-separated values
   * @return Typed list suitable for an IN bind
   */
  public static Object convertList(
    String objectApiName,
    String fieldPath,
    String value
  ) {
    List<String> items = new List<String>();
    for (String item : (value ?? '').split(',')) {
      if (String.isBlank(item)) {
        throw PromptContextException.withReason(
          PromptContextReasonCodes.INVALID_CONFIGURATION,
          'Separate list values with commas and leave no value empty.'
        );
      }
      items.add(item.trim());
    }
    if (items.size() > PromptContextContract.MAX_FILTER_LIST_VALUES) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Use no more than ' +
          PromptContextContract.MAX_FILTER_LIST_VALUES +
          ' values in one list.'
      );
    }
    Schema.DisplayType fieldType = PromptContextSchema.getTerminalFieldDescription(
        objectApiName,
        fieldPath
      )
      .getType();
    if (fieldType == Schema.DisplayType.Date) {
      List<Date> dates = new List<Date>();
      for (String item : items) {
        dates.add((Date) convertValue(objectApiName, fieldPath, item));
      }
      return dates;
    }
    if (fieldType == Schema.DisplayType.Datetime) {
      List<Datetime> instants = new List<Datetime>();
      for (String item : items) {
        instants.add((Datetime) convertValue(objectApiName, fieldPath, item));
      }
      return instants;
    }
    Object sample = convertValue(objectApiName, fieldPath, items[0]);
    if (sample instanceof Decimal) {
      List<Decimal> numbers = new List<Decimal>();
      for (String item : items) {
        numbers.add((Decimal) convertValue(objectApiName, fieldPath, item));
      }
      return numbers;
    }
    return items;
  }

  private static String buildOrderBy(PromptContextDTO.SourceConfig source) {
    return ' ORDER BY ' + buildOrderByClauses(source);
  }

  private static String buildOrderByClauses(
    PromptContextDTO.SourceConfig source
  ) {
    List<String> clauses = new List<String>();
    Boolean sortsById = false;
    for (
      PromptContextDTO.SortRule sortRule : source.sorts ??
        new List<PromptContextDTO.SortRule>()
    ) {
      String fieldName = PromptContextSchema.requireReadableFieldPath(
        source.relatedObject,
        sortRule.fieldName
      );
      clauses.add(
        fieldName +
          ' ' +
          sortRule.direction +
          (String.isBlank(sortRule.nullsOrder)
            ? ''
            : ' NULLS ' + sortRule.nullsOrder)
      );
      sortsById = sortsById || fieldName.equalsIgnoreCase('Id');
    }
    if (!sortsById) {
      clauses.add('Id ASC');
    }
    return String.join(clauses, ', ');
  }

  @TestVisible
  public static Object convertValue(
    String objectApiName,
    String fieldPath,
    String value
  ) {
    Schema.DisplayType fieldType = PromptContextSchema.getTerminalFieldDescription(
        objectApiName,
        fieldPath
      )
      .getType();
    try {
      if (fieldType == Schema.DisplayType.Boolean) {
        if (value != 'true' && value != 'false') {
          throw new PromptContextException();
        }
        return Boolean.valueOf(value);
      }
      if (fieldType == Schema.DisplayType.Date) {
        return Date.valueOf(value);
      }
      if (fieldType == Schema.DisplayType.Datetime) {
        return (Datetime) JSON.deserialize(
          JSON.serialize(value),
          Datetime.class
        );
      }
      if (
        fieldType == Schema.DisplayType.Currency ||
        fieldType == Schema.DisplayType.Double ||
        fieldType == Schema.DisplayType.Integer ||
        fieldType == Schema.DisplayType.Long ||
        fieldType == Schema.DisplayType.Percent
      ) {
        return Decimal.valueOf(value);
      }
      return value;
    } catch (Exception exceptionValue) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'A filter value does not match the selected field type.'
      );
    }
  }

  private static String escapeLikeValue(String value) {
    return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
  }
}
