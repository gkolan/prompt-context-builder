/**
 * Stable contract identifiers and hard resource ceilings for Prompt Context Builder.
 * Hard ceilings are code-owned security boundaries and cannot be raised by configuration.
 */
public with sharing class PromptContextContract {
  public static final String CONTRACT_VERSION = '1.0';
  public static final Integer SYNTAX_VERSION = 2;
  /** First syntax version that prints labels, plain text, and fixed date formats. */
  public static final Integer SYNTAX_VERSION_READABLE_OUTPUT = 2;

  public static final Integer MAX_SOURCES = 10;
  public static final Integer MAX_FIELDS_PER_SOURCE = 25;
  public static final Integer MAX_FILTERS_PER_SOURCE = 10;
  public static final Integer MAX_FILTER_GROUPS_PER_SOURCE = 5;
  public static final Integer MAX_SORTS_PER_SOURCE = 3;
  public static final Integer MAX_ROWS_PER_SOURCE = 50;
  public static final Integer MAX_ROWS_PER_PROMPT = 200;
  public static final Integer MAX_AGGREGATE_INPUT_ROWS = 1000;
  public static final Integer MAX_TEMPLATE_CHARACTERS = 20000;
  public static final Integer MAX_PROMPT_CHARACTERS = 20000;
  public static final Integer MAX_BLOCK_ITERATIONS = 100;
  public static final Integer MAX_RELATIONSHIP_DEPTH = 5;
  public static final Integer MAX_SELECTED_FILES = 5;
  public static final Integer PROVIDER_REVIEW_MAX_AGE_DAYS = 90;
  public static final Integer MAX_FILE_BYTES = 4500000;
  public static final Integer MAX_TOTAL_FILE_BYTES = 22500000;
  public static final Integer MAX_LINKED_FILES_INSPECTED = 500;
  public static final Integer FILE_PICKER_PAGE_SIZE = 50;
  public static final Integer DEFAULT_INPUT_RETENTION_DAYS = 30;
  public static final Integer INPUT_PROCESSING_MINUTES = 10;
  public static final Integer INPUT_RETRY_MINUTES = 15;
  public static final Integer MAX_INPUT_DELIVERY_ATTEMPTS = 3;
  public static final Integer MAX_INPUTS_PER_WORKER = 25;
  public static final String INPUT_FORMAT_VERSION = '1';

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
    'STARTS_WITH',
    'IN',
    'NOT_IN'
  };
  public static final Integer MAX_FILTER_LIST_VALUES = 50;
  public static final Integer MAX_FILTER_LOGIC_CHARACTERS = 255;
  /** Salesforce relative date literals accepted as filter values for Date and Date/Time fields. */
  public static final Set<String> DATE_LITERALS = new Set<String>{
    'YESTERDAY',
    'TODAY',
    'TOMORROW',
    'LAST_WEEK',
    'THIS_WEEK',
    'NEXT_WEEK',
    'LAST_MONTH',
    'THIS_MONTH',
    'NEXT_MONTH',
    'LAST_90_DAYS',
    'NEXT_90_DAYS',
    'LAST_QUARTER',
    'THIS_QUARTER',
    'NEXT_QUARTER',
    'LAST_YEAR',
    'THIS_YEAR',
    'NEXT_YEAR'
  };
  /** Relative date literals that take a whole-number amount, written as NAME:n. */
  public static final Set<String> DATE_LITERALS_WITH_AMOUNT = new Set<String>{
    'LAST_N_DAYS',
    'NEXT_N_DAYS',
    'N_DAYS_AGO',
    'LAST_N_WEEKS',
    'NEXT_N_WEEKS',
    'N_WEEKS_AGO',
    'LAST_N_MONTHS',
    'NEXT_N_MONTHS',
    'N_MONTHS_AGO',
    'LAST_N_QUARTERS',
    'NEXT_N_QUARTERS',
    'N_QUARTERS_AGO',
    'LAST_N_YEARS',
    'NEXT_N_YEARS',
    'N_YEARS_AGO'
  };
  public static final Integer MAX_DATE_LITERAL_AMOUNT = 4000;
  public static final Set<String> FILTER_GROUP_JOINS = new Set<String>{
    'AND',
    'OR'
  };

  private PromptContextContract() {
  }
}
