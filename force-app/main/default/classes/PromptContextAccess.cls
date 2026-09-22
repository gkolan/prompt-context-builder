/** Central capability authorization for every Prompt Context Builder entry point. */
public with sharing class PromptContextAccess {
  @TestVisible
  private static Boolean generateOverride;
  @TestVisible
  private static Boolean configureOverride;
  @TestVisible
  private static Boolean diagnosticsOverride;

  public class AuthorizationException extends Exception {
    public String reasonCode = PromptContextReasonCodes.NOT_AUTHORIZED;
  }

  public static Boolean canGenerate() {
    return generateOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Generate')
      : generateOverride;
  }

  public static Boolean canConfigure() {
    return configureOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Configure')
      : configureOverride;
  }

  public static Boolean canViewDiagnostics() {
    return diagnosticsOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Diagnostics')
      : diagnosticsOverride;
  }

  public static void requireGenerate() {
    if (!canGenerate()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to generate prompt context.'
      );
    }
  }

  public static void requireConfigure() {
    if (!canConfigure()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to configure prompt templates.'
      );
    }
  }

  @TestVisible
  private static void setGenerateForTest(Boolean allowed) {
    generateOverride = allowed;
  }

  @TestVisible
  private static void setConfigureForTest(Boolean allowed) {
    configureOverride = allowed;
  }

  @TestVisible
  private static void setDiagnosticsForTest(Boolean allowed) {
    diagnosticsOverride = allowed;
  }
}
