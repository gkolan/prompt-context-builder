/**
 * Compiles one validated related source into deterministic bind-variable SOQL.
 */
public with sharing class PromptContextQuery {
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

  /** Builds one limited calculated value from the same safe data set settings. */
  public static Plan buildAggregate(
    PromptContextDTO.SourceConfig source,
    Object correlationValue
  ) {
    String operation = source.aggregateOperation;
    String expression;
    if (operation == 'COUNT') {
      expression = 'COUNT(Id)';
    } else {
      String fieldName = PromptContextSchema.requireReadableFieldPath(
        source.relatedObject,
        source.aggregateField
      );
      expression = operation + '(' + fieldName + ')';
    }
    Map<String, Object> binds = new Map<String, Object>();
    List<String> conditions = buildConditions(source, correlationValue, binds);
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
    Object typedValue = convertValue(objectApiName, fieldName, filter.value);
    if (filter.operator == 'CONTAINS') {
      typedValue = '%' + escapeLikeValue(String.valueOf(typedValue)) + '%';
    } else if (filter.operator == 'STARTS_WITH') {
      typedValue = escapeLikeValue(String.valueOf(typedValue)) + '%';
    }
    binds.put(bindName, typedValue);
    Map<String, String> operators = new Map<String, String>{
      'EQ' => '=',
      'NE' => '!=',
      'GT' => '>',
      'GTE' => '>=',
      'LT' => '<',
      'LTE' => '<=',
      'CONTAINS' => 'LIKE',
      'STARTS_WITH' => 'LIKE'
    };
    return fieldName + ' ' + operators.get(filter.operator) + ' :' + bindName;
  }

  private static String buildOrderBy(PromptContextDTO.SourceConfig source) {
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
    return ' ORDER BY ' + String.join(clauses, ', ');
  }

  private static Object convertValue(
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
        return Boolean.valueOf(value);
      }
      if (fieldType == Schema.DisplayType.Date) {
        return Date.valueOf(value);
      }
      if (fieldType == Schema.DisplayType.Datetime) {
        return Datetime.valueOf(value.replace('T', ' ').replace('Z', ''));
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
