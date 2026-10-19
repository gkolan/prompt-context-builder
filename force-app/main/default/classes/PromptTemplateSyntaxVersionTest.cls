/**
 * Verifies the syntax version 2 grammar and output rules, and that publications stored with
 * version 1 keep producing exactly the same text.
 */
@isTest
private class PromptTemplateSyntaxVersionTest {
  private static final Integer V1 = 1;
  private static final Integer V2 = PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT;

  @isTest
  static void shouldStampNewDraftsWithTheCurrentSyntaxVersion() {
    Assert.areEqual(
      V2,
      PromptContextContract.SYNTAX_VERSION,
      'New drafts and publications use the readable-output grammar.'
    );
    Assert.areEqual(
      V2,
      new PromptContextDTO.TemplateConfig().syntaxVersion,
      'A new configuration starts on the current grammar.'
    );
  }

  @isTest
  static void shouldPrintLabelsAndIsoDatesOnlyForVersion2() {
    Prompt_Template__c rootRecord = new Prompt_Template__c(
      Name = 'Acme',
      File_Input_Mode__c = 'USER_SELECT',
      Published_At__c = Datetime.newInstanceGmt(2026, 10, 19, 15, 4, 5)
    );
    String body = '{!record.File_Input_Mode__c} | {!record.Published_At__c}';

    String version2 = renderText(body, rootRecord, V2);
    String version1 = renderText(body, rootRecord, V1);

    Assert.areEqual('User Selects Files | 2026-10-19T15:04:05Z', version2);
    Assert.areEqual(
      'USER_SELECT | ' + rootRecord.Published_At__c.format(),
      version1,
      'A version 1 publication must keep its original output exactly.'
    );
  }

  @isTest
  static void shouldFormatRelatedAndLoopValuesWithTheSameRules() {
    String body =
      '{!related.versions[0].File_Input_Mode__c};' +
      '{!#each related.versions as="v"}{!v.File_Input_Mode__c},{!/each}';
    Map<String, List<SObject>> related = new Map<String, List<SObject>>{
      'versions' => new List<SObject>{
        new Prompt_Template__c(File_Input_Mode__c = 'ALL_ELIGIBLE'),
        new Prompt_Template__c(File_Input_Mode__c = 'DISABLED')
      }
    };

    Assert.areEqual(
      'All Eligible Files;All Eligible Files,Disabled,',
      PromptTemplateLanguage.render(
          body,
          new Prompt_Template__c(),
          related,
          new Map<String, Object>(),
          V2
        )
        .text
    );
  }

  @isTest
  static void shouldPrintCurrencyWithCodeAndPercentOnce() {
    Opportunity opportunityRecord = new Opportunity(
      Amount = Decimal.valueOf('2500.00'),
      Probability = 40
    );
    String expectedCode = UserInfo.isMultiCurrencyOrganization()
      ? null
      : UserInfo.getDefaultCurrency();

    String rendered = renderText(
      '{!record.Amount}|{!record.Probability}|{!record.Probability format="percent"}',
      opportunityRecord,
      V2
    );

    Assert.areEqual(
      (expectedCode == null ? '2500.00' : '2500.00 ' + expectedCode) +
      '|40%|40%',
      rendered,
      'Percent fields print one percent sign even with format="percent".'
    );
  }

  @isTest
  static void shouldShortenOnlyValuesLongerThanMaxLengthAndReportIt() {
    Prompt_Template__c rootRecord = new Prompt_Template__c(
      Name = 'Acme Research'
    );

    PromptTemplateLanguage.RenderOutput shortened = PromptTemplateLanguage.render(
      '{!record.Name maxLength="4"}',
      rootRecord,
      new Map<String, List<SObject>>(),
      new Map<String, Object>(),
      V2
    );
    PromptTemplateLanguage.RenderOutput untouched = PromptTemplateLanguage.render(
      '{!record.Name maxLength="13"}',
      rootRecord,
      new Map<String, List<SObject>>(),
      new Map<String, Object>(),
      V2
    );

    Assert.areEqual('Acme…', shortened.text);
    Assert.isTrue(shortened.truncated, 'Shortening must be reported.');
    Assert.areEqual('Acme Research', untouched.text);
    Assert.isFalse(
      untouched.truncated,
      'A value at exactly maxLength is not shortened.'
    );
  }

  @isTest
  static void shouldApplyMaxLengthToFallbackText() {
    Assert.areEqual(
      'Unkn…',
      renderText(
        '{!record.Description__c fallback="Unknown" maxLength="4"}',
        new Prompt_Template__c(),
        V2
      )
    );
  }

  @isTest
  static void shouldRejectInvalidMaxLengthValues() {
    for (String value : new List<String>{ '0', '-1', 'abc', '20001', '' }) {
      PromptContextDTO.ValidationResult result = PromptTemplateLanguage.validateSyntax(
        '{!record.Name maxLength="' + value + '"}',
        new Set<String>()
      );
      Assert.isFalse(result.isValid, 'maxLength="' + value + '" must fail.');
      Assert.isTrue(
        hasCode(result.messages, 'INVALID_MAX_LENGTH') ||
        hasCode(result.messages, 'MALFORMED_ATTRIBUTE'),
        'maxLength="' + value + '" must name the problem.'
      );
    }
    Assert.isTrue(
      PromptTemplateLanguage.validateSyntax(
          '{!record.Name maxLength="20000"}',
          new Set<String>()
        )
        .isValid,
      'The prompt limit itself is a valid maxLength.'
    );
  }

  @isTest
  static void shouldPrintALiteralMergeOpenerFromTheEscapeToken() {
    String body = 'Salesforce merge fields look like {!!}Account.Name}. Name: {!record.Name}';

    PromptContextDTO.ValidationResult validation = PromptTemplateLanguage.validateSyntax(
      body,
      new Set<String>()
    );
    String rendered = renderText(
      body,
      new Prompt_Template__c(Name = 'Acme'),
      V2
    );

    Assert.isTrue(validation.isValid, 'The escape token must validate.');
    Assert.areEqual(
      'Salesforce merge fields look like {!Account.Name}. Name: Acme',
      rendered
    );
    Assert.isFalse(
      PromptTemplateLanguage.getRootFieldPaths(body).contains('Account.Name'),
      'Escaped text must never become a field dependency.'
    );
  }

  @isTest
  static void shouldNotLetEscapedTextOpenABlock() {
    String rendered = renderText(
      '{!!}#each related.x as="r"}',
      new Prompt_Template__c(),
      V2
    );

    Assert.areEqual(
      '{!#each related.x as="r"}',
      rendered,
      'Escaped block syntax must print as text, not run.'
    );
  }

  @isTest
  static void shouldRejectAnIndexBeyondTheDataSetRowLimitForVersion2Only() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[1].maxRows = 1;
    config.templateBody += '\nSecond priority: {!related.priority_contacts[1].Reference_Name__c}';

    PromptContextDTO.ValidationResult version2 = PromptContextValidator.validate(
      config
    );
    config.syntaxVersion = V1;
    PromptContextDTO.ValidationResult version1 = PromptContextValidator.validate(
      config
    );

    Assert.isTrue(hasCode(version2.messages, 'INDEX_OUT_OF_RANGE'));
    Assert.isFalse(
      hasCode(version1.messages, 'INDEX_OUT_OF_RANGE'),
      'A stored version 1 publication must keep validating as it did.'
    );
  }

  @isTest
  static void shouldAcceptTheLastIndexInsideTheRowLimit() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources[0].maxRows = 2;
    config.templateBody += '\nSecond: {!related.recent_contacts[1].Reference_Name__c}';

    Assert.isFalse(
      hasCode(
        PromptContextValidator.validate(config).messages,
        'INDEX_OUT_OF_RANGE'
      )
    );
  }

  @isTest
  static void shouldRejectCompoundAddressFieldsForVersion2Only() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Address check';
    config.rootObject = 'Account';
    config.templateBody = 'Ship to {!record.ShippingAddress}';

    PromptContextDTO.ValidationResult version2 = PromptContextValidator.validate(
      config
    );
    config.syntaxVersion = V1;
    PromptContextDTO.ValidationResult version1 = PromptContextValidator.validate(
      config
    );

    Assert.isTrue(
      hasCode(version2.messages, 'COMPOUND_FIELD_NOT_SUPPORTED'),
      'An address must be built from its parts.'
    );
    Assert.isFalse(
      hasCode(version1.messages, 'COMPOUND_FIELD_NOT_SUPPORTED'),
      'A stored version 1 publication must keep validating as it did.'
    );
  }

  @isTest
  static void shouldNotOfferCompoundFieldsInTheFieldPicker() {
    Set<String> offered = new Set<String>();
    for (
      PromptContextDTO.Option option : PromptContextSchema.getFieldOptions(
        'Account'
      )
    ) {
      offered.add(option.value);
    }

    Assert.isFalse(offered.contains('ShippingAddress'));
    Assert.isFalse(offered.contains('BillingAddress'));
    Assert.isTrue(
      offered.contains('BillingCity'),
      'The individual address parts remain available.'
    );
  }

  @isTest
  static void shouldTreatAHugeRowIndexAsAnEmptyRowInEveryVersion() {
    String body = '{!related.rows[99999999999].Name fallback="none"}';
    Map<String, List<SObject>> related = new Map<String, List<SObject>>{
      'rows' => new List<SObject>{ new Prompt_Template__c(Name = 'Only') }
    };

    for (Integer version : new List<Integer>{ V1, V2 }) {
      Assert.areEqual(
        'none',
        PromptTemplateLanguage.render(
            body,
            new Prompt_Template__c(),
            related,
            new Map<String, Object>(),
            version
          )
          .text,
        'Version ' + version + ' must not crash on a huge index.'
      );
    }
  }

  @isTest
  static void shouldAllowExactlyTheMaximumNumberOfBlocks() {
    String block = '{!#if related.rows.hasRecords}x{!/if}';
    PromptContextDTO.ValidationResult atLimit = PromptTemplateLanguage.validateSyntax(
      block.repeat(PromptContextContract.MAX_BLOCK_ITERATIONS),
      new Set<String>{ 'rows' }
    );
    PromptContextDTO.ValidationResult overLimit = PromptTemplateLanguage.validateSyntax(
      block.repeat(PromptContextContract.MAX_BLOCK_ITERATIONS + 1),
      new Set<String>{ 'rows' }
    );

    Assert.isTrue(atLimit.isValid, 'The limit itself is allowed.');
    Assert.isTrue(hasCode(overLimit.messages, 'TOO_MANY_BLOCKS'));
    Assert.areEqual(
      'x'.repeat(PromptContextContract.MAX_BLOCK_ITERATIONS),
      PromptTemplateLanguage.render(
          block.repeat(PromptContextContract.MAX_BLOCK_ITERATIONS),
          new Prompt_Template__c(),
          new Map<String, List<SObject>>{
            'rows' => new List<SObject>{ new Prompt_Template__c() }
          },
          new Map<String, Object>(),
          V2
        )
        .text,
      'A template at the block limit must also render.'
    );
  }

  private static String renderText(
    String body,
    SObject rootRecord,
    Integer syntaxVersion
  ) {
    return PromptTemplateLanguage.render(
        body,
        rootRecord,
        new Map<String, List<SObject>>(),
        new Map<String, Object>(),
        syntaxVersion
      )
      .text;
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
