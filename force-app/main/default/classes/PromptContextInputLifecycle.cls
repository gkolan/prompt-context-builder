/** Claims, completes, retries, and removes saved Prompt Input Logs with tested state rules. */
public with sharing class PromptContextInputLifecycle {
  /** Claims a limited set of available records. Concurrent workers cannot claim the same row. */
  public static List<Prompt_Input_Log__c> claimAvailable(
    Integer requestedLimit
  ) {
    PromptContextAccess.requireProcessInput();
    Integer safeLimit = Math.max(
      1,
      Math.min(
        requestedLimit ?? PromptContextContract.MAX_INPUTS_PER_WORKER,
        PromptContextContract.MAX_INPUTS_PER_WORKER
      )
    );
    Datetime nowValue = System.now();
    List<Prompt_Input_Log__c> candidates = [
      SELECT
        Id,
        Source_Record_Id__c,
        Prompt_Template_Version__c,
        Prompt_Text__c,
        Selected_Files_JSON__c,
        Input_Format_Version__c,
        Input_Verification_Value__c,
        Status__c,
        Available_At__c,
        Processing_Expires_At__c,
        Attempt_Count__c,
        Retain_Until__c
      FROM Prompt_Input_Log__c
      WHERE
        (Status__c = 'Ready'
        AND Available_At__c <= :nowValue)
        OR (Status__c = 'Processing'
        AND Processing_Expires_At__c <= :nowValue)
      WITH USER_MODE
      LIMIT :safeLimit
      FOR UPDATE
    ];
    List<Prompt_Input_Log__c> claimed = new List<Prompt_Input_Log__c>();
    List<Prompt_Input_Log__c> updates = new List<Prompt_Input_Log__c>();
    for (Prompt_Input_Log__c candidate : candidates) {
      if (candidate.Status__c == 'Processing') {
        updates.add(
          new Prompt_Input_Log__c(
            Id = candidate.Id,
            Status__c = 'Failed',
            Last_Reason_Code__c = PromptContextReasonCodes.DELIVERY_OUTCOME_UNCERTAIN,
            Processing_Expires_At__c = null
          )
        );
        continue;
      }
      if (!PromptContextInputLogService.isVerificationValid(candidate)) {
        updates.add(
          new Prompt_Input_Log__c(
            Id = candidate.Id,
            Status__c = 'Failed',
            Last_Reason_Code__c = PromptContextReasonCodes.INPUT_VERIFICATION_FAILED,
            Processing_Expires_At__c = null
          )
        );
        continue;
      }
      Integer attempts = Integer.valueOf(candidate.Attempt_Count__c ?? 0);
      if (attempts >= PromptContextContract.MAX_INPUT_DELIVERY_ATTEMPTS) {
        updates.add(
          new Prompt_Input_Log__c(
            Id = candidate.Id,
            Status__c = 'Failed',
            Last_Reason_Code__c = PromptContextReasonCodes.DELIVERY_RETRY_LIMIT,
            Processing_Expires_At__c = null
          )
        );
        continue;
      }
      attempts++;
      candidate.Status__c = 'Processing';
      candidate.Attempt_Count__c = attempts;
      candidate.Processing_Expires_At__c = nowValue.addMinutes(
        PromptContextContract.INPUT_PROCESSING_MINUTES
      );
      candidate.Last_Reason_Code__c = null;
      updates.add(candidate);
      claimed.add(candidate);
    }
    if (!updates.isEmpty()) {
      Database.update(updates, true, AccessLevel.USER_MODE);
    }
    return claimed;
  }

  /** Marks one currently processing input as sent. */
  public static void markSent(Id inputLogId) {
    PromptContextAccess.requireProcessInput();
    Prompt_Input_Log__c recordValue = requireProcessing(inputLogId);
    recordValue.Status__c = 'Sent';
    recordValue.Processing_Expires_At__c = null;
    recordValue.Last_Reason_Code__c = null;
    Database.update(
      new List<Prompt_Input_Log__c>{ recordValue },
      true,
      AccessLevel.USER_MODE
    );
  }

  /** Records a safe failure. Uncertain provider outcomes never retry automatically. */
  public static void recordFailure(
    Id inputLogId,
    String reasonCode,
    Boolean retryable,
    Boolean providerMayHaveAccepted
  ) {
    PromptContextAccess.requireProcessInput();
    Prompt_Input_Log__c recordValue = requireProcessing(inputLogId);
    Integer attempts = Integer.valueOf(recordValue.Attempt_Count__c ?? 0);
    Boolean mayRetry =
      retryable == true &&
      providerMayHaveAccepted != true &&
      attempts < PromptContextContract.MAX_INPUT_DELIVERY_ATTEMPTS;
    recordValue.Status__c = mayRetry ? 'Ready' : 'Failed';
    recordValue.Available_At__c = mayRetry
      ? System.now().addMinutes(PromptContextContract.INPUT_RETRY_MINUTES)
      : recordValue.Available_At__c;
    recordValue.Processing_Expires_At__c = null;
    recordValue.Last_Reason_Code__c = providerMayHaveAccepted == true
      ? PromptContextReasonCodes.DELIVERY_OUTCOME_UNCERTAIN
      : (String.isBlank(reasonCode)
          ? PromptContextReasonCodes.UNEXPECTED_ERROR
          : reasonCode);
    Database.update(
      new List<Prompt_Input_Log__c>{ recordValue },
      true,
      AccessLevel.USER_MODE
    );
  }

  /** Deletes expired logs while preserving active Processing records until their claim expires. */
  public static Integer deleteExpired(Integer requestedLimit) {
    PromptContextAccess.requireProcessInput();
    Integer safeLimit = Math.max(1, Math.min(requestedLimit ?? 200, 200));
    Datetime nowValue = System.now();
    List<Prompt_Input_Log__c> expired = [
      SELECT Id
      FROM Prompt_Input_Log__c
      WHERE
        Retain_Until__c <= :nowValue
        AND (Status__c != 'Processing'
        OR Processing_Expires_At__c <= :nowValue)
      WITH USER_MODE
      ORDER BY Retain_Until__c ASC, Id ASC
      LIMIT :safeLimit
    ];
    if (!expired.isEmpty()) {
      Database.delete(expired, true, AccessLevel.USER_MODE);
    }
    return expired.size();
  }

  private static Prompt_Input_Log__c requireProcessing(Id inputLogId) {
    if (inputLogId == null) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_REQUEST,
        'A Prompt Input Log Id is required.'
      );
    }
    List<Prompt_Input_Log__c> records = [
      SELECT
        Id,
        Status__c,
        Attempt_Count__c,
        Available_At__c,
        Processing_Expires_At__c,
        Last_Reason_Code__c
      FROM Prompt_Input_Log__c
      WHERE Id = :inputLogId
      WITH USER_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (records.isEmpty() || records[0].Status__c != 'Processing') {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.INPUT_LOG_STATE_CHANGED,
        'This Prompt Input Log is no longer in Processing status.'
      );
    }
    return records[0];
  }

  private PromptContextInputLifecycle() {
  }
}
