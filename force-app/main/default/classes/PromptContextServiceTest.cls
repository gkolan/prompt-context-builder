/**
 * Tests validation and generation, including two independently configured sources on the same object.
 */
@isTest
private class PromptContextServiceTest {
  @TestSetup
  static void setupTestData() {
    Account accountRecord = PromptContextTestDataFactory.createAccount(true);
    PromptContextTestDataFactory.createContacts(accountRecord.Id, true);
  }

  @isTest
  static void shouldKeepSameObjectSourcesIndependent_WhenFiltersAndSortsDiffer() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
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
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources.remove(1);
    PromptContextDTO.SourceConfig source = config.sources[0];
    source.maxRows = 10;
    source.filterGroupJoin = 'OR';
    source.filters.clear();
    for (String lastName : new List<String>{ 'Alpha', 'Zulu' }) {
      PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
      filter.fieldName = 'LastName';
      filter.operator = 'EQ';
      filter.value = lastName;
      filter.groupName = 'name_' + lastName.toLowerCase();
      source.filters.add(filter);
    }
    config.templateBody = '{!#each related.recent_contacts as="row"}{!row.LastName};{!/each}';

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
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
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
    config.templateBody += ' {!related.recent_contacts[0].Phone}';

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
    Account emptyAccount = new Account(Name = 'No Contacts');
    insert emptyAccount;
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
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Reference Context';
    config.rootObject = 'Account';
    config.templateBody =
      'Account: {!record.Name}\n' +
      '{!#each related.reference_contacts as="row"}{!row.LastName};{!/each}';
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
    Account accountRecord = [SELECT Id, ParentId FROM Account LIMIT 1];
    insert new Contact(LastName = 'Unrelated Orphan');
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].rootField = 'ParentId';
    config.sources[0].maxRows = 10;
    config.sources.remove(1);
    config.templateBody = '{!#each related.recent_contacts as="row"}{!row.LastName};{!else}None{!/each}';

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
      hasMessage(result.messages, 'NULL_CORRELATION_VALUE'),
      'The skipped query should be explained to the user.'
    );
  }

  @isTest
  static void shouldRenderBoundedAggregate_WhenSourceCountsRelatedRecords() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Contact Count';
    config.rootObject = 'Account';
    config.templateBody = 'Visible contacts: {!aggregate.contact_count.value}';
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'contact_count';
    source.relatedObject = 'Contact';
    source.correlationField = 'AccountId';
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
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[1].filters[0].fieldName = 'Birthdate';
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
