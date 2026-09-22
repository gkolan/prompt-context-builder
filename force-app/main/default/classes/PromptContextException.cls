/**
 * Safe Prompt Context Builder error used for setup checks and prompt-generation failures.
 */
public class PromptContextException extends Exception {
  public String reasonCode;

  /** Creates a safe domain exception with a stable machine-readable reason. */
  public static PromptContextException withReason(
    String reasonCode,
    String message
  ) {
    PromptContextException exceptionValue = new PromptContextException(message);
    exceptionValue.reasonCode = reasonCode;
    return exceptionValue;
  }
}
