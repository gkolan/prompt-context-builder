/**
 * Validates template settings and builds one prompt for preview and publication. Generation runs on
 * PromptContextBulkService, the engine record pages, Flow, Apex, and Batch use, so a preview shows
 * exactly what those callers will receive.
 */
public with sharing class PromptContextService {
  /**
   * Checks prompt text, Salesforce fields, access, and limits without reading business records.
   * @param config Complete template configuration
   * @return Actionable validation result
   */
  public static PromptContextDTO.ValidationResult validate(
    PromptContextDTO.TemplateConfig config
  ) {
    return PromptContextValidator.validate(config);
  }

  /**
   * Generates one prompt with the shared engine.
   * @param config Template configuration
   * @param recordId Current Salesforce record Id
   * @return Complete prompt result with counts and warnings
   * @throws PromptContextException with a stable reason when no complete prompt can be built
   */
  public static PromptContextDTO.PromptResult generate(
    PromptContextDTO.TemplateConfig config,
    Id recordId
  ) {
    if (recordId == null) {
      throw new PromptContextException(
        'Choose a sample record before generating a prompt.'
      );
    }
    PromptContextBulkService.Outcome outcome = PromptContextBulkService.generate(
      config,
      new List<Id>{ recordId }
    )[0];
    if (!outcome.isSuccess()) {
      throw PromptContextException.withReason(
        outcome.reasonCode,
        outcome.message
      );
    }
    return outcome.result;
  }

  /** Warning returned when a maxLength attribute shortened at least one value. */
  public static PromptContextDTO.Message truncationWarning() {
    return new PromptContextDTO.Message(
      'WARNING',
      PromptContextReasonCodes.FIELD_TRUNCATED,
      'Template body',
      'One or more values were shortened by maxLength.'
    );
  }
}
