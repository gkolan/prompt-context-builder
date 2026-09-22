/** Calculates safe Salesforce transaction capacity before reading business records. */
public with sharing class PromptContextResourcePlanner {
  public class Plan {
    public Integer queriesPerRecord { get; private set; }
    public Integer rowsPerRecord { get; private set; }
    public Integer safeRecordCount { get; private set; }

    private Plan(
      Integer queriesPerRecord,
      Integer rowsPerRecord,
      Integer safeRecordCount
    ) {
      this.queriesPerRecord = queriesPerRecord;
      this.rowsPerRecord = rowsPerRecord;
      this.safeRecordCount = safeRecordCount;
    }
  }

  public static Plan plan(PromptContextDTO.TemplateConfig config) {
    Integer activeSources = 0;
    Integer rows = 1;
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source != null && source.active != false) {
        activeSources++;
        rows += source.resultMode == 'AGGREGATE'
          ? 1
          : Math.min(
              source.maxRows ?? 10,
              PromptContextContract.MAX_ROWS_PER_SOURCE
            ) + 1;
      }
    }
    Integer queriesPerRecord = 1 + activeSources;
    Integer availableQueries = Math.max(
      0,
      Limits.getLimitQueries() -
        Limits.getQueries() -
        PromptContextContract.QUERY_HEADROOM
    );
    Integer availableRows = Math.max(
      0,
      Limits.getLimitQueryRows() -
        Limits.getQueryRows() -
        PromptContextContract.QUERY_ROW_HEADROOM
    );
    Integer byQueries = queriesPerRecord == 0
      ? PromptContextContract.MAX_RECORDS_PER_REQUEST
      : availableQueries / queriesPerRecord;
    Integer byRows = rows == 0
      ? PromptContextContract.MAX_RECORDS_PER_REQUEST
      : availableRows / rows;
    return new Plan(
      queriesPerRecord,
      rows,
      Math.max(
        0,
        Math.min(
          PromptContextContract.MAX_RECORDS_PER_REQUEST,
          Math.min(byQueries, byRows)
        )
      )
    );
  }

  private PromptContextResourcePlanner() {
  }
}
