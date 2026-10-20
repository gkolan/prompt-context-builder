/**
 * Creates package-owned records and prompt configurations for isolated tests.
 */
@isTest
public with sharing class PromptContextTestDataFactory {
  /**
   * Reuses the running test user and grants configuration access without User DML.
   * @return Configurator test user
   */
  public static User createConfiguratorUser() {
    User testUser = new User(Id = UserInfo.getUserId());
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    Set<Id> assignedPermissionSetIds = new Set<Id>();
    for (PermissionSetAssignment existingAssignment : [
      SELECT PermissionSetId
      FROM PermissionSetAssignment
      WHERE
        AssigneeId = :testUser.Id
        AND PermissionSet.Name IN (
          'Prompt_Context_Configure',
          'Prompt_Context_Save_Input'
        )
    ]) {
      assignedPermissionSetIds.add(existingAssignment.PermissionSetId);
    }
    for (PermissionSet permissionSetRecord : [
      SELECT Id
      FROM PermissionSet
      WHERE Name IN ('Prompt_Context_Configure', 'Prompt_Context_Save_Input')
    ]) {
      if (!assignedPermissionSetIds.contains(permissionSetRecord.Id)) {
        assignments.add(
          new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = permissionSetRecord.Id
          )
        );
      }
    }
    if (!assignments.isEmpty()) {
      insert assignments;
    }
    return testUser;
  }

  /** Returns the running test user without creating an org-specific User record. */
  public static User createRestrictedGeneratorUser() {
    return new User(Id = UserInfo.getUserId());
  }

  /**
   * Creates one package-owned current record.
   * @param doInsert Whether to insert the record
   * @return Test current record
   */
  public static Prompt_Template__c createRootRecord(Boolean doInsert) {
    String uniqueValue =
      String.valueOf(DateTime.now().getTime()) +
      '-' +
      String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    Prompt_Template__c rootRecord = new Prompt_Template__c(
      Name = 'Acme Research',
      Developer_Key__c = 'test_root_' + uniqueValue,
      Root_Object__c = 'Prompt_Template__c',
      Template_Body__c = '{!record.Name}',
      Status__c = 'Draft',
      Version__c = 0,
      File_Input_Mode__c = 'DISABLED'
    );
    if (doInsert) {
      insert rootRecord;
    }
    return rootRecord;
  }

  /**
   * Returns the one package-owned current record created for the test. Fails instead of guessing
   * when a sibling root exists; keep that sibling's Id from createRootRecord instead.
   * @return the only record whose Developer_Key__c starts with test_root_
   */
  public static Prompt_Template__c selectRootRecord() {
    List<Prompt_Template__c> roots = [
      SELECT Id, Name
      FROM Prompt_Template__c
      WHERE Developer_Key__c LIKE 'test_root_%'
      WITH SYSTEM_MODE
      LIMIT 2
    ];
    Assert.areEqual(
      1,
      roots.size(),
      'selectRootRecord needs exactly one test_root_ record.'
    );
    return roots[0];
  }

  /** Creates package-owned roots without touching customer business objects. */
  public static List<Prompt_Template__c> createRootRecords(Integer count) {
    List<Prompt_Template__c> rootRecords = new List<Prompt_Template__c>();
    String uniqueValue =
      String.valueOf(DateTime.now().getTime()) +
      String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    for (Integer index = 0; index < count; index++) {
      rootRecords.add(
        new Prompt_Template__c(
          Name = 'Bulk prompt ' + index,
          Developer_Key__c = 'test_bulk_' + uniqueValue + '_' + index,
          Root_Object__c = 'Prompt_Template__c',
          Template_Body__c = '{!record.Name}',
          Status__c = 'Draft',
          Version__c = 0,
          File_Input_Mode__c = 'DISABLED'
        )
      );
    }
    insert rootRecords;
    return rootRecords;
  }

  /** Creates package-owned roots with caller-supplied match values. */
  public static List<Prompt_Template__c> createRootRecords(
    List<String> rootNames
  ) {
    List<Prompt_Template__c> rootRecords = createRootRecords(rootNames.size());
    for (Integer index = 0; index < rootRecords.size(); index++) {
      rootRecords[index].Name = rootNames[index];
    }
    update rootRecords;
    return rootRecords;
  }

  /** Returns a well-formed but absent package-owned root Id. */
  public static Id missingRootRecordId() {
    return Id.valueOf(
      Prompt_Template__c.SObjectType.getDescribe(
          SObjectDescribeOptions.DEFERRED
        )
        .getKeyPrefix() + '000000000001'
    );
  }

  /**
   * Creates three package-owned related records for one root.
   * @param rootRecordId Parent current record Id
   * @param doInsert Whether to insert the records
   * @return Test related records
   */
  public static List<Prompt_Context_Source__c> createRelatedRecords(
    Id rootRecordId,
    Boolean doInsert
  ) {
    List<Prompt_Context_Source__c> relatedRecords = new List<Prompt_Context_Source__c>{
      new Prompt_Context_Source__c(
        Prompt_Template__c = rootRecordId,
        Reference_Name__c = 'Alpha',
        Related_Object__c = 'amy@example.com',
        Source_Mode__c = 'RELATED',
        Result_Mode__c = 'RECORDS',
        Filter_Group_Join__c = 'AND'
      ),
      new Prompt_Context_Source__c(
        Prompt_Template__c = rootRecordId,
        Reference_Name__c = 'Middle',
        Related_Object__c = 'mia@example.com',
        Source_Mode__c = 'RELATED',
        Result_Mode__c = 'RECORDS',
        Filter_Group_Join__c = 'AND'
      ),
      new Prompt_Context_Source__c(
        Prompt_Template__c = rootRecordId,
        Reference_Name__c = 'Zulu',
        Related_Object__c = 'zoe@priority.example',
        Source_Mode__c = 'RELATED',
        Result_Mode__c = 'RECORDS',
        Filter_Group_Join__c = 'AND'
      )
    };
    if (doInsert) {
      insert relatedRecords;
    }
    return relatedRecords;
  }

  /** Creates package-owned related rows sharing one test match value. */
  public static List<Prompt_Context_Source__c> createMatchRecords(
    Id parentId,
    String matchValue,
    Integer count
  ) {
    List<Prompt_Context_Source__c> relatedRecords = new List<Prompt_Context_Source__c>();
    for (Integer index = 0; index < count; index++) {
      relatedRecords.add(
        new Prompt_Context_Source__c(
          Prompt_Template__c = parentId,
          Reference_Name__c = matchValue,
          Related_Object__c = 'Contact ' + index + ' ' + matchValue,
          Source_Mode__c = 'RELATED',
          Result_Mode__c = 'RECORDS',
          Filter_Group_Join__c = 'AND'
        )
      );
    }
    insert relatedRecords;
    return relatedRecords;
  }

  /**
   * Creates Salesforce Files linked directly to one record.
   * @param recordId Record that owns each direct file link
   * @param count Number of files to create
   * @param extension Lowercase file extension
   * @return Inserted latest ContentVersion records
   */
  public static List<ContentVersion> createLinkedFiles(
    Id recordId,
    Integer count,
    String extension
  ) {
    List<ContentVersion> versions = new List<ContentVersion>();
    for (Integer index = 1; index <= count; index++) {
      versions.add(
        new ContentVersion(
          Title = 'Prompt File ' + index,
          PathOnClient = 'prompt-file-' + index + '.' + extension,
          VersionData = Blob.valueOf('File ' + index),
          FirstPublishLocationId = recordId
        )
      );
    }
    insert versions;
    Set<Id> versionIds = new Map<Id, ContentVersion>(versions).keySet();
    return [
      SELECT
        Id,
        ContentDocumentId,
        Title,
        FileExtension,
        FileType,
        ContentSize,
        VersionNumber,
        LastModifiedDate
      FROM ContentVersion
      WHERE Id IN :versionIds
      ORDER BY Title
    ];
  }

  /**
   * Builds a valid configuration with two independently filtered package-owned sources.
   * @return Unsaved template configuration
   */
  public static PromptContextDTO.TemplateConfig createTwoSourceConfig() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Account Context Summary';
    config.description = 'Summarizes an account and two independently selected contact groups.';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody =
      'Account: {!record.Name}\n' +
      'Recent: {!#each related.recent_contacts as="row"}{!row.Reference_Name__c};{!else}None{!/each}\n' +
      'Priority: {!related.priority_contacts[0].Reference_Name__c fallback="None"}\n' +
      'Recent count: {!related.recent_contacts.count}';
    config.sources.add(createRecentContactsSource());
    config.sources.add(createPriorityContactsSource());
    return config;
  }

  private static PromptContextDTO.SourceConfig createRecentContactsSource() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'recent_contacts';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.correlationField = 'Prompt_Template__c';
    source.rootField = 'Id';
    source.selectedFields = new List<String>{
      'Reference_Name__c',
      'Related_Object__c'
    };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'Related_Object__c';
    filter.operator = 'CONTAINS';
    filter.value = 'example.com';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'Reference_Name__c';
    sortRule.direction = 'ASC';
    sortRule.nullsOrder = 'LAST';
    source.sorts.add(sortRule);
    source.maxRows = 2;
    source.sequence = 1;
    return source;
  }

  private static PromptContextDTO.SourceConfig createPriorityContactsSource() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'priority_contacts';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.correlationField = 'Prompt_Template__c';
    source.rootField = 'Id';
    source.selectedFields = new List<String>{
      'Reference_Name__c',
      'Related_Object__c'
    };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'Reference_Name__c';
    filter.operator = 'EQ';
    filter.value = 'Zulu';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'Reference_Name__c';
    sortRule.direction = 'DESC';
    sortRule.nullsOrder = '';
    source.sorts.add(sortRule);
    source.maxRows = 1;
    source.sequence = 2;
    return source;
  }

  /**
   * Builds a limited reference data set that is intentionally independent of the current record.
   * @return Reference-mode package-owned source
   */
  public static PromptContextDTO.SourceConfig createReferenceContactsSource() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'reference_contacts';
    source.sourceMode = 'REFERENCE';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.rootField = null;
    source.correlationField = null;
    source.selectedFields = new List<String>{ 'Reference_Name__c' };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'Reference_Name__c';
    filter.operator = 'STARTS_WITH';
    filter.value = 'A';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'Reference_Name__c';
    sortRule.direction = 'ASC';
    sortRule.nullsOrder = 'LAST';
    source.sorts.add(sortRule);
    source.maxRows = 5;
    source.sequence = 1;
    return source;
  }
}
