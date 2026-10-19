/**
 * Verifies end to end that a publication stored with syntax version 1 keeps its exact output, that
 * republishing adopts version 2, and that comparison and warnings report the change.
 */
@isTest
private class PromptContextSyntaxPublicationTest {
  private static final String TEMPLATE_KEY = 'pcb_syntax_publication';
  private static final String BODY = 'Mode: {!record.File_Input_Mode__c}';

  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        false
      );
      rootRecord.File_Input_Mode__c = 'USER_SELECT';
      insert rootRecord;

      Datetime publishedAt = Datetime.newInstanceGmt(2026, 9, 1, 0, 0, 0);
      Prompt_Template__c templateRecord = new Prompt_Template__c(
        Name = 'Version 1 publication',
        Developer_Key__c = TEMPLATE_KEY,
        Root_Object__c = 'Prompt_Template__c',
        Template_Body__c = BODY,
        Status__c = 'Published',
        Version__c = 1,
        Published_At__c = publishedAt,
        File_Input_Mode__c = 'DISABLED'
      );
      insert templateRecord;
      insert new Prompt_Template_Version__c(
        Prompt_Template__c = templateRecord.Id,
        Version_Key__c = TEMPLATE_KEY + ':1',
        Version_Number__c = 1,
        Syntax_Version__c = 1,
        Contract_Version__c = PromptContextContract.CONTRACT_VERSION,
        Root_Object__c = 'Prompt_Template__c',
        Template_Body__c = BODY,
        Fingerprint__c = 'version-1-fixture',
        Published_At__c = publishedAt,
        File_Input_Mode__c = 'DISABLED'
      );
    }
  }

  @isTest
  static void shouldKeepVersion1OutputUntilTheTemplateIsRepublished() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Developer_Key__c LIKE 'test_root_%'
        LIMIT 1
      ]
      .Id;
      Id templateId = [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Developer_Key__c = :TEMPLATE_KEY
        LIMIT 1
      ]
      .Id;

      Test.startTest();
      PromptContextInputApi.Result before = prepare(rootId);
      PromptTemplateService.publish(templateId, rootId);
      PromptContextInputApi.Result afterRepublish = prepare(rootId);
      PromptContextDTO.VersionComparison comparison = PromptTemplateGovernanceService.compareVersions(
        templateId,
        1,
        2
      );
      Test.stopTest();

      Assert.areEqual(
        'Mode: USER_SELECT',
        before.prompt,
        'A version 1 publication must keep its exact output.'
      );
      Assert.areEqual(1, before.syntaxVersion);
      Assert.areEqual(
        'Mode: User Selects Files',
        afterRepublish.prompt,
        'Republishing adopts the readable version 2 output.'
      );
      Assert.areEqual(
        PromptContextContract.SYNTAX_VERSION,
        afterRepublish.syntaxVersion
      );
      Assert.isTrue(
        comparison.changes.contains('Syntax version changed.'),
        'Version comparison must show the grammar change: ' + comparison.changes
      );
    }
  }

  @isTest
  static void shouldReturnAFieldTruncatedWarningThroughTheApi() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
      config.name = 'Truncation';
      config.developerKey = 'pcb_truncation';
      config.rootObject = 'Prompt_Template__c';
      config.templateBody = 'Name: {!record.Name maxLength="4"}';
      PromptTemplateService.publish(
        PromptTemplateService.saveDraft(config).id,
        rootRecord.Id
      );

      Test.startTest();
      PromptContextInputApi.Request request = new PromptContextInputApi.Request();
      request.templateDeveloperKey = 'pcb_truncation';
      request.recordId = rootRecord.Id;
      request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
      PromptContextInputApi.Result result = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      )[0];
      Test.stopTest();

      Assert.isTrue(result.success, result.reasonCode + ' ' + result.message);
      Assert.areEqual('Name: Acme…', result.prompt);
      Assert.isTrue(
        result.warningCodes.contains('FIELD_TRUNCATED'),
        'Callers must learn that a value was shortened.'
      );
    }
  }

  private static PromptContextInputApi.Result prepare(Id rootId) {
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.templateDeveloperKey = TEMPLATE_KEY;
    request.recordId = rootId;
    request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
    PromptContextInputApi.Result result = PromptContextInputApi.prepare(
      new List<PromptContextInputApi.Request>{ request }
    )[0];
    Assert.isTrue(result.success, result.reasonCode + ' ' + result.message);
    return result;
  }
}
