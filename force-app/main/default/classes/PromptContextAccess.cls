/** Central capability authorization for every Prompt Context Builder entry point. */
public with sharing class PromptContextAccess {
  @TestVisible
  private static Boolean generateOverride;
  @TestVisible
  private static Boolean configureOverride;
  @TestVisible
  private static Boolean diagnosticsOverride;
  @TestVisible
  private static Boolean saveInputOverride;
  @TestVisible
  private static Boolean sendFilesOverride;
  private static Boolean processInputOverride;

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

  /** Returns whether the running user may save prepared input. */
  public static Boolean canSaveInput() {
    return saveInputOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Save_Input')
      : saveInputOverride;
  }

  /** Returns whether the running user may send Salesforce Files outside Salesforce. */
  public static Boolean canSendFiles() {
    return sendFilesOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Send_Files')
      : sendFilesOverride;
  }

  /** Returns whether the running user may process saved Prompt Input Logs. */
  public static Boolean canProcessInput() {
    return processInputOverride == null
      ? FeatureManagement.checkPermission('Prompt_Context_Process_Input')
      : processInputOverride;
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

  /** Requires the separate permission for storing prepared text and file details. */
  public static void requireSaveInput() {
    if (!canSaveInput()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to save prepared input.'
      );
    }
  }

  /** Requires the separate permission for a file-bearing provider request. */
  public static void requireSendFiles() {
    if (!canSendFiles()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to send Salesforce Files.'
      );
    }
  }

  /** Stops saved-input processing when the dedicated permission is missing. */
  public static void requireProcessInput() {
    if (!canProcessInput()) {
      throw new AuthorizationException(
        'NOT_AUTHORIZED: You do not have permission to process saved prompt input.'
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

  @TestVisible
  private static void setSaveInputForTest(Boolean allowed) {
    saveInputOverride = allowed;
  }

  @TestVisible
  private static void setSendFilesForTest(Boolean allowed) {
    sendFilesOverride = allowed;
  }

  @TestVisible
  private static void setProcessInputForTest(Boolean allowed) {
    processInputOverride = allowed;
  }
}
