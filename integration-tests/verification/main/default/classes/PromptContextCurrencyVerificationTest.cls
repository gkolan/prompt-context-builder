/**
 * Verifies calculated currency values in a multi-currency org: the result is the exact amount in the
 * required rule's currency, never Salesforce's corporate-currency conversion, on both the matched
 * and the reference-list paths. Requires an active EUR currency that is not the corporate currency.
 * Test-only; not packaged.
 */
@isTest
private class PromptContextCurrencyVerificationTest {
  private static final String KEY = 'pcb_currency_root';

  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Template__c root = PromptContextTestDataFactory.createRootRecord(
        false
      );
      root.Developer_Key__c = KEY;
      insert root;
      List<Opportunity> opportunities = new List<Opportunity>();
      for (
        List<Object> row : new List<List<Object>>{
          new List<Object>{ 'PCB Currency A', 'EUR', 1000 },
          new List<Object>{ 'PCB Currency B', 'EUR', 300 },
          new List<Object>{ 'PCB Currency C', 'USD', 2500 }
        }
      ) {
        Opportunity opportunityRecord = new Opportunity(
          Name = (String) row[0],
          StageName = 'Closed Won',
          CloseDate = Date.newInstance(2026, 6, 1),
          Amount = (Integer) row[2],
          NextStep = KEY
        );
        opportunityRecord.put('CurrencyIsoCode', row[1]);
        opportunities.add(opportunityRecord);
      }
      insert opportunities;
    }
  }

  @isTest
  static void shouldSumInTheRuleCurrencyOnBothCalculationPaths() {
    Assert.isTrue(
      UserInfo.isMultiCurrencyOrganization(),
      'Prerequisite: run this suite in a multi-currency org.'
    );
    Assert.areNotEqual(
      'EUR',
      [SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1]
      .IsoCode,
      'Prerequisite: EUR must not be the corporate currency.'
    );
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
      config.name = 'Currency verification';
      config.rootObject = 'Prompt_Template__c';
      config.templateBody = 'Matched {!aggregate.matched.value}; Reference {!aggregate.listed.value}';
      PromptContextDTO.SourceConfig matched = euroSum('matched');
      matched.correlationField = 'NextStep';
      matched.rootField = 'Developer_Key__c';
      config.sources.add(matched);
      PromptContextDTO.SourceConfig listed = euroSum('listed');
      listed.sourceMode = 'REFERENCE';
      listed.correlationField = null;
      listed.rootField = null;
      PromptContextDTO.FilterRule onlyFixtures = new PromptContextDTO.FilterRule();
      onlyFixtures.fieldName = 'Name';
      onlyFixtures.operator = 'STARTS_WITH';
      onlyFixtures.value = 'PCB Currency';
      listed.filters.add(onlyFixtures);
      config.sources.add(listed);

      Id rootId = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Developer_Key__c = :KEY
        LIMIT 1
      ]
      .Id;

      Assert.areEqual(
        'Matched 1300.00 EUR; Reference 1300.00 EUR',
        PromptContextService.generate(config, rootId).prompt,
        'EUR amounts must be summed in EUR, not converted to the corporate currency.'
      );
    }
  }

  private static PromptContextDTO.SourceConfig euroSum(String alias) {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = alias;
    source.relatedObject = 'Opportunity';
    source.resultMode = 'AGGREGATE';
    source.aggregateOperation = 'SUM';
    source.aggregateField = 'Amount';
    source.selectedFields = new List<String>();
    source.maxRows = 1;
    PromptContextDTO.FilterRule boundary = new PromptContextDTO.FilterRule();
    boundary.fieldName = 'CurrencyIsoCode';
    boundary.operator = 'EQ';
    boundary.value = 'EUR';
    source.filters.add(boundary);
    return source;
  }
}
