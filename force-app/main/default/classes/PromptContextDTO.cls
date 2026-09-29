/**
 * Transport types shared by the Prompt Context Builder controller, services, and Lightning components.
 */
public with sharing class PromptContextDTO {
  /** A selectable object or field option. */
  public class Option implements Comparable {
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String value { get; set; }
    @AuraEnabled
    public String dataType { get; set; }

    /** Creates an empty option for JSON serialization. */
    public Option() {
    }

    /**
     * @param label Display label
     * @param value API value
     * @param dataType Optional Salesforce field type
     */
    public Option(String label, String value, String dataType) {
      this.label = label;
      this.value = value;
      this.dataType = dataType;
    }

    /**
     * Sorts options by their display label.
     * @param compareTo Option being compared
     * @return Negative, zero, or positive sort result
     */
    public Integer compareTo(Object compareTo) {
      Option other = (Option) compareTo;
      return label.toLowerCase().compareTo(other.label.toLowerCase());
    }
  }

  /** One structured filter compiled to bind-variable SOQL. */
  public class FilterRule {
    @AuraEnabled
    public String fieldName { get; set; }
    @AuraEnabled
    public String operator { get; set; }
    @AuraEnabled
    public String value { get; set; }
    @AuraEnabled
    public String groupName { get; set; }
  }

  /** One deterministic sort rule. */
  public class SortRule {
    @AuraEnabled
    public String fieldName { get; set; }
    @AuraEnabled
    public String direction { get; set; }
    @AuraEnabled
    public String nullsOrder { get; set; }
  }

  /** Related-record source configuration. */
  public class SourceConfig implements Comparable {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String referenceName { get; set; }
    @AuraEnabled
    public String sourceMode { get; set; }
    @AuraEnabled
    public String resultMode { get; set; }
    @AuraEnabled
    public String aggregateOperation { get; set; }
    @AuraEnabled
    public String aggregateField { get; set; }
    @AuraEnabled
    public String relatedObject { get; set; }
    @AuraEnabled
    public String correlationField { get; set; }
    @AuraEnabled
    public String rootField { get; set; }
    @AuraEnabled
    public List<String> selectedFields { get; set; }
    @AuraEnabled
    public List<FilterRule> filters { get; set; }
    @AuraEnabled
    public String filterGroupJoin { get; set; }
    @AuraEnabled
    public List<SortRule> sorts { get; set; }
    @AuraEnabled
    public Integer maxRows { get; set; }
    @AuraEnabled
    public Integer sequence { get; set; }
    @AuraEnabled
    public Boolean active { get; set; }

    /** Creates a source with safe, understandable defaults. */
    public SourceConfig() {
      selectedFields = new List<String>();
      filters = new List<FilterRule>();
      filterGroupJoin = 'AND';
      sorts = new List<SortRule>();
      rootField = 'Id';
      sourceMode = 'RELATED';
      resultMode = 'RECORDS';
      maxRows = 10;
      sequence = 1;
      active = true;
    }

    /**
     * Sorts sources deterministically by sequence and then reference name.
     * @param compareTo Source being compared
     * @return Negative, zero, or positive sort result
     */
    public Integer compareTo(Object compareTo) {
      SourceConfig other = (SourceConfig) compareTo;
      Integer thisSequence = sequence ?? 1;
      Integer otherSequence = other.sequence ?? 1;
      if (thisSequence != otherSequence) {
        return thisSequence < otherSequence ? -1 : 1;
      }
      return (referenceName ?? '')
        .toLowerCase()
        .compareTo((other.referenceName ?? '').toLowerCase());
    }
  }

  /** Complete editable template configuration. */
  public class TemplateConfig {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public Id publishedVersionId { get; set; }
    @AuraEnabled
    public String developerKey { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String rootObject { get; set; }
    @AuraEnabled
    public String templateBody { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Integer version { get; set; }
    @AuraEnabled
    public Integer syntaxVersion { get; set; }
    @AuraEnabled
    public String contractVersion { get; set; }
    @AuraEnabled
    public String fingerprint { get; set; }
    @AuraEnabled
    public Datetime publishedAt { get; set; }
    @AuraEnabled
    public String lastHealthStatus { get; set; }
    @AuraEnabled
    public Datetime lastHealthCheckedAt { get; set; }
    @AuraEnabled
    public String lastHealthCodes { get; set; }
    @AuraEnabled
    public Integer lastHealthVersion { get; set; }
    @AuraEnabled
    public String fileInputMode { get; set; }
    @AuraEnabled
    public Integer maxFiles { get; set; }
    @AuraEnabled
    public Boolean requireAtLeastOneFile { get; set; }
    @AuraEnabled
    public String allowedFileFormats { get; set; }
    @AuraEnabled
    public String providerProfileKey { get; set; }
    @AuraEnabled
    public Boolean fileCitationsEnabled { get; set; }
    @AuraEnabled
    public List<SourceConfig> sources { get; set; }

    /** Creates a draft template with an empty source list. */
    public TemplateConfig() {
      sources = new List<SourceConfig>();
      status = 'Draft';
      version = 0;
      syntaxVersion = PromptContextContract.SYNTAX_VERSION;
      contractVersion = PromptContextContract.CONTRACT_VERSION;
      fileInputMode = 'DISABLED';
      requireAtLeastOneFile = false;
      fileCitationsEnabled = false;
    }
  }

  /** One actionable validation or generation message. */
  public class Message {
    @AuraEnabled
    public String severity { get; set; }
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String location { get; set; }
    @AuraEnabled
    public String text { get; set; }

    /** Creates an empty message for JSON serialization. */
    public Message() {
    }

    /**
     * @param severity ERROR or WARNING
     * @param code Stable machine-readable code
     * @param location Template or source location
     * @param text Junior-admin-friendly explanation
     */
    public Message(String severity, String code, String location, String text) {
      this.severity = severity;
      this.code = code;
      this.location = location;
      this.text = text;
    }
  }

  /** Validation result returned before preview or publish. */
  public class ValidationResult {
    @AuraEnabled
    public Boolean isValid { get; set; }
    @AuraEnabled
    public List<Message> messages { get; set; }

    /** Creates an initially valid result. */
    public ValidationResult() {
      isValid = true;
      messages = new List<Message>();
    }

    /**
     * Adds an error and marks the result invalid.
     * @param code Stable error code
     * @param location Configuration location
     * @param text Actionable explanation
     */
    public void addError(String code, String location, String text) {
      isValid = false;
      messages.add(new Message('ERROR', code, location, text));
    }

    /**
     * Adds a non-blocking warning.
     * @param code Stable warning code
     * @param location Configuration location
     * @param text Actionable explanation
     */
    public void addWarning(String code, String location, String text) {
      messages.add(new Message('WARNING', code, location, text));
    }
  }

  /** Generated prompt and safe provenance details. */
  public class PromptResult {
    @AuraEnabled
    public String prompt { get; set; }
    @AuraEnabled
    public String contractVersion { get; set; }
    @AuraEnabled
    public Integer syntaxVersion { get; set; }
    @AuraEnabled
    public String fingerprint { get; set; }
    @AuraEnabled
    public Integer templateVersion { get; set; }
    @AuraEnabled
    public Map<String, Integer> sourceRecordCounts { get; set; }
    @AuraEnabled
    public List<Message> messages { get; set; }
    @AuraEnabled
    public AccessManifest accessManifest { get; set; }
    @AuraEnabled
    public String selectedFilesJson { get; set; }

    /** Creates an empty result that contains no partial prompt. */
    public PromptResult() {
      sourceRecordCounts = new Map<String, Integer>();
      messages = new List<Message>();
    }
  }

  /** Lightweight template choice for the record-page generator. */
  public class TemplateSummary {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String developerKey { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String rootObject { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Integer version { get; set; }
    @AuraEnabled
    public Datetime publishedAt { get; set; }
    @AuraEnabled
    public String lastHealthStatus { get; set; }
    @AuraEnabled
    public Datetime lastHealthCheckedAt { get; set; }
  }

  /** One keyset-paginated page of lightweight template choices. */
  public class TemplateSummaryPage {
    @AuraEnabled
    public List<TemplateSummary> items { get; set; }
    @AuraEnabled
    public Boolean hasMore { get; set; }
    @AuraEnabled
    public String nextName { get; set; }
    @AuraEnabled
    public Id nextId { get; set; }

    /** Creates an empty page for safe serialization. */
    public TemplateSummaryPage() {
      items = new List<TemplateSummary>();
      hasMore = false;
    }
  }

  /** Lightweight template choice for the record-page generator. */
  public class TemplateChoice {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public Integer version { get; set; }
    @AuraEnabled
    public String fileInputMode { get; set; }
    @AuraEnabled
    public Integer maxFiles { get; set; }
    @AuraEnabled
    public Boolean requireAtLeastOneFile { get; set; }
    @AuraEnabled
    public String allowedFileFormats { get; set; }

    /** Creates an empty choice for JSON serialization. */
    public TemplateChoice() {
    }
  }

  /** One current Salesforce File choice shown on a record page. */
  public class FileChoice {
    @AuraEnabled
    public Id contentVersionId { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String fileFormat { get; set; }
    @AuraEnabled
    public Integer sizeInBytes { get; set; }
  }

  /** One limited page of current Salesforce Files. */
  public class FileChoicePage {
    @AuraEnabled
    public List<FileChoice> items { get; set; }
    @AuraEnabled
    public Boolean hasMore { get; set; }
    @AuraEnabled
    public String nextTitle { get; set; }
    @AuraEnabled
    public Id nextId { get; set; }

    public FileChoicePage() {
      items = new List<FileChoice>();
      hasMore = false;
    }
  }

  /** One field required by a template, including why it is used. */
  public class AccessManifestItem implements Comparable {
    @AuraEnabled
    public String objectApiName { get; set; }
    @AuraEnabled
    public String fieldPath { get; set; }
    @AuraEnabled
    public String sourceAlias { get; set; }
    @AuraEnabled
    public String usage { get; set; }
    @AuraEnabled
    public String dataType { get; set; }
    @AuraEnabled
    public String sensitivity { get; set; }

    /** Creates an empty required-field item for the response. */
    public AccessManifestItem() {
    }

    /** Sorts required fields by object, data set, field, and use. */
    public Integer compareTo(Object compareTo) {
      AccessManifestItem other = (AccessManifestItem) compareTo;
      String thisKey = String.join(
        new List<String>{
          objectApiName ?? '',
          sourceAlias ?? '',
          fieldPath ?? '',
          usage ?? ''
        },
        '|'
      );
      String otherKey = String.join(
        new List<String>{
          other.objectApiName ?? '',
          other.sourceAlias ?? '',
          other.fieldPath ?? '',
          other.usage ?? ''
        },
        '|'
      );
      return thisKey.toLowerCase().compareTo(otherKey.toLowerCase());
    }
  }

  /** Publish-time summary of every object and field the template requires. */
  public class AccessManifest {
    @AuraEnabled
    public List<AccessManifestItem> items { get; set; }
    @AuraEnabled
    public List<Message> warnings { get; set; }

    /** Creates an empty required-field list. */
    public AccessManifest() {
      items = new List<AccessManifestItem>();
      warnings = new List<Message>();
    }
  }

  /** Current setup-check result for one editable or published template. */
  public class TemplateHealth {
    @AuraEnabled
    public Boolean isValid { get; set; }
    @AuraEnabled
    public Datetime checkedAt { get; set; }
    @AuraEnabled
    public List<Message> messages { get; set; }
    @AuraEnabled
    public AccessManifest accessManifest { get; set; }

    /** Creates an empty health result. */
    public TemplateHealth() {
      isValid = false;
      checkedAt = System.now();
      messages = new List<Message>();
      accessManifest = new AccessManifest();
    }
  }

  /** Small fixed publication choice for the version list. */
  public class VersionSummary {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public Integer versionNumber { get; set; }
    @AuraEnabled
    public Datetime publishedAt { get; set; }
    @AuraEnabled
    public String fingerprint { get; set; }
  }

  /** Human-readable, limited comparison between two fixed published versions. */
  public class VersionComparison {
    @AuraEnabled
    public Integer fromVersion { get; set; }
    @AuraEnabled
    public Integer toVersion { get; set; }
    @AuraEnabled
    public List<String> changes { get; set; }

    /** Creates an empty version comparison. */
    public VersionComparison() {
      changes = new List<String>();
    }
  }
}
