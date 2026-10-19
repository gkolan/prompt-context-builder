/**
 * Parses, validates, and renders the closed Prompt Context Builder merge language.
 */
public with sharing class PromptTemplateLanguage {
  private static final Pattern TOKEN_PATTERN = Pattern.compile(
    '\\{!([^}]*)\\}'
  );
  private static final Pattern RECORD_TOKEN = Pattern.compile(
    '^record\\.([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*)$'
  );
  private static final Pattern RELATED_TOKEN = Pattern.compile(
    '^related\\.([A-Za-z][A-Za-z0-9_]*)\\[([0-9]+)\\]\\.([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*)$'
  );
  private static final Pattern RELATED_COUNT_TOKEN = Pattern.compile(
    '^related\\.([A-Za-z][A-Za-z0-9_]*)\\.count$'
  );
  private static final Pattern AGGREGATE_TOKEN = Pattern.compile(
    '^aggregate\\.([A-Za-z][A-Za-z0-9_]*)\\.value$'
  );
  private static final Pattern LOCAL_TOKEN = Pattern.compile(
    '^([A-Za-z][A-Za-z0-9_]*)\\.([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z][A-Za-z0-9_]*)*)$'
  );
  private static final Pattern EACH_BLOCK = Pattern.compile(
    '(?s)\\{!\\s*#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as\\s*=\\s*"([A-Za-z][A-Za-z0-9_]*)"\\s*\\}' +
    '((?:(?!\\{!\\s*#(?:each|if)\\s).)*?)\\{!\\s*/each\\s*\\}'
  );
  private static final Pattern IF_BLOCK = Pattern.compile(
    '(?s)\\{!\\s*#if\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\.hasRecords\\s*\\}' +
    '((?:(?!\\{!\\s*#(?:each|if)\\s).)*?)\\{!\\s*/if\\s*\\}'
  );
  private static final Pattern EACH_DEPENDENCY = Pattern.compile(
    '(?s)\\{!\\s*#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as\\s*=\\s*"([A-Za-z][A-Za-z0-9_]*)"\\s*\\}(.*?)\\{!\\s*/each\\s*\\}'
  );
  private static final Pattern OPTION_PATTERN = Pattern.compile(
    '([A-Za-z][A-Za-z0-9_]*)="([^"]*)"'
  );
  private static final Set<String> SUPPORTED_FORMATS = new Set<String>{
    'upper',
    'lower',
    'percent'
  };
  private static final Set<String> RESERVED_LOCAL_NAMES = new Set<String>{
    'record',
    'related',
    'aggregate'
  };
  private static final String LITERAL_TOKEN_OPEN = '\uE000PCB_LITERAL_OPEN\uE001';
  /** Escape token that prints a literal {! in the prompt. */
  public static final String LITERAL_ESCAPE = '{!!}';
  private static final Set<String> SUPPORTED_ATTRIBUTES = new Set<String>{
    'fallback',
    'format',
    'maxLength'
  };
  private static final String TRUNCATION_MARKER = '\u2026';
  private static Map<Schema.SObjectType, Map<String, PromptContextValueFormatter.FieldInfo>> fieldInfoByType = new Map<Schema.SObjectType, Map<String, PromptContextValueFormatter.FieldInfo>>();
  private static Integer activeSyntaxVersion = PromptContextContract.SYNTAX_VERSION;
  private static Boolean truncatedDuringRender = false;

  /** Rendered prompt text and whether any value was shortened by maxLength. */
  public class RenderOutput {
    public String text;
    public Boolean truncated = false;
  }

  /**
   * Validates token shape, block balance, and configured aliases.
   * @param templateBody Template text
   * @param aliases Names of the available data sets
   * @return Syntax messages
   */
  public static PromptContextDTO.ValidationResult validateSyntax(
    String templateBody,
    Set<String> aliases
  ) {
    PromptContextDTO.ValidationResult result = new PromptContextDTO.ValidationResult();
    if (String.isBlank(templateBody)) {
      result.addError(
        'EMPTY_TEMPLATE',
        'Template body',
        'Enter prompt text before previewing.'
      );
      return result;
    }
    validateBalancedBlocks(templateBody, result);
    validateTokens(templateBody, aliases, result);
    return result;
  }

  /**
   * Extracts every root-record field referenced by the template.
   * @param templateBody Template text
   * @return Current-record field paths
   */
  public static Set<String> getRootFieldPaths(String templateBody) {
    Set<String> fields = new Set<String>();
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody ?? '');
    while (tokens.find()) {
      String core = getTokenCore(tokens.group(1).trim());
      Matcher recordMatcher = RECORD_TOKEN.matcher(core);
      if (recordMatcher.matches()) {
        fields.add(recordMatcher.group(1));
      }
    }
    return fields;
  }

  /**
   * Extracts related fields referenced directly or through each-block local variables.
   * @param templateBody Template text
   * @return Field paths grouped by source alias
   */
  public static Map<String, Set<String>> getRelatedFieldPaths(
    String templateBody
  ) {
    Map<String, Set<String>> fieldsByAlias = new Map<String, Set<String>>();
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody ?? '');
    while (tokens.find()) {
      Matcher relatedMatcher = RELATED_TOKEN.matcher(
        getTokenCore(tokens.group(1).trim())
      );
      if (relatedMatcher.matches()) {
        addDependency(
          fieldsByAlias,
          relatedMatcher.group(1),
          relatedMatcher.group(3)
        );
      }
    }

    Matcher eachBlocks = EACH_DEPENDENCY.matcher(templateBody ?? '');
    while (eachBlocks.find()) {
      String alias = eachBlocks.group(1);
      String variable = eachBlocks.group(2);
      Matcher bodyTokens = TOKEN_PATTERN.matcher(eachBlocks.group(3));
      while (bodyTokens.find()) {
        Matcher localMatcher = LOCAL_TOKEN.matcher(
          getTokenCore(bodyTokens.group(1).trim())
        );
        if (localMatcher.matches() && localMatcher.group(1) == variable) {
          addDependency(fieldsByAlias, alias, localMatcher.group(2));
        }
      }
    }
    return fieldsByAlias;
  }

  /**
   * Renders a validated template from one current record and separately loaded related data.
   * @param templateBody Template text
   * @param rootRecord Current Salesforce record
   * @param relatedByAlias Related records grouped by source alias
   * @return Final plain-text prompt
   */
  public static String render(
    String templateBody,
    SObject rootRecord,
    Map<String, List<SObject>> relatedByAlias
  ) {
    return render(
      templateBody,
      rootRecord,
      relatedByAlias,
      new Map<String, Object>()
    );
  }

  /** Builds text from record data sets and separately calculated values. */
  public static String render(
    String templateBody,
    SObject rootRecord,
    Map<String, List<SObject>> relatedByAlias,
    Map<String, Object> aggregateByAlias
  ) {
    return render(
        templateBody,
        rootRecord,
        relatedByAlias,
        aggregateByAlias,
        PromptContextContract.SYNTAX_VERSION
      )
      .text;
  }

  /**
   * Builds text with the output rules of the publication's syntax version.
   * @param templateBody Template text
   * @param rootRecord Current Salesforce record
   * @param relatedByAlias Related records grouped by source alias
   * @param aggregateByAlias Calculated values grouped by source alias
   * @param syntaxVersion Syntax version stored on the publication
   * @return Prompt text and truncation state
   */
  public static RenderOutput render(
    String templateBody,
    SObject rootRecord,
    Map<String, List<SObject>> relatedByAlias,
    Map<String, Object> aggregateByAlias,
    Integer syntaxVersion
  ) {
    activeSyntaxVersion = syntaxVersion ?? PromptContextContract.SYNTAX_VERSION;
    truncatedDuringRender = false;
    String rendered = renderBlocks(
      (templateBody ?? '').replace(LITERAL_ESCAPE, LITERAL_TOKEN_OPEN),
      rootRecord,
      relatedByAlias,
      aggregateByAlias
    );
    RenderOutput output = new RenderOutput();
    output.text = restoreLiteralMergeSyntax(
      replaceScalarTokens(
        rendered,
        rootRecord,
        relatedByAlias,
        aggregateByAlias,
        new Map<String, SObject>()
      )
    );
    output.truncated = truncatedDuringRender;
    return output;
  }

  /**
   * Returns the highest zero-based row index referenced for each data set.
   * @param templateBody Template text
   * @return Highest index by data-set reference name
   */
  public static Map<String, Integer> getHighestRelatedIndexes(
    String templateBody
  ) {
    Map<String, Integer> highest = new Map<String, Integer>();
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody ?? '');
    while (tokens.find()) {
      Matcher relatedMatcher = RELATED_TOKEN.matcher(
        getTokenCore(tokens.group(1).trim())
      );
      if (relatedMatcher.matches()) {
        Integer index = rowIndex(relatedMatcher.group(2));
        String alias = relatedMatcher.group(1);
        if (!highest.containsKey(alias) || highest.get(alias) < index) {
          highest.put(alias, index);
        }
      }
    }
    return highest;
  }

  private static String renderBlocks(
    String templateBody,
    SObject rootRecord,
    Map<String, List<SObject>> relatedByAlias,
    Map<String, Object> aggregateByAlias
  ) {
    String rendered = templateBody;
    Integer iterations = 0;
    while (
      containsBlockStart(rendered) &&
      iterations < PromptContextContract.MAX_BLOCK_ITERATIONS
    ) {
      iterations++;
      Matcher eachMatcher = EACH_BLOCK.matcher(rendered);
      if (eachMatcher.find()) {
        String fullBlock = eachMatcher.group(0);
        String alias = eachMatcher.group(1);
        String variable = eachMatcher.group(2);
        List<String> branches = splitElse(eachMatcher.group(3));
        List<SObject> records = relatedByAlias.get(alias);
        String replacement = '';
        if (records != null && !records.isEmpty()) {
          List<String> rows = new List<String>();
          for (SObject record : records) {
            rows.add(
              replaceScalarTokens(
                branches[0],
                rootRecord,
                relatedByAlias,
                aggregateByAlias,
                new Map<String, SObject>{ variable => record }
              )
            );
          }
          replacement = String.join(rows, '');
        } else if (branches.size() == 2) {
          replacement = branches[1];
        }
        rendered = rendered.replace(fullBlock, replacement);
        continue;
      }

      Matcher ifMatcher = IF_BLOCK.matcher(rendered);
      if (ifMatcher.find()) {
        String alias = ifMatcher.group(1);
        List<String> branches = splitElse(ifMatcher.group(2));
        List<SObject> records = relatedByAlias.get(alias);
        Boolean hasRecords = records != null && !records.isEmpty();
        String replacement = hasRecords
          ? branches[0]
          : (branches.size() == 2 ? branches[1] : '');
        rendered = rendered.replace(ifMatcher.group(0), replacement);
        continue;
      }
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'A template block could not be rendered. Check its opening and closing tags.'
      );
    }
    if (containsBlockStart(rendered)) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template contains too many nested blocks.'
      );
    }
    return rendered;
  }

  private static String replaceScalarTokens(
    String text,
    SObject rootRecord,
    Map<String, List<SObject>> relatedByAlias,
    Map<String, Object> aggregateByAlias,
    Map<String, SObject> localRecords
  ) {
    Matcher tokens = TOKEN_PATTERN.matcher(text ?? '');
    List<String> output = new List<String>();
    Integer cursor = 0;
    while (tokens.find()) {
      output.add(text.substring(cursor, tokens.start()));
      String tokenText = tokens.group(1).trim();
      String core = getTokenCore(tokenText);
      Object value;
      ValueTarget target;

      Matcher recordMatcher = RECORD_TOKEN.matcher(core);
      Matcher relatedMatcher = RELATED_TOKEN.matcher(core);
      Matcher countMatcher = RELATED_COUNT_TOKEN.matcher(core);
      Matcher aggregateMatcher = AGGREGATE_TOKEN.matcher(core);
      Matcher localMatcher = LOCAL_TOKEN.matcher(core);
      if (recordMatcher.matches()) {
        target = getPathTarget(rootRecord, recordMatcher.group(1));
      } else if (relatedMatcher.matches()) {
        List<SObject> records = relatedByAlias.get(relatedMatcher.group(1));
        Integer rowIndex = rowIndex(relatedMatcher.group(2));
        target = records != null &&
          rowIndex < records.size()
          ? getPathTarget(records[rowIndex], relatedMatcher.group(3))
          : null;
      } else if (countMatcher.matches()) {
        List<SObject> records = relatedByAlias.get(countMatcher.group(1));
        value = records == null ? 0 : records.size();
      } else if (aggregateMatcher.matches()) {
        value = aggregateByAlias.get(aggregateMatcher.group(1));
      } else if (
        localMatcher.matches() &&
        localRecords.containsKey(localMatcher.group(1))
      ) {
        target = getPathTarget(
          localRecords.get(localMatcher.group(1)),
          localMatcher.group(2)
        );
      } else {
        value = '';
      }
      if (target != null) {
        value = target.value;
      }
      output.add(
        protectLiteralMergeSyntax(
          limitLength(
            formatValue(
              value,
              target,
              getOption(tokenText, 'fallback'),
              getOption(tokenText, 'format')
            ),
            getOption(tokenText, 'maxLength')
          )
        )
      );
      cursor = tokens.end();
    }
    output.add(text.substring(cursor));
    return String.join(output, '');
  }

  private static void validateBalancedBlocks(
    String templateBody,
    PromptContextDTO.ValidationResult result
  ) {
    List<String> stack = new List<String>();
    Integer blockCount = 0;
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody);
    while (tokens.find()) {
      String tokenText = tokens.group(1).trim();
      if (tokenText.startsWith('#each ') || tokenText.startsWith('#if ')) {
        blockCount++;
        if (blockCount == PromptContextContract.MAX_BLOCK_ITERATIONS + 1) {
          result.addError(
            'TOO_MANY_BLOCKS',
            'Template body',
            'Use no more than ' +
              PromptContextContract.MAX_BLOCK_ITERATIONS +
              ' each and if blocks in one template.'
          );
        }
      }
      if (tokenText.startsWith('#each ')) {
        if (stack.contains('each')) {
          result.addError(
            'NESTED_EACH',
            'Template body',
            'An each block cannot be nested inside another each block.'
          );
        }
        stack.add('each');
      } else if (tokenText.startsWith('#if ')) {
        stack.add('if');
      } else if (tokenText == 'else') {
        if (stack.isEmpty()) {
          result.addError(
            'ORPHAN_ELSE',
            'Template body',
            'An else tag must be inside an each or if block.'
          );
        }
      } else if (tokenText == '/each' || tokenText == '/if') {
        String expected = tokenText.substring(1);
        if (stack.isEmpty() || stack[stack.size() - 1] != expected) {
          result.addError(
            'BLOCK_MISMATCH',
            'Template body',
            'Close ' + expected + ' only after its matching open tag.'
          );
        } else {
          stack.remove(stack.size() - 1);
        }
      }
    }
    if (!stack.isEmpty()) {
      result.addError(
        'UNCLOSED_BLOCK',
        'Template body',
        'Close every each and if block.'
      );
    }
  }

  private static void validateTokens(
    String templateBody,
    Set<String> aliases,
    PromptContextDTO.ValidationResult result
  ) {
    Set<String> declaredLocals = new Set<String>();
    Matcher declaredEachBlocks = EACH_DEPENDENCY.matcher(templateBody);
    while (declaredEachBlocks.find()) {
      declaredLocals.add(declaredEachBlocks.group(2));
    }
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody);
    while (tokens.find()) {
      String tokenText = tokens.group(1).trim();
      String core = getTokenCore(tokenText);
      String alias;
      Matcher localMatcher = LOCAL_TOKEN.matcher(core);
      Boolean valid = RECORD_TOKEN.matcher(core).matches();
      Matcher relatedMatcher = RELATED_TOKEN.matcher(core);
      Matcher countMatcher = RELATED_COUNT_TOKEN.matcher(core);
      Matcher aggregateMatcher = AGGREGATE_TOKEN.matcher(core);
      Matcher eachMatcher = Pattern.compile(
          '^#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as\\s*=\\s*"([A-Za-z][A-Za-z0-9_]*)"$'
        )
        .matcher(tokenText);
      Matcher ifMatcher = Pattern.compile(
          '^#if\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\.hasRecords$'
        )
        .matcher(tokenText);
      if (relatedMatcher.matches()) {
        valid = true;
        alias = relatedMatcher.group(1);
      } else if (countMatcher.matches()) {
        valid = true;
        alias = countMatcher.group(1);
      } else if (aggregateMatcher.matches()) {
        valid = true;
        alias = aggregateMatcher.group(1);
      } else if (eachMatcher.matches()) {
        valid = true;
        alias = eachMatcher.group(1);
        if (RESERVED_LOCAL_NAMES.contains(eachMatcher.group(2).toLowerCase())) {
          result.addError(
            'RESERVED_LOCAL_NAME',
            'Template body',
            'Use a row alias other than record, related, or aggregate.'
          );
        }
      } else if (ifMatcher.matches()) {
        valid = true;
        alias = ifMatcher.group(1);
      } else if (
        tokenText == 'else' ||
        tokenText == '/each' ||
        tokenText == '/if' ||
        tokenText == '!'
      ) {
        valid = true;
      } else if (
        localMatcher.matches() && declaredLocals.contains(localMatcher.group(1))
      ) {
        valid = true;
      }
      if (!valid) {
        result.addError(
          'UNKNOWN_TOKEN',
          'Template body',
          'Unsupported merge expression: {!' + tokenText + '}'
        );
      } else if (alias != null && !aliases.contains(alias)) {
        result.addError(
          'UNKNOWN_SOURCE',
          'Template body',
          'No included data set is named ' + alias + '.'
        );
      }
      if (
        RECORD_TOKEN.matcher(core).matches() ||
        RELATED_TOKEN.matcher(core).matches() ||
        RELATED_COUNT_TOKEN.matcher(core).matches() ||
        AGGREGATE_TOKEN.matcher(core).matches() ||
        LOCAL_TOKEN.matcher(core).matches()
      ) {
        validateScalarOptions(tokenText, core, result);
      }
    }
  }

  private static void validateScalarOptions(
    String tokenText,
    String core,
    PromptContextDTO.ValidationResult result
  ) {
    String optionText = tokenText.substring(core.length()).trim();
    if (String.isBlank(optionText)) {
      return;
    }
    Set<String> seen = new Set<String>();
    Matcher options = OPTION_PATTERN.matcher(optionText);
    Integer cursor = 0;
    Boolean found = false;
    while (options.find()) {
      found = true;
      if (!String.isBlank(optionText.substring(cursor, options.start()))) {
        result.addError(
          'MALFORMED_ATTRIBUTE',
          'Template body',
          'Use attributes in the form name="value", separated by spaces.'
        );
        return;
      }
      String optionName = options.group(1);
      String optionValue = options.group(2);
      if (!SUPPORTED_ATTRIBUTES.contains(optionName)) {
        result.addError(
          'UNKNOWN_ATTRIBUTE',
          'Template body',
          'Only fallback, format, and maxLength attributes are supported.'
        );
      } else if (seen.contains(optionName)) {
        result.addError(
          'DUPLICATE_ATTRIBUTE',
          'Template body',
          'Use the ' + optionName + ' attribute only once per merge field.'
        );
      } else if (
        optionName == 'format' && !SUPPORTED_FORMATS.contains(optionValue)
      ) {
        result.addError(
          'UNSUPPORTED_FORMAT',
          'Template body',
          'Format must be upper, lower, or percent.'
        );
      } else if (
        optionName == 'maxLength' &&
        parseMaxLength(optionValue) == null
      ) {
        result.addError(
          'INVALID_MAX_LENGTH',
          'Template body',
          'maxLength must be a whole number from 1 to ' +
            PromptContextContract.MAX_PROMPT_CHARACTERS +
            '.'
        );
      }
      seen.add(optionName);
      cursor = options.end();
    }
    if (
      !found ||
      !String.isBlank(optionText.substring(cursor, optionText.length()))
    ) {
      result.addError(
        'MALFORMED_ATTRIBUTE',
        'Template body',
        'Use attributes in the form name="value", separated by spaces.'
      );
    }
  }

  private static String getTokenCore(String tokenText) {
    tokenText = tokenText.trim();
    Integer optionStart = tokenText.indexOf(' ');
    return optionStart < 0 ? tokenText : tokenText.substring(0, optionStart);
  }

  private static String getOption(String tokenText, String optionName) {
    Matcher optionMatcher = Pattern.compile(optionName + '="([^"]*)"')
      .matcher(tokenText);
    return optionMatcher.find() ? optionMatcher.group(1) : null;
  }

  private static List<String> splitElse(String blockBody) {
    Matcher elseMatcher = Pattern.compile('\\{!\\s*else\\s*\\}')
      .matcher(blockBody);
    if (!elseMatcher.find()) {
      return new List<String>{ blockBody };
    }
    return new List<String>{
      blockBody.substring(0, elseMatcher.start()),
      blockBody.substring(elseMatcher.end())
    };
  }

  private static Boolean containsBlockStart(String text) {
    Matcher tokens = TOKEN_PATTERN.matcher(text ?? '');
    while (tokens.find()) {
      String tokenText = tokens.group(1).trim();
      if (tokenText.startsWith('#each ') || tokenText.startsWith('#if ')) {
        return true;
      }
    }
    return false;
  }

  private static String protectLiteralMergeSyntax(String value) {
    return value == null ? '' : value.replace('{!', LITERAL_TOKEN_OPEN);
  }

  private static String restoreLiteralMergeSyntax(String value) {
    return value == null ? null : value.replace(LITERAL_TOKEN_OPEN, '{!');
  }

  /** A resolved field value with the record that holds it. */
  private class ValueTarget {
    Object value;
    SObject holder;
    String fieldName;
  }

  private static ValueTarget getPathTarget(SObject record, String fieldPath) {
    if (record == null) {
      return null;
    }
    List<String> segments = fieldPath.split('\\.');
    SObject currentRecord = record;
    for (Integer index = 0; index < segments.size() - 1; index++) {
      currentRecord = currentRecord.getSObject(segments[index]);
      if (currentRecord == null) {
        return null;
      }
    }
    ValueTarget target = new ValueTarget();
    target.holder = currentRecord;
    target.fieldName = segments[segments.size() - 1];
    target.value = currentRecord.get(target.fieldName);
    return target;
  }

  private static PromptContextValueFormatter.FieldInfo fieldInfo(
    ValueTarget target
  ) {
    if (target == null || target.holder == null) {
      return null;
    }
    Schema.SObjectType objectType = target.holder.getSObjectType();
    if (!fieldInfoByType.containsKey(objectType)) {
      fieldInfoByType.put(
        objectType,
        new Map<String, PromptContextValueFormatter.FieldInfo>()
      );
    }
    Map<String, PromptContextValueFormatter.FieldInfo> byName = fieldInfoByType.get(
      objectType
    );
    String key = target.fieldName.toLowerCase();
    if (!byName.containsKey(key)) {
      Schema.SObjectField token = PromptContextSchemaCache.describeObject(
          objectType
        )
        .fields.getMap()
        .get(key);
      byName.put(
        key,
        new PromptContextValueFormatter.FieldInfo(
          PromptContextSchemaCache.describeField(token)
        )
      );
    }
    return byName.get(key);
  }

  private static String currencyCode(ValueTarget target) {
    if (target == null || target.holder == null) {
      return null;
    }
    Object code = target.holder.getPopulatedFieldsAsMap()
      .get('CurrencyIsoCode');
    if (code != null) {
      return String.valueOf(code);
    }
    return UserInfo.isMultiCurrencyOrganization()
      ? null
      : UserInfo.getDefaultCurrency();
  }

  private static String formatValue(
    Object value,
    ValueTarget target,
    String fallback,
    String formatName
  ) {
    if (value == null || String.isBlank(String.valueOf(value))) {
      return fallback ?? '';
    }
    Boolean usesFieldRules =
      activeSyntaxVersion >=
      PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT &&
      target != null;
    String rendered = PromptContextValueFormatter.format(
      value,
      usesFieldRules ? fieldInfo(target) : null,
      usesFieldRules ? currencyCode(target) : null,
      activeSyntaxVersion
    );
    if (formatName == 'upper') {
      return rendered.toUpperCase();
    }
    if (formatName == 'lower') {
      return rendered.toLowerCase();
    }
    if (formatName == 'percent') {
      return activeSyntaxVersion >=
        PromptContextContract.SYNTAX_VERSION_READABLE_OUTPUT &&
        rendered.endsWith('%')
        ? rendered
        : rendered + '%';
    }
    if (!String.isBlank(formatName)) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template contains an unsupported format.'
      );
    }
    return rendered;
  }

  private static String limitLength(String text, String maxLengthOption) {
    Integer maxLength = parseMaxLength(maxLengthOption);
    if (maxLength == null || text == null || text.length() <= maxLength) {
      return text;
    }
    truncatedDuringRender = true;
    Integer cut = maxLength;
    // Never keep only the first half of a two-unit character such as an emoji.
    if (isHighSurrogate(text.charAt(cut - 1))) {
      cut--;
    }
    return text.substring(0, cut) + TRUNCATION_MARKER;
  }

  private static Boolean isHighSurrogate(Integer codeUnit) {
    return codeUnit >= 55296 && codeUnit <= 56319;
  }

  /** Reads a row index; any index too large to be an Integer can never match a row. */
  private static Integer rowIndex(String digits) {
    return digits.length() > 9 ? 2147483647 : Integer.valueOf(digits);
  }

  private static Integer parseMaxLength(String value) {
    if (String.isBlank(value) || !value.isNumeric() || value.length() > 5) {
      return null;
    }
    Integer parsed = Integer.valueOf(value);
    return parsed >= 1 &&
      parsed <= PromptContextContract.MAX_PROMPT_CHARACTERS
      ? parsed
      : null;
  }

  private static void addDependency(
    Map<String, Set<String>> fieldsByAlias,
    String alias,
    String fieldPath
  ) {
    if (!fieldsByAlias.containsKey(alias)) {
      fieldsByAlias.put(alias, new Set<String>());
    }
    fieldsByAlias.get(alias).add(fieldPath);
  }
}
