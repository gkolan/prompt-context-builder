/** Tests privacy-safe setup checks, required field access, comparison, and restore behavior. */
@isTest
private class PromptTemplateGovernanceServiceTest {
  @TestSetup
  static void setupTestData() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
    }
  }

  @isTest
  static void shouldReturnHealthAndSensitivityWarnings_WhenConfigIsValid() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
      config.rootObject = 'Account';
      config.templateBody =
        'Account: {!record.Name}\n' +
        '{!#each related.recent_contacts as="row"}{!row.LastName}: {!row.Email};{!/each}';
      config.sources.remove(1);
      PromptContextDTO.SourceConfig source = config.sources[0];
      source.relatedObject = 'Contact';
      source.rootField = 'Id';
      source.correlationField = 'AccountId';
      source.selectedFields = new List<String>{ 'LastName', 'Email' };
      source.filters[0].fieldName = 'Email';
      source.sorts[0].fieldName = 'LastName';

      Test.startTest();
      PromptContextDTO.TemplateHealth health = PromptContextController.checkTemplateHealth(
        JSON.serialize(config)
      );
      Test.stopTest();

      Assert.isTrue(
        health.isValid,
        'The known-good configuration should be healthy.'
      );
      Assert.isTrue(
        health.accessManifest.items.size() >= 5,
        'The required-field list should include prompt, match, filter, and sort fields.'
      );
      Boolean foundContactData = false;
      for (PromptContextDTO.Message warning : health.accessManifest.warnings) {
        foundContactData =
          foundContactData || warning.code == 'SENSITIVE_FIELD_REVIEW';
      }
      Assert.isTrue(
        foundContactData,
        'Email use should produce an explicit contact-data review warning.'
      );
    }
  }

  @isTest
  static void shouldCompareAndRestoreImmutableVersion_AsEditableDraft() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );
      PromptContextController.publish(saved.id, accountRecord.Id);
      saved = PromptContextController.getTemplate(saved.id);
      saved.templateBody += '\nVersion two marker';
      saved.sources[0].maxRows = 1;
      saved = PromptContextController.saveDraft(JSON.serialize(saved));
      PromptContextController.publish(saved.id, accountRecord.Id);

      Test.startTest();
      List<PromptContextDTO.VersionSummary> versions = PromptContextController.getTemplateVersions(
        saved.id
      );
      PromptContextDTO.VersionComparison comparison = PromptContextController.compareTemplateVersions(
        saved.id,
        1,
        2
      );
      PromptContextDTO.TemplateConfig restored = PromptContextController.restoreTemplateVersion(
        saved.id,
        1
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        versions.size(),
        'Both fixed published versions should be listed.'
      );
      Assert.areEqual(
        2,
        versions[0].versionNumber,
        'Newest version should appear first.'
      );
      Assert.isTrue(
        comparison.changes.size() >= 2,
        'Template and source changes should both be reported.'
      );
      Assert.areEqual(
        'Published',
        restored.status,
        'Restoring editable settings must not take the current publication offline.'
      );
      Assert.isFalse(
        restored.templateBody.contains('Version two marker'),
        'The restored Draft should use the selected fixed prompt text.'
      );
      Assert.areEqual(
        2,
        [SELECT COUNT() FROM Prompt_Template_Version__c],
        'Restore must never alter or delete fixed published versions.'
      );
    }
  }

  @isTest
  static void shouldRejectUnknownVersion_WithoutChangingDraft() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      PromptContextDTO.TemplateConfig saved = PromptContextController.saveDraft(
        JSON.serialize(PromptContextTestDataFactory.createTwoSourceConfig())
      );

      Test.startTest();
      try {
        PromptTemplateGovernanceService.restoreVersionAsDraft(saved.id, 99);
        Assert.fail('A missing published version must be rejected.');
      } catch (PromptContextException expected) {
        Assert.isTrue(
          expected.getMessage().contains('version'),
          'The safe error should explain that the published version was unavailable.'
        );
      }
      Test.stopTest();

      Assert.areEqual(
        'Draft',
        [SELECT Status__c FROM Prompt_Template__c WHERE Id = :saved.id]
        .Status__c,
        'A failed restore must leave the draft unchanged.'
      );
    }
  }

  @isTest
  static void shouldReportNoChangesForEquivalentPublications() {
    User configurator = getConfigurator();
    System.runAs(configurator) {
      Prompt_Template__c accountRecord = PromptContextTestDataFactory.selectRootRecord();
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(saved.id, accountRecord.Id);
      PromptTemplateService.publish(saved.id, accountRecord.Id);

      PromptContextDTO.VersionComparison comparison = PromptTemplateGovernanceService.compareVersions(
        saved.id,
        1,
        2
      );

      Assert.areEqual(
        new List<String>{ 'No configuration differences were found.' },
        comparison.changes,
        'Publication record identities and version numbers are not configuration changes.'
      );
    }
  }

  @isTest
  static void shouldRejectServicePublish_WhenConfigurePermissionIsMissing() {
    PromptContextAccess.setConfigureForTest(false);
    Integer versionsBefore = [SELECT COUNT() FROM Prompt_Template_Version__c];
    Exception thrown;

    Test.startTest();
    try {
      PromptTemplateService.publish(null, null);
    } catch (Exception exceptionValue) {
      thrown = exceptionValue;
    }
    Test.stopTest();

    Assert.isInstanceOfType(
      thrown,
      PromptContextAccess.AuthorizationException.class,
      'The system-mode publish service must authorize the caller itself.'
    );
    Assert.areEqual(
      versionsBefore,
      [SELECT COUNT() FROM Prompt_Template_Version__c],
      'A denied publish must not create a template version.'
    );
  }

  private static User getConfigurator() {
    return PromptContextTestDataFactory.createConfiguratorUser();
  }
}
