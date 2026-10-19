/**
 * Reads Prompt Context Builder settings and Salesforce records with the running user's access.
 */
public inherited sharing class PromptContextSelector {
  /** Returns a limited Id-ordered page of published templates for scheduled setup checks. */
  public static List<Prompt_Template__c> selectPublishedTemplatePage(
    Id afterId,
    Integer requestedLimit
  ) {
    Integer queryLimit = Math.max(1, Math.min(requestedLimit ?? 15, 15));
    if (afterId == null) {
      return [
        SELECT Id
        FROM Prompt_Template__c
        WHERE Status__c = 'Published'
        WITH USER_MODE
        ORDER BY Id
        LIMIT :queryLimit
      ];
    }
    return [
      SELECT Id
      FROM Prompt_Template__c
      WHERE Status__c = 'Published' AND Id > :afterId
      WITH USER_MODE
      ORDER BY Id
      LIMIT :queryLimit
    ];
  }

  /** Returns one deterministic keyset page plus one overflow row. */
  public static List<Prompt_Template__c> selectTemplateSummaryPage(
    String searchText,
    Integer requestedLimit,
    String afterName,
    Id afterId
  ) {
    Integer pageSize = Math.max(
      1,
      Math.min(
        requestedLimit ?? PromptContextContract.DEFAULT_TEMPLATE_PAGE_SIZE,
        PromptContextContract.MAX_TEMPLATE_PAGE_SIZE
      )
    );
    Integer queryLimit = pageSize + 1;
    String normalizedSearch = String.isBlank(searchText)
      ? null
      : '%' + escapeLikeValue(searchText.trim()) + '%';
    Boolean hasCursor = !String.isBlank(afterName) && afterId != null;
    if (normalizedSearch == null && !hasCursor) {
      return [
        SELECT
          Id,
          Name,
          Developer_Key__c,
          Description__c,
          Root_Object__c,
          Status__c,
          Version__c,
          Published_At__c,
          Last_Health_Status__c,
          Last_Health_Checked_At__c
        FROM Prompt_Template__c
        WITH USER_MODE
        ORDER BY Name, Id
        LIMIT :queryLimit
      ];
    }
    if (normalizedSearch == null) {
      return [
        SELECT
          Id,
          Name,
          Developer_Key__c,
          Description__c,
          Root_Object__c,
          Status__c,
          Version__c,
          Published_At__c,
          Last_Health_Status__c,
          Last_Health_Checked_At__c
        FROM Prompt_Template__c
        WHERE Name > :afterName OR (Name = :afterName AND Id > :afterId)
        WITH USER_MODE
        ORDER BY Name, Id
        LIMIT :queryLimit
      ];
    }
    if (!hasCursor) {
      return [
        SELECT
          Id,
          Name,
          Developer_Key__c,
          Description__c,
          Root_Object__c,
          Status__c,
          Version__c,
          Published_At__c,
          Last_Health_Status__c,
          Last_Health_Checked_At__c
        FROM Prompt_Template__c
        WHERE Name LIKE :normalizedSearch
        WITH USER_MODE
        ORDER BY Name, Id
        LIMIT :queryLimit
      ];
    }
    return [
      SELECT
        Id,
        Name,
        Developer_Key__c,
        Description__c,
        Root_Object__c,
        Status__c,
        Version__c,
        Published_At__c,
        Last_Health_Status__c,
        Last_Health_Checked_At__c
      FROM Prompt_Template__c
      WHERE
        Name LIKE :normalizedSearch
        AND (Name > :afterName
        OR (Name = :afterName
        AND Id > :afterId))
      WITH USER_MODE
      ORDER BY Name, Id
      LIMIT :queryLimit
    ];
  }

  private static String escapeLikeValue(String value) {
    return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
  }

  /**
   * Returns one visible template.
   * @param templateId Template record Id
   * @return Template or null when unavailable
   */
  public static Prompt_Template__c selectTemplateById(Id templateId) {
    if (templateId == null) {
      return null;
    }
    List<Prompt_Template__c> templates = [
      SELECT
        Id,
        Name,
        Developer_Key__c,
        Description__c,
        Root_Object__c,
        Template_Body__c,
        Status__c,
        Version__c,
        Fingerprint__c,
        Published_At__c,
        Last_Health_Status__c,
        Last_Health_Checked_At__c,
        Last_Health_Codes__c,
        Last_Health_Version__c,
        File_Input_Mode__c,
        Maximum_Files__c,
        Require_File__c,
        Allowed_File_Formats__c,
        Provider_Profile_Key__c,
        File_Citations_Enabled__c,
        Draft_Revision__c
      FROM Prompt_Template__c
      WHERE Id = :templateId
      WITH USER_MODE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0];
  }

  /** Locks one template row while its draft is saved, so concurrent saves run one at a time. */
  public static Prompt_Template__c selectTemplateForDraftSave(Id templateId) {
    List<Prompt_Template__c> templates = [
      SELECT Id, Status__c, Draft_Revision__c
      FROM Prompt_Template__c
      WHERE Id = :templateId
      WITH USER_MODE
      LIMIT 1
      FOR UPDATE
    ];
    return templates.isEmpty() ? null : templates[0];
  }

  /** Finds stable automation keys in one access-aware Salesforce query. */
  public static Map<String, Prompt_Template__c> selectTemplatesByDeveloperKeys(
    Set<String> developerKeys
  ) {
    Map<String, Prompt_Template__c> byKey = new Map<String, Prompt_Template__c>();
    if (developerKeys == null || developerKeys.isEmpty()) {
      return byKey;
    }
    for (Prompt_Template__c templateRecord : [
      SELECT
        Id,
        Name,
        Developer_Key__c,
        Description__c,
        Root_Object__c,
        Template_Body__c,
        Status__c,
        Version__c,
        Fingerprint__c,
        Published_At__c,
        Last_Health_Status__c,
        Last_Health_Checked_At__c,
        Last_Health_Codes__c,
        Last_Health_Version__c,
        File_Input_Mode__c,
        Maximum_Files__c,
        Require_File__c,
        Allowed_File_Formats__c,
        Provider_Profile_Key__c,
        File_Citations_Enabled__c
      FROM Prompt_Template__c
      WHERE Developer_Key__c IN :developerKeys
      WITH USER_MODE
      LIMIT 200
    ]) {
      byKey.put(templateRecord.Developer_Key__c.toLowerCase(), templateRecord);
    }
    return byKey;
  }

  /**
   * Returns published templates for the current record's Salesforce object.
   * @param rootObject Salesforce object API name for the current record
   * @return Published templates ordered by name
   */
  public static List<Prompt_Template__c> selectPublishedTemplates(
    String rootObject
  ) {
    if (String.isBlank(rootObject)) {
      return new List<Prompt_Template__c>();
    }
    return [
      SELECT
        Id,
        Name,
        Description__c,
        Version__c,
        File_Input_Mode__c,
        Maximum_Files__c,
        Require_File__c,
        Allowed_File_Formats__c,
        Provider_Profile_Key__c
      FROM Prompt_Template__c
      WHERE Root_Object__c = :rootObject AND Status__c = 'Published'
      WITH USER_MODE
      ORDER BY Name
      LIMIT 200
    ];
  }

  /**
   * Returns context sources owned by a template.
   * @param templateId Parent template Id
   * @return Sources in configured sequence
   */
  public static List<Prompt_Context_Source__c> selectSourcesByTemplate(
    Id templateId
  ) {
    if (templateId == null) {
      return new List<Prompt_Context_Source__c>();
    }
    return selectSourcesByTemplates(new Set<Id>{ templateId });
  }

  /**
   * Returns context sources owned by any supplied template.
   * @param templateIds Parent template Ids
   * @return Sources in configured sequence
   */
  public static List<Prompt_Context_Source__c> selectSourcesByTemplates(
    Set<Id> templateIds
  ) {
    if (templateIds == null || templateIds.isEmpty()) {
      return new List<Prompt_Context_Source__c>();
    }
    return [
      SELECT
        Id,
        Prompt_Template__c,
        Reference_Name__c,
        Source_Mode__c,
        Result_Mode__c,
        Aggregate_Operation__c,
        Aggregate_Field__c,
        Related_Object__c,
        Correlation_Field__c,
        Root_Field__c,
        Selected_Fields__c,
        Filters_JSON__c,
        Filter_Group_Join__c,
        Filter_Logic__c,
        Sort_JSON__c,
        Max_Rows__c,
        Sequence__c,
        Active__c
      FROM Prompt_Context_Source__c
      WHERE Prompt_Template__c IN :templateIds
      WITH USER_MODE
      ORDER BY Sequence__c, Reference_Name__c
      LIMIT 200
    ];
  }

  /**
   * Runs a fully schema-allowlisted query with bind variables and user-mode security.
   * @param soql Query assembled only from validated identifiers and fixed keywords
   * @param binds Query bind values
   * @return Records visible to the current user
   */
  public static List<SObject> selectDynamic(
    String soql,
    Map<String, Object> binds
  ) {
    if (String.isBlank(soql)) {
      throw new PromptContextException('A record request is required.');
    }
    try {
      return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    } catch (QueryException exceptionValue) {
      // Some objects require special filters, and very large objects require selective filters.
      // Report a named reason instead of a raw platform error.
      throw PromptContextException.withReason(
        PromptContextReasonCodes.QUERY_NOT_SUPPORTED,
        'Salesforce refused a data set query. Some objects need special filters, and very large ' +
          'objects need more selective filters. Preview the template to find the data set, then ' +
          'add a filter or choose another object.'
      );
    }
  }

  /** Returns the exact fixed publication selected by a template header. */
  public static Prompt_Template_Version__c selectPublishedVersion(
    Id templateId,
    Integer versionNumber
  ) {
    if (templateId == null || versionNumber == null) {
      return null;
    }
    List<Prompt_Template_Version__c> versions = [
      SELECT
        Id,
        Prompt_Template__c,
        Version_Key__c,
        Version_Number__c,
        Syntax_Version__c,
        Contract_Version__c,
        Root_Object__c,
        Template_Body__c,
        Fingerprint__c,
        Published_At__c,
        File_Input_Mode__c,
        Maximum_Files__c,
        Require_File__c,
        Allowed_File_Formats__c,
        Provider_Profile_Key__c,
        File_Citations_Enabled__c
      FROM Prompt_Template_Version__c
      WHERE
        Prompt_Template__c = :templateId
        AND Version_Number__c = :versionNumber
      WITH USER_MODE
      LIMIT 2
    ];
    if (versions.size() > 1) {
      throw PromptContextException.withReason(
        PromptContextReasonCodes.TEMPLATE_VERSION_AMBIGUOUS,
        'The published template version is ambiguous. Contact your Salesforce administrator.'
      );
    }
    return versions.isEmpty() ? null : versions[0];
  }

  /** Returns every fixed publication for a template, newest first. */
  public static List<Prompt_Template_Version__c> selectPublishedVersions(
    Id templateId
  ) {
    if (templateId == null) {
      return new List<Prompt_Template_Version__c>();
    }
    return [
      SELECT
        Id,
        Prompt_Template__c,
        Version_Key__c,
        Version_Number__c,
        Syntax_Version__c,
        Contract_Version__c,
        Root_Object__c,
        Template_Body__c,
        Fingerprint__c,
        Published_At__c,
        File_Input_Mode__c,
        Maximum_Files__c,
        Require_File__c,
        Allowed_File_Formats__c,
        Provider_Profile_Key__c,
        File_Citations_Enabled__c
      FROM Prompt_Template_Version__c
      WHERE Prompt_Template__c = :templateId
      WITH USER_MODE
      ORDER BY Version_Number__c DESC
      LIMIT 200
    ];
  }

  /** Returns fixed data set versions in a consistent processing order. */
  public static List<Prompt_Context_Source_Version__c> selectPublishedSources(
    Id templateVersionId
  ) {
    if (templateVersionId == null) {
      return new List<Prompt_Context_Source_Version__c>();
    }
    return [
      SELECT
        Id,
        Prompt_Template_Version__c,
        Reference_Name__c,
        Source_Mode__c,
        Result_Mode__c,
        Aggregate_Operation__c,
        Aggregate_Field__c,
        Related_Object__c,
        Correlation_Field__c,
        Root_Field__c,
        Selected_Fields__c,
        Filters_JSON__c,
        Filter_Group_Join__c,
        Filter_Logic__c,
        Sort_JSON__c,
        Max_Rows__c,
        Sequence__c,
        Active__c
      FROM Prompt_Context_Source_Version__c
      WHERE Prompt_Template_Version__c = :templateVersionId
      WITH USER_MODE
      ORDER BY Sequence__c, Reference_Name__c
      LIMIT 200
    ];
  }
}
