/** Tests conservative transaction admission for grouped data and per-record files. */
@isTest
private class PromptContextResourcePlannerTest {
  @isTest
  static void shouldReservePerRecordQueriesWhenFilesAreEnabled() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.fileInputMode = 'ALL_ELIGIBLE';

    PromptContextResourcePlanner.Plan plan = PromptContextResourcePlanner.plan(
      config
    );

    Integer availableQueries =
      Limits.getLimitQueries() -
      Limits.getQueries() -
      PromptContextContract.QUERY_HEADROOM;
    Assert.isTrue(
      plan.safeRecordCount <= (availableQueries - 1) / 2,
      'Each admitted record must reserve both linked-file queries.'
    );
    Assert.isTrue(
      plan.plannedRowsPerRecord >
      PromptContextContract.MAX_LINKED_FILES_INSPECTED,
      'All-eligible mode must reserve inspected link and version rows.'
    );
  }

  @isTest
  static void shouldKeepGroupedQueriesIndependentOfRecordCountWithoutFiles() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();

    PromptContextResourcePlanner.Plan plan = PromptContextResourcePlanner.plan(
      config
    );

    Assert.areEqual(3, plan.groupedQueryCount);
    Assert.isTrue(plan.safeRecordCount > 1);
  }

  @isTest
  static void shouldReserveCandidateAndCalculationQueriesForAggregate() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    config.sources.remove(1);
    config.sources[0].resultMode = 'AGGREGATE';

    PromptContextResourcePlanner.Plan plan = PromptContextResourcePlanner.plan(
      config
    );

    Assert.areEqual(
      3,
      plan.groupedQueryCount,
      'Root, bounded candidate, and calculation queries must all be reserved.'
    );
    Assert.areEqual(
      2,
      plan.plannedRowsPerRecord,
      'The root and grouped calculation result rows must be reserved per record.'
    );
  }
}
