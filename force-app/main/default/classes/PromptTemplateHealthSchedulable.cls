/** Schedules setup checks for fixed published prompt template versions. */
public with sharing class PromptTemplateHealthSchedulable implements Schedulable {
  public static final String CRON_DAILY_2AM = '0 0 2 * * ?';

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
    return System.schedule(
      'Prompt Template Health - Daily 2AM',
      CRON_DAILY_2AM,
      new PromptTemplateHealthSchedulable()
    );
  }
}
