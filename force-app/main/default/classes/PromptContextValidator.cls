/**
 * Checks prompt text, Salesforce objects and fields, user access, and size limits.
 */
public with sharing class PromptContextValidator {
  private static final Pattern REFERENCE_NAME = Pattern.compile(
    '^[A-Za-z][A-Za-z0-9_]*$'
  );
  private static final Pattern FILTER_GROUP_NAME = Pattern.compile(
    '^[A-Za-z][A-Za-z0-9_]{0,39}$'
  );
  private static final Set<Schema.DisplayType> TEXT_FILTER_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Email,
    Schema.DisplayType.Phone,
    Schema.DisplayType.String,
    Schema.DisplayType.TextArea,
    Schema.DisplayType.Url
  };
  private static final Set<Schema.DisplayType> RANGE_FILTER_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Currency,
    Schema.DisplayType.Date,
    Schema.DisplayType.Datetime,
    Schema.DisplayType.Double,
    Schema.DisplayType.Integer,
    Schema.DisplayType.Long,
    Schema.DisplayType.Percent
  };
  private static final Set<Schema.DisplayType> NUMERIC_AGGREGATE_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Currency,
    Schema.DisplayType.Double,
    Schema.DisplayType.Integer,
    Schema.DisplayType.Long,
    Schema.DisplayType.Percent
  };

  /**
   * Validates a complete configuration without querying business records.
   * @param config Template configuration
   * @return All blocking errors and non-blocking warnings
   */
  public static PromptContextDTO.ValidationResult validate(
    PromptContextDTO.TemplateConfig config
  ) {
    PromptContextDTO.ValidationResult result = new PromptContextDTO.ValidationResult();
    if (config == null) {
      result.addError(
        'MISSING_CONFIG',
        'Template',
        'Template settings are required.'
      );
      return result;
    }
    if (String.isBlank(config.name)) {
      result.addError(
        'MISSING_NAME',
        'Template name',
        'Enter a template name.'
      );
    }
    if (String.isBlank(config.templateBody)) {
      result.addError(
        'MISSING_TEMPLATE_BODY',
        'Prompt template',
        'Enter the prompt text and at least one merge value.'
      );
    } else if (
      config.templateBody.length() >
      PromptContextContract.MAX_TEMPLATE_CHARACTERS
    ) {
      result.addError(
        'TEMPLATE_TOO_LONG',
        'Prompt template',
        'Keep the prompt template at or below 20,000 characters.'
      );
    }
    validateRoot(config, result);
    Map<String, PromptContextDTO.SourceConfig> activeSources = validateSources(
      config,
      result
    );
    mergeValidation(
      result,
      PromptTemplateLanguage.validateSyntax(
        config.templateBody,
        activeSources.keySet()
      )
    );
    validateSourceTokenModes(config.templateBody, activeSources, result);
    validateDependencies(config, activeSources, result);
    return result;
  }

  private static void validateRoot(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.ValidationResult result
  ) {
    if (String.isBlank(config.rootObject)) {
      result.addError(
        'MISSING_ROOT_OBJECT',
        'Salesforce object',
        'Choose the Salesforce object for the current record.'
      );
      return;
    }
    try {
      PromptContextSchema.requireReadableObject(config.rootObject);
    } catch (PromptContextException exceptionValue) {
      result.addError(
        validationCode(exceptionValue, 'ROOT_OBJECT_ACCESS'),
        'Salesforce object',
        exceptionValue.getMessage()
      );
    }
  }

  private static Map<String, PromptContextDTO.SourceConfig> validateSources(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.ValidationResult result
  ) {
    Map<String, PromptContextDTO.SourceConfig> activeSources = new Map<String, PromptContextDTO.SourceConfig>();
    List<PromptContextDTO.SourceConfig> sources = config.sources ??
      new List<PromptContextDTO.SourceConfig>();
    if (sources.size() > PromptContextContract.MAX_SOURCES) {
      result.addError(
        'TOO_MANY_SOURCES',
        'Related data',
        'Use no more than 10 data sets in one template.'
      );
    }
    Integer position = 0;
    Integer requestedRows = 0;
    for (PromptContextDTO.SourceConfig source : sources) {
      position++;
      if (source == null || source.active == false) {
        continue;
      }
      String location = 'Data set ' + position;
      validateIdentity(source, location, activeSources, result);
      validateSchema(config.rootObject, source, location, result);
      validateLimits(source, location, result);
      if (
        source.resultMode != 'AGGREGATE' &&
        source.maxRows != null &&
        source.maxRows > 0
      ) {
        requestedRows += source.maxRows;
      }
      if (
        !String.isBlank(source.referenceName) &&
        !containsAliasIgnoreCase(activeSources, source.referenceName)
      ) {
        activeSources.put(source.referenceName, source);
      }
    }
    if (requestedRows > PromptContextContract.MAX_ROWS_PER_PROMPT) {
      result.addWarning(
        'TOTAL_ROW_BUDGET_EXCEEDED',
        'Related data',
        'The data sets request up to ' +
          requestedRows +
          ' records. A prompt can include 200 records, in data set order.'
      );
    }
    return activeSources;
  }

  private static void validateIdentity(
    PromptContextDTO.SourceConfig source,
    String location,
    Map<String, PromptContextDTO.SourceConfig> activeSources,
    PromptContextDTO.ValidationResult result
  ) {
    if (
      String.isBlank(source.referenceName) ||
      !REFERENCE_NAME.matcher(source.referenceName).matches()
    ) {
      result.addError(
        'INVALID_REFERENCE',
        location,
        'Reference name must start with a letter and use only letters, numbers, or underscores.'
      );
    } else if (containsAliasIgnoreCase(activeSources, source.referenceName)) {
      result.addError(
        'DUPLICATE_REFERENCE',
        location,
        'Reference name ' + source.referenceName + ' is already used.'
      );
    }
    if (String.isBlank(source.relatedObject)) {
      result.addError(
        'MISSING_RELATED_OBJECT',
        location,
        'Choose a related object.'
      );
    }
    if (!PromptContextContract.SOURCE_MODES.contains(source.sourceMode)) {
      result.addError(
        'INVALID_SOURCE_MODE',
        location,
        'Choose Related to current record or Reference records.'
      );
    }
    if (
      !PromptContextContract.RESULT_MODES.contains(
        source.resultMode ?? 'RECORDS'
      )
    ) {
      result.addError(
        'INVALID_RESULT_MODE',
        location,
        'Choose Records or Calculated value.'
      );
    }
    if (source.resultMode == 'AGGREGATE') {
      if (
        !PromptContextContract.AGGREGATE_OPERATIONS.contains(
          source.aggregateOperation
        )
      ) {
        result.addError(
          'INVALID_AGGREGATE_OPERATION',
          location,
          'Choose Count, Sum, Average, Minimum, or Maximum.'
        );
      } else if (
        source.aggregateOperation != 'COUNT' &&
        String.isBlank(source.aggregateField)
      ) {
        result.addError(
          'MISSING_AGGREGATE_FIELD',
          location,
          'Choose the field to calculate.'
        );
      }
    }
    if (
      source.sourceMode != 'REFERENCE' &&
      String.isBlank(source.correlationField)
    ) {
      result.addError(
        'MISSING_CORRELATION_FIELD',
        location,
        'Choose the related record field that matches the current record.'
      );
    }
    if (source.sourceMode != 'REFERENCE' && String.isBlank(source.rootField)) {
      result.addError(
        'MISSING_ROOT_FIELD',
        location,
        'Choose the current record field used for matching.'
      );
    }
    if (source.sourceMode == 'REFERENCE') {
      result.addWarning(
        'REFERENCE_SOURCE',
        location,
        'This data set is not limited to the current record. It includes only records the person can access and that match the filters and record limit.'
      );
      if (
        (source.filters ?? new List<PromptContextDTO.FilterRule>()).isEmpty()
      ) {
        result.addWarning(
          'UNFILTERED_REFERENCE_SOURCE',
          location,
          'This reference data set has no filters. It includes the first available records in the chosen order, up to the record limit.'
        );
      }
    }
  }

  private static Boolean containsAliasIgnoreCase(
    Map<String, PromptContextDTO.SourceConfig> sources,
    String candidate
  ) {
    for (String existing : sources.keySet()) {
      if (existing.equalsIgnoreCase(candidate)) {
        return true;
      }
    }
    return false;
  }

  private static void validateSchema(
    String rootObject,
    PromptContextDTO.SourceConfig source,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    if (String.isBlank(source.relatedObject)) {
      return;
    }
    try {
      PromptContextSchema.requireReadableObject(source.relatedObject);
      if (
        source.sourceMode != 'REFERENCE' &&
        !String.isBlank(source.correlationField)
      ) {
        Schema.DescribeFieldResult correlationDescription = PromptContextSchema.getTerminalFieldDescription(
          source.relatedObject,
          source.correlationField
        );
        if (!correlationDescription.isFilterable()) {
          result.addError(
            'CORRELATION_NOT_FILTERABLE',
            location,
            'Salesforce cannot filter on the related record match field.'
          );
        }
        if (!String.isBlank(rootObject) && !String.isBlank(source.rootField)) {
          Schema.DescribeFieldResult rootDescription = PromptContextSchema.getTerminalFieldDescription(
            rootObject,
            source.rootField
          );
          if (
            !areCorrelationTypesCompatible(
              rootDescription.getType(),
              correlationDescription.getType()
            )
          ) {
            result.addError(
              'INCOMPATIBLE_CORRELATION_TYPES',
              location,
              'The current record field and related record match field use different field types.'
            );
          }
        }
      }
      for (String fieldName : source.selectedFields ?? new List<String>()) {
        PromptContextSchema.requireReadableFieldPath(
          source.relatedObject,
          fieldName
        );
      }
      if (
        source.resultMode == 'AGGREGATE' &&
        source.aggregateOperation != 'COUNT' &&
        !String.isBlank(source.aggregateField)
      ) {
        Schema.DescribeFieldResult aggregateDescription = PromptContextSchema.getTerminalFieldDescription(
          source.relatedObject,
          source.aggregateField
        );
        Schema.DisplayType aggregateType = aggregateDescription.getType();
        Boolean supported = NUMERIC_AGGREGATE_TYPES.contains(aggregateType);
        if (
          source.aggregateOperation == 'MIN' ||
          source.aggregateOperation == 'MAX'
        ) {
          supported =
            supported ||
            aggregateType == Schema.DisplayType.Date ||
            aggregateType == Schema.DisplayType.Datetime;
        }
        if (!supported) {
          result.addError(
            'AGGREGATE_TYPE_MISMATCH',
            location,
            'The chosen calculation is not supported for that field type.'
          );
        }
      }
      for (
        PromptContextDTO.FilterRule filter : source.filters ??
          new List<PromptContextDTO.FilterRule>()
      ) {
        if (filter != null && !String.isBlank(filter.fieldName)) {
          Schema.DescribeFieldResult filterDescription = PromptContextSchema.getTerminalFieldDescription(
            source.relatedObject,
            filter.fieldName
          );
          if (!filterDescription.isFilterable()) {
            result.addError(
              'FIELD_NOT_FILTERABLE',
              location,
              'Salesforce cannot filter on ' + filter.fieldName + '.'
            );
          } else if (
            !isOperatorCompatible(filter.operator, filterDescription.getType())
          ) {
            result.addError(
              'OPERATOR_TYPE_MISMATCH',
              location,
              'The selected rule ' +
                filter.operator +
                ' cannot be used with ' +
                filter.fieldName +
                '.'
            );
          }
        }
      }
      for (
        PromptContextDTO.SortRule sortRule : source.sorts ??
          new List<PromptContextDTO.SortRule>()
      ) {
        if (sortRule != null && !String.isBlank(sortRule.fieldName)) {
          Schema.DescribeFieldResult sortDescription = PromptContextSchema.getTerminalFieldDescription(
            source.relatedObject,
            sortRule.fieldName
          );
          if (!sortDescription.isSortable()) {
            result.addError(
              'FIELD_NOT_SORTABLE',
              location,
              'Salesforce cannot sort by ' + sortRule.fieldName + '.'
            );
          }
        }
      }
    } catch (PromptContextException exceptionValue) {
      result.addError(
        validationCode(exceptionValue, 'SOURCE_SCHEMA_ACCESS'),
        location,
        exceptionValue.getMessage()
      );
    }
  }

  private static void validateLimits(
    PromptContextDTO.SourceConfig source,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    Integer fieldCount = (source.selectedFields ?? new List<String>()).size();
    Integer filterCount = (source.filters ??
        new List<PromptContextDTO.FilterRule>())
      .size();
    Integer sortCount = (source.sorts ?? new List<PromptContextDTO.SortRule>())
      .size();
    if (source.resultMode == 'AGGREGATE' && fieldCount > 0) {
      result.addError(
        'AGGREGATE_FIELDS_NOT_ALLOWED',
        location,
        'A data set with one calculated value does not use selected record fields. Choose the field to calculate instead.'
      );
    } else if (source.resultMode != 'AGGREGATE' && fieldCount == 0) {
      result.addError(
        'MISSING_SELECTED_FIELDS',
        location,
        'Choose at least one field to make available to the prompt.'
      );
    } else if (fieldCount > PromptContextContract.MAX_FIELDS_PER_SOURCE) {
      result.addError(
        'TOO_MANY_FIELDS',
        location,
        'Choose no more than 25 fields for one data set.'
      );
    }
    if (filterCount > PromptContextContract.MAX_FILTERS_PER_SOURCE) {
      result.addError(
        'TOO_MANY_FILTERS',
        location,
        'Use no more than 10 filters for one data set.'
      );
    }
    if (
      !PromptContextContract.FILTER_GROUP_JOINS.contains(
        source.filterGroupJoin ?? 'AND'
      )
    ) {
      result.addError(
        'INVALID_FILTER_GROUP_JOIN',
        location,
        'Choose AND or OR for how filter groups are combined.'
      );
    }
    if (source.resultMode == 'AGGREGATE' && sortCount > 0) {
      result.addError(
        'AGGREGATE_SORT_NOT_ALLOWED',
        location,
        'A single calculated value does not use sort order.'
      );
    } else if (sortCount > PromptContextContract.MAX_SORTS_PER_SOURCE) {
      result.addError(
        'TOO_MANY_SORTS',
        location,
        'Use no more than three sort fields for one data set.'
      );
    }
    if (
      source.maxRows == null ||
      source.maxRows < 1 ||
      source.maxRows > PromptContextContract.MAX_ROWS_PER_SOURCE
    ) {
      result.addError(
        'INVALID_MAX_ROWS',
        location,
        'Maximum records must be from 1 through 50.'
      );
    }
    if (
      source.sequence == null ||
      source.sequence < 1 ||
      source.sequence > 999
    ) {
      result.addError(
        'INVALID_SEQUENCE',
        location,
        'Order must be from 1 through 999.'
      );
    }
    validateFilters(source.filters, location, result);
    validateSorts(source.sorts, location, result);
  }

  private static void validateSourceTokenModes(
    String templateBody,
    Map<String, PromptContextDTO.SourceConfig> sources,
    PromptContextDTO.ValidationResult result
  ) {
    String body = templateBody ?? '';
    for (String alias : sources.keySet()) {
      Boolean aggregate = sources.get(alias).resultMode == 'AGGREGATE';
      Boolean usesAggregate = Pattern.compile(
          '\\{!aggregate\\.' + alias + '\\.value(?:\\s|\\})'
        )
        .matcher(body)
        .find();
      Boolean usesRecords = Pattern.compile(
          '\\{!(?:#(?:each|if)\\s+)?related\\.' + alias + '(?:\\.|\\[)'
        )
        .matcher(body)
        .find();
      if (aggregate && usesRecords) {
        result.addError(
          'AGGREGATE_USED_AS_RECORDS',
          'Template body',
          'Data set ' +
            alias +
            ' returns one calculated value. Insert its calculated value instead of record fields or repeat blocks.'
        );
      } else if (!aggregate && usesAggregate) {
        result.addError(
          'RECORDS_USED_AS_AGGREGATE',
          'Template body',
          'Data set ' +
            alias +
            ' returns records. Use a record field, count, or repeat block.'
        );
      }
    }
  }

  private static Boolean isOperatorCompatible(
    String operatorName,
    Schema.DisplayType fieldType
  ) {
    if (operatorName == 'CONTAINS' || operatorName == 'STARTS_WITH') {
      return TEXT_FILTER_TYPES.contains(fieldType);
    }
    if (
      operatorName == 'GT' ||
      operatorName == 'GTE' ||
      operatorName == 'LT' ||
      operatorName == 'LTE'
    ) {
      return RANGE_FILTER_TYPES.contains(fieldType);
    }
    return fieldType != Schema.DisplayType.MultiPicklist;
  }

  private static Boolean areCorrelationTypesCompatible(
    Schema.DisplayType rootType,
    Schema.DisplayType relatedType
  ) {
    if (rootType == relatedType) {
      return true;
    }
    Set<Schema.DisplayType> idTypes = new Set<Schema.DisplayType>{
      Schema.DisplayType.Id,
      Schema.DisplayType.Reference,
      Schema.DisplayType.String
    };
    return idTypes.contains(rootType) && idTypes.contains(relatedType);
  }

  private static void validateFilters(
    List<PromptContextDTO.FilterRule> filters,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    Integer position = 0;
    Set<String> groupNames = new Set<String>();
    for (
      PromptContextDTO.FilterRule filter : filters ??
        new List<PromptContextDTO.FilterRule>()
    ) {
      position++;
      if (!String.isBlank(filter?.groupName)) {
        if (!FILTER_GROUP_NAME.matcher(filter.groupName).matches()) {
          result.addError(
            'INVALID_FILTER_GROUP',
            location,
            'Filter group names must start with a letter and use only letters, numbers, or underscores.'
          );
        } else {
          groupNames.add(filter.groupName.toLowerCase());
        }
      } else {
        groupNames.add('default');
      }
      if (
        filter == null ||
        String.isBlank(filter.fieldName) ||
        !PromptContextContract.FILTER_OPERATORS.contains(filter.operator)
      ) {
        result.addError(
          'INVALID_FILTER',
          location,
          'Filter ' + position + ' needs a field and a supported rule.'
        );
      } else if (
        filter.operator != 'IS_NULL' &&
        filter.operator != 'NOT_NULL' &&
        filter.value == null
      ) {
        result.addError(
          'MISSING_FILTER_VALUE',
          location,
          'Filter ' + position + ' needs a value.'
        );
      }
    }
    if (
      groupNames.size() > PromptContextContract.MAX_FILTER_GROUPS_PER_SOURCE
    ) {
      result.addError(
        'TOO_MANY_FILTER_GROUPS',
        location,
        'Use no more than five filter groups for one data set.'
      );
    }
  }

  private static void validateSorts(
    List<PromptContextDTO.SortRule> sorts,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    Integer position = 0;
    for (
      PromptContextDTO.SortRule sortRule : sorts ??
        new List<PromptContextDTO.SortRule>()
    ) {
      position++;
      Boolean validDirection =
        sortRule != null &&
        (sortRule.direction == 'ASC' ||
        sortRule.direction == 'DESC');
      Boolean validNulls =
        sortRule != null &&
        (String.isBlank(sortRule.nullsOrder) ||
        sortRule.nullsOrder == 'FIRST' ||
        sortRule.nullsOrder == 'LAST');
      if (
        sortRule == null ||
        String.isBlank(sortRule.fieldName) ||
        !validDirection ||
        !validNulls
      ) {
        result.addError(
          'INVALID_SORT',
          location,
          'Sort ' +
            position +
            ' needs a field, Ascending or Descending, and an optional choice for where blank values appear.'
        );
      }
    }
  }

  private static void validateDependencies(
    PromptContextDTO.TemplateConfig config,
    Map<String, PromptContextDTO.SourceConfig> activeSources,
    PromptContextDTO.ValidationResult result
  ) {
    if (!String.isBlank(config.rootObject)) {
      for (
        String fieldPath : PromptTemplateLanguage.getRootFieldPaths(
          config.templateBody
        )
      ) {
        try {
          PromptContextSchema.requireReadableFieldPath(
            config.rootObject,
            fieldPath
          );
        } catch (PromptContextException exceptionValue) {
          result.addError(
            validationCode(exceptionValue, 'ROOT_FIELD_ACCESS'),
            'Template body',
            exceptionValue.getMessage()
          );
        }
      }
    }

    Map<String, Set<String>> relatedDependencies = PromptTemplateLanguage.getRelatedFieldPaths(
      config.templateBody
    );
    for (String alias : relatedDependencies.keySet()) {
      PromptContextDTO.SourceConfig source = activeSources.get(alias);
      if (source == null) {
        continue;
      }
      Set<String> selected = new Set<String>();
      for (String selectedField : source.selectedFields ?? new List<String>()) {
        selected.add(selectedField.toLowerCase());
      }
      for (String fieldPath : relatedDependencies.get(alias)) {
        if (!selected.contains(fieldPath.toLowerCase())) {
          result.addError(
            'FIELD_NOT_SELECTED',
            'Data set ' + alias,
            'Add ' +
              fieldPath +
              ' to Selected Fields before using it in the template.'
          );
        }
      }
    }
    Set<Integer> seenSequences = new Set<Integer>();
    for (String alias : activeSources.keySet()) {
      if (
        !relatedDependencies.containsKey(alias) &&
        !config.templateBody.contains('related.' + alias + '.') &&
        !config.templateBody.contains('aggregate.' + alias + '.value')
      ) {
        result.addWarning(
          'UNUSED_SOURCE',
          'Data set ' + alias,
          'This data set is included but not used by the template.'
        );
      }
      Integer sourceSequence = activeSources.get(alias).sequence ?? 1;
      if (seenSequences.contains(sourceSequence)) {
        result.addWarning(
          'DUPLICATE_SEQUENCE',
          'Data set ' + alias,
          'Another data set uses order ' +
            sourceSequence +
            '. Reference name decides which one runs first.'
        );
      }
      seenSequences.add(sourceSequence);
      if (
        activeSources.get(alias).sourceMode != 'REFERENCE' &&
        !String.isBlank(config.rootObject)
      ) {
        try {
          PromptContextSchema.requireReadableFieldPath(
            config.rootObject,
            activeSources.get(alias).rootField
          );
        } catch (PromptContextException exceptionValue) {
          result.addError(
            validationCode(exceptionValue, 'ROOT_CORRELATION_ACCESS'),
            'Data set ' + alias,
            exceptionValue.getMessage()
          );
        }
      }
    }
  }

  private static void mergeValidation(
    PromptContextDTO.ValidationResult target,
    PromptContextDTO.ValidationResult source
  ) {
    target.isValid = target.isValid && source.isValid;
    target.messages.addAll(source.messages);
  }

  private static String validationCode(
    PromptContextException exceptionValue,
    String fallback
  ) {
    return String.isBlank(exceptionValue.reasonCode)
      ? fallback
      : exceptionValue.reasonCode;
  }
}
