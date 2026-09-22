/** Stable, additive machine-readable result and failure codes. */
public with sharing class PromptContextReasonCodes {
  public static final String SUCCESS = 'SUCCESS';
  public static final String INVALID_REQUEST = 'INVALID_REQUEST';
  public static final String NOT_AUTHORIZED = 'NOT_AUTHORIZED';
  public static final String TEMPLATE_NOT_FOUND = 'TEMPLATE_NOT_FOUND';
  public static final String TEMPLATE_NOT_PUBLISHED = 'TEMPLATE_NOT_PUBLISHED';
  public static final String TEMPLATE_VERSION_AMBIGUOUS = 'TEMPLATE_VERSION_AMBIGUOUS';
  public static final String INVALID_CONFIGURATION = 'INVALID_CONFIGURATION';
  public static final String RECORD_NOT_ACCESSIBLE = 'RECORD_NOT_ACCESSIBLE';
  public static final String OBJECT_NOT_ACCESSIBLE = 'OBJECT_NOT_ACCESSIBLE';
  public static final String FIELD_NOT_ACCESSIBLE = 'FIELD_NOT_ACCESSIBLE';
  public static final String NULL_CORRELATION_VALUE = 'NULL_CORRELATION_VALUE';
  public static final String SOURCE_TRUNCATED = 'SOURCE_TRUNCATED';
  public static final String TOTAL_ROW_LIMIT = 'TOTAL_ROW_LIMIT';
  public static final String TRANSACTION_BUDGET_EXCEEDED = 'TRANSACTION_BUDGET_EXCEEDED';
  public static final String FLOW_GROUP_LIMIT_EXCEEDED = 'FLOW_GROUP_LIMIT_EXCEEDED';
  public static final String FLOW_PAYLOAD_LIMIT_EXCEEDED = 'FLOW_PAYLOAD_LIMIT_EXCEEDED';
  public static final String PROMPT_TOO_LONG = 'PROMPT_TOO_LONG';
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

  private PromptContextReasonCodes() {
  }
}
