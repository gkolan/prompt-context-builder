/** Maps validation messages to the common runtime failure contract. */
public with sharing class PromptContextValidationMessages {
  public static String joinErrors(List<PromptContextDTO.Message> messages) {
    List<String> errors = new List<String>();
    for (PromptContextDTO.Message message : messages) {
      if (message.severity == 'ERROR') {
        errors.add(message.text);
      }
    }
    return String.join(errors, ' ');
  }

  public static String reason(List<PromptContextDTO.Message> messages) {
    for (
      String preferredCode : new List<String>{
        PromptContextReasonCodes.OBJECT_NOT_ACCESSIBLE,
        PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE
      }
    ) {
      for (PromptContextDTO.Message message : messages) {
        if (message.severity == 'ERROR' && message.code == preferredCode) {
          return preferredCode;
        }
      }
    }
    return PromptContextReasonCodes.INVALID_CONFIGURATION;
  }

  private PromptContextValidationMessages() {
  }
}
