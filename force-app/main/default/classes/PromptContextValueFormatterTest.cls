/** Verifies syntax version 2 value output and that version 1 output stays frozen. */
@isTest
private class PromptContextValueFormatterTest {
  private static final Integer V1 = 1;
  private static final Integer V2 = PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT;

  @isTest
  static void shouldConvertRichTextToPlainTextWithBreaksAndListMarkers() {
    PromptContextValueFormatter.FieldInfo richText = new PromptContextValueFormatter.FieldInfo(
      Schema.DisplayType.TextArea,
      true
    );
    String html =
      '<p>Renewal <b>at risk</b> &amp; escalated</p>' +
      '<ul><li>Call CFO</li><li>Send&nbsp;quote</li></ul>' +
      '<style>p{color:red}</style><script>alert(1)</script>' +
      '<p>Line one<br>Line two</p>';

    String text = PromptContextValueFormatter.format(html, richText, null, V2);

    Assert.areEqual(
      'Renewal at risk & escalated\n\n- Call CFO\n- Send quote\nLine one\nLine two',
      text,
      'Rich text must reach the prompt as readable plain text.'
    );
    Assert.isFalse(text.contains('<'), 'No markup may remain.');
    Assert.isFalse(
      text.contains('alert'),
      'Script and style content is dropped.'
    );
    Assert.areEqual(
      html,
      PromptContextValueFormatter.format(html, richText, null, V1),
      'Version 1 output is frozen and keeps the stored markup.'
    );
  }

  @isTest
  static void shouldNotDecodeEntitiesTwice() {
    PromptContextValueFormatter.FieldInfo richText = new PromptContextValueFormatter.FieldInfo(
      Schema.DisplayType.TextArea,
      true
    );

    Assert.areEqual(
      'Use &lt;b&gt; for bold',
      PromptContextValueFormatter.format(
        '<p>Use &amp;lt;b&amp;gt; for bold</p>',
        richText,
        null,
        V2
      ),
      'An escaped entity typed by a user must stay visible as text.'
    );
  }

  @isTest
  static void shouldPrintPicklistLabelsAndFallBackToUnknownValues() {
    PromptContextValueFormatter.FieldInfo picklist = new PromptContextValueFormatter.FieldInfo(
      Prompt_Template__c.File_Input_Mode__c.getDescribe()
    );

    Assert.areEqual(
      'User Selects Files',
      PromptContextValueFormatter.format('USER_SELECT', picklist, null, V2)
    );
    Assert.areEqual(
      'RETIRED_VALUE',
      PromptContextValueFormatter.format('RETIRED_VALUE', picklist, null, V2),
      'A value missing from the field definition prints as stored.'
    );
    Assert.areEqual(
      'USER_SELECT',
      PromptContextValueFormatter.format('USER_SELECT', picklist, null, V1),
      'Version 1 output is frozen and prints the API value.'
    );
  }

  @isTest
  static void shouldJoinMultiSelectLabelsWithSemicolonAndSpace() {
    PromptContextValueFormatter.FieldInfo multi = new PromptContextValueFormatter.FieldInfo(
      Schema.DisplayType.MultiPicklist,
      false
    );
    multi.picklistLabels.put('A_1', 'Alpha');
    multi.picklistLabels.put('B_2', 'Beta');

    Assert.areEqual(
      'Alpha; Beta; C_3',
      PromptContextValueFormatter.format('A_1;B_2;C_3', multi, null, V2)
    );
  }

  @isTest
  static void shouldPrintDatesAndTimesInFixedIsoFormat() {
    Datetime instant = Datetime.newInstanceGmt(2026, 10, 19, 15, 4, 5);
    Date day = Date.newInstance(2026, 1, 9);

    Assert.areEqual(
      '2026-10-19T15:04:05Z',
      PromptContextValueFormatter.format(instant, null, null, V2),
      'Date-times print in UTC regardless of the running user.'
    );
    Assert.areEqual(
      '2026-01-09',
      PromptContextValueFormatter.format(day, null, null, V2)
    );
    Assert.areEqual(
      '09:30:00',
      PromptContextValueFormatter.format(
        Time.newInstance(9, 30, 0, 0),
        null,
        null,
        V2
      )
    );
    Assert.areEqual(
      day.format(),
      PromptContextValueFormatter.format(day, null, null, V1),
      'Version 1 keeps the running user locale format.'
    );
    Assert.areEqual(
      instant.format(),
      PromptContextValueFormatter.format(instant, null, null, V1)
    );
  }

  @isTest
  static void shouldPrintCurrencyCodePercentSignAndPlainNumbers() {
    PromptContextValueFormatter.FieldInfo currencyField = new PromptContextValueFormatter.FieldInfo(
      Opportunity.Amount.getDescribe()
    );
    PromptContextValueFormatter.FieldInfo percentField = new PromptContextValueFormatter.FieldInfo(
      Opportunity.Probability.getDescribe()
    );

    Assert.areEqual(
      '1234.50 EUR',
      PromptContextValueFormatter.format(
        Decimal.valueOf('1234.50'),
        currencyField,
        'EUR',
        V2
      )
    );
    Assert.areEqual(
      '1234.50',
      PromptContextValueFormatter.format(
        Decimal.valueOf('1234.50'),
        currencyField,
        null,
        V2
      ),
      'Without a known currency the number prints alone.'
    );
    Assert.areEqual(
      '75%',
      PromptContextValueFormatter.format(
        Decimal.valueOf('75'),
        percentField,
        null,
        V2
      )
    );
    Assert.areEqual(
      '10000000',
      PromptContextValueFormatter.format(
        Decimal.valueOf('1E+7'),
        null,
        null,
        V2
      ),
      'Large numbers never print in scientific notation.'
    );
    Assert.areEqual(
      '1234.50',
      PromptContextValueFormatter.format(
        Decimal.valueOf('1234.50'),
        currencyField,
        'EUR',
        V1
      ),
      'Version 1 prints the bare stored number.'
    );
  }

  @isTest
  static void shouldKeepLinkAddressesAndImageDescriptions() {
    PromptContextValueFormatter.FieldInfo richText = new PromptContextValueFormatter.FieldInfo(
      Schema.DisplayType.TextArea,
      true
    );
    Map<String, String> cases = new Map<String, String>{
      '<a href="https://example.com/a?x=1&amp;y=2" target="_blank">Open case</a>' => 'Open case (https://example.com/a?x=1&y=2)',
      '<a href=\'mailto:help@example.com\'>Email us</a>' => 'Email us (mailto:help@example.com)',
      '<a href="https://example.com">https://example.com</a>' => 'https://example.com',
      '<a href="javascript:alert(1)">Click</a>' => 'Click',
      '<a href="/lightning/r/Case/500/view"><b>Case</b></a>' => 'Case (/lightning/r/Case/500/view)',
      '<img src="https://example.com/logo.png" alt="Company logo" border="0"/>' => '[Image: Company logo]',
      '<img src="https://example.com/pixel.gif">' => '',
      'Before <a href="https://a.example">A</a> and <a href="https://b.example">B</a>' => 'Before A (https://a.example) and B (https://b.example)'
    };
    for (String html : cases.keySet()) {
      Assert.areEqual(
        cases.get(html),
        PromptContextValueFormatter.format(html, richText, null, V2),
        'Unexpected text for ' + html
      );
    }
  }

  @isTest
  static void shouldRemoveInvisibleControlAndDirectionCharacters() {
    String hostile =
      'Pay \u202Eexe.txt\u202C now\u0000\u0007' +
      '\u2066x\u2069 tab\there\nline 👨\u200D👩\u200D👧';

    Assert.areEqual(
      'Pay exe.txt nowx tab\there\nline 👨\u200D👩\u200D👧',
      PromptContextValueFormatter.format(hostile, null, null, V2),
      'Hidden characters are removed; tabs, newlines, and emoji joiners stay.'
    );
    Assert.areEqual(
      hostile,
      PromptContextValueFormatter.format(hostile, null, null, V1),
      'Version 1 output is frozen.'
    );
  }
}
