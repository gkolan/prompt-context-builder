/**
 * Parses numbered filter logic such as 1 AND (2 OR NOT 3). The query text is rebuilt from the
 * parsed tree, so the stored logic string itself never reaches SOQL.
 */
public with sharing class PromptContextFilterLogic {
  private static final Pattern TOKEN = Pattern.compile(
    '(?i)\\s*(\\d+|\\(|\\)|AND\\b|OR\\b|NOT\\b)\\s*'
  );

  private List<String> tokens;
  private Integer position = 0;
  private Integer filterCount;

  /** One parsed logic expression. */
  public class Node {
    private String kind;
    private Integer filterNumber;
    private List<Node> children = new List<Node>();

    private Node(String kind) {
      this.kind = kind;
    }

    /**
     * Builds the WHERE fragment from conditions listed in filter order.
     * @param conditions One compiled condition per filter, in filter order
     * @return Parenthesized SOQL condition
     */
    public String toSoql(List<String> conditions) {
      if (kind == 'FILTER') {
        return '(' + conditions[filterNumber - 1] + ')';
      }
      if (kind == 'NOT') {
        return '(NOT ' + children[0].toSoql(conditions) + ')';
      }
      List<String> parts = new List<String>();
      for (Node child : children) {
        parts.add(child.toSoql(conditions));
      }
      return '(' + String.join(parts, ' ' + kind + ' ') + ')';
    }

    /** Returns every filter number the logic uses. */
    public Set<Integer> referencedFilters() {
      Set<Integer> numbers = new Set<Integer>();
      if (kind == 'FILTER') {
        numbers.add(filterNumber);
      }
      for (Node child : children) {
        numbers.addAll(child.referencedFilters());
      }
      return numbers;
    }

    /** Returns filter numbers that every matching record must satisfy. */
    public Set<Integer> requiredFilters() {
      Set<Integer> numbers = new Set<Integer>();
      if (kind == 'FILTER') {
        numbers.add(filterNumber);
      } else if (kind == 'AND') {
        for (Node child : children) {
          numbers.addAll(child.requiredFilters());
        }
      }
      return numbers;
    }
  }

  private PromptContextFilterLogic(List<String> tokens, Integer filterCount) {
    this.tokens = tokens;
    this.filterCount = filterCount;
  }

  /**
   * Parses and checks one logic string.
   * @param logic Text such as 1 AND (2 OR 3)
   * @param filterCount Number of filters in the data set
   * @return Parsed expression
   * @throws PromptContextException With an author-facing explanation when the logic is invalid
   */
  public static Node parse(String logic, Integer filterCount) {
    if (String.isBlank(logic)) {
      throw invalid('Enter filter logic such as 1 AND (2 OR 3).');
    }
    if (logic.length() > PromptContextContract.MAX_FILTER_LOGIC_CHARACTERS) {
      throw invalid(
        'Keep filter logic at or below ' +
          PromptContextContract.MAX_FILTER_LOGIC_CHARACTERS +
          ' characters.'
      );
    }
    PromptContextFilterLogic parser = new PromptContextFilterLogic(
      tokenize(logic),
      filterCount ?? 0
    );
    Node root = parser.expression();
    if (parser.position < parser.tokens.size()) {
      throw invalid(
        'Unexpected "' + parser.tokens[parser.position] + '" in filter logic.'
      );
    }
    Set<Integer> used = root.referencedFilters();
    for (Integer index = 1; index <= parser.filterCount; index++) {
      if (!used.contains(index)) {
        throw PromptContextException.withReason(
          'FILTER_NOT_IN_LOGIC',
          'Filter ' + index + ' is not used in the filter logic.'
        );
      }
    }
    return root;
  }

  private static List<String> tokenize(String logic) {
    List<String> values = new List<String>();
    Matcher matcher = TOKEN.matcher(logic);
    Integer cursor = 0;
    while (cursor < logic.length()) {
      if (!matcher.find(cursor) || matcher.start() != cursor) {
        throw invalid(
          'Filter logic can use only filter numbers, AND, OR, NOT, and parentheses.'
        );
      }
      values.add(matcher.group(1).toUpperCase());
      cursor = matcher.end();
    }
    return values;
  }

  private Node expression() {
    List<Node> operands = new List<Node>{ unary() };
    String joiner;
    while (position < tokens.size() && isJoiner(tokens[position])) {
      String next = tokens[position];
      if (joiner != null && joiner != next) {
        throw invalid(
          'Use parentheses when combining AND with OR, for example 1 AND (2 OR 3).'
        );
      }
      joiner = next;
      position++;
      operands.add(unary());
    }
    if (joiner == null) {
      return operands[0];
    }
    Node combined = new Node(joiner);
    combined.children = operands;
    return combined;
  }

  private Node unary() {
    if (position < tokens.size() && tokens[position] == 'NOT') {
      position++;
      Node negated = new Node('NOT');
      negated.children.add(unary());
      return negated;
    }
    return primary();
  }

  private Node primary() {
    if (position >= tokens.size()) {
      throw invalid('Filter logic ends too early.');
    }
    String token = tokens[position++];
    if (token == '(') {
      Node grouped = expression();
      if (position >= tokens.size() || tokens[position] != ')') {
        throw invalid('Close every parenthesis in the filter logic.');
      }
      position++;
      return grouped;
    }
    if (!token.isNumeric()) {
      throw invalid('Expected a filter number but found "' + token + '".');
    }
    Integer filterNumber = token.length() > 3 ? -1 : Integer.valueOf(token);
    if (filterNumber < 1 || filterNumber > filterCount) {
      throw invalid(
        'Filter ' +
          token +
          ' does not exist. Use numbers 1 to ' +
          filterCount +
          '.'
      );
    }
    Node leaf = new Node('FILTER');
    leaf.filterNumber = filterNumber;
    return leaf;
  }

  private static Boolean isJoiner(String token) {
    return token == 'AND' || token == 'OR';
  }

  private static PromptContextException invalid(String message) {
    return PromptContextException.withReason('INVALID_FILTER_LOGIC', message);
  }
}
