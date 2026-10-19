/**
 * Runs the Prepare Record Prompt Input action inside the real Flow runtime: an autolaunched Flow
 * started from Apex and a record-triggered Flow fired by one bulk insert. Not packaged.
 */
@isTest
private class PromptContextFlowRuntimeTest {
  private static final String TEMPLATE_KEY = 'pcb_flow_runtime';

  @TestSetup
  static void setupData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
      config.developerKey = TEMPLATE_KEY;
      PromptTemplateService.publish(
        PromptTemplateService.saveDraft(config).id,
        rootRecord.Id
      );
    }
  }

  @isTest
  static void shouldReturnAndSaveThroughAnAutolaunchedFlow() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;

      Test.startTest();
      Flow.Interview returned = runFlow(rootId, 'RETURN_TO_APEX', null);
      Flow.Interview saved = runFlow(rootId, 'SAVE_TO_LOG', 'flow-runtime');
      Flow.Interview invalid = runFlow(rootId, 'Save to log', 'flow-bad');
      Test.stopTest();

      Assert.areEqual(true, returned.getVariableValue('success'));
      Assert.areEqual('SUCCESS', returned.getVariableValue('reasonCode'));
      Assert.isNotNull(
        returned.getVariableValue('prompt'),
        'The Flow output variable must receive the prompt.'
      );
      Assert.isNull(returned.getVariableValue('inputLogId'));

      Assert.areEqual(true, saved.getVariableValue('success'));
      Assert.isNotNull(
        saved.getVariableValue('inputLogId'),
        'The Flow output variable must receive the saved log Id.'
      );

      Assert.areEqual(
        false,
        invalid.getVariableValue('success'),
        'A label typed instead of the API value must fail, not fault the Flow.'
      );
      Assert.areEqual(
        'INVALID_DELIVERY_CHOICE',
        invalid.getVariableValue('reasonCode')
      );
      Assert.areEqual(1, [SELECT COUNT() FROM Prompt_Input_Log__c]);
    }
  }

  @isTest
  static void shouldSaveOneLogPerRecordWhenARecordTriggeredFlowRunsInBulk() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      List<Prompt_Template__c> probes = new List<Prompt_Template__c>();
      for (Integer index = 0; index < 50; index++) {
        probes.add(
          new Prompt_Template__c(
            Name = 'PCB Flow Probe ' + index,
            Developer_Key__c = 'pcb_flow_probe_' + index,
            Root_Object__c = 'Prompt_Template__c',
            Template_Body__c = '{!record.Name}',
            Status__c = 'Draft',
            Version__c = 0,
            File_Input_Mode__c = 'DISABLED'
          )
        );
      }

      Test.startTest();
      insert probes;
      Test.stopTest();

      Set<String> probeIds = new Set<String>();
      for (Prompt_Template__c probe : probes) {
        probeIds.add(String.valueOf(probe.Id));
      }
      List<Prompt_Input_Log__c> logs = [
        SELECT Source_Record_Id__c, Status__c
        FROM Prompt_Input_Log__c
        WHERE Source_Record_Id__c IN :probeIds
      ];
      Assert.areEqual(
        probes.size(),
        logs.size(),
        'One bulk insert must save one log for every triggering record.'
      );
      for (Prompt_Input_Log__c log : logs) {
        Assert.areEqual('Ready', log.Status__c);
        probeIds.remove(log.Source_Record_Id__c);
      }
      Assert.isTrue(probeIds.isEmpty(), 'No triggering record may be skipped.');
    }
  }

  private static Flow.Interview runFlow(
    Id recordId,
    String deliveryChoice,
    String requestKey
  ) {
    Flow.Interview interview = Flow.Interview.createInterview(
      'PCB_Test_Prepare_Input',
      new Map<String, Object>{
        'templateKey' => TEMPLATE_KEY,
        'recordId' => String.valueOf(recordId),
        'deliveryChoice' => deliveryChoice,
        'requestKey' => requestKey
      }
    );
    interview.start();
    return interview;
  }
}
