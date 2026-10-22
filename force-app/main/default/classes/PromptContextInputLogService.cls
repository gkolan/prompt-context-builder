/** Saves complete prepared inputs without storing Salesforce File contents. */
public with sharing class PromptContextInputLogService {
  private static final String EMPTY_FILE_LIST = '[]';
  private static final String SAVE_FAILED_MESSAGE = 'The prepared input could not be saved. Contact your Salesforce administrator.';

  /** One complete input that may be saved. */
  public class SaveRequest {
    public Integer responseIndex;
    public String requestKey;
    public Id rootRecordId;
    public Id templateVersionId;
    public String promptText;
    public String selectedFilesJson;
  }

  /** Save outcome mapped to the original public response. */
  public class SaveResult {
    public Integer responseIndex;
    public Boolean success;
    public Id inputLogId;
    public String reasonCode;
    public String message;
  }

  private class PendingSave {
    public Prompt_Input_Log__c recordValue;
    public String verificationValue;
    public List<Integer> resultPositions = new List<Integer>();
  }

  /**
   * Saves valid prepared inputs in bulk and safely reuses an identical request.
   * @param requests Complete prepared inputs to save
   * @return One save result per request in the same order
   * @throws PromptContextAccess.AuthorizationException when save permission is missing
   */
  public static List<SaveResult> save(List<SaveRequest> requests) {
    PromptContextAccess.requireSaveInput();
    List<SaveRequest> safeRequests = requests ?? new List<SaveRequest>();
    List<SaveResult> results = createResults(safeRequests);
    if (safeRequests.isEmpty()) {
      return results;
    }

    Set<String> storedRequestKeys = new Set<String>();
    Map<Integer, String> storedKeyByPosition = new Map<Integer, String>();
    Map<Integer, String> verificationByPosition = new Map<Integer, String>();
    for (Integer position = 0; position < safeRequests.size(); position++) {
      SaveRequest request = safeRequests[position];
      if (!hasRequiredValues(request)) {
        fail(
          results[position],
          PromptContextReasonCodes.INPUT_LOG_SAVE_FAILED,
          SAVE_FAILED_MESSAGE
        );
        continue;
      }
      String fileReason = fileListReason(request.selectedFilesJson);
      if (fileReason != null) {
        fail(
          results[position],
          fileReason,
          'The selected Salesforce File details are not valid.'
        );
        continue;
      }
      String storedKey = createStoredRequestKey(request.requestKey);
      String verificationValue = createVerificationValue(request);
      storedRequestKeys.add(storedKey);
      storedKeyByPosition.put(position, storedKey);
      verificationByPosition.put(position, verificationValue);
    }

    Map<String, Prompt_Input_Log__c> existingByRequestKey = new Map<String, Prompt_Input_Log__c>();
    for (
      Prompt_Input_Log__c existingRecord : PromptContextInputLogSelector.selectByRequestKeys(
        storedRequestKeys
      )
    ) {
      existingByRequestKey.put(existingRecord.Request_Key__c, existingRecord);
    }

    Map<String, PendingSave> pendingByRequestKey = new Map<String, PendingSave>();
    for (Integer position = 0; position < safeRequests.size(); position++) {
      if (!storedKeyByPosition.containsKey(position)) {
        continue;
      }
      SaveRequest request = safeRequests[position];
      String storedKey = storedKeyByPosition.get(position);
      String verificationValue = verificationByPosition.get(position);
      if (existingByRequestKey.containsKey(storedKey)) {
        Prompt_Input_Log__c existingRecord = existingByRequestKey.get(
          storedKey
        );
        if (existingRecord.Input_Verification_Value__c == verificationValue) {
          succeed(results[position], existingRecord.Id);
        } else {
          fail(
            results[position],
            PromptContextReasonCodes.REQUEST_KEY_CONFLICT,
            'The Request Key was already used for different prepared input.'
          );
        }
        continue;
      }
      if (pendingByRequestKey.containsKey(storedKey)) {
        PendingSave existingPending = pendingByRequestKey.get(storedKey);
        if (existingPending.verificationValue == verificationValue) {
          existingPending.resultPositions.add(position);
        } else {
          fail(
            results[position],
            PromptContextReasonCodes.REQUEST_KEY_CONFLICT,
            'The Request Key was repeated with different prepared input.'
          );
        }
        continue;
      }
      PendingSave pending = new PendingSave();
      pending.verificationValue = verificationValue;
      pending.resultPositions.add(position);
      pending.recordValue = mapRecord(request, storedKey, verificationValue);
      pendingByRequestKey.put(storedKey, pending);
    }

    insertPending(pendingByRequestKey, results);
    return results;
  }

  /** Confirms that a stored input still matches the verification value created at save time. */
  public static Boolean isVerificationValid(Prompt_Input_Log__c recordValue) {
    if (
      recordValue == null ||
      String.isBlank(recordValue.Input_Verification_Value__c)
    ) {
      return false;
    }
    return recordValue.Input_Verification_Value__c ==
      digest(
        String.join(
          new List<String>{
            recordValue.Source_Record_Id__c,
            String.valueOf(recordValue.Prompt_Template_Version__c),
            recordValue.Prompt_Text__c,
            normalizeFiles(recordValue.Selected_Files_JSON__c),
            recordValue.Input_Format_Version__c
          },
          '\n'
        )
      );
  }

  private static List<SaveResult> createResults(List<SaveRequest> requests) {
    List<SaveResult> results = new List<SaveResult>();
    for (Integer position = 0; position < requests.size(); position++) {
      SaveRequest request = requests[position];
      SaveResult result = new SaveResult();
      result.responseIndex = request?.responseIndex ?? position;
      result.success = false;
      results.add(result);
    }
    return results;
  }

  private static Boolean hasRequiredValues(SaveRequest request) {
    return request != null &&
      !String.isBlank(request.requestKey) &&
      request.rootRecordId != null &&
      request.templateVersionId != null &&
      request.promptText != null;
  }

  private static String fileListReason(String selectedFilesJson) {
    String normalized = normalizeFiles(selectedFilesJson);
    if (normalized.length() > 30000) {
      return PromptContextReasonCodes.INVALID_FILE_SELECTION;
    }
    try {
      Object parsed = JSON.deserializeUntyped(normalized);
      if (!(parsed instanceof List<Object>)) {
        return PromptContextReasonCodes.INVALID_FILE_SELECTION;
      }
      List<Object> entries = (List<Object>) parsed;
      if (entries.size() > PromptContextContract.MAX_SELECTED_FILES) {
        return PromptContextReasonCodes.TOO_MANY_FILES;
      }
      Set<String> allowedKeys = new Set<String>{
        'order',
        'contentDocumentId',
        'contentVersionId',
        'fileName',
        'fileFormat',
        'sizeInBytes',
        'versionNumber',
        'lastModifiedDate'
      };
      for (Object entry : entries) {
        if (!(entry instanceof Map<String, Object>)) {
          return PromptContextReasonCodes.INVALID_FILE_SELECTION;
        }
        Map<String, Object> values = (Map<String, Object>) entry;
        if (
          values.keySet().size() > allowedKeys.size() ||
          !allowedKeys.containsAll(values.keySet()) ||
          String.isBlank((String) values.get('contentVersionId')) ||
          String.isBlank((String) values.get('fileFormat')) ||
          values.get('sizeInBytes') == null
        ) {
          return PromptContextReasonCodes.INVALID_FILE_SELECTION;
        }
      }
      return null;
    } catch (Exception exceptionValue) {
      return PromptContextReasonCodes.INVALID_FILE_SELECTION;
    }
  }

  private static String createStoredRequestKey(String requestKey) {
    return digest(UserInfo.getUserId() + ':' + requestKey.trim());
  }

  private static String createVerificationValue(SaveRequest request) {
    return digest(
      String.join(
        new List<String>{
          String.valueOf(request.rootRecordId),
          String.valueOf(request.templateVersionId),
          request.promptText,
          normalizeFiles(request.selectedFilesJson),
          PromptContextContract.INPUT_FORMAT_VERSION
        },
        '\n'
      )
    );
  }

  private static String normalizeFiles(String selectedFilesJson) {
    return String.isBlank(selectedFilesJson)
      ? EMPTY_FILE_LIST
      : selectedFilesJson;
  }

  private static String digest(String value) {
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(value))
      )
      .toLowerCase();
  }

  private static Prompt_Input_Log__c mapRecord(
    SaveRequest request,
    String storedRequestKey,
    String verificationValue
  ) {
    Datetime nowValue = System.now();
    return new Prompt_Input_Log__c(
      Request_Key__c = storedRequestKey,
      Input_Verification_Value__c = verificationValue,
      Source_Record_Id__c = String.valueOf(request.rootRecordId),
      Prompt_Template_Version__c = request.templateVersionId,
      Prompt_Text__c = request.promptText,
      Selected_Files_JSON__c = normalizeFiles(request.selectedFilesJson),
      Input_Format_Version__c = PromptContextContract.INPUT_FORMAT_VERSION,
      Status__c = PromptContextContract.INPUT_READY,
      Available_At__c = nowValue,
      Attempt_Count__c = 0,
      Retain_Until__c = nowValue.addDays(
        PromptContextContract.DEFAULT_INPUT_RETENTION_DAYS
      ),
      Last_Reason_Code__c = null
    );
  }

  private static void insertPending(
    Map<String, PendingSave> pendingByRequestKey,
    List<SaveResult> results
  ) {
    if (pendingByRequestKey.isEmpty()) {
      return;
    }
    List<String> orderedKeys = new List<String>(pendingByRequestKey.keySet());
    orderedKeys.sort();
    List<Prompt_Input_Log__c> records = new List<Prompt_Input_Log__c>();
    for (String storedKey : orderedKeys) {
      records.add(pendingByRequestKey.get(storedKey).recordValue);
    }
    List<Database.SaveResult> saveResults = Database.insert(
      records,
      false,
      AccessLevel.USER_MODE
    );
    Set<String> duplicateKeys = new Set<String>();
    for (
      Integer recordIndex = 0; recordIndex < saveResults.size(); recordIndex++
    ) {
      if (
        !saveResults[recordIndex].isSuccess() &&
        isDuplicate(saveResults[recordIndex])
      ) {
        duplicateKeys.add(orderedKeys[recordIndex]);
      }
    }
    Map<String, Prompt_Input_Log__c> recoveredByKey = new Map<String, Prompt_Input_Log__c>();
    for (
      Prompt_Input_Log__c recovered : PromptContextInputLogSelector.selectByRequestKeysSystem(
        duplicateKeys
      )
    ) {
      recoveredByKey.put(recovered.Request_Key__c, recovered);
    }
    for (
      Integer recordIndex = 0; recordIndex < saveResults.size(); recordIndex++
    ) {
      PendingSave pending = pendingByRequestKey.get(orderedKeys[recordIndex]);
      Database.SaveResult databaseResult = saveResults[recordIndex];
      for (Integer resultPosition : pending.resultPositions) {
        if (databaseResult.isSuccess()) {
          succeed(results[resultPosition], databaseResult.getId());
        } else if (
          recoveredByKey.containsKey(orderedKeys[recordIndex]) &&
          recoveredByKey
            .get(orderedKeys[recordIndex])
            .Input_Verification_Value__c == pending.verificationValue
        ) {
          succeed(
            results[resultPosition],
            recoveredByKey.get(orderedKeys[recordIndex]).Id
          );
        } else if (recoveredByKey.containsKey(orderedKeys[recordIndex])) {
          fail(
            results[resultPosition],
            PromptContextReasonCodes.REQUEST_KEY_CONFLICT,
            'The Request Key was already used for different prepared input.'
          );
        } else {
          fail(
            results[resultPosition],
            PromptContextReasonCodes.INPUT_LOG_SAVE_FAILED,
            SAVE_FAILED_MESSAGE
          );
        }
      }
    }
  }

  private static Boolean isDuplicate(Database.SaveResult result) {
    for (Database.Error error : result.getErrors()) {
      if (error.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
        return true;
      }
    }
    return false;
  }

  private static void succeed(SaveResult result, Id inputLogId) {
    result.success = true;
    result.inputLogId = inputLogId;
    result.reasonCode = PromptContextReasonCodes.SUCCESS;
    result.message = 'Prepared input saved.';
  }

  private static void fail(
    SaveResult result,
    String reasonCode,
    String message
  ) {
    result.success = false;
    result.inputLogId = null;
    result.reasonCode = reasonCode;
    result.message = message;
  }

  private PromptContextInputLogService() {
  }
}
