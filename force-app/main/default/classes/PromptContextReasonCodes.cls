/** Stable, additive machine-readable result and failure codes. */
public with sharing class PromptContextReasonCodes {
  public static final String SUCCESS = 'SUCCESS';
  public static final String INVALID_REQUEST = 'INVALID_REQUEST';
  public static final String INVALID_DELIVERY_CHOICE = 'INVALID_DELIVERY_CHOICE';
  public static final String REQUEST_KEY_REQUIRED = 'REQUEST_KEY_REQUIRED';
  public static final String REQUEST_KEY_CONFLICT = 'REQUEST_KEY_CONFLICT';
  public static final String INPUT_LOG_SAVE_FAILED = 'INPUT_LOG_SAVE_FAILED';
  public static final String INPUT_LOG_CLAIM_FAILED = 'INPUT_LOG_CLAIM_FAILED';
  public static final String INPUT_LOG_STATE_CHANGED = 'INPUT_LOG_STATE_CHANGED';
  public static final String INPUT_VERIFICATION_FAILED = 'INPUT_VERIFICATION_FAILED';
  public static final String DELIVERY_OUTCOME_UNCERTAIN = 'DELIVERY_OUTCOME_UNCERTAIN';
  public static final String DELIVERY_RETRY_LIMIT = 'DELIVERY_RETRY_LIMIT';
  public static final String FILES_NOT_ENABLED = 'FILES_NOT_ENABLED';
  public static final String FILE_REQUIRED = 'FILE_REQUIRED';
  public static final String INVALID_FILE_SELECTION = 'INVALID_FILE_SELECTION';
  public static final String TOO_MANY_FILES = 'TOO_MANY_FILES';
  public static final String TOO_MANY_LINKED_FILES = 'TOO_MANY_LINKED_FILES';
  public static final String FILE_TOO_LARGE = 'FILE_TOO_LARGE';
  public static final String TOTAL_FILE_BYTES_EXCEEDED = 'TOTAL_FILE_BYTES_EXCEEDED';
  public static final String UNSUPPORTED_FILE_TYPE = 'UNSUPPORTED_FILE_TYPE';
  public static final String FILE_TYPE_MISMATCH = 'FILE_TYPE_MISMATCH';
  public static final String FILE_NOT_LINKED_TO_RECORD = 'FILE_NOT_LINKED_TO_RECORD';
  public static final String FILE_NOT_ACCESSIBLE = 'FILE_NOT_ACCESSIBLE';
  public static final String FILE_VERSION_STALE = 'FILE_VERSION_STALE';
  public static final String FILE_SECURITY_REJECTED = 'FILE_SECURITY_REJECTED';
  public static final String FILE_SCAN_UNAVAILABLE = 'FILE_SCAN_UNAVAILABLE';
  public static final String NOT_AUTHORIZED = 'NOT_AUTHORIZED';
  public static final String TEMPLATE_NOT_FOUND = 'TEMPLATE_NOT_FOUND';
  public static final String DRAFT_CHANGED = 'DRAFT_CHANGED';
  public static final String TEMPLATE_NOT_PUBLISHED = 'TEMPLATE_NOT_PUBLISHED';
  public static final String TEMPLATE_VERSION_AMBIGUOUS = 'TEMPLATE_VERSION_AMBIGUOUS';
  public static final String INVALID_CONFIGURATION = 'INVALID_CONFIGURATION';
  public static final String RECORD_NOT_ACCESSIBLE = 'RECORD_NOT_ACCESSIBLE';
  public static final String OBJECT_NOT_ACCESSIBLE = 'OBJECT_NOT_ACCESSIBLE';
  public static final String FIELD_NOT_ACCESSIBLE = 'FIELD_NOT_ACCESSIBLE';
  public static final String NULL_MATCH_VALUE = 'NULL_MATCH_VALUE';
  public static final String MISSING_CURRENCY_BOUNDARY = 'MISSING_CURRENCY_BOUNDARY';
  public static final String INVALID_MATCH_VALUE = 'INVALID_MATCH_VALUE';
  public static final String SOURCE_TRUNCATED = 'SOURCE_TRUNCATED';
  public static final String TOTAL_ROW_LIMIT = 'TOTAL_ROW_LIMIT';
  public static final String TRANSACTION_BUDGET_EXCEEDED = 'TRANSACTION_BUDGET_EXCEEDED';
  public static final String FLOW_GROUP_LIMIT_EXCEEDED = 'FLOW_GROUP_LIMIT_EXCEEDED';
  public static final String FLOW_PAYLOAD_LIMIT_EXCEEDED = 'FLOW_PAYLOAD_LIMIT_EXCEEDED';
  public static final String PROMPT_TOO_LONG = 'PROMPT_TOO_LONG';
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

  @TestVisible
  private PromptContextReasonCodes() {
  }
}
