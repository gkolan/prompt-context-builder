/** Creates privacy-safe request IDs and short troubleshooting messages. */
public with sharing class PromptContextTrace {
  public static String newCorrelationId() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128))
      .substring(0, 24);
  }

  public static String safeMessage(Exception exceptionValue) {
    if (exceptionValue instanceof PromptContextAccess.AuthorizationException) {
      return Label.PCB_Access_Denied;
    }
    if (exceptionValue instanceof PromptContextException) {
      String message = exceptionValue.getMessage();
      return message.length() <= 500 ? message : message.substring(0, 500);
    }
    return Label.PCB_Generation_Failed;
  }

  /** Returns short request details without customer values only to troubleshooting users. */
  public static String diagnosticSummary(
    String outcome,
    Integer templateVersion
  ) {
    if (!PromptContextAccess.canViewDiagnostics()) {
      return null;
    }
    String summary =
      'contract=' +
      PromptContextContract.CONTRACT_VERSION +
      '; syntax=' +
      PromptContextContract.SYNTAX_VERSION +
      '; outcome=' +
      (String.isBlank(outcome) ? 'UNKNOWN' : outcome);
    if (templateVersion != null) {
      summary += '; templateVersion=' + templateVersion;
    }
    return summary.length() <= 200 ? summary : summary.substring(0, 200);
  }

  private PromptContextTrace() {
  }
}
