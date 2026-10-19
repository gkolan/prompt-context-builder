/** Verifies that a stale editor cannot silently overwrite another person's newer draft. */
@isTest
private class PromptTemplateDraftConflictTest {
  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextTestDataFactory.createRootRecord(true);
    }
  }

  @isTest
  static void shouldRejectASaveBasedOnAnOlderDraft() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig created = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptContextDTO.TemplateConfig firstEditor = PromptTemplateService.getTemplate(
        created.id
      );
      PromptContextDTO.TemplateConfig secondEditor = PromptTemplateService.getTemplate(
        created.id
      );
      firstEditor.description = 'First editor change';
      secondEditor.description = 'Second editor change';

      Test.startTest();
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        firstEditor
      );
      String reason;
      try {
        PromptTemplateService.saveDraft(secondEditor);
      } catch (PromptContextException expected) {
        reason = expected.reasonCode;
      }
      Test.stopTest();

      Assert.areEqual(1, created.draftRevision, 'A new draft starts at 1.');
      Assert.areEqual(
        2,
        saved.draftRevision,
        'Each save advances the revision.'
      );
      Assert.areEqual(
        PromptContextReasonCodes.DRAFT_CHANGED,
        reason,
        'The stale editor must be told to reload.'
      );
      Assert.areEqual(
        'First editor change',
        PromptTemplateService.getTemplate(created.id).description,
        'The newer change must survive.'
      );
    }
  }

  @isTest
  static void shouldRejectARevisionThatSkipsAhead() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig created = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      created.draftRevision = 999;

      String reason;
      try {
        PromptTemplateService.saveDraft(created);
      } catch (PromptContextException expected) {
        reason = expected.reasonCode;
      }

      Assert.areEqual(PromptContextReasonCodes.DRAFT_CHANGED, reason);
    }
  }

  @isTest
  static void shouldKeepTheRevisionWhenPublishingDeactivatingOrRestoring() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      PromptContextDTO.TemplateConfig created = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );

      Test.startTest();
      PromptTemplateService.publish(created.id, rootId);
      created.description = 'Edited after publishing';
      PromptContextDTO.TemplateConfig afterPublish = PromptTemplateService.saveDraft(
        created
      );
      PromptContextDTO.TemplateConfig restored = PromptTemplateGovernanceService.restoreVersionAsDraft(
        created.id,
        1
      );
      PromptContextDTO.TemplateConfig inactive = PromptTemplateService.deactivate(
        created.id
      );
      inactive.description = 'Edited after deactivating';
      PromptContextDTO.TemplateConfig afterDeactivate = PromptTemplateService.saveDraft(
        inactive
      );
      Test.stopTest();

      Assert.areEqual(
        2,
        afterPublish.draftRevision,
        'Publishing must not make the open editor stale.'
      );
      Assert.areEqual(3, restored.draftRevision, 'Restore is a draft save.');
      Assert.areEqual(4, afterDeactivate.draftRevision);
    }
  }

  @isTest
  static void shouldExcludeTheRevisionFromThePublicationFingerprint() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
      PromptContextDTO.TemplateConfig created = PromptTemplateService.saveDraft(
        PromptContextTestDataFactory.createTwoSourceConfig()
      );
      PromptTemplateService.publish(created.id, rootId);
      PromptContextDTO.TemplateConfig resaved = PromptTemplateService.saveDraft(
        PromptTemplateService.getTemplate(created.id)
      );

      Test.startTest();
      PromptTemplateService.publish(created.id, rootId);
      Test.stopTest();

      Assert.areEqual(
        new List<String>{ 'No configuration differences were found.' },
        PromptTemplateGovernanceService.compareVersions(created.id, 1, 2)
          .changes,
        'Saving without edits must not look like a configuration change.'
      );
      Assert.areEqual(2, resaved.draftRevision);
    }
  }
}
