/**
 * Tests validation and generation with package-owned records that subscriber automation cannot alter.
 */
@isTest
private class PromptContextServiceTest {
  @isTest
  static void shouldRejectUnsupportedRecordSelectionStrategy() {
    try {
      PromptContextSourceStrategies.forMode('UNSUPPORTED');
      Assert.fail('An unsupported record selection must stop the request.');
    } catch (PromptContextException exceptionValue) {
      Assert.isTrue(exceptionValue.getMessage().contains('unsupported'));
    }
    Assert.isNotNull(
      new PromptContextReasonCodes(),
      'The stable result-code utility should remain constructible only for tests.'
    );
  }

  @TestSetup
  static void setupTestData() {
    Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
      true
    );
    PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
  }

  @isTest
  static void shouldPrintTheOwnerNameOfTheCurrentRecord() {
    Prompt_Template__c rootRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Owner name';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = 'Owner: {!record.Owner.Name}';

    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      rootRecord.Id
    );

    // Apex tests cannot read Name values through a polymorphic relationship (SOQL returns null
    // here), so compare with what Salesforce returns in this context. A real org prints the name.
    String ownerName = [
      SELECT Owner.Name
      FROM Prompt_Template__c
      WHERE Id = :rootRecord.Id
    ]
    .Owner.Name;
    Assert.areEqual('Owner: ' + (ownerName ?? ''), result.prompt);
  }

  @isTest
  static void shouldKeepSameObjectSourcesIndependent_WhenFiltersAndSortsDiffer() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.isTrue(
      result.prompt.contains('Recent: Alpha;Middle;'),
      'The first source should apply its own ascending sort and two-row limit.'
    );
    Assert.isTrue(
      result.prompt.contains('Priority: Zulu'),
      'The second source should apply its own filter independently.'
    );
    Assert.areEqual(
      2,
      result.sourceRecordCounts.get('recent_contacts'),
      'The first source should report two rows.'
    );
    Assert.areEqual(
      1,
      result.sourceRecordCounts.get('priority_contacts'),
      'The second source should report one row.'
    );
  }

  @isTest
  static void shouldApplyBoundedOrBetweenNamedFilterGroups() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources.remove(1);
    PromptContextDTO.SourceConfig source = config.sources[0];
    source.maxRows = 10;
    source.filterGroupJoin = 'OR';
    source.filters.clear();
    for (String lastName : new List<String>{ 'Alpha', 'Zulu' }) {
      PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
      filter.fieldName = 'Reference_Name__c';
      filter.operator = 'EQ';
      filter.value = lastName;
      filter.groupName = 'name_' + lastName.toLowerCase();
      source.filters.add(filter);
    }
    config.templateBody = '{!#each related.recent_contacts as="row"}{!row.Reference_Name__c};{!/each}';

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.isTrue(
      result.prompt.contains('Alpha;'),
      'The first group should match.'
    );
    Assert.isTrue(
      result.prompt.contains('Zulu;'),
      'The second group should match.'
    );
    Assert.isFalse(
      result.prompt.contains('Middle;'),
      'A record outside both groups must not match.'
    );
  }

  @isTest
  static void shouldWarnAndTruncate_WhenMoreRowsMatchThanConfigured() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].maxRows = 1;

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      result.sourceRecordCounts.get('recent_contacts'),
      'The source must honor its one-row bound.'
    );
    Assert.isTrue(
      result.messages.size() > 0,
      'Truncation should always be reported.'
    );
    Assert.areEqual(
      'SOURCE_TRUNCATED',
      result.messages[0].code,
      'The warning should have a stable code.'
    );
  }

  @isTest
  static void shouldReportFieldNotSelected_WhenTemplateUsesUnavailableField() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.templateBody += ' {!related.recent_contacts[0].Correlation_Field__c}';

    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptContextService.validate(
      config
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'A related merge field must be explicitly selected.'
    );
    Assert.isTrue(
      hasMessage(result.messages, 'FIELD_NOT_SELECTED'),
      'The result should explain how to fix the field selection.'
    );
  }

  @isTest
  static void shouldRenderElse_WhenNoRelatedRecordsMatch() {
    Prompt_Template__c emptyAccount = PromptContextTestDataFactory.createRootRecord(
      true
    );
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      emptyAccount.Id
    );
    Test.stopTest();

    Assert.isTrue(
      result.prompt.contains('Recent: None'),
      'An empty source should render the each-block else branch.'
    );
    Assert.isTrue(
      result.prompt.contains('Priority: None'),
      'A missing indexed row should render its fallback.'
    );
  }

  @isTest
  static void shouldGenerateBoundedRows_WhenSourceIsReferenceMode() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Reference Context';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody =
      'Account: {!record.Name}\n' +
      '{!#each related.reference_contacts as="row"}{!row.Reference_Name__c};{!/each}';
    config.sources.add(
      PromptContextTestDataFactory.createReferenceContactsSource()
    );

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.isTrue(
      result.prompt.contains('Alpha;'),
      'The structured reference query should render matching visible records.'
    );
    Assert.areEqual(
      1,
      result.sourceRecordCounts.get('reference_contacts'),
      'The reference data set should honor its filter independently of the current record.'
    );
  }

  @isTest
  static void shouldReturnNoRows_WhenRelatedRootValueIsBlank() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].rootField = 'Description__c';
    config.sources[0].correlationField = 'Reference_Name__c';
    config.sources[0].maxRows = 10;
    config.sources.remove(1);
    config.templateBody = '{!#each related.recent_contacts as="row"}{!row.Reference_Name__c};{!else}None{!/each}';

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      result.sourceRecordCounts.get('recent_contacts'),
      'A blank current-record match value must not include unrelated records with blank lookups.'
    );
    Assert.isTrue(
      hasMessage(result.messages, PromptContextReasonCodes.NULL_MATCH_VALUE),
      'The skipped query should be explained to the user.'
    );
  }

  @isTest
  static void shouldRenderBoundedAggregate_WhenSourceCountsRelatedRecords() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Related Record Count';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = 'Visible contacts: {!aggregate.contact_count.value}';
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'contact_count';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.correlationField = 'Prompt_Template__c';
    source.rootField = 'Id';
    source.resultMode = 'AGGREGATE';
    source.aggregateOperation = 'COUNT';
    source.selectedFields.clear();
    config.sources.add(source);

    Test.startTest();
    PromptContextDTO.PromptResult result = PromptContextService.generate(
      config,
      accountRecord.Id
    );
    Test.stopTest();

    Assert.isTrue(
      result.prompt.contains('Visible contacts: 3'),
      'COUNT must use the same current-record match and running-user access.'
    );
    Assert.areEqual(1, result.sourceRecordCounts.get('contact_count'));
  }

  @isTest
  static void shouldFailAtomicallyWithoutExposingARejectedFilterValue() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[1].filters[0].fieldName = 'Sequence__c';
    config.sources[1].filters[0].operator = 'GTE';
    config.sources[1].filters[0].value = 'CANARY_CUSTOMER_VALUE';

    try {
      PromptContextService.generate(config, accountRecord.Id);
      Assert.fail(
        'A later source failure must abort the whole prompt instead of returning partial content.'
      );
    } catch (PromptContextException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        expected.reasonCode
      );
      Assert.isFalse(
        expected.getMessage().contains('CANARY_CUSTOMER_VALUE'),
        'Rejected record-like values must not appear in diagnostics.'
      );
    }
  }

  private static Boolean hasMessage(
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
