/** Tests Prompt Input Log claim, retry, uncertain outcome, and retention rules. */
@isTest
private class PromptContextInputLifecycleTest {
  @TestSetup
  static void setupTemplate() {
    PromptContextTestDataFactory.createConfiguratorUser();
    User configurator = PromptContextTestDataFactory.assignPermissionSets(
      new Set<String>{ 'Prompt_Context_Process_Input' }
    );
    System.runAs(configurator) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(saved.id, rootRecord.Id);
    }
  }

  @isTest
  static void shouldClaimAndCompleteOneReadyInput() {
    System.runAs(configurator()) {
      Id logId = createLog('claim-one');
      PromptContextAccess.setProcessInputForTest(true);
      List<Prompt_Input_Log__c> claimed = PromptContextInputLifecycle.claimAvailable(
        10
      );
      Assert.areEqual(1, claimed.size(), 'One Ready input should be claimed.');
      Assert.areEqual(
        logId,
        claimed[0].Id,
        'The returned record should be the claimed input.'
      );
      Assert.areEqual(
        'Processing',
        claimed[0].Status__c,
        'A claim should set Processing.'
      );
      Assert.areEqual(
        1,
        claimed[0].Attempt_Count__c,
        'A claim should count one delivery attempt.'
      );

      PromptContextInputLifecycle.markSent(logId);
      Prompt_Input_Log__c completed = [
        SELECT Status__c, Processing_Expires_At__c, Last_Reason_Code__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];
      Assert.areEqual(
        'Sent',
        completed.Status__c,
        'A confirmed delivery should set Sent.'
      );
      Assert.isNull(
        completed.Processing_Expires_At__c,
        'A completed input should release its claim.'
      );
    }
  }

  @isTest
  static void shouldRetryTemporaryFailureAndStopAtAttemptLimit() {
    System.runAs(configurator()) {
      Id logId = createLog('retry-one');
      PromptContextAccess.setProcessInputForTest(true);
      PromptContextInputLifecycle.claimAvailable(1);
      PromptContextInputLifecycle.recordFailure(
        logId,
        'TEMPORARY_PROVIDER_ERROR',
        true,
        false
      );
      Prompt_Input_Log__c retryRecord = [
        SELECT Status__c, Available_At__c, Attempt_Count__c, Last_Reason_Code__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];
      Assert.areEqual(
        'Ready',
        retryRecord.Status__c,
        'A safe temporary failure should return to Ready.'
      );
      Assert.isTrue(
        retryRecord.Available_At__c > System.now(),
        'A retry should wait before another claim.'
      );

      retryRecord.Available_At__c = System.now().addMinutes(-1);
      retryRecord.Attempt_Count__c =
        PromptContextContract.MAX_INPUT_DELIVERY_ATTEMPTS - 1;
      update retryRecord;
      PromptContextInputLifecycle.claimAvailable(1);
      PromptContextInputLifecycle.recordFailure(
        logId,
        'TEMPORARY_PROVIDER_ERROR',
        true,
        false
      );
      retryRecord = [
        SELECT Status__c, Attempt_Count__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];
      Assert.areEqual(
        'Failed',
        retryRecord.Status__c,
        'The maximum attempt should end automatic retry.'
      );
      Assert.areEqual(
        3,
        retryRecord.Attempt_Count__c,
        'Every claim should count once.'
      );
    }
  }

  @isTest
  static void shouldNeverRetryAnUncertainProviderOutcome() {
    System.runAs(configurator()) {
      Id logId = createLog('uncertain-one');
      PromptContextAccess.setProcessInputForTest(true);
      PromptContextInputLifecycle.claimAvailable(1);
      PromptContextInputLifecycle.recordFailure(logId, null, true, true);
      Prompt_Input_Log__c failed = [
        SELECT Status__c, Last_Reason_Code__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];
      Assert.areEqual(
        'Failed',
        failed.Status__c,
        'An uncertain accepted request must not retry.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.DELIVERY_OUTCOME_UNCERTAIN,
        failed.Last_Reason_Code__c,
        'The stable reason should explain why automation stopped.'
      );
    }
  }

  @isTest
  static void shouldFailAnExpiredClaimWithoutRedelivery() {
    System.runAs(configurator()) {
      Id logId = createLog('expired-claim');
      update new Prompt_Input_Log__c(
        Id = logId,
        Status__c = 'Processing',
        Attempt_Count__c = 1,
        Processing_Expires_At__c = System.now().addMinutes(-1)
      );
      PromptContextAccess.setProcessInputForTest(true);

      List<Prompt_Input_Log__c> claimed = PromptContextInputLifecycle.claimAvailable(
        10
      );
      Prompt_Input_Log__c failed = [
        SELECT Status__c, Attempt_Count__c, Last_Reason_Code__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];

      Assert.isTrue(
        claimed.isEmpty(),
        'An expired Processing claim has an uncertain provider outcome and must not be delivered again.'
      );
      Assert.areEqual('Failed', failed.Status__c);
      Assert.areEqual(1, failed.Attempt_Count__c);
      Assert.areEqual(
        PromptContextReasonCodes.DELIVERY_OUTCOME_UNCERTAIN,
        failed.Last_Reason_Code__c
      );
    }
  }

  @isTest
  static void shouldPreserveActiveProcessingDuringRetentionCleanup() {
    System.runAs(configurator()) {
      Id expiredReadyId = createLog('expired-ready');
      Id activeId = createLog('expired-active');
      update new List<Prompt_Input_Log__c>{
        new Prompt_Input_Log__c(
          Id = expiredReadyId,
          Retain_Until__c = System.now().addDays(-1)
        ),
        new Prompt_Input_Log__c(
          Id = activeId,
          Status__c = 'Processing',
          Retain_Until__c = System.now().addDays(-1),
          Processing_Expires_At__c = System.now().addMinutes(5)
        )
      };
      PromptContextAccess.setProcessInputForTest(true);
      Integer deletedCount = PromptContextInputLifecycle.deleteExpired(200);
      Assert.areEqual(
        1,
        deletedCount,
        'Only the inactive expired record should be removed.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Prompt_Input_Log__c WHERE Id = :activeId],
        'An active Processing record must remain until its claim expires.'
      );
    }
  }

  @isTest
  static void shouldFailAStoredInputThatWasChangedAfterSave() {
    System.runAs(configurator()) {
      Id logId = createLog('changed-after-save');
      update new Prompt_Input_Log__c(
        Id = logId,
        Prompt_Text__c = 'Changed after the verification value was stored.'
      );
      PromptContextAccess.setProcessInputForTest(true);

      List<Prompt_Input_Log__c> claimed = PromptContextInputLifecycle.claimAvailable(
        10
      );
      Prompt_Input_Log__c failed = [
        SELECT Status__c, Last_Reason_Code__c
        FROM Prompt_Input_Log__c
        WHERE Id = :logId
      ];

      Assert.isTrue(claimed.isEmpty(), 'Changed input must not be delivered.');
      Assert.areEqual('Failed', failed.Status__c);
      Assert.areEqual(
        PromptContextReasonCodes.INPUT_VERIFICATION_FAILED,
        failed.Last_Reason_Code__c
      );
    }
  }

  @isTest
  static void shouldClaimTheOldestReadyInputFirst() {
    System.runAs(configurator()) {
      Id newerId = createLog('claim-order-newer');
      Id middleId = createLog('claim-order-middle');
      // Inserted last but waiting longest, so insertion order cannot pick it by accident.
      Id oldestId = createLog('claim-order-oldest');
      Datetime nowValue = System.now();
      update new List<Prompt_Input_Log__c>{
        new Prompt_Input_Log__c(
          Id = newerId,
          Available_At__c = nowValue.addMinutes(-1)
        ),
        new Prompt_Input_Log__c(
          Id = middleId,
          Available_At__c = nowValue.addMinutes(-30)
        ),
        new Prompt_Input_Log__c(
          Id = oldestId,
          Available_At__c = nowValue.addDays(-1)
        )
      };

      Test.startTest();
      List<Prompt_Input_Log__c> first = PromptContextInputLifecycle.claimAvailable(
        1
      );
      List<Prompt_Input_Log__c> next = PromptContextInputLifecycle.claimAvailable(
        2
      );
      Test.stopTest();

      Assert.areEqual(oldestId, first[0].Id, 'The oldest work goes first.');
      Assert.areEqual(middleId, next[0].Id, 'Claims follow waiting time.');
      Assert.areEqual(newerId, next[1].Id);
    }
  }

  @isTest
  static void shouldPurgeOnlyExpiredInputs() {
    System.runAs(configurator()) {
      Id expiredId = createLog('purge-expired');
      Id keptId = createLog('purge-kept');
      update new Prompt_Input_Log__c(
        Id = expiredId,
        Retain_Until__c = System.now().addDays(-1)
      );

      Test.startTest();
      System.enqueueJob(new PromptContextInputPurgeQueueable());
      Test.stopTest();

      Assert.areEqual(
        new Set<Id>{ keptId },
        new Map<Id, Prompt_Input_Log__c>(
            [
              SELECT Id
              FROM Prompt_Input_Log__c
              WHERE Id IN (:expiredId, :keptId)
            ]
          )
          .keySet(),
        'The purge deletes expired logs and keeps current ones.'
      );
    }
  }

  private static User configurator() {
    return PromptContextTestDataFactory.createConfiguratorUser();
  }

  private static Id createLog(String requestKey) {
    PromptContextAccess.setSaveInputForTest(true);
    String templateName = PromptContextTestDataFactory.createTwoSourceConfig()
      .name;
    Prompt_Template_Version__c versionRecord = [
      SELECT Id
      FROM Prompt_Template_Version__c
      WHERE Prompt_Template__r.Name = :templateName
      ORDER BY Version_Number__c DESC
      LIMIT 1
    ];
    Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
    PromptContextInputLogService.SaveRequest request = new PromptContextInputLogService.SaveRequest();
    request.responseIndex = 0;
    request.requestKey = requestKey;
    request.rootRecordId = accountRecord.Id;
    request.templateVersionId = versionRecord.Id;
    request.promptText = 'Prepared input for lifecycle testing.';
    request.selectedFilesJson = '[]';
    PromptContextInputLogService.SaveResult result = PromptContextInputLogService.save(
      new List<PromptContextInputLogService.SaveRequest>{ request }
    )[0];
    Assert.isTrue(
      result.success,
      'Lifecycle setup should create a complete Ready log.'
    );
    return result.inputLogId;
  }
}
