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
  /** Invisible control and text-direction characters that can hide or reorder prompt text. */
  private static final Pattern HIDDEN_CONTROLS = Pattern.compile(
    '[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F\\u202A-\\u202E\\u2066-\\u2069]'
  );
  private static final Pattern HTML_LINK = Pattern.compile(
    '(?is)<a\\b[^>]*?href\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')[^>]*>(.*?)</a\\s*>'
  );
  private static final Pattern HTML_IMAGE = Pattern.compile(
    '(?is)<img\\b[^>]*>'
  );
  private static final Pattern HTML_ALT = Pattern.compile(
    '(?is)\\balt\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')'
  );
  private static final Pattern SAFE_LINK = Pattern.compile(
    '(?i)^(?:https?://|mailto:|/)\\S*$'
  );
  private static final Pattern EXTRA_BLANK_LINES = Pattern.compile(
    '\\n[ \\t]*\\n(?:[ \\t]*\\n)+'
  );

  /** A calculated currency amount and the ISO code it is expressed in. */
  public class Money {
    public Decimal amount;
    public String currencyCode;

    /** Creates an amount in one currency. */
    public Money(Decimal amount, String currencyCode) {
      this.amount = amount;
      this.currencyCode = currencyCode;
    }
  }

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
    return HIDDEN_CONTROLS.matcher(formatReadable(value, field, currencyCode))
      .replaceAll('');
  }

  private static String formatReadable(
    Object value,
    FieldInfo field,
    String currencyCode
  ) {
    if (value instanceof Money) {
      Money money = (Money) value;
      return money.amount.toPlainString() +
        (String.isBlank(money.currencyCode) ? '' : ' ' + money.currencyCode);
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
    text = replaceLinks(text);
    text = replaceImages(text);
    text = HTML_LIST_ITEM.matcher(text).replaceAll('\n- ');
    text = HTML_BREAK.matcher(text).replaceAll('\n');
    text = HTML_TAG.matcher(text).replaceAll('');
    text = text.unescapeHtml4().replace(' ', ' ').replace('\r\n', '\n');
    text = EXTRA_BLANK_LINES.matcher(text).replaceAll('\n\n');
    return text.trim();
  }

  /** Keeps link text and adds a web or mail address the model can read; drops unsafe schemes. */
  private static String replaceLinks(String html) {
    Matcher links = HTML_LINK.matcher(html);
    List<String> parts = new List<String>();
    Integer cursor = 0;
    while (links.find()) {
      parts.add(html.substring(cursor, links.start()));
      String href = (links.group(1) ?? links.group(2) ?? '')
        .unescapeHtml4()
        .trim();
      String label = HTML_TAG.matcher(links.group(3)).replaceAll('').trim();
      Boolean safe = SAFE_LINK.matcher(href).matches();
      if (!safe || href == label.unescapeHtml4()) {
        parts.add(label);
      } else if (String.isBlank(label)) {
        parts.add(href.escapeHtml4());
      } else {
        parts.add(label + ' (' + href.escapeHtml4() + ')');
      }
      cursor = links.end();
    }
    parts.add(html.substring(cursor));
    return String.join(parts, '');
  }

  /** Replaces an image with its alternative text so the description is not lost. */
  private static String replaceImages(String html) {
    Matcher images = HTML_IMAGE.matcher(html);
    List<String> parts = new List<String>();
    Integer cursor = 0;
    while (images.find()) {
      parts.add(html.substring(cursor, images.start()));
      Matcher alt = HTML_ALT.matcher(images.group(0));
      if (alt.find()) {
        String altText = alt.group(1) ?? alt.group(2) ?? '';
        if (String.isNotBlank(altText)) {
          parts.add('[Image: ' + altText.trim() + ']');
        }
      }
      cursor = images.end();
    }
    parts.add(html.substring(cursor));
    return String.join(parts, '');
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
