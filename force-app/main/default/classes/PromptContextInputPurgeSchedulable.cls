/**
 * Starts the nightly Prompt Input Log purge. It names no other package class: Salesforce refuses
 * to deploy any class a pending scheduled job depends on, so the worker is found by name, and the
 * worker authorizes itself. Schedule it with PromptContextSchedules.scheduleInputPurgeDaily().
 */
public with sharing class PromptContextInputPurgeSchedulable implements Schedulable {
  /** Enqueues the purge worker. @param context Scheduled Apex details */
  public void execute(SchedulableContext context) {
    System.enqueueJob(
      (Queueable) Type.forName('PromptContextInputPurgeQueueable').newInstance()
    );
  }
}
