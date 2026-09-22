/** Extension contract for determining how a configured data set matches the current record. */
public interface PromptContextSourceStrategy {
  Boolean requiresCorrelation();
  Object getCorrelationValue(
    PromptContextDTO.SourceConfig source,
    SObject rootRecord
  );
}
