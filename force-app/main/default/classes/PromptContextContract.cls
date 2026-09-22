/**
 * Stable contract identifiers and hard resource ceilings for Prompt Context Builder.
 * Hard ceilings are code-owned security boundaries and cannot be raised by configuration.
 */
public with sharing class PromptContextContract {
  public static final String CONTRACT_VERSION = '1.0';
  public static final Integer SYNTAX_VERSION = 1;

  public static final Integer MAX_SOURCES = 10;
  public static final Integer MAX_FIELDS_PER_SOURCE = 25;
  public static final Integer MAX_FILTERS_PER_SOURCE = 10;
  public static final Integer MAX_FILTER_GROUPS_PER_SOURCE = 5;
  public static final Integer MAX_SORTS_PER_SOURCE = 3;
  public static final Integer MAX_ROWS_PER_SOURCE = 50;
  public static final Integer MAX_ROWS_PER_PROMPT = 200;
  public static final Integer MAX_TEMPLATE_CHARACTERS = 20000;
  public static final Integer MAX_PROMPT_CHARACTERS = 20000;
  public static final Integer MAX_BLOCK_ITERATIONS = 100;
  public static final Integer MAX_RELATIONSHIP_DEPTH = 5;

  public static final Integer MAX_RECORDS_PER_REQUEST = 200;
  public static final Integer MAX_FLOW_GROUPS = 10;
  public static final Integer MAX_FLOW_RESPONSE_CHARACTERS = 1000000;
  public static final Integer QUERY_HEADROOM = 10;
  public static final Integer QUERY_ROW_HEADROOM = 5000;
  public static final Integer DEFAULT_TEMPLATE_PAGE_SIZE = 50;
  public static final Integer MAX_TEMPLATE_PAGE_SIZE = 100;

  public static final Set<String> SOURCE_MODES = new Set<String>{
    'RELATED',
    'REFERENCE'
  };
  public static final Set<String> RESULT_MODES = new Set<String>{
    'RECORDS',
    'AGGREGATE'
  };
  public static final Set<String> AGGREGATE_OPERATIONS = new Set<String>{
    'COUNT',
    'SUM',
    'AVG',
    'MIN',
    'MAX'
  };
  public static final Set<String> FILTER_OPERATORS = new Set<String>{
    'EQ',
    'NE',
    'GT',
    'GTE',
    'LT',
    'LTE',
    'IS_NULL',
    'NOT_NULL',
    'CONTAINS',
    'STARTS_WITH'
  };
  public static final Set<String> FILTER_GROUP_JOINS = new Set<String>{
    'AND',
    'OR'
  };

  private PromptContextContract() {
  }
}
