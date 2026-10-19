/**
 * Converts one Salesforce value into prompt text. Syntax version 1 output is frozen; version 2
 * prints readable, deterministic text that does not depend on the running user's locale.
 */
public with sharing class PromptContextValueFormatter {
  private static final Pattern HTML_BREAK = Pattern.compile(
    '(?i)<br\\s*/?>|</(?:p|div|h[1-6]|tr|blockquote|pre|ul|ol)>'
  );
  private static final Pattern HTML_LIST_ITEM = Pattern.compile(
    '(?i)<li[^>]*>'
  );
  private static final Pattern HTML_HIDDEN = Pattern.compile(
    '(?is)<(script|style)[^>]*>.*?</\\1\\s*>'
  );
  private static final Pattern HTML_TAG = Pattern.compile('<[^>]*>');
  private static final Pattern EXTRA_BLANK_LINES = Pattern.compile(
    '\\n[ \\t]*\\n(?:[ \\t]*\\n)+'
  );

  /** Field facts that decide how a value is printed. */
  public class FieldInfo {
    public Schema.DisplayType type;
    public Boolean isHtml = false;
    public Map<String, String> picklistLabels = new Map<String, String>();

    /** Creates field facts from a Salesforce field description. */
    public FieldInfo(Schema.DescribeFieldResult description) {
      if (description == null) {
        return;
      }
      type = description.getType();
      isHtml = description.isHtmlFormatted();
      if (
        type == Schema.DisplayType.Picklist ||
        type == Schema.DisplayType.MultiPicklist
      ) {
        for (Schema.PicklistEntry entry : description.getPicklistValues()) {
          picklistLabels.put(entry.getValue(), entry.getLabel());
        }
      }
    }

    /** Creates field facts directly, for values without a field description. */
    public FieldInfo(Schema.DisplayType type, Boolean isHtml) {
      this.type = type;
      this.isHtml = isHtml == true;
    }
  }

  /**
   * Prints one non-null value.
   * @param value Salesforce value
   * @param field Field facts, or null for calculated values
   * @param currencyCode ISO code printed after a currency value, or null
   * @param syntaxVersion Syntax version of the publication being rendered
   * @return Prompt text
   */
  public static String format(
    Object value,
    FieldInfo field,
    String currencyCode,
    Integer syntaxVersion
  ) {
    if (
      syntaxVersion == null ||
      syntaxVersion < PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT
    ) {
      return formatVersion1(value);
    }
    // Apex treats a Date as an instance of Datetime, so the Date check must come first.
    if (value instanceof Date) {
      return String.valueOf((Date) value);
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    if (value instanceof Time) {
      return String.valueOf((Time) value).substring(0, 8);
    }
    if (value instanceof Decimal || value instanceof Double) {
      return formatNumber(value, field, currencyCode);
    }
    String text = String.valueOf(value);
    if (field == null) {
      return text;
    }
    if (field.type == Schema.DisplayType.Picklist) {
      return field.picklistLabels.get(text) ?? text;
    }
    if (field.type == Schema.DisplayType.MultiPicklist) {
      List<String> labels = new List<String>();
      for (String item : text.split(';')) {
        labels.add(field.picklistLabels.get(item) ?? item);
      }
      return String.join(labels, '; ');
    }
    if (field.isHtml) {
      return htmlToText(text);
    }
    return text;
  }

  /**
   * Converts Salesforce rich text to plain text with line breaks and list markers.
   * @param html Rich text value
   * @return Plain text without markup
   */
  public static String htmlToText(String html) {
    if (html == null) {
      return null;
    }
    String text = HTML_HIDDEN.matcher(html).replaceAll('');
    text = HTML_LIST_ITEM.matcher(text).replaceAll('\n- ');
    text = HTML_BREAK.matcher(text).replaceAll('\n');
    text = HTML_TAG.matcher(text).replaceAll('');
    text = text.unescapeHtml4().replace(' ', ' ').replace('\r\n', '\n');
    text = EXTRA_BLANK_LINES.matcher(text).replaceAll('\n\n');
    return text.trim();
  }

  private static String formatNumber(
    Object value,
    FieldInfo field,
    String currencyCode
  ) {
    Decimal amount = (value instanceof Decimal)
      ? (Decimal) value
      : Decimal.valueOf((Double) value);
    if (field == null) {
      // Calculated values have no field scale; print 180, not 180.0.
      return amount.stripTrailingZeros().toPlainString();
    }
    String text = amount.toPlainString();
    if (field.type == Schema.DisplayType.Percent) {
      return text + '%';
    }
    if (
      field.type == Schema.DisplayType.Currency &&
      String.isNotBlank(currencyCode)
    ) {
      return text + ' ' + currencyCode;
    }
    return text;
  }

  private static String formatVersion1(Object value) {
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).format();
    }
    return String.valueOf(value);
  }

  private PromptContextValueFormatter() {
  }
}
