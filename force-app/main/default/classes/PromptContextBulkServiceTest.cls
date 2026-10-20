/** Proves field-value matching uses grouped queries and preserves aligned prompt results. */
@isTest
private class PromptContextBulkServiceTest {
  @isTest
  static void shouldNormalizeIdCaseAndDecimalScaleForBulkKeys() {
    Id accountId = PromptContextTestDataFactory.missingRootRecordId();

    Assert.areEqual(
      PromptContextBulkService.matchKey(String.valueOf(accountId)),
      PromptContextBulkService.matchKey(accountId),
      'String and Id forms of the same identifier should share a key.'
    );
    Assert.areEqual(
      PromptContextBulkService.matchKey(Decimal.valueOf('100.00')),
      PromptContextBulkService.matchKey(Decimal.valueOf('100')),
      'Decimal scale should not affect a bulk match key.'
    );
  }

  @isTest
  static void shouldMatchSharedFieldValueWithOneGroupedSourceQuery() {
    List<String> rootNames = new List<String>();
    for (Integer index = 0; index < 10; index++) {
      rootNames.add('Shared Industry');
    }
    List<Prompt_Template__c> accounts = PromptContextTestDataFactory.createRootRecords(
      rootNames
    );
    PromptContextTestDataFactory.createMatchRecords(
      accounts[0].Id,
      'Shared Industry',
      2
    );
    PromptContextDTO.TemplateConfig config = matchingConfig();
    List<Id> accountIds = new List<Id>();
    for (Prompt_Template__c accountRecord : accounts) {
      accountIds.add(accountRecord.Id);
    }

    Test.startTest();
    Integer beforeQueries = Limits.getQueries();
    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      accountIds
    );
    Integer usedQueries = Limits.getQueries() - beforeQueries;
    Test.stopTest();

    Assert.areEqual(
      2,
      usedQueries,
      'Bulk matching should use one current-record query and one source query.'
    );
    Assert.areEqual(
      10,
      outcomes.size(),
      'Every current record should have one aligned result.'
    );
    for (PromptContextBulkService.Outcome outcome : outcomes) {
      Assert.isTrue(
        outcome.isSuccess(),
        'Every visible current record should render.'
      );
      Assert.isTrue(
        outcome.result.prompt.contains('Contact 0 Shared Industry'),
        'Rows matched by the shared field value should be reused for each current record.'
      );
      Assert.areEqual(
        2,
        outcome.result.sourceRecordCounts.get('guidance'),
        'Each prompt should receive its own record count.'
      );
    }
  }

  @isTest
  static void shouldSkipSourceQueryWhenEveryMatchValueIsBlank() {
    List<Prompt_Template__c> accounts = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Blank one', 'Blank two' }
    );
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.sources[0].rootField = 'Description__c';
    config.sources[0].correlationField = 'Reference_Name__c';
    List<Id> accountIds = new List<Id>{ accounts[0].Id, accounts[1].Id };

    Integer beforeQueries = Limits.getQueries();
    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      accountIds
    );
    Integer usedQueries = Limits.getQueries() - beforeQueries;

    Assert.areEqual(
      1,
      usedQueries,
      'Blank match values should require only the current-record query.'
    );
    for (PromptContextBulkService.Outcome outcome : outcomes) {
      Assert.areEqual(
        'NULL_MATCH_VALUE',
        outcome.result.messages[0].code,
        'The prompt should explain the blank current-record match field.'
      );
    }
  }

  @isTest
  static void shouldGroupAggregateValuesForEveryCurrentRecord() {
    List<Prompt_Template__c> accounts = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Group Alpha', 'Group Beta' }
    );
    PromptContextTestDataFactory.createMatchRecords(
      accounts[0].Id,
      'Group Alpha',
      2
    );
    PromptContextTestDataFactory.createMatchRecords(
      accounts[0].Id,
      'Group Beta',
      1
    );
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.templateBody = 'Matches: {!aggregate.guidance.value}';
    config.sources[0].resultMode = 'AGGREGATE';
    config.sources[0].aggregateOperation = 'COUNT';
    config.sources[0].selectedFields.clear();
    config.sources[0].sorts.clear();

    Integer beforeQueries = Limits.getQueries();
    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      new List<Id>{ accounts[0].Id, accounts[1].Id }
    );
    Integer usedQueries = Limits.getQueries() - beforeQueries;

    Assert.areEqual(
      3,
      usedQueries,
      'The grouped count should use one root query, one bounded candidate query, and one aggregate query.'
    );
    Assert.isTrue(outcomes[0].result.prompt.contains('Matches: 2'));
    Assert.isTrue(outcomes[1].result.prompt.contains('Matches: 1'));
  }

  @isTest
  static void shouldRenderZeroForGroupedCountWithoutMatches() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'No matching records' }
    )[0];
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.templateBody = 'Matches: {!aggregate.guidance.value}';
    config.sources[0].resultMode = 'AGGREGATE';
    config.sources[0].aggregateOperation = 'COUNT';
    config.sources[0].selectedFields.clear();
    config.sources[0].sorts.clear();

    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      new List<Id>{ accountRecord.Id }
    );

    Assert.areEqual(
      'Matches: 0',
      outcomes[0].result.prompt,
      'Bulk COUNT must match the single-record result when no rows match.'
    );
  }

  @isTest
  static void shouldRejectAnAggregateAboveTheInputRowLimit() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Aggregate overflow' }
    )[0];
    PromptContextTestDataFactory.createMatchRecords(
      accountRecord.Id,
      accountRecord.Name,
      PromptContextContract.MAX_AGGREGATE_INPUT_ROWS + 1
    );
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.templateBody = 'Matches: {!aggregate.guidance.value}';
    config.sources[0].resultMode = 'AGGREGATE';
    config.sources[0].aggregateOperation = 'COUNT';
    config.sources[0].selectedFields.clear();
    config.sources[0].sorts.clear();

    try {
      PromptContextBulkService.generate(
        config,
        new List<Id>{ accountRecord.Id }
      );
      Assert.fail('The aggregate must stop before it can exceed query rows.');
    } catch (PromptContextException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.TRANSACTION_BUDGET_EXCEEDED,
        expected.reasonCode
      );
    }
  }

  @isTest
  static void shouldTruncateBusyRecordInsteadOfFailingGeneration() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Busy account' }
    )[0];
    PromptContextTestDataFactory.createMatchRecords(
      accountRecord.Id,
      accountRecord.Name,
      6
    );
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.sources[0].maxRows = 3;

    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      new List<Id>{ accountRecord.Id }
    );

    Assert.isTrue(
      outcomes[0].isSuccess(),
      'A busy parent should still render.'
    );
    Assert.areEqual(3, outcomes[0].result.sourceRecordCounts.get('guidance'));
    Assert.areEqual(
      PromptContextReasonCodes.SOURCE_TRUNCATED,
      outcomes[0].result.messages[0].code,
      'The result should explain deterministic truncation.'
    );
  }

  @isTest
  static void shouldKeepLaterMatchesWhenAnEarlierParentFillsTheGroupedQuery() {
    // The busy parent sorts first, so its rows alone can fill one shared grouped-query limit.
    List<Prompt_Template__c> roots = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Aaa busy parent', 'Zzz quiet parent' }
    );
    PromptContextTestDataFactory.createMatchRecords(
      roots[0].Id,
      roots[0].Name,
      20
    );
    PromptContextTestDataFactory.createMatchRecords(
      roots[1].Id,
      roots[1].Name,
      2
    );

    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      matchingConfig(),
      new List<Id>{ roots[0].Id, roots[1].Id }
    );

    Assert.areEqual(
      3,
      outcomes[0].result.sourceRecordCounts.get('guidance'),
      'The busy parent should stop at its record limit.'
    );
    Assert.areEqual(
      PromptContextReasonCodes.SOURCE_TRUNCATED,
      outcomes[0].result.messages[0].code,
      'The busy parent should report truncation.'
    );
    Assert.areEqual(
      2,
      outcomes[1].result.sourceRecordCounts.get('guidance'),
      'A parent after a busy parent should keep every match.'
    );
    Assert.isTrue(
      outcomes[1].result.messages.isEmpty(),
      'A complete data set should not report truncation: ' +
      outcomes[1].result.messages
    );
  }

  @isTest
  static void shouldReadOneReferenceDataSetForTheWholeCollection() {
    List<Prompt_Template__c> accounts = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'First root', 'Second root' }
    );
    PromptContextTestDataFactory.createMatchRecords(accounts[0].Id, 'Able', 1);
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Shared reference records';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = '{!related.reference_contacts[0].Reference_Name__c}';
    config.sources.add(
      PromptContextTestDataFactory.createReferenceContactsSource()
    );

    Integer beforeQueries = Limits.getQueries();
    List<PromptContextBulkService.Outcome> outcomes = PromptContextBulkService.generate(
      config,
      new List<Id>{ accounts[0].Id, accounts[1].Id }
    );
    Integer usedQueries = Limits.getQueries() - beforeQueries;

    Assert.areEqual(
      2,
      usedQueries,
      'Reference records should be queried once.'
    );
    Assert.areEqual('Able', outcomes[0].result.prompt);
    Assert.areEqual('Able', outcomes[1].result.prompt);
  }

  @isTest
  static void shouldRejectAStringThatCannotBeUsedAsAnIdMatch() {
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.createRootRecords(
      new List<String>{ 'Not an Id' }
    )[0];
    PromptContextDTO.TemplateConfig config = matchingConfig();
    config.sources[0].correlationField = 'Prompt_Template__c';

    try {
      PromptContextBulkService.generate(
        config,
        new List<Id>{ accountRecord.Id }
      );
      Assert.fail('A non-Id String must not reach an Id bind.');
    } catch (PromptContextException exceptionValue) {
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_MATCH_VALUE,
        exceptionValue.reasonCode
      );
    }
  }

  private static PromptContextDTO.TemplateConfig matchingConfig() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Shared value match';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = 'Account {!record.Name}\n{!#each related.guidance as="row"}{!row.Related_Object__c}\n{!/each}';
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'guidance';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.rootField = 'Name';
    source.correlationField = 'Reference_Name__c';
    source.selectedFields = new List<String>{ 'Related_Object__c' };
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'Related_Object__c';
    sortRule.direction = 'ASC';
    source.sorts = new List<PromptContextDTO.SortRule>{ sortRule };
    source.maxRows = 3;
    config.sources.add(source);
    return config;
  }

  @isTest
  static void shouldCalculateInApexWithSoqlNullRulesWhenTheMatchCannotBeGrouped() {
    Id first = PromptContextTestDataFactory.missingRootRecordId();
    Id second = Id.valueOf(String.valueOf(first).left(14) + '2');
    List<SObject> rows = new List<SObject>{
      new Prompt_Context_Source__c(Prompt_Template__c = first, Sequence__c = 5),
      new Prompt_Context_Source__c(
        Prompt_Template__c = first,
        Sequence__c = null
      ),
      new Prompt_Context_Source__c(Prompt_Template__c = first, Sequence__c = 1),
      new Prompt_Context_Source__c(
        Prompt_Template__c = second,
        Sequence__c = null
      )
    };
    Map<String, Object> expectedFirst = new Map<String, Object>{
      'COUNT' => 3,
      'SUM' => Decimal.valueOf(6),
      'AVG' => (Object) Double.valueOf(3),
      'MIN' => Decimal.valueOf(1),
      'MAX' => Decimal.valueOf(5)
    };
    for (String operation : expectedFirst.keySet()) {
      PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
      source.relatedObject = 'Prompt_Context_Source__c';
      source.correlationField = 'Prompt_Template__c';
      source.aggregateOperation = operation;
      source.aggregateField = operation == 'COUNT' ? null : 'Sequence__c';

      Map<String, Object> byKey = PromptContextBulkService.calculateByKey(
        source,
        rows
      );

      Assert.areEqual(
        expectedFirst.get(operation),
        byKey.get(PromptContextBulkService.matchKey(first)),
        operation + ' must ignore blank values like SOQL does.'
      );
      Assert.areEqual(
        operation == 'COUNT' ? (Object) 1 : null,
        byKey.get(PromptContextBulkService.matchKey(second)),
        operation + ' over only blank values follows SOQL.'
      );
    }
  }
}
