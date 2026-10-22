/**
 * Runs generation and template governance as a real user who holds only package Permission Sets,
 * so Salesforce enforces object access, field access, and sharing instead of a test override. The
 * suite creates one minimum-access user, which Salesforce rolls back after each test, so it needs
 * one free Salesforce user license. Not packaged; it lives outside force-app so subscriber
 * deployments never run it.
 */
@isTest
private class PromptContextRestrictedUserTest {
  private static final String USER_LAST_NAME = 'PCB Restricted Test User';
  private static final String TWO_SOURCE_KEY = 'restricted_two_source';
  private static final String BODY_FIELD_KEY = 'restricted_body_field';
  private static final String LOGS_KEY = 'restricted_logs';

  @TestSetup
  static void setupData() {
    User admin = PromptContextTestDataFactory.createConfiguratorUser();
    System.runAs(admin) {
      Profile minimumAccess = [
        SELECT Id
        FROM Profile
        WHERE
          UserLicense.LicenseDefinitionKey = 'SFDC'
          AND PermissionsModifyAllData = FALSE
          AND PermissionsViewAllData = FALSE
          AND PermissionsViewSetup = FALSE
        ORDER BY Name, Id
        LIMIT 1
      ];
      String unique =
        UserInfo.getOrganizationId() +
        String.valueOf(Crypto.getRandomInteger()).replace('-', '');
      insert new User(
        LastName = USER_LAST_NAME,
        Alias = 'pcbrstr',
        Email = 'pcb.restricted@example.com',
        Username = 'pcb.restricted.' + unique + '@example.com',
        ProfileId = minimumAccess.Id,
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Los_Angeles'
      );
    }
    // Setup-object and business-object DML must run in separate runAs blocks.
    System.runAs(admin) {
      Prompt_Template__c root = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(root.Id, true);

      PromptContextDTO.TemplateConfig twoSource = PromptContextTestDataFactory.createTwoSourceConfig();
      twoSource.developerKey = TWO_SOURCE_KEY;
      twoSource = PromptTemplateService.saveDraft(twoSource);
      PromptTemplateService.publish(twoSource.id, root.Id);

      PromptContextDTO.TemplateConfig bodyField = new PromptContextDTO.TemplateConfig();
      bodyField.name = 'Draft body field';
      bodyField.developerKey = BODY_FIELD_KEY;
      bodyField.rootObject = 'Prompt_Template__c';
      bodyField.templateBody = 'Body: {!record.Template_Body__c}';
      bodyField = PromptTemplateService.saveDraft(bodyField);
      PromptTemplateService.publish(bodyField.id, root.Id);

      Id adminLogId = saveLog('admin-log');
      PromptContextDTO.TemplateConfig logs = new PromptContextDTO.TemplateConfig();
      logs.name = 'Visible logs';
      logs.developerKey = LOGS_KEY;
      logs.rootObject = 'Prompt_Input_Log__c';
      logs.templateBody = 'Log {!record.Name}; visible logs {!related.logs.count}';
      PromptContextDTO.SourceConfig visibleLogs = new PromptContextDTO.SourceConfig();
      visibleLogs.referenceName = 'logs';
      visibleLogs.sourceMode = 'REFERENCE';
      visibleLogs.resultMode = 'RECORDS';
      visibleLogs.relatedObject = 'Prompt_Input_Log__c';
      visibleLogs.selectedFields = new List<String>{ 'Name' };
      PromptContextDTO.SortRule byName = new PromptContextDTO.SortRule();
      byName.fieldName = 'Name';
      byName.direction = 'ASC';
      visibleLogs.sorts.add(byName);
      visibleLogs.maxRows = 10;
      visibleLogs.sequence = 1;
      logs.sources.add(visibleLogs);
      logs = PromptTemplateService.saveDraft(logs);
      PromptTemplateService.publish(logs.id, adminLogId);
    }
  }

  @isTest
  static void shouldGenerateWithOnlyThePackagePermissionSets() {
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate', 'Prompt_Context_Save_Input' }
    );
    System.runAs(generator) {
      Id ownLogId = saveLog('own-log');

      PromptContextPreparationService.Response response = generate(
        LOGS_KEY,
        ownLogId
      );

      Assert.isTrue(
        response.success,
        response.reasonCode + ': ' + response.message
      );
      Assert.isTrue(
        response.prompt.endsWith('visible logs 1'),
        'A Reference data set must include only records shared with the user: ' +
        response.prompt
      );
    }
  }

  @isTest
  static void shouldStopWhenTheCurrentRecordIsNotSharedWithTheUser() {
    Id adminLogId = [
      SELECT Id
      FROM Prompt_Input_Log__c
      WHERE OwnerId = :UserInfo.getUserId()
      LIMIT 1
    ]
    .Id;
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate', 'Prompt_Context_Save_Input' }
    );
    System.runAs(generator) {
      PromptContextPreparationService.Response response = generate(
        LOGS_KEY,
        adminLogId
      );

      Assert.isFalse(response.success);
      Assert.areEqual(
        PromptContextReasonCodes.RECORD_NOT_ACCESSIBLE,
        response.reasonCode
      );
      Assert.isNull(response.prompt, 'A denial returns no partial prompt.');
    }
  }

  @isTest
  static void shouldStopWithoutNamingAFieldTheUserCannotRead() {
    Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate' }
    );
    System.runAs(generator) {
      PromptContextPreparationService.Response response = generate(
        BODY_FIELD_KEY,
        rootId
      );

      Assert.areEqual(
        PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
        response.reasonCode
      );
      Assert.areEqual(
        Label.PCB_Access_Denied,
        response.message,
        'Without Diagnostics, the message must not name the hidden field.'
      );
      Assert.isNull(response.prompt);
    }
  }

  @isTest
  static void shouldStopWhenADataSetObjectIsNotReadable() {
    Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate' }
    );
    System.runAs(generator) {
      PromptContextPreparationService.Response response = generate(
        TWO_SOURCE_KEY,
        rootId
      );

      Assert.areEqual(
        PromptContextReasonCodes.OBJECT_NOT_ACCESSIBLE,
        response.reasonCode
      );
      Assert.isNull(response.prompt);
    }
  }

  @isTest
  static void shouldNotLetAGeneratorReadDraftSettings() {
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate' }
    );
    System.runAs(generator) {
      Assert.isTrue(
        queryFails('SELECT Id FROM Prompt_Context_Source__c'),
        'Generate must not read draft data sets.'
      );
      Assert.isTrue(
        queryFails('SELECT Template_Body__c FROM Prompt_Template__c'),
        'Generate must not read draft template text.'
      );
    }
  }

  @isTest
  static void shouldNameAFieldDenialFromAUserModeQuery() {
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate' }
    );
    System.runAs(generator) {
      String reason;
      try {
        PromptContextSelector.selectDynamic(
          'SELECT Template_Body__c FROM Prompt_Template__c LIMIT 1',
          new Map<String, Object>()
        );
      } catch (PromptContextException expected) {
        reason = expected.reasonCode;
      }
      Assert.areEqual(
        PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
        reason,
        'A hidden field is an access failure, not a refused query.'
      );
    }
  }

  @isTest
  static void shouldKeepLifecycleFieldsAwayFromAuthors() {
    Id templateId = templateId(TWO_SOURCE_KEY);
    User author = restrictedUser(
      new List<String>{ 'Prompt_Context_Configure' }
    );
    System.runAs(author) {
      Boolean directEditRefused = false;
      try {
        Database.update(
          new Prompt_Template__c(Id = templateId, Status__c = 'Inactive'),
          true,
          AccessLevel.USER_MODE
        );
      } catch (Exception expected) {
        directEditRefused = true;
      }
      Assert.isTrue(
        directEditRefused,
        'An author must not edit Status directly.'
      );
      Assert.areEqual(
        'Published',
        PromptTemplateService.getTemplate(templateId).status
      );

      Assert.areEqual(
        'Inactive',
        PromptTemplateService.deactivate(templateId).status,
        'Deactivate still works for an author.'
      );
    }
  }

  @isTest
  static void shouldLetAnAuthorSaveAndPublishANewVersion() {
    Id rootId = PromptContextTestDataFactory.selectRootRecord().Id;
    Id templateId = templateId(TWO_SOURCE_KEY);
    User author = restrictedUser(
      new List<String>{ 'Prompt_Context_Configure' }
    );
    System.runAs(author) {
      PromptContextDTO.TemplateConfig draft = PromptTemplateService.getTemplate(
        templateId
      );
      draft.templateBody += '\nAuthor edit';
      PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
        draft
      );

      PromptContextDTO.PromptResult published = PromptTemplateService.publish(
        templateId,
        rootId,
        saved.draftRevision
      );

      Assert.areEqual(2, published.templateVersion);
      Assert.isTrue(published.prompt.endsWith('Author edit'));
    }
  }

  @isTest
  static void shouldRefuseLifecycleWritesWithoutTemplateEditAccess() {
    Id templateId = templateId(TWO_SOURCE_KEY);
    User generator = restrictedUser(
      new List<String>{ 'Prompt_Context_Generate' }
    );
    System.runAs(generator) {
      // Pass the Configure check so only the user-mode edit proof can stop the write.
      PromptContextAccess.setConfigureForTest(true);
      Boolean refused = false;
      try {
        PromptTemplateService.writeLifecycle(
          new List<Prompt_Template__c>{
            new Prompt_Template__c(Id = templateId, Status__c = 'Inactive')
          },
          true
        );
      } catch (Exception expected) {
        refused = true;
      }
      Assert.isTrue(refused, 'The edit proof must stop a read-only user.');
    }
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Assert.areEqual(
        'Published',
        [SELECT Status__c FROM Prompt_Template__c WHERE Id = :templateId]
        .Status__c
      );
    }
  }

  private static User restrictedUser(List<String> permissionSetNames) {
    User restricted = [
      SELECT Id
      FROM User
      WHERE LastName = :USER_LAST_NAME AND Alias = 'pcbrstr'
      LIMIT 1
    ];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
      for (PermissionSet permissionSetRecord : [
        SELECT Id
        FROM PermissionSet
        WHERE Name IN :permissionSetNames
        ORDER BY Name
      ]) {
        assignments.add(
          new PermissionSetAssignment(
            AssigneeId = restricted.Id,
            PermissionSetId = permissionSetRecord.Id
          )
        );
      }
      insert assignments;
    }
    return restricted;
  }

  private static PromptContextPreparationService.Response generate(
    String developerKey,
    Id recordId
  ) {
    PromptContextPreparationService.Request request = new PromptContextPreparationService.Request();
    request.templateDeveloperKey = developerKey;
    request.recordId = recordId;
    return PromptContextPreparationService.execute(
      new List<PromptContextPreparationService.Request>{ request },
      'APEX'
    )[0];
  }

  private static Id saveLog(String requestKey) {
    PromptContextInputLogService.SaveRequest request = new PromptContextInputLogService.SaveRequest();
    request.responseIndex = 0;
    request.requestKey = requestKey;
    request.rootRecordId = PromptContextTestDataFactory.selectRootRecord().Id;
    request.templateVersionId = [
      SELECT Id
      FROM Prompt_Template_Version__c
      WHERE Prompt_Template__r.Developer_Key__c = :TWO_SOURCE_KEY
      LIMIT 1
    ]
    .Id;
    request.promptText = 'Prepared input for ' + requestKey;
    PromptContextInputLogService.SaveResult result = PromptContextInputLogService.save(
      new List<PromptContextInputLogService.SaveRequest>{ request }
    )[0];
    Assert.isTrue(result.success, result.reasonCode + ': ' + result.message);
    return result.inputLogId;
  }

  private static Id templateId(String developerKey) {
    return [
      SELECT Id
      FROM Prompt_Template__c
      WHERE Developer_Key__c = :developerKey
      LIMIT 1
    ]
    .Id;
  }

  private static Boolean queryFails(String soql) {
    try {
      Database.query(soql, AccessLevel.USER_MODE);
      return false;
    } catch (QueryException expected) {
      return true;
    }
  }
}
