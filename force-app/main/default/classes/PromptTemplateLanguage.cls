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
    '(?s)\\{!#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as="([A-Za-z][A-Za-z0-9_]*)"\\}' +
    '((?:(?!\\{!#(?:each|if)\\s).)*?)\\{!/each\\}'
  );
  private static final Pattern IF_BLOCK = Pattern.compile(
    '(?s)\\{!#if\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\.hasRecords\\}' +
    '((?:(?!\\{!#(?:each|if)\\s).)*?)\\{!/if\\}'
  );
  private static final Pattern EACH_DEPENDENCY = Pattern.compile(
    '(?s)\\{!#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as="([A-Za-z][A-Za-z0-9_]*)"\\}(.*?)\\{!/each\\}'
  );
  private static final Pattern OPTION_PATTERN = Pattern.compile(
    '([A-Za-z][A-Za-z0-9_]*)="([^"]*)"'
  );
  private static final Set<String> SUPPORTED_FORMATS = new Set<String>{
    'upper',
    'lower',
    'percent'
  };

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
      String core = getTokenCore(tokens.group(1));
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
        getTokenCore(tokens.group(1))
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
          getTokenCore(bodyTokens.group(1))
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
    String rendered = renderBlocks(
      templateBody,
      rootRecord,
      relatedByAlias,
      aggregateByAlias
    );
    return replaceScalarTokens(
      rendered,
      rootRecord,
      relatedByAlias,
      aggregateByAlias,
      new Map<String, SObject>()
    );
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
      (rendered.contains('{!#each ') || rendered.contains('{!#if ')) &&
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
      throw new PromptContextException(
        'A template block could not be rendered. Check its opening and closing tags.'
      );
    }
    if (iterations == PromptContextContract.MAX_BLOCK_ITERATIONS) {
      throw new PromptContextException(
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
    String output = '';
    Integer cursor = 0;
    while (tokens.find()) {
      output += text.substring(cursor, tokens.start());
      String tokenText = tokens.group(1).trim();
      String core = getTokenCore(tokenText);
      Object value;

      Matcher recordMatcher = RECORD_TOKEN.matcher(core);
      Matcher relatedMatcher = RELATED_TOKEN.matcher(core);
      Matcher countMatcher = RELATED_COUNT_TOKEN.matcher(core);
      Matcher aggregateMatcher = AGGREGATE_TOKEN.matcher(core);
      Matcher localMatcher = LOCAL_TOKEN.matcher(core);
      if (recordMatcher.matches()) {
        value = getPathValue(rootRecord, recordMatcher.group(1));
      } else if (relatedMatcher.matches()) {
        List<SObject> records = relatedByAlias.get(relatedMatcher.group(1));
        Integer rowIndex = Integer.valueOf(relatedMatcher.group(2));
        value = records != null &&
          rowIndex < records.size()
          ? getPathValue(records[rowIndex], relatedMatcher.group(3))
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
        value = getPathValue(
          localRecords.get(localMatcher.group(1)),
          localMatcher.group(2)
        );
      } else {
        value = '';
      }
      output += formatValue(
        value,
        getOption(tokenText, 'fallback'),
        getOption(tokenText, 'format')
      );
      cursor = tokens.end();
    }
    output += text.substring(cursor);
    return output;
  }

  private static void validateBalancedBlocks(
    String templateBody,
    PromptContextDTO.ValidationResult result
  ) {
    List<String> stack = new List<String>();
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody);
    while (tokens.find()) {
      String tokenText = tokens.group(1).trim();
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
    Matcher tokens = TOKEN_PATTERN.matcher(templateBody);
    while (tokens.find()) {
      String tokenText = tokens.group(1).trim();
      String core = getTokenCore(tokenText);
      String alias;
      Boolean valid =
        RECORD_TOKEN.matcher(core).matches() ||
        LOCAL_TOKEN.matcher(core).matches();
      Matcher relatedMatcher = RELATED_TOKEN.matcher(core);
      Matcher countMatcher = RELATED_COUNT_TOKEN.matcher(core);
      Matcher aggregateMatcher = AGGREGATE_TOKEN.matcher(core);
      Matcher eachMatcher = Pattern.compile(
          '^#each\\s+related\\.([A-Za-z][A-Za-z0-9_]*)\\s+as="[A-Za-z][A-Za-z0-9_]*"$'
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
      } else if (ifMatcher.matches()) {
        valid = true;
        alias = ifMatcher.group(1);
      } else if (
        tokenText == 'else' ||
        tokenText == '/each' ||
        tokenText == '/if'
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
      if (optionName != 'fallback' && optionName != 'format') {
        result.addError(
          'UNKNOWN_ATTRIBUTE',
          'Template body',
          'Only fallback and format attributes are supported.'
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
    Integer optionStart = tokenText.indexOf(' ');
    return optionStart < 0 ? tokenText : tokenText.substring(0, optionStart);
  }

  private static String getOption(String tokenText, String optionName) {
    Matcher optionMatcher = Pattern.compile(optionName + '="([^"]*)"')
      .matcher(tokenText);
    return optionMatcher.find() ? optionMatcher.group(1) : null;
  }

  private static List<String> splitElse(String blockBody) {
    Integer elseIndex = blockBody.indexOf('{!else}');
    if (elseIndex < 0) {
      return new List<String>{ blockBody };
    }
    return new List<String>{
      blockBody.substring(0, elseIndex),
      blockBody.substring(elseIndex + '{!else}'.length())
    };
  }

  private static Object getPathValue(SObject record, String fieldPath) {
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
    return currentRecord.get(segments[segments.size() - 1]);
  }

  private static String formatValue(
    Object value,
    String fallback,
    String formatName
  ) {
    if (value == null || String.isBlank(String.valueOf(value))) {
      return fallback ?? '';
    }
    String rendered;
    if (value instanceof Date) {
      rendered = ((Date) value).format();
    } else if (value instanceof Datetime) {
      rendered = ((Datetime) value).format();
    } else {
      rendered = String.valueOf(value);
    }
    if (formatName == 'upper') {
      return rendered.toUpperCase();
    }
    if (formatName == 'lower') {
      return rendered.toLowerCase();
    }
    if (formatName == 'percent') {
      return rendered + '%';
    }
    if (!String.isBlank(formatName)) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'The template contains an unsupported format.'
      );
    }
    return rendered;
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
