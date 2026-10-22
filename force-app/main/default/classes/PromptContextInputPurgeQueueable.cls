/**
 * Deletes Prompt Input Logs past their Retain Until date, 200 at a time, until none remain. It
 * deletes only logs the running user can see and delete, so schedule it as a user whose sharing
 * covers every saved log.
 */
public with sharing class PromptContextInputPurgeQueueable implements Queueable {
  private static final Integer BATCH_SIZE = 200;

  /** Deletes one batch and continues while a full batch was found. @param context Queueable details */
  public void execute(QueueableContext context) {
    PromptContextAccess.requireProcessInput();
    if (PromptContextInputLifecycle.deleteExpired(BATCH_SIZE) == BATCH_SIZE) {
      System.enqueueJob(new PromptContextInputPurgeQueueable());
    }
  }
}
