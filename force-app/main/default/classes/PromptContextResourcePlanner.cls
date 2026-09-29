/** Calculates safe Salesforce transaction capacity before reading business records. */
public with sharing class PromptContextResourcePlanner {
  public class Plan {
    public Integer groupedQueryCount { get; private set; }
    public Integer plannedRowsPerRecord { get; private set; }
    public Integer safeRecordCount { get; private set; }

    private Plan(
      Integer groupedQueryCount,
      Integer plannedRowsPerRecord,
      Integer safeRecordCount
    ) {
      this.groupedQueryCount = groupedQueryCount;
      this.plannedRowsPerRecord = plannedRowsPerRecord;
      this.safeRecordCount = safeRecordCount;
    }
  }

  public static Plan plan(PromptContextDTO.TemplateConfig config) {
    Integer activeSources = 0;
    Integer aggregateSources = 0;
    Integer rows = 1;
    Integer fileQueriesPerRecord = 0;
    Integer fileRowsPerRecord = 0;
    if (config.fileInputMode == 'USER_SELECT') {
      fileQueriesPerRecord = 2;
      fileRowsPerRecord = 2 * PromptContextContract.MAX_SELECTED_FILES;
    } else if (config.fileInputMode == 'ALL_ELIGIBLE') {
      fileQueriesPerRecord = 2;
      fileRowsPerRecord =
        (2 * PromptContextContract.MAX_LINKED_FILES_INSPECTED) + 1;
    }
    for (
      PromptContextDTO.SourceConfig source : config.sources ??
        new List<PromptContextDTO.SourceConfig>()
    ) {
      if (source != null && source.active != false) {
        activeSources++;
        if (source.resultMode == 'AGGREGATE') {
          aggregateSources++;
          rows++;
        } else {
          rows +=
            Math.min(
              source.maxRows ?? 10,
              PromptContextContract.MAX_ROWS_PER_SOURCE
            ) + 1;
        }
      }
    }
    Integer groupedQueries = 1 + activeSources + aggregateSources;
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
    Integer byQueries = 0;
    if (availableQueries >= groupedQueries) {
      byQueries = fileQueriesPerRecord == 0
        ? PromptContextContract.MAX_RECORDS_PER_REQUEST
        : (availableQueries - groupedQueries) / fileQueriesPerRecord;
    }
    Integer fixedAggregateRows =
      aggregateSources * (PromptContextContract.MAX_AGGREGATE_INPUT_ROWS + 1);
    Integer rowsPerRecord = rows + fileRowsPerRecord;
    Integer byRows =
      Math.max(0, availableRows - fixedAggregateRows) / rowsPerRecord;
    return new Plan(
      groupedQueries,
      rowsPerRecord,
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
