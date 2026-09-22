/**
 * Creates isolated Account, Contact, and prompt configuration records for Prompt Context Builder tests.
 */
@isTest
public with sharing class PromptContextTestDataFactory {
  /**
   * Creates a dedicated test user and grants configuration access.
   * @return Configurator test user
   */
  public static User createConfiguratorUser() {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String uniqueValue = String.valueOf(DateTime.now().getTime());
    User testUser = new User(
      Alias = 'pcbtest',
      Email = 'pcb.test.' + uniqueValue + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LastName = 'Prompt Context Tester',
      LocaleSidKey = 'en_US',
      ProfileId = profileRecord.Id,
      TimeZoneSidKey = 'America/Chicago',
      Username = 'pcb.test.' + uniqueValue + '@example.com'
    );
    insert testUser;
    PermissionSet permissionSetRecord = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Prompt_Context_Configure'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = testUser.Id,
      PermissionSetId = permissionSetRecord.Id
    );
    return testUser;
  }

  /** Creates a user with only the Generate Permission Set and no extra data access. */
  public static User createRestrictedGeneratorUser() {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    String uniqueValue = String.valueOf(DateTime.now().getTime());
    User testUser = new User(
      Alias = 'pcbmin',
      Email = 'pcb.minimum.' + uniqueValue + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LastName = 'Prompt Context Minimum Access',
      LocaleSidKey = 'en_US',
      ProfileId = profileRecord.Id,
      TimeZoneSidKey = 'America/Chicago',
      Username = 'pcb.minimum.' + uniqueValue + '@example.com'
    );
    insert testUser;
    PermissionSet permissionSetRecord = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Prompt_Context_Generate'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = testUser.Id,
      PermissionSetId = permissionSetRecord.Id
    );
    return testUser;
  }

  /**
   * Creates one account.
   * @param doInsert Whether to insert the record
   * @return Test account
   */
  public static Account createAccount(Boolean doInsert) {
    Account accountRecord = new Account(Name = 'Acme Research');
    if (doInsert) {
      insert accountRecord;
    }
    return accountRecord;
  }

  /**
   * Creates three deterministically named contacts for an account.
   * @param accountId Parent account Id
   * @param doInsert Whether to insert the records
   * @return Test contacts
   */
  public static List<Contact> createContacts(Id accountId, Boolean doInsert) {
    List<Contact> contacts = new List<Contact>{
      new Contact(
        FirstName = 'Amy',
        LastName = 'Alpha',
        Email = 'amy@example.com',
        AccountId = accountId
      ),
      new Contact(
        FirstName = 'Mia',
        LastName = 'Middle',
        Email = 'mia@example.com',
        AccountId = accountId
      ),
      new Contact(
        FirstName = 'Zoe',
        LastName = 'Zulu',
        Email = 'zoe@priority.example',
        AccountId = accountId
      )
    };
    if (doInsert) {
      insert contacts;
    }
    return contacts;
  }

  /**
   * Builds a valid configuration with two independently filtered and sorted Contact sources.
   * @return Unsaved template configuration
   */
  public static PromptContextDTO.TemplateConfig createTwoSourceConfig() {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Account Context Summary';
    config.description = 'Summarizes an account and two independently selected contact groups.';
    config.rootObject = 'Account';
    config.templateBody =
      'Account: {!record.Name}\n' +
      'Recent: {!#each related.recent_contacts as="row"}{!row.LastName};{!else}None{!/each}\n' +
      'Priority: {!related.priority_contacts[0].LastName fallback="None"}\n' +
      'Recent count: {!related.recent_contacts.count}';
    config.sources.add(createRecentContactsSource());
    config.sources.add(createPriorityContactsSource());
    return config;
  }

  private static PromptContextDTO.SourceConfig createRecentContactsSource() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'recent_contacts';
    source.relatedObject = 'Contact';
    source.correlationField = 'AccountId';
    source.rootField = 'Id';
    source.selectedFields = new List<String>{ 'LastName', 'Email' };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'Email';
    filter.operator = 'CONTAINS';
    filter.value = 'example.com';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'LastName';
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
    source.relatedObject = 'Contact';
    source.correlationField = 'AccountId';
    source.rootField = 'Id';
    source.selectedFields = new List<String>{ 'LastName', 'Email' };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'LastName';
    filter.operator = 'EQ';
    filter.value = 'Zulu';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'LastName';
    sortRule.direction = 'DESC';
    sortRule.nullsOrder = '';
    source.sorts.add(sortRule);
    source.maxRows = 1;
    source.sequence = 2;
    return source;
  }

  /**
   * Builds a limited reference data set that is intentionally independent of the current record.
   * @return Reference-mode Contact source
   */
  public static PromptContextDTO.SourceConfig createReferenceContactsSource() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'reference_contacts';
    source.sourceMode = 'REFERENCE';
    source.relatedObject = 'Contact';
    source.rootField = null;
    source.correlationField = null;
    source.selectedFields = new List<String>{ 'LastName' };
    PromptContextDTO.FilterRule filter = new PromptContextDTO.FilterRule();
    filter.fieldName = 'LastName';
    filter.operator = 'STARTS_WITH';
    filter.value = 'A';
    source.filters.add(filter);
    PromptContextDTO.SortRule sortRule = new PromptContextDTO.SortRule();
    sortRule.fieldName = 'LastName';
    sortRule.direction = 'ASC';
    sortRule.nullsOrder = 'LAST';
    source.sorts.add(sortRule);
    source.maxRows = 5;
    source.sequence = 1;
    return source;
  }
}
