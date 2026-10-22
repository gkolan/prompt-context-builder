/**
 * Verifies numbered filter logic, IN lists, and relative date literals, including hostile and
 * misconfigured input that must never reach SOQL.
 */
@isTest
private class PromptContextFilterLogicTest {
  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
    }
  }

  @isTest
  static void shouldRebuildNestedLogicFromTheParsedTree() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextFilterLogic.Node logic = PromptContextFilterLogic.parse(
        ' 1  and ( 2 OR not 3 ) ',
        3
      );

      Assert.areEqual(
        '((a) AND ((b) OR (NOT (c))))',
        logic.toSoql(new List<String>{ 'a', 'b', 'c' })
      );
      Assert.areEqual(new Set<Integer>{ 1 }, logic.requiredFilters());
      Assert.areEqual(new Set<Integer>{ 1, 2, 3 }, logic.referencedFilters());
    }
  }

  @isTest
  static void shouldReportOnlyTopLevelAndFiltersAsRequired() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Assert.areEqual(
        new Set<Integer>{ 1 },
        PromptContextFilterLogic.parse('1', 1).requiredFilters()
      );
      Assert.areEqual(
        new Set<Integer>(),
        PromptContextFilterLogic.parse('1 OR 2', 2).requiredFilters()
      );
      Assert.areEqual(
        new Set<Integer>(),
        PromptContextFilterLogic.parse('NOT 1', 1).requiredFilters()
      );
      Assert.areEqual(
        new Set<Integer>{ 1, 2, 3 },
        PromptContextFilterLogic.parse('(1 AND 2) AND 3', 3).requiredFilters(),
        'Nested AND groups are still required.'
      );
      Assert.areEqual(
        new Set<Integer>{ 1 },
        PromptContextFilterLogic.parse('1 AND (2 OR 3)', 3).requiredFilters()
      );
    }
  }

  @isTest
  static void shouldRejectMalformedAndHostileLogicWithoutBuildingSoql() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Map<String, String> expectedCodes = new Map<String, String>{
        '1 AND 2 OR 3' => 'INVALID_FILTER_LOGIC',
        '1 OR Id != null' => 'INVALID_FILTER_LOGIC',
        '1; DELETE' => 'INVALID_FILTER_LOGIC',
        '1 OR (2' => 'INVALID_FILTER_LOGIC',
        '()' => 'INVALID_FILTER_LOGIC',
        '1 AND' => 'INVALID_FILTER_LOGIC',
        'NOT' => 'INVALID_FILTER_LOGIC',
        '1 2 3' => 'INVALID_FILTER_LOGIC',
        '4 AND 1 AND 2 AND 3' => 'INVALID_FILTER_LOGIC',
        '0 OR 1 OR 2 OR 3' => 'INVALID_FILTER_LOGIC',
        '0001 OR 2 OR 3' => 'INVALID_FILTER_LOGIC',
        '1 AND 2' => 'FILTER_NOT_IN_LOGIC',
        '   ' => 'INVALID_FILTER_LOGIC'
      };
      for (String logic : expectedCodes.keySet()) {
        try {
          PromptContextFilterLogic.parse(logic, 3);
          Assert.fail('Logic "' + logic + '" must be rejected.');
        } catch (PromptContextException expected) {
          Assert.areEqual(
            expectedCodes.get(logic),
            expected.reasonCode,
            'Wrong reason for "' + logic + '": ' + expected.getMessage()
          );
        }
      }
      try {
        PromptContextFilterLogic.parse('1' + ' OR 1'.repeat(60), 1);
        Assert.fail('Logic longer than the limit must be rejected.');
      } catch (PromptContextException expected) {
        Assert.areEqual('INVALID_FILTER_LOGIC', expected.reasonCode);
      }
    }
  }

  @isTest
  static void shouldApplyNestedLogicToRealRecords() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'Related_Object__c', 'CONTAINS', 'example' },
          new List<String>{ 'Reference_Name__c', 'EQ', 'Alpha' },
          new List<String>{ 'Reference_Name__c', 'EQ', 'Zulu' }
        }
      );
      config.sources[0].filterLogic = '1 AND (2 OR 3)';

      Assert.areEqual('Alpha;Zulu;', generate(config));

      config.sources[0].filterLogic = '1 AND NOT (2 OR 3)';
      Assert.areEqual('Middle;', generate(config), 'NOT must exclude both.');
    }
  }

  @isTest
  static void shouldMatchInAndNotInLists() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig included = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'Reference_Name__c', 'IN', ' Alpha ,Middle' }
        }
      );
      PromptContextDTO.TemplateConfig excluded = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'Reference_Name__c', 'NOT_IN', 'Alpha' }
        }
      );

      Assert.areEqual('Alpha;Middle;', generate(included));
      Assert.areEqual('Middle;Zulu;', generate(excluded));
    }
  }

  @isTest
  static void shouldFilterWithRelativeDateLiterals() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig today = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'CreatedDate', 'GTE', 'last_n_days:1' }
        }
      );
      PromptContextDTO.TemplateConfig lastYear = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'CreatedDate', 'EQ', 'LAST_YEAR' }
        }
      );

      Assert.areEqual('Alpha;Middle;Zulu;', generate(today));
      Assert.areEqual(
        'None',
        generate(lastYear),
        'Records created today are not from last year.'
      );
    }
  }

  @isTest
  static void shouldTreatDateLiteralWordsAsPlainTextOnTextFields() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Assert.isNull(
        PromptContextQuery.dateLiteral(
          'Prompt_Context_Source__c',
          'Reference_Name__c',
          'TODAY'
        ),
        'A text field compares against the word, not a date.'
      );
    }
  }

  @isTest
  static void shouldCanonicalizeOnlyAllowlistedDateLiterals() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Map<String, String> cases = new Map<String, String>{
        'today' => 'TODAY',
        ' This_Quarter ' => 'THIS_QUARTER',
        'LAST_N_DAYS:007' => 'LAST_N_DAYS:7',
        'N_DAYS_AGO:4000' => 'N_DAYS_AGO:4000',
        'LAST_N_DAYS:0' => null,
        'LAST_N_DAYS:4001' => null,
        'LAST_N_DAYS:-5' => null,
        'LAST_N_DAYS' => null,
        'TODAY OR Id != null' => null,
        'LAST_FISCAL_YEAR' => null,
        'NEXT_N_SECONDS:5' => null
      };
      for (String value : cases.keySet()) {
        Assert.areEqual(
          cases.get(value),
          PromptContextQuery.dateLiteral(
            'Prompt_Context_Source__c',
            'CreatedDate',
            value
          ),
          'Unexpected literal for "' + value + '"'
        );
      }
    }
  }

  @isTest
  static void shouldReportActionableErrorsForMisconfiguredFilters() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Map<String, List<String>> cases = new Map<String, List<String>>{
        'empty list item' => new List<String>{
          'Reference_Name__c',
          'IN',
          'Alpha,,Zulu',
          'commas'
        },
        'boolean list' => new List<String>{
          'Active__c',
          'IN',
          'true,false',
          'OPERATOR_TYPE_MISMATCH'
        },
        'bad date amount' => new List<String>{
          'CreatedDate',
          'GT',
          'LAST_N_DAYS:0',
          'THIS_QUARTER'
        },
        'locale date' => new List<String>{
          'CreatedDate',
          'GT',
          '10/19/2026',
          '2026-10-19T09:00:00Z'
        },
        'currency symbol' => new List<String>{
          'Max_Rows__c',
          'GT',
          '$5',
          'without currency symbols'
        }
      };
      for (String label : cases.keySet()) {
        List<String> item = cases.get(label);
        PromptContextDTO.TemplateConfig config = configWithFilters(
          new List<List<String>>{
            new List<String>{ item[0], item[1], item[2] }
          }
        );
        PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
          config
        );
        Assert.isFalse(result.isValid, label + ' must fail validation.');
        Assert.isTrue(
          mentions(result.messages, item[3]),
          label + ' must explain the fix (' + item[3] + '): ' + result.messages
        );
      }
    }
  }

  @isTest
  static void shouldRejectListsAboveTheValueLimit() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      List<String> values = new List<String>();
      for (
        Integer index = 0;
        index <= PromptContextContract.MAX_FILTER_LIST_VALUES;
        index++
      ) {
        values.add('Name' + index);
      }
      PromptContextDTO.TemplateConfig config = configWithFilters(
        new List<List<String>>{
          new List<String>{
            'Reference_Name__c',
            'IN',
            String.join(values, ',')
          }
        }
      );

      Assert.isFalse(PromptContextValidator.validate(config).isValid);
    }
  }

  @isTest
  static void shouldRejectLogicMixedWithGroupsOrUnusedFilters() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = configWithFilters(
        new List<List<String>>{
          new List<String>{ 'Reference_Name__c', 'EQ', 'Alpha' },
          new List<String>{ 'Reference_Name__c', 'EQ', 'Zulu' }
        }
      );
      config.sources[0].filterLogic = '1 OR 2';
      config.sources[0].filters[1].groupName = 'second';

      Assert.isTrue(
        hasCode(
          PromptContextValidator.validate(config).messages,
          'FILTER_LOGIC_WITH_GROUPS'
        )
      );

      config.sources[0].filters[1].groupName = null;
      config.sources[0].filterLogic = '1';
      Assert.isTrue(
        hasCode(
          PromptContextValidator.validate(config).messages,
          'FILTER_NOT_IN_LOGIC'
        ),
        'An unused filter is almost always a mistake.'
      );
    }
  }

  @isTest
  static void shouldRequireTheCurrencyBoundaryAsATopLevelAndInLogic() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
      source.filters = new List<PromptContextDTO.FilterRule>{
        filter('CurrencyIsoCode', 'EQ', 'USD'),
        filter('Name', 'EQ', 'Acme')
      };
      source.filterLogic = '1 AND 2';
      Assert.isTrue(
        PromptContextValidator.hasMandatoryCurrencyBoundary(source)
      );

      source.filterLogic = '1 OR 2';
      Assert.isFalse(
        PromptContextValidator.hasMandatoryCurrencyBoundary(source),
        'An OR can bypass the currency boundary.'
      );

      source.filterLogic = 'NOT 1 AND 2';
      Assert.isFalse(
        PromptContextValidator.hasMandatoryCurrencyBoundary(source),
        'A negated boundary is not a boundary.'
      );
    }
  }

  private static PromptContextDTO.TemplateConfig configWithFilters(
    List<List<String>> filters
  ) {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources.remove(1);
    PromptContextDTO.SourceConfig source = config.sources[0];
    source.maxRows = 10;
    source.filters.clear();
    for (List<String> item : filters) {
      source.filters.add(filter(item[0], item[1], item[2]));
    }
    config.templateBody =
      '{!#each related.recent_contacts as="row"}{!row.Reference_Name__c};' +
      '{!else}None{!/each}';
    return config;
  }

  private static PromptContextDTO.FilterRule filter(
    String fieldName,
    String operator,
    String value
  ) {
    PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
    rule.fieldName = fieldName;
    rule.operator = operator;
    rule.value = value;
    return rule;
  }

  private static String generate(PromptContextDTO.TemplateConfig config) {
    return PromptContextService.generate(
        config,
        PromptContextTestDataFactory.selectRootRecord().Id
      )
      .prompt;
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

  private static Boolean mentions(
    List<PromptContextDTO.Message> messages,
    String text
  ) {
    for (PromptContextDTO.Message message : messages) {
      if (
        (message.code ?? '').contains(text) ||
        (message.text ?? '').contains(text)
      ) {
        return true;
      }
    }
    return false;
  }
}
