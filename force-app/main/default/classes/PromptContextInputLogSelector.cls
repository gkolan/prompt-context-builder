/** Reads Prompt Input Logs through explicit user mode, with one digest-checked recovery query. */
public without sharing class PromptContextInputLogSelector {
  /**
   * Finds visible logs by their stored request keys.
   * @param requestKeys User-specific request keys prepared by the save service
   * @return Visible matching Prompt Input Logs
   */
  public static List<Prompt_Input_Log__c> selectByRequestKeys(
    Set<String> requestKeys
  ) {
    if (requestKeys == null || requestKeys.isEmpty()) {
      return new List<Prompt_Input_Log__c>();
    }
    return [
      SELECT Id, Request_Key__c, Input_Verification_Value__c
      FROM Prompt_Input_Log__c
      WHERE Request_Key__c IN :requestKeys
      WITH USER_MODE
      ORDER BY Request_Key__c ASC
      LIMIT 200
    ];
  }

  /**
   * Recovers an exact user-scoped request key after a unique-key race or sharing change.
   * Callers must verify the stored input digest before returning the record Id.
   */
  public static List<Prompt_Input_Log__c> selectByRequestKeysSystem(
    Set<String> requestKeys
  ) {
    if (requestKeys == null || requestKeys.isEmpty()) {
      return new List<Prompt_Input_Log__c>();
    }
    return [
      SELECT Id, Request_Key__c, Input_Verification_Value__c
      FROM Prompt_Input_Log__c
      WHERE Request_Key__c IN :requestKeys
      WITH SYSTEM_MODE
      ORDER BY Request_Key__c ASC
      LIMIT 200
    ];
  }

  private PromptContextInputLogSelector() {
  }
}
