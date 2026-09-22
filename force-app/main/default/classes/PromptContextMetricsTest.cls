/** Tests privacy-safe operational metric validation and publication. */
@isTest
private class PromptContextMetricsTest {
  @isTest
  static void shouldPublish_WhenSignalContainsOnlyAllowlistedMetadata() {
    PromptContextMetrics.Signal signal = validSignal();

    Test.startTest();
    Integer accepted = PromptContextMetrics.publishAll(
      new List<PromptContextMetrics.Signal>{ signal }
    );
    Test.stopTest();

    Assert.areEqual(1, accepted, 'One valid metric should be accepted.');
  }

  @isTest
  static void shouldSkip_WhenOutcomeCouldContainFreeFormContent() {
    PromptContextMetrics.Signal signal = validSignal();
    signal.outcomeCode = 'Prompt value: secret';

    Test.startTest();
    Boolean accepted = PromptContextMetrics.publishOne(signal);
    Test.stopTest();

    Assert.isFalse(accepted, 'Free-form outcome content must be rejected.');
  }

  @isTest
  static void shouldRejectBatch_WhenMoreThanContractLimit() {
    List<PromptContextMetrics.Signal> signals = new List<PromptContextMetrics.Signal>();
    for (Integer index = 0; index < 201; index++) {
      signals.add(validSignal());
    }

    Test.startTest();
    Integer accepted = PromptContextMetrics.publishAll(signals);
    Test.stopTest();

    Assert.areEqual(0, accepted, 'Oversized metric batches must fail closed.');
  }

  private static PromptContextMetrics.Signal validSignal() {
    PromptContextMetrics.Signal signal = new PromptContextMetrics.Signal();
    signal.channel = 'APEX';
    signal.outcomeCode = PromptContextReasonCodes.SUCCESS;
    signal.startedAtMilliseconds = Datetime.now().getTime();
    signal.templateId = UserInfo.getUserId();
    signal.templateVersion = 1;
    signal.correlationId = PromptContextTrace.newCorrelationId();
    return signal;
  }
}
