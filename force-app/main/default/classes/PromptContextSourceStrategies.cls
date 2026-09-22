/** Built-in behavior for related and reference data, selected from a fixed list. */
public with sharing class PromptContextSourceStrategies {
  private static final Map<String, PromptContextSourceStrategy> STRATEGIES = new Map<String, PromptContextSourceStrategy>{
    'RELATED' => new RelatedStrategy(),
    'REFERENCE' => new ReferenceStrategy()
  };

  public static PromptContextSourceStrategy forMode(String sourceMode) {
    PromptContextSourceStrategy strategy = STRATEGIES.get(sourceMode);
    if (strategy == null) {
      throw new PromptContextException(
        'This data set uses an unsupported record selection: ' +
          sourceMode +
          '.'
      );
    }
    return strategy;
  }

  private class RelatedStrategy implements PromptContextSourceStrategy {
    public Boolean requiresCorrelation() {
      return true;
    }
    public Object getCorrelationValue(
      PromptContextDTO.SourceConfig source,
      SObject rootRecord
    ) {
      return getPathValue(rootRecord, source.rootField);
    }
  }

  private class ReferenceStrategy implements PromptContextSourceStrategy {
    public Boolean requiresCorrelation() {
      return false;
    }
    public Object getCorrelationValue(
      PromptContextDTO.SourceConfig source,
      SObject rootRecord
    ) {
      return null;
    }
  }

  private static Object getPathValue(SObject record, String fieldPath) {
    List<String> segments = fieldPath.split('\\.');
    SObject currentRecord = record;
    for (Integer index = 0; index < segments.size() - 1; index++) {
      currentRecord = currentRecord.getSObject(segments[index]);
      if (currentRecord == null) {
        return null;
      }
    }
    return currentRecord.get(segments[segments.size() - 1]);
  }

  private PromptContextSourceStrategies() {
  }
}
