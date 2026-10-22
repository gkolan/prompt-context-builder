/**
 * Verifies the shared preparation contract at every supported invocation boundary: Apex, the Flow
 * invocable action, the Lightning controller, Queueable, and Batch Apex at full scope. Also covers
 * least-privilege runners, misconfiguration, and hostile request values.
 */
@isTest
private class PromptContextEntryPointContractTest {
  private static final String TEMPLATE_KEY = 'pcb_entry_contract';

  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
      config.developerKey = TEMPLATE_KEY;
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        config
      );
      PromptTemplateService.publish(saved.id, rootRecord.Id);
    }
  }

  @isTest
  static void shouldPrepareAndSaveEveryRecordInOneBatchScopeOf200() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Set<Id> rootIds = new Map<Id, Prompt_Template__c>(
          PromptContextTestDataFactory.createRootRecords(
            PromptContextContract.MAX_RECORDS_PER_REQUEST
          )
        )
        .keySet();

      Test.startTest();
      Database.executeBatch(
        new PromptContextSaveBatchTestHarness(
          TEMPLATE_KEY,
          new List<Id>(rootIds)
        ),
        PromptContextContract.MAX_RECORDS_PER_REQUEST
      );
      Test.stopTest();

      assertOneReadyLogPerRecord(rootIds, 'batch:');
    }
  }

  @isTest
  static void shouldPrepareAndSaveFiftyRecordsFromQueueable() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Set<Id> rootIds = new Map<Id, Prompt_Template__c>(
          PromptContextTestDataFactory.createRootRecords(50)
        )
        .keySet();

      Test.startTest();
      System.enqueueJob(new SaveQueueable(new List<Id>(rootIds)));
      Test.stopTest();

      assertOneReadyLogPerRecord(rootIds, 'queueable:');
    }
  }

  @isTest
  static void shouldReturnOrderedIsolatedOutcomesFromTheFlowAction() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      Prompt_Template__c draft = PromptContextTestDataFactory.createRootRecord(
        true
      );
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>{
        request(
          TEMPLATE_KEY,
          rootId,
          PromptContextInputApi.RETURN_TO_APEX,
          null
        ),
        request(
          TEMPLATE_KEY,
          rootId,
          PromptContextInputApi.SAVE_TO_LOG,
          'flow-mixed'
        ),
        // Delivery choices match case-insensitively, like every Apex String comparison.
        request(TEMPLATE_KEY, rootId, 'save_to_log', 'flow-lowercase'),
        request(TEMPLATE_KEY, rootId, PromptContextInputApi.SAVE_TO_LOG, '   '),
        request(
          'x\' OR Name != \'',
          rootId,
          PromptContextInputApi.RETURN_TO_APEX,
          null
        ),
        request(TEMPLATE_KEY, null, PromptContextInputApi.RETURN_TO_APEX, null),
        request(
          draft.Developer_Key__c,
          rootId,
          PromptContextInputApi.RETURN_TO_APEX,
          null
        ),
        null
      };

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepareForFlow(
        requests
      );
      Test.stopTest();

      List<String> expected = new List<String>{
        PromptContextReasonCodes.SUCCESS,
        PromptContextReasonCodes.SUCCESS,
        PromptContextReasonCodes.SUCCESS,
        PromptContextReasonCodes.REQUEST_KEY_REQUIRED,
        PromptContextReasonCodes.INVALID_REQUEST,
        PromptContextReasonCodes.INVALID_REQUEST,
        PromptContextReasonCodes.TEMPLATE_NOT_PUBLISHED,
        PromptContextReasonCodes.INVALID_DELIVERY_CHOICE
      };
      Assert.areEqual(expected.size(), results.size(), 'One result per item.');
      for (Integer index = 0; index < expected.size(); index++) {
        Assert.areEqual(
          expected[index],
          results[index].reasonCode,
          'Unexpected outcome at position ' + index
        );
        Assert.areEqual(
          expected[index] == PromptContextReasonCodes.SUCCESS,
          results[index].success == true,
          'success must agree with the reason code at position ' + index
        );
        if (results[index].success != true) {
          Assert.isNull(
            results[index].prompt,
            'A failed item must not return a partial prompt at position ' +
            index
          );
          Assert.isNull(
            results[index].inputLogId,
            'A failed item must not report a log at position ' + index
          );
        }
      }
      Assert.isNull(results[0].inputLogId, 'Return to Apex never saves.');
      Assert.isNotNull(results[1].inputLogId, 'Save to log returns its log.');
      Assert.isNotNull(
        results[2].inputLogId,
        'A lowercase delivery value must save exactly like the constant.'
      );
      Assert.areEqual(
        2,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'Only the two valid save requests may create logs.'
      );
    }
  }

  @isTest
  static void shouldGrantAGenerateOnlyRunnerNothingBeyondPreparation() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      Id templateId = publishedTemplateId();
      PromptContextAccess.setGenerateForTest(true);
      PromptContextAccess.setConfigureForTest(false);
      PromptContextAccess.setSaveInputForTest(false);
      PromptContextAccess.setSendFilesForTest(false);
      PromptContextAccess.setDiagnosticsForTest(false);

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{
          request(
            TEMPLATE_KEY,
            rootId,
            PromptContextInputApi.RETURN_TO_APEX,
            null
          ),
          request(
            TEMPLATE_KEY,
            rootId,
            PromptContextInputApi.SAVE_TO_LOG,
            'generate-only'
          )
        }
      );
      PromptContextDTO.PromptResult lightningResult = PromptContextController.generatePrompt(
        templateId,
        rootId,
        null
      );
      Boolean configureDenied = false;
      try {
        PromptContextController.getObjectOptions();
      } catch (AuraHandledException expected) {
        configureDenied = true;
      }
      Boolean publishDenied = false;
      try {
        PromptTemplateService.publish(templateId, rootId);
      } catch (PromptContextAccess.AuthorizationException expected) {
        publishDenied = true;
      }
      Test.stopTest();

      Assert.isTrue(results[0].success, 'Generate alone may prepare a prompt.');
      Assert.isNull(
        results[0].diagnosticSummary,
        'Generate alone must not expose diagnostics.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        results[1].reasonCode,
        'Generate alone must not save prepared input.'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'A denied save must not write a log.'
      );
      Assert.isNotNull(
        lightningResult.prompt,
        'The record page uses the same Generate capability.'
      );
      Assert.isTrue(
        configureDenied,
        'Generate alone must not reach the builder.'
      );
      Assert.isTrue(publishDenied, 'Generate alone must not publish.');
    }
  }

  @isTest
  static void shouldDenyEveryPreparationEntryWithoutGenerate() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      Id templateId = publishedTemplateId();
      // Every other capability is granted so only the missing Generate permission can deny.
      PromptContextAccess.setGenerateForTest(false);
      PromptContextAccess.setConfigureForTest(true);
      PromptContextAccess.setSaveInputForTest(true);
      PromptContextAccess.setSendFilesForTest(true);
      PromptContextAccess.setProcessInputForTest(true);
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>{
        request(
          TEMPLATE_KEY,
          rootId,
          PromptContextInputApi.SAVE_TO_LOG,
          'no-generate'
        )
      };
      Integer denials = 0;

      Test.startTest();
      try {
        PromptContextInputApi.prepare(requests);
      } catch (PromptContextAccess.AuthorizationException expected) {
        denials++;
      }
      try {
        PromptContextInputApi.prepareForFlow(requests);
      } catch (PromptContextAccess.AuthorizationException expected) {
        denials++;
      }
      try {
        PromptContextController.generatePrompt(templateId, rootId, null);
      } catch (AuraHandledException expected) {
        denials++;
      }
      Test.stopTest();

      Assert.areEqual(3, denials, 'Apex, Flow, and Lightning must all deny.');
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Prompt_Input_Log__c],
        'A denied request must not write a log.'
      );
    }
  }

  @isTest
  static void shouldStoreOnlyAUserScopedDigestOfTheRequestKey() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      String rawKey = 'order-42 customer@example.com';

      Test.startTest();
      PromptContextInputApi.Result result = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{
          request(
            TEMPLATE_KEY,
            rootId,
            PromptContextInputApi.SAVE_TO_LOG,
            rawKey
          )
        }
      )[0];
      Test.stopTest();

      String storedKey = [
        SELECT Request_Key__c
        FROM Prompt_Input_Log__c
        WHERE Id = :result.inputLogId
      ]
      .Request_Key__c;
      Assert.areEqual(
        EncodingUtil.convertToHex(
          Crypto.generateDigest(
            'SHA-256',
            Blob.valueOf(UserInfo.getUserId() + ':' + rawKey)
          )
        ),
        storedKey,
        'The stored key must be a digest bound to the saving user.'
      );
      Assert.isFalse(
        storedKey.contains('customer@example.com'),
        'The caller-supplied key must never be stored in clear text.'
      );
    }
  }

  @isTest
  static void shouldStopPreparingOnceTheTemplateIsDeactivated() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      PromptTemplateService.deactivate(publishedTemplateId());

      Test.startTest();
      PromptContextInputApi.Result result = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{
          request(
            TEMPLATE_KEY,
            rootId,
            PromptContextInputApi.RETURN_TO_APEX,
            null
          )
        }
      )[0];
      Test.stopTest();

      Assert.isFalse(
        result.success,
        'An automation that still names a deactivated template must fail.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.TEMPLATE_NOT_PUBLISHED,
        result.reasonCode,
        'Deactivation must return a stable reason, not a stale prompt.'
      );
      Assert.isNull(result.prompt, 'No prompt from a deactivated template.');
    }
  }

  @isTest
  static void shouldFailEveryItemWhenTheRecordTypeDoesNotMatchTheTemplate() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      Id wrongObjectId = PromptContextTestDataFactory.createRelatedRecords(
          rootId,
          true
        )[0]
        .Id;

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{
          request(
            TEMPLATE_KEY,
            wrongObjectId,
            PromptContextInputApi.RETURN_TO_APEX,
            null
          ),
          request(
            TEMPLATE_KEY,
            rootId,
            PromptContextInputApi.RETURN_TO_APEX,
            null
          )
        }
      );
      Test.stopTest();

      Assert.isFalse(
        results[0].success,
        'A Record Id of another object must not render the template.'
      );
      Assert.isNull(results[0].prompt, 'No partial prompt for a wrong object.');
      Assert.isTrue(results[1].success, 'A valid neighbor must still succeed.');
    }
  }

  private static void assertOneReadyLogPerRecord(
    Set<Id> rootIds,
    String keyPrefix
  ) {
    Set<String> expectedSources = new Set<String>();
    for (Id rootId : rootIds) {
      expectedSources.add(String.valueOf(rootId));
    }
    List<Prompt_Input_Log__c> logs = [
      SELECT Source_Record_Id__c, Status__c, Prompt_Text__c
      FROM Prompt_Input_Log__c
      WHERE Source_Record_Id__c IN :expectedSources
    ];
    Assert.areEqual(
      rootIds.size(),
      logs.size(),
      'Every ' + keyPrefix + ' record must save exactly one log.'
    );
    for (Prompt_Input_Log__c log : logs) {
      Assert.areEqual('Ready', log.Status__c, 'Each saved log must be Ready.');
      Assert.isTrue(
        String.isNotBlank(log.Prompt_Text__c),
        'Each saved log must hold its prompt.'
      );
      expectedSources.remove(log.Source_Record_Id__c);
    }
    Assert.isTrue(
      expectedSources.isEmpty(),
      'Every requested record must have its own log.'
    );
  }

  private static Id publishedTemplateId() {
    return [
      SELECT Id
      FROM Prompt_Template__c
      WHERE Developer_Key__c = :TEMPLATE_KEY AND Status__c = 'Published'
      LIMIT 1
    ]
    .Id;
  }

  private static PromptContextInputApi.Request request(
    String templateKey,
    Id recordId,
    String deliveryChoice,
    String requestKey
  ) {
    PromptContextInputApi.Request value = new PromptContextInputApi.Request();
    value.templateDeveloperKey = templateKey;
    value.recordId = recordId;
    value.deliveryChoice = deliveryChoice;
    value.requestKey = requestKey;
    return value;
  }

  private class SaveQueueable implements Queueable {
    private List<Id> recordIds;

    private SaveQueueable(List<Id> recordIds) {
      this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
      PromptContextSaveBatchTestHarness.saveAll(
        TEMPLATE_KEY,
        recordIds,
        'queueable:'
      );
    }
  }
}
