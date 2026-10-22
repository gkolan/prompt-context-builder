/**
 * Tests PromptContextSchedules registration, permission checks, and by-name worker start for the
 * nightly jobs. The class keeps its original name so existing orgs have no stale test class.
 */
@isTest
private class PromptTemplateHealthSchedulableTest {
  @TestSetup
  static void setupTestUser() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextTestDataFactory.assignPermissionSets(
        new Set<String>{ 'Prompt_Context_Process_Input' }
      );
    }
  }

  @isTest
  static void shouldRegisterEachDailyJobOnce() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      // Registration is under test here; shouldRejectEachScheduleWithoutItsPermission covers access,
      // and the worker tests cover running each job. No Test.stopTest, so the jobs stay scheduled
      // instead of running in a context that cannot see permission sets granted inside the test.
      PromptContextAccess.setProcessInputForTest(true);
      String healthId = PromptContextSchedules.scheduleHealthCheckDaily();
      String repeatedHealthId = PromptContextSchedules.scheduleHealthCheckDaily();
      String purgeId = PromptContextSchedules.scheduleInputPurgeDaily();
      String repeatedPurgeId = PromptContextSchedules.scheduleInputPurgeDaily();

      Map<Id, CronTrigger> jobs = new Map<Id, CronTrigger>(
        [
          SELECT Id, CronExpression, State
          FROM CronTrigger
          WHERE Id IN :new List<Id>{ healthId, purgeId }
        ]
      );
      Assert.areEqual(
        PromptContextSchedules.HEALTH_CRON,
        jobs.get(healthId).CronExpression
      );
      Assert.areEqual(
        PromptContextSchedules.PURGE_CRON,
        jobs.get(purgeId).CronExpression
      );
      Assert.areEqual('WAITING', jobs.get(healthId).State);
      Assert.areEqual(healthId, repeatedHealthId, 'Reuse the active job.');
      Assert.areEqual(purgeId, repeatedPurgeId, 'Reuse the active job.');
    }
  }

  @isTest
  static void shouldRejectEachScheduleWithoutItsPermission() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextAccess.setConfigureForTest(false);
      PromptContextAccess.setProcessInputForTest(false);
      List<String> refused = new List<String>();
      try {
        PromptContextSchedules.scheduleHealthCheckDaily();
      } catch (PromptContextAccess.AuthorizationException expected) {
        refused.add(expected.reasonCode);
      }
      try {
        PromptContextSchedules.scheduleInputPurgeDaily();
      } catch (PromptContextAccess.AuthorizationException expected) {
        refused.add(expected.reasonCode);
      }

      Assert.areEqual(
        new List<String>{
          PromptContextReasonCodes.NOT_AUTHORIZED,
          PromptContextReasonCodes.NOT_AUTHORIZED
        },
        refused
      );
    }
  }

  @isTest
  static void shouldStartEachWorkerByName() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Test.startTest();
      new PromptTemplateHealthSchedulable().execute(null);
      new PromptContextInputPurgeSchedulable().execute(null);
      Test.stopTest();

      // A misspelled worker name would fail in Type.forName before any job was queued.
      Assert.areEqual(
        2,
        [
          SELECT COUNT()
          FROM AsyncApexJob
          WHERE
            JobType = 'Queueable'
            AND ApexClass.Name IN (
              'PromptTemplateHealthQueueable',
              'PromptContextInputPurgeQueueable'
            )
        ]
      );
    }
  }
}
