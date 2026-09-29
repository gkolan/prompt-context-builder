/** Tests strict, timezone-independent conversion of filter bind values. */
@isTest
private class PromptContextQueryTest {
  @isTest
  static void shouldParseIsoDatetimeAsTheDeclaredInstant() {
    Datetime utcValue = (Datetime) PromptContextQuery.convertValue(
      'Contact',
      'CreatedDate',
      '2024-01-01T00:00:00Z'
    );
    Datetime offsetValue = (Datetime) PromptContextQuery.convertValue(
      'Contact',
      'CreatedDate',
      '2024-01-01T05:00:00+05:00'
    );

    Assert.areEqual(
      Datetime.newInstanceGmt(2024, 1, 1, 0, 0, 0),
      utcValue,
      'A Z value must not be shifted by the running user time zone.'
    );
    Assert.areEqual(
      utcValue,
      offsetValue,
      'Equivalent ISO-8601 offsets must resolve to the same instant.'
    );
  }

  @isTest
  static void shouldRejectNonBooleanText() {
    try {
      PromptContextQuery.convertValue('Account', 'IsDeleted', 'Yes');
      Assert.fail('Non-boolean text must not silently become false.');
    } catch (PromptContextException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        expected.reasonCode
      );
    }
  }
}
