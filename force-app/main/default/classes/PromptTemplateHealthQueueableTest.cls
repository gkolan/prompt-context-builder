/** Tests current setup checks without reading customer record values. */
@isTest
private class PromptTemplateHealthQueueableTest {
  @TestSetup
  static void setupTestData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Account accountRecord = PromptContextTestDataFactory.createAccount(true);
      PromptContextTestDataFactory.createContacts(accountRecord.Id, true);
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(saved.id, accountRecord.Id);
    }
  }

  @isTest
  static void shouldStoreValueFreeHealth_WhenPublishedSnapshotIsValid() {
    User configurator = [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
    System.runAs(configurator) {
      Test.startTest();
      System.enqueueJob(new PromptTemplateHealthQueueable());
      Test.stopTest();

      Prompt_Template__c checked = [
        SELECT
          Version__c,
          Last_Health_Status__c,
          Last_Health_Checked_At__c,
          Last_Health_Codes__c,
          Last_Health_Version__c
        FROM Prompt_Template__c
        LIMIT 1
      ];
      Assert.areEqual(
        'Healthy',
        checked.Last_Health_Status__c,
        'A valid published version should remain healthy.'
      );
      Assert.isNotNull(
        checked.Last_Health_Checked_At__c,
        'The check time should be recorded.'
      );
      Assert.areEqual(
        checked.Version__c,
        checked.Last_Health_Version__c,
        'The setup check must identify the exact fixed version checked.'
      );
      Assert.isFalse(
        checked.Last_Health_Codes__c.contains('Acme'),
        'Health evidence must not contain customer record values.'
      );
    }
  }

  @isTest
  static void shouldFailClosed_WhenCapabilityIsMissing() {
    PromptContextAccess.setConfigureForTest(false);
    Test.startTest();
    try {
      new PromptTemplateHealthQueueable().execute(null);
      Assert.fail('Scheduled health must require Configure permission.');
    } catch (PromptContextAccess.AuthorizationException expected) {
      Assert.areEqual(
        PromptContextReasonCodes.NOT_AUTHORIZED,
        expected.reasonCode,
        'Authorization should use the stable reason code.'
      );
    }
    Test.stopTest();
    PromptContextAccess.setConfigureForTest(null);
  }
}
