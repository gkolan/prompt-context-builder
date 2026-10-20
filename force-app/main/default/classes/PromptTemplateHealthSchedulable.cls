/**
 * Starts the nightly template health check. It names no other package class: Salesforce refuses to
 * deploy any class a pending scheduled job depends on, so the worker is found by name, and the
 * worker authorizes itself. Schedule it with PromptContextSchedules.scheduleHealthCheckDaily().
 */
public with sharing class PromptTemplateHealthSchedulable implements Schedulable {
  /** Enqueues the health worker. @param context Scheduled Apex details */
  public void execute(SchedulableContext context) {
    System.enqueueJob(
      (Queueable) Type.forName('PromptTemplateHealthQueueable').newInstance()
    );
  }
}
