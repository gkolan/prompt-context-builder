/** Verifies that automation keys are readable, unique, and fixed once a template is published. */
@isTest
private class PromptTemplateAutomationKeyTest {
  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextTestDataFactory.createRootRecord(true);
    }
  }

  private static PromptContextDTO.TemplateConfig named(String name) {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.name = name;
    config.developerKey = null;
    return config;
  }

  private static String reasonFor(PromptContextDTO.TemplateConfig config) {
    try {
      PromptTemplateService.saveDraft(config);
    } catch (PromptContextException expected) {
      return expected.reasonCode + ': ' + expected.getMessage();
    }
    return null;
  }

  @isTest
  static void shouldGenerateAReadableKeyAndNumberDuplicates() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      String first = PromptTemplateService.saveDraft(
          named('  Account Call Prep! ')
        )
        .developerKey;
      String second = PromptTemplateService.saveDraft(
          named('Account call prep')
        )
        .developerKey;
      String third = PromptTemplateService.saveDraft(
          named('Account - Call - Prep')
        )
        .developerKey;
      String leadingDigit = PromptTemplateService.saveDraft(named('2026 Plan'))
        .developerKey;

      Assert.areEqual('account_call_prep', first);
      Assert.areEqual('account_call_prep_2', second);
      Assert.areEqual('account_call_prep_3', third);
      Assert.areEqual('template_2026_plan', leadingDigit);
    }
  }

  @isTest
  static void shouldAcceptAChosenKeyAndChangesBeforeTheFirstPublish() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = named('Chosen Key');
      config.developerKey = ' Call_Prep_V1 ';
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        config
      );
      Assert.areEqual('call_prep_v1', saved.developerKey);

      saved.developerKey = 'call_prep';
      saved.name = 'Renamed';
      PromptContextDTO.TemplateConfig changed = PromptTemplateService.saveDraft(
        saved
      );
      Assert.areEqual('call_prep', changed.developerKey);
    }
  }

  @isTest
  static void shouldLockTheKeyAfterTheFirstPublish() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        named('Locked Key')
      );
      PromptTemplateService.publish(
        saved.id,
        PromptContextTestDataFactory.selectRootRecord().Id
      );
      PromptContextDTO.TemplateConfig published = PromptTemplateService.getTemplate(
        saved.id
      );

      published.name = 'Locked Key renamed';
      Assert.areEqual(
        'locked_key',
        PromptTemplateService.saveDraft(published).developerKey,
        'Saving without changing the key must keep it.'
      );

      PromptContextDTO.TemplateConfig reopened = PromptTemplateService.getTemplate(
        saved.id
      );
      reopened.developerKey = 'other_key';
      String reason = reasonFor(reopened);
      Assert.isNotNull(reason, 'A published key must not change.');
      Assert.isTrue(
        reason.startsWith(PromptContextReasonCodes.INVALID_CONFIGURATION),
        reason
      );
      Assert.areEqual(
        'locked_key',
        PromptTemplateService.getTemplate(saved.id).developerKey
      );
    }
  }

  @isTest
  static void shouldRejectMalformedAndTakenKeys() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptTemplateService.saveDraft(named('Taken'));
      for (
        String badKey : new List<String>{
          'has spaces',
          '9starts_with_digit',
          'dash-key',
          'a'.repeat(81),
          'taken'
        }
      ) {
        PromptContextDTO.TemplateConfig config = named(
          'Bad ' + badKey.left(10)
        );
        config.developerKey = badKey;
        String reason = reasonFor(config);
        Assert.isNotNull(reason, badKey + ' must be refused.');
        Assert.isTrue(
          reason.startsWith(PromptContextReasonCodes.INVALID_CONFIGURATION),
          reason
        );
      }
    }
  }
}
