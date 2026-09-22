/**
 * Tests successful and safe-error Lightning controller paths.
 */
@isTest
private class PromptContextControllerTest {
  @TestSetup
  static void setupTestData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Account accountRecord = PromptContextTestDataFactory.createAccount(true);
      PromptContextTestDataFactory.createContacts(accountRecord.Id, true);
    }
  }

  @isTest
  static void shouldCompleteLifecycle_WhenConfigurationIsValid() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();

      Test.startTest();
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(config)
      );
      PromptContextDTO.ValidationResult validation = PromptContextController.validateConfig(
        JSON.serialize(saved)
      );
      PromptContextDTO.PromptResult previewResult = PromptContextController.preview(
        JSON.serialize(saved),
        accountRecord.Id
      );
      PromptContextDTO.PromptResult publishResult = PromptContextController.publish(
        saved.id,
        accountRecord.Id
      );
      List<PromptContextDTO.TemplateChoice> choices = PromptContextController.getPublishedTemplates(
        'Account'
      );
      PromptContextDTO.PromptResult generated = PromptContextController.generatePrompt(
        saved.id,
        accountRecord.Id
      );
      PromptContextDTO.TemplateSummaryPage templatePage = PromptContextController.getTemplateSummaryPage(
        null,
        50,
        null,
        null
      );
      PromptContextDTO.TemplateConfig loaded = PromptContextController.getTemplate(
        saved.id
      );
      Test.stopTest();

      Assert.areEqual(
        'Draft',
        saved.status,
        'A save should always return a draft.'
      );
      Assert.isTrue(
        validation.isValid,
        'The saved configuration should validate.'
      );
      Assert.areEqual(
        previewResult.prompt,
        publishResult.prompt,
        'Publish should use a successful preview.'
      );
      Assert.areEqual(
        1,
        publishResult.templateVersion,
        'The first publish should create version one.'
      );
      Assert.areEqual(
        64,
        publishResult.fingerprint.length(),
        'The version signature should use SHA-256 hexadecimal text.'
      );
      Assert.isTrue(
        publishResult.accessManifest.items.size() > 0,
        'Publish should return the exact required-field list reviewed.'
      );
      Assert.areEqual(
        1,
        choices.size(),
        'The published template should be available.'
      );
      Assert.areEqual(
        publishResult.prompt,
        generated.prompt,
        'Published generation should be deterministic.'
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Prompt_Template_Version__c],
        'Publishing should create one fixed template version.'
      );
      Assert.areEqual(
        2,
        [SELECT COUNT() FROM Prompt_Context_Source_Version__c],
        'Publishing should save each independently configured data set version.'
      );
      Assert.areEqual(
        1,
        templatePage.items.size(),
        'The builder should reload its saved template.'
      );
      Assert.areEqual(
        saved.id,
        loaded.id,
        'The selected template should reload by Id.'
      );
    }
  }

  @isTest
  static void shouldExcludeTemplate_WhenRootObjectDoesNotMatch() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );
      PromptContextController.publish(saved.id, accountRecord.Id);

      Test.startTest();
      List<PromptContextDTO.TemplateChoice> choices = PromptContextController.getPublishedTemplates(
        'Contact'
      );
      Test.stopTest();

      Assert.areEqual(
        0,
        choices.size(),
        'A template must appear only for its current record object.'
      );
    }
  }

  @isTest
  static void shouldRemovePublishedChoice_WhenTemplateIsDeactivated() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );
      PromptContextController.publish(saved.id, accountRecord.Id);

      Test.startTest();
      PromptContextDTO.TemplateConfig inactive = PromptContextController.deactivateTemplate(
        saved.id
      );
      List<PromptContextDTO.TemplateChoice> choices = PromptContextController.getPublishedTemplates(
        'Account'
      );
      Test.stopTest();

      Assert.areEqual(
        'Inactive',
        inactive.status,
        'Deactivation should preserve the template but change its lifecycle state.'
      );
      Assert.areEqual(
        0,
        choices.size(),
        'Inactive templates must disappear from prompt-generation choices.'
      );
    }
  }

  @isTest
  static void shouldSaveIncompleteSourceAsDraft() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
      config.sources[0].referenceName = '';
      config.sources[0].relatedObject = '';
      config.sources[0].correlationField = '';

      Test.startTest();
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(config)
      );
      PromptContextDTO.ValidationResult validation = PromptContextController.validateConfig(
        JSON.serialize(saved)
      );
      Test.stopTest();

      Assert.areEqual(
        'Draft',
        saved.status,
        'Incomplete work should remain recoverable as a draft.'
      );
      Assert.isFalse(
        validation.isValid,
        'An incomplete source must still block preview and publication.'
      );
    }
  }

  @isTest
  static void shouldPageTemplateCatalogWithoutDuplicates() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      for (String templateName : new List<String>{ 'Alpha', 'Beta', 'Gamma' }) {
        PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
        config.name = templateName;
        config.developerKey = templateName.toLowerCase();
        PromptContextController.saveDraft(JSON.serialize(config));
      }

      Test.startTest();
      PromptContextDTO.TemplateSummaryPage firstPage = PromptContextController.getTemplateSummaryPage(
        null,
        2,
        null,
        null
      );
      PromptContextDTO.TemplateSummaryPage secondPage = PromptContextController.getTemplateSummaryPage(
        null,
        2,
        firstPage.nextName,
        firstPage.nextId
      );
      PromptContextDTO.TemplateSummaryPage searchPage = PromptContextController.getTemplateSummaryPage(
        'Beta',
        10,
        null,
        null
      );
      Test.stopTest();

      Assert.areEqual(2, firstPage.items.size());
      Assert.isTrue(firstPage.hasMore);
      Assert.areEqual('Alpha', firstPage.items[0].name);
      Assert.areEqual('Beta', firstPage.items[1].name);
      Assert.areEqual(1, secondPage.items.size());
      Assert.isFalse(secondPage.hasMore);
      Assert.areEqual('Gamma', secondPage.items[0].name);
      Assert.areEqual(1, searchPage.items.size());
      Assert.areEqual('Beta', searchPage.items[0].name);
    }
  }

  @isTest
  static void shouldRejectChangesToPublishedSnapshots() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Account accountRecord = [SELECT Id FROM Account LIMIT 1];
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );
      PromptContextController.publish(saved.id, accountRecord.Id);
      Prompt_Template_Version__c templateVersion = [
        SELECT Id, Template_Body__c
        FROM Prompt_Template_Version__c
        LIMIT 1
      ];
      templateVersion.Template_Body__c = 'Changed after publication';
      try {
        update templateVersion;
        Assert.fail('Published template versions must stay fixed.');
      } catch (Exception expected) {
        Assert.isTrue(
          expected.getMessage().contains('cannot be edited') ||
          expected.getMessage().contains('UPDATE not allowed')
        );
      }
      Prompt_Context_Source_Version__c sourceVersion = [
        SELECT Id, Reference_Name__c
        FROM Prompt_Context_Source_Version__c
        LIMIT 1
      ];
      sourceVersion.Reference_Name__c = 'changed_alias';
      try {
        update sourceVersion;
        Assert.fail('Published data set versions must stay fixed.');
      } catch (Exception expected) {
        Assert.isTrue(
          expected.getMessage().contains('cannot be edited') ||
          expected.getMessage().contains('UPDATE not allowed')
        );
      }
    }
  }

  @isTest
  static void shouldKeepAutomationKeyStableAfterFirstSave() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );
      Prompt_Template__c templateRecord = [
        SELECT Id, Developer_Key__c
        FROM Prompt_Template__c
        WHERE Id = :saved.id
      ];
      templateRecord.Developer_Key__c = 'replacement_key';
      try {
        update templateRecord;
        Assert.fail('The stable automation key must not be editable.');
      } catch (DmlException expected) {
        Assert.isTrue(expected.getMessage().contains('permanent'));
      }
    }
  }

  @isTest
  static void shouldReturnOptions_WhenBuilderLoads() {
    PromptContextAccess.setConfigureForTest(true);
    Test.startTest();
    List<PromptContextDTO.Option> objects = PromptContextController.getObjectOptions();
    List<PromptContextDTO.Option> fields = PromptContextController.getFieldOptions(
      'Account'
    );
    Test.stopTest();

    Assert.isTrue(objects.size() > 0, 'Accessible objects should be returned.');
    Assert.isTrue(fields.size() > 0, 'Readable fields should be returned.');
  }

  @isTest
  static void shouldReturnSafeError_WhenFieldObjectIsInvalid() {
    assertAuraError('FIELD');
  }

  @isTest
  static void shouldReturnSafeError_WhenTemplateIsMissing() {
    assertAuraError('TEMPLATE');
  }

  @isTest
  static void shouldReturnSafeError_WhenDraftJsonIsMissing() {
    assertAuraError('SAVE');
  }

  @isTest
  static void shouldReturnSafeError_WhenDraftJsonIsMalformed() {
    assertAuraError('SAVE_JSON');
  }

  @isTest
  static void shouldReturnSafeError_WhenValidationJsonIsMalformed() {
    assertAuraError('VALIDATE');
  }

  @isTest
  static void shouldReturnSafeError_WhenValidationJsonIsMissing() {
    assertAuraError('VALIDATE_MISSING');
  }

  @isTest
  static void shouldReturnSafeError_WhenPreviewRecordIsMissing() {
    assertAuraError('PREVIEW');
  }

  @isTest
  static void shouldReturnSafeError_WhenPreviewJsonIsMalformed() {
    assertAuraError('PREVIEW_JSON');
  }

  @isTest
  static void shouldReturnSafeError_WhenPublishInputIsMissing() {
    assertAuraError('PUBLISH');
  }

  @isTest
  static void shouldReturnSafeError_WhenPublishedRootIsInvalid() {
    assertAuraError('PUBLISHED');
  }

  @isTest
  static void shouldReturnSafeError_WhenGenerationInputIsMissing() {
    assertAuraError('GENERATE');
  }

  private static void assertAuraError(String action) {
    PromptContextAccess.setConfigureForTest(true);
    PromptContextAccess.setGenerateForTest(true);
    Test.startTest();
    try {
      if (action == 'FIELD') {
        PromptContextController.getFieldOptions('Missing_Object__c');
      } else if (action == 'TEMPLATE') {
        PromptContextController.getTemplate(null);
      } else if (action == 'SAVE') {
        PromptContextController.saveDraft(null);
      } else if (action == 'SAVE_JSON') {
        PromptContextController.saveDraft('{bad json');
      } else if (action == 'VALIDATE') {
        PromptContextController.validateConfig('{bad json');
      } else if (action == 'VALIDATE_MISSING') {
        PromptContextController.validateConfig(null);
      } else if (action == 'PREVIEW') {
        PromptContextController.preview(
          JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig()),
          null
        );
      } else if (action == 'PREVIEW_JSON') {
        PromptContextController.preview('{bad json', null);
      } else if (action == 'PUBLISH') {
        PromptContextController.publish(null, null);
      } else if (action == 'PUBLISHED') {
        PromptContextController.getPublishedTemplates('Missing_Object__c');
      } else if (action == 'GENERATE') {
        PromptContextController.generatePrompt(null, null);
      }
      Assert.fail('The invalid request should return a safe error.');
    } catch (AuraHandledException exceptionValue) {
      Assert.isNotNull(
        exceptionValue,
        'The controller should return an Aura-safe error.'
      );
    }
    Test.stopTest();
  }

  private static User getConfigurator() {
    return [SELECT Id FROM User WHERE Alias = 'pcbtest' LIMIT 1];
  }
}
