/**
 * Checks prompt text, Salesforce objects and fields, user access, and size limits.
 */
public with sharing class PromptContextValidator {
  private static final Set<Schema.DisplayType> NUMERIC_FILTER_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.Currency,
    Schema.DisplayType.Double,
    Schema.DisplayType.Integer,
    Schema.DisplayType.Long,
    Schema.DisplayType.Percent
  };
  @TestVisible
  private static Boolean multiCurrencyOverride;
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
        'Keep the prompt template at or below ' +
          PromptContextContract.MAX_TEMPLATE_CHARACTERS.format() +
          ' characters.'
      );
    }
    validateRoot(config, result);
    validateFileSettings(config, result);
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
    if (
      (config.syntaxVersion ?? PromptContextContract.SYNTAX_VERSION) >=
      PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT
    ) {
      validateReadableOutputRules(config, activeSources, result);
    }
    return result;
  }

  /** Rules that apply only to publications using syntax version 2 or later. */
  private static void validateReadableOutputRules(
    PromptContextDTO.TemplateConfig config,
    Map<String, PromptContextDTO.SourceConfig> activeSources,
    PromptContextDTO.ValidationResult result
  ) {
    String templateBody = config.templateBody ?? '';
    rejectUnsupportedObjectKind(config.rootObject, 'Salesforce object', result);
    for (String alias : activeSources.keySet()) {
      rejectUnsupportedObjectKind(
        activeSources.get(alias).relatedObject,
        'Data set ' + alias,
        result
      );
    }
    rejectCompoundFields(
      config.rootObject,
      PromptTemplateLanguage.getRootFieldPaths(templateBody),
      'Template body',
      result
    );
    Map<String, Set<String>> relatedDependencies = PromptTemplateLanguage.getRelatedFieldPaths(
      templateBody
    );
    for (String alias : activeSources.keySet()) {
      PromptContextDTO.SourceConfig source = activeSources.get(alias);
      Set<String> paths = new Set<String>(
        source.selectedFields ?? new List<String>()
      );
      paths.addAll(relatedDependencies.get(alias) ?? new Set<String>());
      rejectCompoundFields(
        source.relatedObject,
        paths,
        'Data set ' + alias,
        result
      );
    }
    requireReadableFormulaInputs(
      config.rootObject,
      PromptTemplateLanguage.getRootFieldPaths(templateBody),
      'Template body',
      result
    );
    for (String alias : activeSources.keySet()) {
      PromptContextDTO.SourceConfig source = activeSources.get(alias);
      Set<String> paths = new Set<String>(
        source.selectedFields ?? new List<String>()
      );
      paths.addAll(relatedDependencies.get(alias) ?? new Set<String>());
      for (
        PromptContextDTO.FilterRule filter : source.filters ??
          new List<PromptContextDTO.FilterRule>()
      ) {
        if (String.isNotBlank(filter?.fieldName)) {
          paths.add(filter.fieldName);
        }
      }
      for (
        PromptContextDTO.SortRule sortRule : source.sorts ??
          new List<PromptContextDTO.SortRule>()
      ) {
        if (String.isNotBlank(sortRule?.fieldName)) {
          paths.add(sortRule.fieldName);
        }
      }
      if (String.isNotBlank(source.aggregateField)) {
        paths.add(source.aggregateField);
      }
      if (String.isNotBlank(source.correlationField)) {
        paths.add(source.correlationField);
      }
      requireReadableFormulaInputs(
        source.relatedObject,
        paths,
        'Data set ' + alias,
        result
      );
      if (
        source.sourceMode != 'REFERENCE' && String.isNotBlank(source.rootField)
      ) {
        requireReadableFormulaInputs(
          config.rootObject,
          new Set<String>{ source.rootField },
          'Data set ' + alias,
          result
        );
      }
    }
    Map<String, Integer> highestIndexes = PromptTemplateLanguage.getHighestRelatedIndexes(
      templateBody
    );
    for (String alias : highestIndexes.keySet()) {
      PromptContextDTO.SourceConfig source = activeSources.get(alias);
      if (
        source != null &&
        source.maxRows != null &&
        highestIndexes.get(alias) >= source.maxRows
      ) {
        result.addError(
          'INDEX_OUT_OF_RANGE',
          'Template body',
          'related.' +
            alias +
            '[' +
            highestIndexes.get(alias) +
            '] can never have a value because the data set returns at most ' +
            source.maxRows +
            ' records. Indexes start at 0.'
        );
      }
    }
  }

  private static void requireReadableFormulaInputs(
    String objectApiName,
    Set<String> fieldPaths,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    if (String.isBlank(objectApiName)) {
      return;
    }
    for (String fieldPath : fieldPaths) {
      try {
        PromptContextFormulaAccess.requireReadableInputs(
          objectApiName,
          fieldPath
        );
      } catch (PromptContextException exceptionValue) {
        if (String.isNotBlank(exceptionValue.reasonCode)) {
          result.addError(
            exceptionValue.reasonCode,
            location,
            exceptionValue.getMessage()
          );
        }
        // A path without a reason is missing or unreadable; the access checks report it.
      }
    }
  }

  /**
   * External objects query through callouts, big objects need index-only filters, and Knowledge
   * article versions need publication filters. None can be verified here, so they are refused.
   */
  private static void rejectUnsupportedObjectKind(
    String objectApiName,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    String name = (objectApiName ?? '').toLowerCase();
    if (
      name.endsWith('__x') ||
      name.endsWith('__b') ||
      name.endsWith('__kav')
    ) {
      result.addError(
        'OBJECT_KIND_NOT_SUPPORTED',
        location,
        objectApiName +
        ' is an external, big, or Knowledge article object. Choose a standard or custom object.'
      );
    }
  }

  private static void rejectCompoundFields(
    String objectApiName,
    Set<String> fieldPaths,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    if (String.isBlank(objectApiName)) {
      return;
    }
    for (String fieldPath : fieldPaths) {
      Schema.DescribeFieldResult description;
      try {
        description = PromptContextSchema.getTerminalFieldDescription(
          objectApiName,
          fieldPath
        );
      } catch (Exception exceptionValue) {
        // Missing or unreadable fields are reported by the access checks.
        continue;
      }
      Schema.DisplayType fieldType = description?.getType();
      if (
        fieldType == Schema.DisplayType.Address ||
        fieldType == Schema.DisplayType.Location
      ) {
        result.addError(
          'COMPOUND_FIELD_NOT_SUPPORTED',
          location,
          fieldPath +
          ' combines several values. Use its individual parts instead, such as BillingCity or Location__Latitude__s.'
        );
      }
    }
  }

  private static void validateFileSettings(
    PromptContextDTO.TemplateConfig config,
    PromptContextDTO.ValidationResult result
  ) {
    try {
      PromptContextFilePolicy.validateConfiguration(config);
    } catch (PromptContextException exceptionValue) {
      result.addError(
        exceptionValue.reasonCode ??
          PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Salesforce Files',
        exceptionValue.getMessage()
      );
    }
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
        REFERENCE_NAME.matcher(source.referenceName).matches() &&
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
        'MISSING_MATCH_FIELD',
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
            'MATCH_FIELD_NOT_FILTERABLE',
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
              'MATCH_FIELD_TYPES_DIFFER',
              location,
              'The current record field and related record match field use different field types.'
            );
          } else if (
            !areReferenceTargetsCompatible(
              rootObject,
              source.relatedObject,
              rootDescription,
              correlationDescription
            )
          ) {
            result.addError(
              'MATCH_REFERENCE_TARGETS_DIFFER',
              location,
              'The current record field and related record match field reference different Salesforce objects.'
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
        } else if (!aggregateDescription.isAggregatable()) {
          result.addError(
            'AGGREGATE_FIELD_NOT_SUPPORTED',
            location,
            'Salesforce cannot calculate ' +
              source.aggregateOperation +
              ' on ' +
              source.aggregateField +
              '. Choose a field that Salesforce can calculate.'
          );
        }
        if (
          aggregateType == Schema.DisplayType.Currency &&
          isMultiCurrencyOrganization() &&
          !hasMandatoryCurrencyBoundary(source)
        ) {
          result.addError(
            PromptContextReasonCodes.MISSING_CURRENCY_BOUNDARY,
            location,
            'Add a required Currency ISO Code equals rule before using this Currency calculation.'
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
          } else if (
            filter.operator != 'IS_NULL' &&
            filter.operator != 'NOT_NULL' &&
            !String.isBlank(filter.value)
          ) {
            warnAboutFilterValue(filter, filterDescription, location, result);
            try {
              requireUsableFilterValue(source.relatedObject, filter);
            } catch (PromptContextException exceptionValue) {
              result.addError(
                PromptContextReasonCodes.INVALID_CONFIGURATION,
                location,
                'The filter value for ' +
                  filter.fieldName +
                  ' does not match its Salesforce field type. ' +
                  valueFormatHint(filterDescription.getType(), filter.operator)
              );
            }
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
        'Choose no more than ' +
          PromptContextContract.MAX_FIELDS_PER_SOURCE +
          ' fields for one data set.'
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
    validateFilterLogic(source, location, result);
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

  /** Warns about filter values that are valid but will silently match nothing. */
  private static void warnAboutFilterValue(
    PromptContextDTO.FilterRule filter,
    Schema.DescribeFieldResult description,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    Boolean isList = filter.operator == 'IN' || filter.operator == 'NOT_IN';
    List<String> values = isList
      ? filter.value.split(',')
      : new List<String>{ filter.value };
    if (!isList && filter.value != filter.value.trim()) {
      result.addWarning(
        'FILTER_VALUE_WHITESPACE',
        location,
        'The value for ' +
          filter.fieldName +
          ' starts or ends with a space, so it only matches values that have the same spaces.'
      );
    }
    if (
      description.getType() != Schema.DisplayType.Picklist ||
      (filter.operator != 'EQ' &&
      filter.operator != 'NE' &&
      !isList)
    ) {
      return;
    }
    Set<String> known = new Set<String>();
    for (Schema.PicklistEntry entry : description.getPicklistValues()) {
      known.add(entry.getValue().toLowerCase());
    }
    for (String value : values) {
      if (!known.contains(value.trim().toLowerCase())) {
        result.addWarning(
          'UNKNOWN_PICKLIST_VALUE',
          location,
          '"' +
            value.trim() +
            '" is not a value of ' +
            filter.fieldName +
            '. Use the picklist API value; the filter will not match otherwise.'
        );
      }
    }
  }

  /** Throws when a filter value cannot be converted for its field and rule. */
  private static void requireUsableFilterValue(
    String objectApiName,
    PromptContextDTO.FilterRule filter
  ) {
    if (filter.operator == 'IN' || filter.operator == 'NOT_IN') {
      PromptContextQuery.convertList(
        objectApiName,
        filter.fieldName,
        filter.value
      );
    } else if (
      PromptContextQuery.dateLiteral(
        objectApiName,
        filter.fieldName,
        filter.value
      ) == null
    ) {
      PromptContextQuery.convertValue(
        objectApiName,
        filter.fieldName,
        filter.value
      );
    }
  }

  /** Tells an author exactly how to write a filter value for the field type. */
  private static String valueFormatHint(
    Schema.DisplayType fieldType,
    String operatorName
  ) {
    String single;
    if (fieldType == Schema.DisplayType.Date) {
      single = 'Use YYYY-MM-DD, such as 2026-10-19, or a date literal such as LAST_N_DAYS:30.';
    } else if (fieldType == Schema.DisplayType.Datetime) {
      single = 'Use an ISO date and time with a time zone, such as 2026-10-19T09:00:00Z, or a date literal such as THIS_QUARTER.';
    } else if (fieldType == Schema.DisplayType.Boolean) {
      single = 'Use true or false.';
    } else if (NUMERIC_FILTER_TYPES.contains(fieldType)) {
      single = 'Use a number without currency symbols or thousands separators, such as 2500.50.';
    } else if (
      fieldType == Schema.DisplayType.Picklist ||
      fieldType == Schema.DisplayType.MultiPicklist
    ) {
      single = 'Use the picklist API value, not its label.';
    } else {
      single = '';
    }
    return operatorName == 'IN' ||
      operatorName == 'NOT_IN'
      ? ('Separate up to ' +
          PromptContextContract.MAX_FILTER_LIST_VALUES +
          ' values with commas. ' +
          single)
          .trim()
      : single;
  }

  private static Boolean isOperatorCompatible(
    String operatorName,
    Schema.DisplayType fieldType
  ) {
    if (operatorName == 'IN' || operatorName == 'NOT_IN') {
      return fieldType != Schema.DisplayType.MultiPicklist &&
        fieldType != Schema.DisplayType.Boolean;
    }
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
    if (idTypes.contains(rootType) && idTypes.contains(relatedType)) {
      return true;
    }
    Set<Schema.DisplayType> textTypes = new Set<Schema.DisplayType>{
      Schema.DisplayType.Email,
      Schema.DisplayType.Phone,
      Schema.DisplayType.Picklist,
      Schema.DisplayType.String,
      Schema.DisplayType.TextArea,
      Schema.DisplayType.Url
    };
    return textTypes.contains(rootType) && textTypes.contains(relatedType);
  }

  private static Boolean areReferenceTargetsCompatible(
    String rootObject,
    String relatedObject,
    Schema.DescribeFieldResult rootField,
    Schema.DescribeFieldResult relatedField
  ) {
    String rootTarget = referenceTarget(rootObject, rootField);
    String relatedTarget = referenceTarget(relatedObject, relatedField);
    if (rootTarget == '__POLYMORPHIC__' || relatedTarget == '__POLYMORPHIC__') {
      return false;
    }
    return rootTarget == null ||
      relatedTarget == null ||
      rootTarget.equalsIgnoreCase(relatedTarget);
  }

  private static String referenceTarget(
    String owningObject,
    Schema.DescribeFieldResult fieldDescription
  ) {
    if (fieldDescription.getType() == Schema.DisplayType.Id) {
      return owningObject;
    }
    if (fieldDescription.getType() != Schema.DisplayType.Reference) {
      return null;
    }
    List<Schema.SObjectType> targets = fieldDescription.getReferenceTo();
    return targets.size() == 1
      ? PromptContextSchemaCache.describeObject(targets[0]).getName()
      : '__POLYMORPHIC__';
  }

  private static Boolean isMultiCurrencyOrganization() {
    return multiCurrencyOverride == null
      ? UserInfo.isMultiCurrencyOrganization()
      : multiCurrencyOverride;
  }

  @TestVisible
  private static Boolean hasMandatoryCurrencyBoundary(
    PromptContextDTO.SourceConfig source
  ) {
    Set<String> groups = new Set<String>();
    Boolean hasBoundary = false;
    for (
      PromptContextDTO.FilterRule filter : source.filters ??
        new List<PromptContextDTO.FilterRule>()
    ) {
      String groupName = String.isBlank(filter?.groupName)
        ? 'default'
        : filter.groupName.toLowerCase();
      groups.add(groupName);
      if (
        filter != null &&
        filter.fieldName != null &&
        filter.fieldName.equalsIgnoreCase('CurrencyIsoCode') &&
        filter.operator == 'EQ' &&
        Pattern.matches('^[A-Z]{3}$', filter.value ?? '')
      ) {
        hasBoundary = true;
      }
    }
    if (!hasBoundary) {
      return false;
    }
    if (String.isNotBlank(source.filterLogic)) {
      return hasRequiredCurrencyBoundaryInLogic(source);
    }
    return source.filterGroupJoin != 'OR' || groups.size() <= 1;
  }

  private static Boolean hasRequiredCurrencyBoundaryInLogic(
    PromptContextDTO.SourceConfig source
  ) {
    Set<Integer> required;
    try {
      required = PromptContextFilterLogic.parse(
          source.filterLogic,
          source.filters.size()
        )
        .requiredFilters();
    } catch (PromptContextException exceptionValue) {
      return false;
    }
    for (Integer filterNumber : required) {
      PromptContextDTO.FilterRule filter = source.filters[filterNumber - 1];
      if (
        filter?.fieldName != null &&
        filter.fieldName.equalsIgnoreCase('CurrencyIsoCode') &&
        filter.operator == 'EQ' &&
        Pattern.matches('^[A-Z]{3}$', filter.value ?? '')
      ) {
        return true;
      }
    }
    return false;
  }

  private static void validateFilterLogic(
    PromptContextDTO.SourceConfig source,
    String location,
    PromptContextDTO.ValidationResult result
  ) {
    if (String.isBlank(source.filterLogic)) {
      return;
    }
    Boolean usesGroups = (source.filterGroupJoin ?? 'AND') != 'AND';
    for (
      PromptContextDTO.FilterRule filter : source.filters ??
        new List<PromptContextDTO.FilterRule>()
    ) {
      usesGroups = usesGroups || String.isNotBlank(filter?.groupName);
    }
    if (usesGroups) {
      result.addError(
        'FILTER_LOGIC_WITH_GROUPS',
        location,
        'Use either filter logic or filter groups, not both. Clear the group names and set groups to AND.'
      );
    }
    try {
      PromptContextFilterLogic.parse(
        source.filterLogic,
        (source.filters ?? new List<PromptContextDTO.FilterRule>()).size()
      );
    } catch (PromptContextException exceptionValue) {
      result.addError(
        exceptionValue.reasonCode,
        location,
        exceptionValue.getMessage()
      );
    }
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
        String.isBlank(filter.value)
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
    String templateBody = config.templateBody ?? '';
    if (!String.isBlank(config.rootObject)) {
      for (
        String fieldPath : PromptTemplateLanguage.getRootFieldPaths(
          templateBody
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
      templateBody
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
        !Pattern.compile(
            '\\{!\\s*(?:#(?:each|if)\\s+)?related\\.' +
              alias +
              '(?:\\.|\\[|\\s)'
          )
          .matcher(templateBody)
          .find() &&
        !templateBody.contains('aggregate.' + alias + '.value')
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
