/** Tests registration and permission checks for daily setup checks. */
@isTest
private class PromptTemplateHealthSchedulableTest {
  @TestSetup
  static void setupTestUser() {
    PromptContextTestDataFactory.createConfiguratorUser();
  }

  @isTest
  static void shouldRegisterDailyJob_WhenConfiguratorSchedulesIt() {
    User configurator = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(configurator) {
      Test.startTest();
      String jobId = PromptTemplateHealthSchedulable.scheduleDaily();
      String repeatedJobId = PromptTemplateHealthSchedulable.scheduleDaily();
      CronTrigger scheduled = [
        SELECT CronExpression, State
        FROM CronTrigger
        WHERE Id = :jobId
      ];
      Assert.areEqual(
        PromptTemplateHealthSchedulable.CRON_DAILY_2AM,
        scheduled.CronExpression,
        'The documented daily schedule should be registered.'
      );
      Assert.areEqual('WAITING', scheduled.State, 'The job should be waiting.');
      Assert.areEqual(
        jobId,
        repeatedJobId,
        'Scheduling twice should reuse the active daily job.'
      );
      Test.stopTest();
    }
  }

  @isTest
  static void shouldRejectSchedule_WhenCapabilityIsMissing() {
    PromptContextAccess.setConfigureForTest(false);
    Test.startTest();
    try {
      PromptTemplateHealthSchedulable.scheduleDaily();
      Assert.fail('Only configurators may schedule template health.');
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
