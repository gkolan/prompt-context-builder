/**
 * Publishes limited, privacy-safe measurements without customer record or prompt content.
 */
public with sharing class PromptContextMetrics {
  private static final Integer MAX_SIGNALS = 200;
  private static final Pattern CODE_PATTERN = Pattern.compile(
    '^[A-Z][A-Z0-9_]{0,79}$'
  );
  private static final Set<String> CHANNELS = new Set<String>{
    'APEX',
    'FLOW',
    'LWC'
  };

  /** Value-free metric input used to publish several results in one event operation. */
  public class Signal {
    public String channel;
    public String outcomeCode;
    public Long startedAtMilliseconds;
    public Id templateId;
    public Integer templateVersion;
    public String correlationId;
  }

  /**
   * Publishes one signal when the caller can create the metric event.
   * @param signal Value-free execution metadata
   * @return True only when the event was accepted
   */
  public static Boolean publishOne(Signal signal) {
    return publishAll(new List<Signal>{ signal }) == 1;
  }

  /**
   * Publishes up to 200 value-free signals in one event operation.
   * Invalid signals are skipped, and metric failure never changes prompt behavior.
   * @param signals Value-free execution metadata
   * @return Number of events accepted by the event bus
   */
  public static Integer publishAll(List<Signal> signals) {
    if (
      signals == null ||
      signals.isEmpty() ||
      signals.size() > MAX_SIGNALS ||
      !Schema.sObjectType.Prompt_Context_Metric__e.isCreateable()
    ) {
      return 0;
    }
    Long nowMilliseconds = Datetime.now().getTime();
    List<Prompt_Context_Metric__e> events = new List<Prompt_Context_Metric__e>();
    for (Signal signal : signals) {
      if (!isValid(signal)) {
        continue;
      }
      Long duration = Math.max(
        0L,
        nowMilliseconds - signal.startedAtMilliseconds
      );
      events.add(
        new Prompt_Context_Metric__e(
          Channel__c = signal.channel,
          Outcome_Code__c = signal.outcomeCode,
          Duration_Milliseconds__c = duration,
          Template_Id__c = signal.templateId == null
            ? null
            : String.valueOf(signal.templateId),
          Template_Version__c = signal.templateVersion,
          Correlation_Id__c = signal.correlationId
        )
      );
    }
    if (events.isEmpty()) {
      return 0;
    }
    try {
      Integer accepted = 0;
      for (Database.SaveResult result : EventBus.publish(events)) {
        if (result.isSuccess()) {
          accepted++;
        }
      }
      return accepted;
    } catch (Exception ignoredMetricFailure) {
      return 0;
    }
  }

  private static Boolean isValid(Signal signal) {
    return signal != null &&
      CHANNELS.contains(signal.channel) &&
      !String.isBlank(signal.outcomeCode) &&
      CODE_PATTERN.matcher(signal.outcomeCode).matches() &&
      signal.startedAtMilliseconds != null &&
      signal.startedAtMilliseconds <= Datetime.now().getTime() &&
      !String.isBlank(signal.correlationId) &&
      signal.correlationId.length() <= 32;
  }

  private PromptContextMetrics() {
  }
}
