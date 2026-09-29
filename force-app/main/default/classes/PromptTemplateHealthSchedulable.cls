/** Schedules setup checks for fixed published prompt template versions. */
public with sharing class PromptTemplateHealthSchedulable implements Schedulable {
  public static final String CRON_DAILY_2AM = '0 0 2 * * ?';
  private static final String JOB_NAME = 'Prompt Template Health - Daily 2AM';

  /** Starts the limited setup-check worker. @param context Scheduled Apex details */
  public void execute(SchedulableContext context) {
    PromptContextAccess.requireConfigure();
    System.enqueueJob(new PromptTemplateHealthQueueable());
  }

  /**
   * Schedules daily health validation at 2:00 AM in the scheduling user's time zone.
   * @return Scheduled job Id
   */
  public static String scheduleDaily() {
    PromptContextAccess.requireConfigure();
    List<CronTrigger> existingJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE
        CronJobDetail.Name = :JOB_NAME
        AND State IN ('WAITING', 'ACQUIRED', 'PAUSED', 'BLOCKED')
      WITH USER_MODE
      LIMIT 1
    ];
    if (!existingJobs.isEmpty()) {
      return String.valueOf(existingJobs[0].Id);
    }
    return String.valueOf(
      Id.valueOf(
        System.schedule(
          JOB_NAME,
          CRON_DAILY_2AM,
          new PromptTemplateHealthSchedulable()
        )
      )
    );
  }
}
