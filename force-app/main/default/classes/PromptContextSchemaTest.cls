/**
 * Tests Salesforce object and field checks for valid, invalid, and relationship fields.
 */
@isTest
private class PromptContextSchemaTest {
  @isTest
  static void shouldReturnCanonicalPath_WhenRelationshipFieldIsReadable() {
    Test.startTest();
    String fieldPath = PromptContextSchema.requireReadableFieldPath(
      'Contact',
      'Account.Name'
    );
    Test.stopTest();

    Assert.areEqual(
      'Account.Name',
      fieldPath,
      'A readable parent relationship path should remain canonical.'
    );
  }

  @isTest
  static void shouldThrow_WhenObjectDoesNotExist() {
    Test.startTest();
    try {
      PromptContextSchema.requireReadableObject('Does_Not_Exist__c');
      Assert.fail('An invalid object must be rejected.');
    } catch (PromptContextException exceptionValue) {
      Assert.isTrue(
        exceptionValue.getMessage().contains('does not exist'),
        'The error should identify the invalid object.'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void shouldReturnFields_WhenObjectIsReadable() {
    Test.startTest();
    List<PromptContextDTO.Option> fields = PromptContextSchema.getFieldOptions(
      'Account'
    );
    Test.stopTest();

    Assert.isTrue(
      fields.size() > 0,
      'Readable Account fields should be available to the builder.'
    );
  }

  @isTest
  static void shouldOfferUnderstandableBusinessObjectsOnly() {
    List<PromptContextDTO.Option> options = PromptContextSchema.getObjectOptions();
    Set<String> values = new Set<String>();
    for (PromptContextDTO.Option option : options) {
      values.add(option.value);
      Assert.isFalse(option.label.startsWith('__MISSING LABEL__'));
    }
    Assert.isTrue(values.contains('Account'));
    Assert.isTrue(values.contains('Contact'));
    Assert.isFalse(values.contains('AccountFeed'));
    Assert.isFalse(values.contains('AccountHistory'));
  }
}
