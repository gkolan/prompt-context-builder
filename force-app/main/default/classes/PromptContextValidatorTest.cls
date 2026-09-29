/**
 * Tests red scenarios and actionable validation messages for unsafe or incomplete configuration.
 */
@isTest
private class PromptContextValidatorTest {
  @isTest
  static void shouldReturnMissingBodyInsteadOfThrowingForNullBody() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.templateBody = null;

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(hasCode(result.messages, 'MISSING_TEMPLATE_BODY'));
  }

  @isTest
  static void shouldReportInvalidReferenceWithoutCompilingItAsRegex() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].referenceName = 'Cases(';

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(hasCode(result.messages, 'INVALID_REFERENCE'));
  }

  @isTest
  static void shouldValidateFilterValuesBeforeRuntime() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].filters[0].fieldName = 'CreatedDate';
    config.sources[0].filters[0].operator = 'GT';
    config.sources[0].filters[0].value = '2024-13-45';

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(
      hasCode(result.messages, PromptContextReasonCodes.INVALID_CONFIGURATION)
    );
  }

  @isTest
  static void shouldRejectMatchFieldsThatReferenceDifferentObjects() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].rootField = 'OwnerId';
    config.sources[0].correlationField = 'Prompt_Template__c';

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(hasCode(result.messages, 'MATCH_REFERENCE_TARGETS_DIFFER'));
  }
  @isTest
  static void shouldRejectMissingConfiguration_WhenInputIsNull() {
    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      null
    );
    Test.stopTest();
    Assert.isFalse(result.isValid, 'A missing configuration must be rejected.');
    Assert.areEqual(
      'MISSING_CONFIG',
      result.messages[0].code,
      'The error code should be stable.'
    );
  }

  @isTest
  static void shouldReportMultipleProblems_WhenSourceIsMisconfigured() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.rootObject = 'Missing_Object__c';
    config.templateBody = '{!related.unknown.count}';
    for (Integer index = 0; index < 11; index++) {
      PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
      source.referenceName = index == 0 ? '1 invalid' : 'duplicate';
      source.relatedObject = index == 0 ? '' : 'Contact';
      source.correlationField = index == 0 ? '' : 'Missing_Field__c';
      source.rootField = '';
      source.selectedFields = new List<String>();
      source.maxRows = 51;
      PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
      filter.fieldName = '';
      filter.operator = 'UNSAFE';
      source.filters.add(filter);
      PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
      sortRule.fieldName = '';
      sortRule.direction = 'SIDEWAYS';
      source.sorts.add(sortRule);
      config.sources.add(source);
    }

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'Unsafe source configuration must be rejected.'
    );
    Assert.isTrue(
      result.messages.size() > 10,
      'All actionable problems should be returned.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'TOO_MANY_SOURCES'),
      'The source limit should be enforced.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'INVALID_FILTER'),
      'Unsafe filters should be rejected.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'INVALID_SORT'),
      'Unsafe sorting should be rejected.'
    );
  }

  @isTest
  static void shouldWarn_WhenActiveSourceIsUnused() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.templateBody = 'Account {!record.Name}';
    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();
    Assert.isTrue(
      result.isValid,
      'Unused sources should not block a valid template.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'UNUSED_SOURCE'),
      'Unused sources should be explicit.'
    );
  }

  @isTest
  static void shouldNotWarn_WhenEachBlockUsesSourceWithoutRowFields() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources.remove(1);
    config.templateBody = '{!#each related.recent_contacts as="contact"}Contact{!/each}';

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(
      hasCode(result.messages, 'UNUSED_SOURCE'),
      'An each block consumes its source even when its body uses no row field.'
    );
  }

  @isTest
  static void shouldWarnWithoutBlocking_WhenReferenceSourceIsBounded() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Reference Context';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = '{!related.reference_contacts[0].Reference_Name__c}';
    config.sources.add(
      PromptContextTestDataFactory.createReferenceContactsSource()
    );

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isTrue(
      result.isValid,
      'A limited reference data set should pass validation.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'REFERENCE_SOURCE'),
      'The broader record choice should remain visible as a warning.'
    );
  }

  @isTest
  static void shouldRejectOperator_WhenFieldTypeIsIncompatible() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].filters[0].fieldName = 'Reference_Name__c';
    config.sources[0].filters[0].operator = 'GT';

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(result.isValid, 'A text field must reject range operators.');
    Assert.isTrue(
      hasCode(result.messages, 'OPERATOR_TYPE_MISMATCH'),
      'The validator should identify the operator and field-type mismatch.'
    );
  }

  @isTest
  static void shouldRejectUnsafeOrGroupConfiguration() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].filterGroupJoin = 'field = value';
    config.sources[0].filters[0].groupName = '1 unsafe';

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(result.isValid, 'Free-form filter logic must be rejected.');
    Assert.isTrue(
      hasCode(result.messages, 'INVALID_FILTER_GROUP_JOIN'),
      'Only the typed AND/OR choice should be accepted.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'INVALID_FILTER_GROUP'),
      'Group identifiers must be schema-safe names.'
    );
  }

  @isTest
  static void shouldRejectCorrelation_WhenFieldTypesAreIncompatible() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].correlationField = 'CreatedDate';

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'A DateTime field cannot correlate to an Account Id.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'MATCH_FIELD_TYPES_DIFFER'),
      'The check should explain incompatible record-matching field types.'
    );
  }

  @isTest
  static void shouldRejectAlias_WhenItDiffersOnlyByCase() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[1].referenceName = 'RECENT_CONTACTS';

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'Aliases that differ only by case must not create ambiguous references.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'DUPLICATE_REFERENCE'),
      'The duplicate alias should have a stable error code.'
    );
  }

  @isTest
  static void shouldRejectBlankBodyAndInvalidSequence() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.templateBody = '';
    config.sources[0].sequence = 0;

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'A blank prompt and invalid sequence must block publication.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'MISSING_TEMPLATE_BODY'),
      'The empty prompt should have a stable correction code.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'INVALID_SEQUENCE'),
      'The data set order should stay within the supported range.'
    );
  }

  @isTest
  static void shouldWarn_WhenRequestedRowsExceedTemplateBudget() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Large Reference Context';
    config.rootObject = 'Account';
    config.templateBody = '{!related.reference_0.count}';
    for (Integer index = 0; index < 5; index++) {
      PromptContextDTO.SourceConfig source = PromptContextTestDataFactory.createReferenceContactsSource();
      source.referenceName = 'reference_' + index;
      source.sequence = index + 1;
      source.maxRows = 50;
      config.sources.add(source);
    }

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );
    Test.stopTest();

    Assert.isTrue(
      result.isValid,
      'Prompt generation can safely lower an oversized requested limit.'
    );
    Assert.isTrue(
      hasCode(result.messages, 'TOTAL_ROW_BUDGET_EXCEEDED'),
      'The administrator should see that later sources can be capped.'
    );
  }

  @isTest
  static void shouldRejectAggregateMisconfigurationAndRecordSyntax() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    PromptContextDTO.SourceConfig source = config.sources[0];
    config.sources.remove(1);
    source.resultMode = 'AGGREGATE';
    source.aggregateOperation = 'SUM';
    source.aggregateField = 'Reference_Name__c';
    source.sorts.clear();
    source.selectedFields.clear();
    config.templateBody = '{!related.recent_contacts.count}';

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(hasCode(result.messages, 'AGGREGATE_TYPE_MISMATCH'));
    Assert.isTrue(hasCode(result.messages, 'AGGREGATE_USED_AS_RECORDS'));
  }

  @isTest
  static void shouldRequireCurrencyBoundaryInMultiCurrencyOrg() {
    PromptContextDTO.TemplateConfig config = currencyAggregateConfig();
    PromptContextValidator.multiCurrencyOverride = true;

    PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
      config
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(
      hasCode(
        result.messages,
        PromptContextReasonCodes.MISSING_CURRENCY_BOUNDARY
      )
    );
  }

  @isTest
  static void shouldAcceptMandatoryCurrencyBoundary() {
    PromptContextDTO.TemplateConfig config = currencyAggregateConfig();
    PromptContextDTO.FilterRule currencyRule = new PromptContextDTO.FilterRule();
    currencyRule.fieldName = 'CurrencyIsoCode';
    currencyRule.operator = 'EQ';
    currencyRule.value = 'USD';
    config.sources[0].filters.add(currencyRule);
    Assert.isTrue(
      PromptContextValidator.hasMandatoryCurrencyBoundary(config.sources[0]),
      'One required ISO code makes SUM comparable.'
    );
  }

  @isTest
  static void shouldRejectCurrencyBoundaryInsideOptionalOrGroups() {
    PromptContextDTO.TemplateConfig config = currencyAggregateConfig();
    PromptContextDTO.FilterRule currencyRule = new PromptContextDTO.FilterRule();
    currencyRule.fieldName = 'CurrencyIsoCode';
    currencyRule.operator = 'EQ';
    currencyRule.value = 'USD';
    currencyRule.groupName = 'currency';
    config.sources[0].filters.add(currencyRule);
    PromptContextDTO.FilterRule otherRule = new PromptContextDTO.FilterRule();
    otherRule.fieldName = 'Name';
    otherRule.operator = 'STARTS_WITH';
    otherRule.value = 'Renewal';
    otherRule.groupName = 'name';
    config.sources[0].filters.add(otherRule);
    config.sources[0].filterGroupJoin = 'OR';
    Assert.isFalse(
      PromptContextValidator.hasMandatoryCurrencyBoundary(config.sources[0]),
      'A currency rule in one optional OR group is not mandatory.'
    );
  }

  private static PromptContextDTO.TemplateConfig currencyAggregateConfig() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Opportunity amount';
    config.rootObject = 'Account';
    config.templateBody = '{!aggregate.amount.value}';
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'amount';
    source.relatedObject = 'Opportunity';
    source.rootField = 'Id';
    source.correlationField = 'AccountId';
    source.resultMode = 'AGGREGATE';
    source.aggregateOperation = 'SUM';
    source.aggregateField = 'Amount';
    source.selectedFields.clear();
    config.sources.add(source);
    return config;
  }

  private static Boolean hasCode(
    List<PromptContextDTO.Message> messages,
    String code
  ) {
    for (PromptContextDTO.Message message : messages) {
      if (message.code == code) {
        return true;
      }
    }
    return false;
  }
}
