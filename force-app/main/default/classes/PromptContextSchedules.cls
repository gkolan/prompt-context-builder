/**
 * Registers the package's nightly jobs once. Each schedule runs as the user who registers it, with
 * that user's access. Scheduled classes name no other package class, so a pending job never blocks
 * deploying the rest of the package.
 */
public with sharing class PromptContextSchedules {
  public static final String HEALTH_JOB_NAME = 'Prompt Template Health - Daily 2AM';
  public static final String HEALTH_CRON = '0 0 2 * * ?';
  public static final String PURGE_JOB_NAME = 'Prompt Input Log Purge - Daily 3AM';
  public static final String PURGE_CRON = '0 0 3 * * ?';

  /**
   * Schedules the template health check at 2:00 AM in the scheduling user's time zone.
   * @return Existing or new scheduled job Id
   */
  public static String scheduleHealthCheckDaily() {
    PromptContextAccess.requireConfigure();
    return scheduleOnce(
      HEALTH_JOB_NAME,
      HEALTH_CRON,
      'PromptTemplateHealthSchedulable'
    );
  }

  /**
   * Schedules the Prompt Input Log purge at 3:00 AM in the scheduling user's time zone.
   * @return Existing or new scheduled job Id
   */
  public static String scheduleInputPurgeDaily() {
    PromptContextAccess.requireProcessInput();
    return scheduleOnce(
      PURGE_JOB_NAME,
      PURGE_CRON,
      'PromptContextInputPurgeSchedulable'
    );
  }

  private static String scheduleOnce(
    String jobName,
    String cronExpression,
    String schedulableClassName
  ) {
    List<CronTrigger> existingJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE
        CronJobDetail.Name = :jobName
        AND State IN ('WAITING', 'ACQUIRED', 'PAUSED', 'BLOCKED')
      WITH USER_MODE
      LIMIT 1
    ];
    if (!existingJobs.isEmpty()) {
      return String.valueOf(existingJobs[0].Id);
    }
    // Normalize to the 18-character form the reuse path returns.
    return String.valueOf(
      Id.valueOf(
        System.schedule(
          jobName,
          cronExpression,
          (Schedulable) Type.forName(schedulableClassName).newInstance()
        )
      )
    );
  }

  private PromptContextSchedules() {
  }
}
