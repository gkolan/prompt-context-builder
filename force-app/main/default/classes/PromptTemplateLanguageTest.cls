/**
 * Tests the closed merge grammar, block handling, fallbacks, and dependency extraction.
 */
@isTest
private class PromptTemplateLanguageTest {
  @isTest
  static void shouldNotEvaluateMergeSyntaxStoredInRecordValues() {
    Account accountRecord = new Account(
      Name = '{!record.Industry}',
      Industry = 'Technology'
    );

    String rendered = PromptTemplateLanguage.render(
      '{!#each related.contacts as="row"}{!row.LastName}{!/each}',
      accountRecord,
      new Map<String, List<SObject>>{
        'contacts' => new List<SObject>{
          new Contact(LastName = '{!record.Industry}')
        }
      }
    );

    Assert.areEqual(
      '{!record.Industry}',
      rendered,
      'Record data must remain plain text rather than becoming executable template syntax.'
    );
  }

  @isTest
  static void shouldNormalizeSupportedWhitespaceAcrossValidationAndRendering() {
    String templateBody =
      '{! #each related.contacts as = "row" }' +
      '{! row.LastName}' +
      '{! /each }';

    PromptContextDTO.ValidationResult validation = PromptTemplateLanguage.validateSyntax(
      templateBody,
      new Set<String>{ 'contacts' }
    );
    String rendered = PromptTemplateLanguage.render(
      templateBody,
      new Account(Name = 'Acme'),
      new Map<String, List<SObject>>{
        'contacts' => new List<SObject>{ new Contact(LastName = 'Alpha') }
      }
    );

    Assert.isTrue(validation.isValid, 'Supported whitespace must validate.');
    Assert.areEqual('Alpha', rendered, 'Supported whitespace must render.');
    Assert.areEqual(
      new Set<String>{ 'LastName' },
      PromptTemplateLanguage.getRelatedFieldPaths(templateBody).get('contacts'),
      'Supported whitespace must preserve dependency extraction.'
    );
  }

  @isTest
  static void shouldRejectUnknownAndReservedLocalAliases() {
    PromptContextDTO.ValidationResult unknown = PromptTemplateLanguage.validateSyntax(
      '{!acct.Name}',
      new Set<String>()
    );
    PromptContextDTO.ValidationResult reserved = PromptTemplateLanguage.validateSyntax(
      '{!#each related.contacts as="record"}{!record.Name}{!/each}',
      new Set<String>{ 'contacts' }
    );

    Assert.isFalse(
      unknown.isValid,
      'Unknown local aliases must not render silently.'
    );
    Assert.isFalse(
      reserved.isValid,
      'Built-in names must not be used as row aliases.'
    );
  }
  @isTest
  static void shouldRenderRootRelatedAndBlocks_WhenContextExists() {
    Account accountRecord = new Account(Name = 'Acme');
    Contact contactRecord = new Contact(LastName = 'Alpha');
    Map<String, List<SObject>> relatedByAlias = new Map<String, List<SObject>>{
      'contacts' => new List<SObject>{ contactRecord }
    };
    String templateBody =
      '{!record.Name} {!related.contacts.count} ' +
      '{!#if related.contacts.hasRecords}Y{!else}N{!/if} ' +
      '{!#each related.contacts as="row"}{!row.LastName}{!else}None{!/each}';

    Test.startTest();
    String rendered = PromptTemplateLanguage.render(
      templateBody,
      accountRecord,
      relatedByAlias
    );
    Test.stopTest();

    Assert.areEqual(
      'Acme 1 Y Alpha',
      rendered,
      'All supported scalar and block expressions should render.'
    );
  }

  @isTest
  static void shouldUseFallback_WhenRelatedIndexIsMissing() {
    String templateBody = '{!related.contacts[3].Email fallback="Not provided"}';

    Test.startTest();
    String rendered = PromptTemplateLanguage.render(
      templateBody,
      new Account(Name = 'Acme'),
      new Map<String, List<SObject>>{ 'contacts' => new List<SObject>() }
    );
    Test.stopTest();

    Assert.areEqual(
      'Not provided',
      rendered,
      'A missing row should use the configured fallback.'
    );
  }

  @isTest
  static void shouldRenderAggregateWithAllowlistedFormatting() {
    String rendered = PromptTemplateLanguage.render(
      '{!aggregate.open_value.value fallback="0"}',
      new Account(Name = 'Acme'),
      new Map<String, List<SObject>>(),
      new Map<String, Object>{ 'open_value' => Decimal.valueOf('42.5') }
    );
    Assert.areEqual('42.5', rendered);
  }

  @isTest
  static void shouldReturnErrors_WhenBlocksAndAliasesAreInvalid() {
    Test.startTest();
    PromptContextDTO.ValidationResult result = PromptTemplateLanguage.validateSyntax(
      '{!#each related.missing as="row"}{!row.Name}{!/if}',
      new Set<String>{ 'contacts' }
    );
    Test.stopTest();

    Assert.isFalse(
      result.isValid,
      'Mismatched blocks and an unknown alias must block validation.'
    );
    Assert.isTrue(
      result.messages.size() >= 2,
      'Validation should report more than one actionable problem.'
    );
  }

  @isTest
  static void shouldExtractDependencies_WhenDirectAndRepeatedFieldsAreUsed() {
    String templateBody =
      '{!record.Owner.Name} {!related.contacts[0].Email} ' +
      '{!#each related.contacts as="person"}{!person.LastName}{!/each}';

    Test.startTest();
    Set<String> rootFields = PromptTemplateLanguage.getRootFieldPaths(
      templateBody
    );
    Map<String, Set<String>> relatedFields = PromptTemplateLanguage.getRelatedFieldPaths(
      templateBody
    );
    Test.stopTest();

    Assert.isTrue(
      rootFields.contains('Owner.Name'),
      'Parent relationship dependencies should be extracted.'
    );
    Assert.isTrue(
      relatedFields.get('contacts').contains('Email'),
      'Direct related fields should be extracted.'
    );
    Assert.isTrue(
      relatedFields.get('contacts').contains('LastName'),
      'Each-block fields should be extracted.'
    );
  }

  @isTest
  static void shouldRejectUnknownDuplicateMalformedAndUnsupportedAttributes() {
    PromptContextDTO.ValidationResult result = PromptTemplateLanguage.validateSyntax(
      '{!record.Name unknown="x"} ' +
        '{!record.Name fallback="a" fallback="b"} ' +
        '{!record.Name fallback=no} ' +
        '{!record.Name format="currency"}',
      new Set<String>()
    );

    Assert.isFalse(result.isValid);
    Assert.isTrue(hasMessage(result.messages, 'UNKNOWN_ATTRIBUTE'));
    Assert.isTrue(hasMessage(result.messages, 'DUPLICATE_ATTRIBUTE'));
    Assert.isTrue(hasMessage(result.messages, 'MALFORMED_ATTRIBUTE'));
    Assert.isTrue(hasMessage(result.messages, 'UNSUPPORTED_FORMAT'));
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
