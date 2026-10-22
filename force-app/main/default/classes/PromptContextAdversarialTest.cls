/**
 * Feeds misconfigured and hostile templates through validation and generation. Every case must
 * end in a named validation code or a safe PromptContextException, never a raw platform error.
 */
@isTest
private class PromptContextAdversarialTest {
  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Template__c rootRecord = PromptContextTestDataFactory.createRootRecord(
        true
      );
      PromptContextTestDataFactory.createRelatedRecords(rootRecord.Id, true);
    }
  }

  @isTest
  static void shouldNameEveryMisconfiguration() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.ValidationResult baseline = PromptContextValidator.validate(
        baseConfig()
      );
      Assert.isTrue(
        baseline.isValid,
        'Each case must start from a valid template: ' +
        codes(baseline.messages)
      );
      Map<String, String> failures = new Map<String, String>();
      for (MisconfiguredCase item : misconfiguredCases()) {
        PromptContextDTO.TemplateConfig config = baseConfig();
        item.apply(config);
        PromptContextDTO.ValidationResult result;
        try {
          result = PromptContextValidator.validate(config);
        } catch (Exception unexpected) {
          failures.put(
            item.label,
            'validator threw ' +
              unexpected.getTypeName() +
              ': ' +
              unexpected.getMessage()
          );
          continue;
        }
        if (result.isValid || !hasCode(result.messages, item.expectedCode)) {
          failures.put(
            item.label,
            'expected ' +
              item.expectedCode +
              ' but got ' +
              codes(result.messages)
          );
        } else if (
          item.expectedCode == PromptContextReasonCodes.INVALID_CONFIGURATION &&
          String.isNotBlank(item.mention) &&
          !hasCodeMentioning(result.messages, item.expectedCode, item.mention)
        ) {
          // A generic code must come from the changed setting, not an unrelated problem.
          failures.put(
            item.label,
            item.expectedCode +
              ' did not name ' +
              item.mention +
              ': ' +
              JSON.serialize(result.messages)
          );
        }
      }
      Assert.isTrue(
        failures.isEmpty(),
        'Unnamed misconfigurations: ' + failures
      );
    }
  }

  @isTest
  static void shouldNeverReachTheDatabaseWithHostileQuerySettings() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Map<String, String> failures = new Map<String, String>();
      for (HostileCase item : hostileCases()) {
        PromptContextDTO.TemplateConfig config = baseConfig();
        item.apply(config);
        try {
          PromptContextService.generate(
            config,
            PromptContextTestDataFactory.selectRootRecord().Id
          );
          failures.put(item.label, 'generated a prompt');
        } catch (PromptContextException expected) {
          // A safe, named stop is the required outcome.
        } catch (Exception unexpected) {
          failures.put(
            item.label,
            unexpected.getTypeName() + ': ' + unexpected.getMessage()
          );
        }
      }
      Assert.isTrue(failures.isEmpty(), 'Unsafe outcomes: ' + failures);
    }
  }

  @isTest
  static void shouldIgnoreAForgedSyntaxVersionFromTheBrowser() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextAccess.setConfigureForTest(true);
      PromptContextDTO.TemplateConfig config = baseConfig();
      config.syntaxVersion = 1;
      config.templateBody = 'Ship to {!record.ShippingAddress}';
      config.rootObject = 'Account';
      config.sources.clear();

      PromptContextDTO.ValidationResult result = PromptContextController.validateConfig(
        JSON.serialize(config)
      );

      Assert.isTrue(
        hasCode(result.messages, 'COMPOUND_FIELD_NOT_SUPPORTED'),
        'A browser cannot opt a draft out of the current rules.'
      );
    }
  }

  @isTest
  static void shouldStopForAWrongObjectOrDeletedRecord() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = baseConfig();
      Prompt_Context_Source__c otherObject = [
        SELECT Id
        FROM Prompt_Context_Source__c
        WHERE Reference_Name__c = 'Alpha'
        LIMIT 1
      ];
      Prompt_Template__c doomed = PromptContextTestDataFactory.createRootRecord(
        true
      );
      Id deletedId = doomed.Id;
      delete doomed;

      for (Id recordId : new List<Id>{ otherObject.Id, deletedId }) {
        try {
          PromptContextService.generate(config, recordId);
          Assert.fail('No prompt may be built for ' + recordId);
        } catch (PromptContextException expected) {
          Assert.isNotNull(expected.getMessage());
        }
      }
    }
  }

  @isTest
  static void shouldRejectATemplateThatUsesAnExcludedDataSet() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = baseConfig();
      config.sources[0].active = false;

      PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
        config
      );

      Assert.isTrue(
        hasCode(result.messages, 'UNKNOWN_SOURCE'),
        'Using a data set that is switched off must be named: ' +
        codes(result.messages)
      );
    }
  }

  @isTest
  static void shouldExplainTooManyBlocksBeforePublishing() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = baseConfig();
      config.templateBody =
        '{!#if related.recent_contacts.hasRecords}x{!/if}'
          .repeat(PromptContextContract.MAX_BLOCK_ITERATIONS + 1) +
        '{!related.recent_contacts.count}';

      PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
        config
      );

      Assert.isFalse(
        result.isValid,
        'More blocks than the renderer allows must fail validation, not only at generation.'
      );
      Assert.isTrue(
        hasCode(result.messages, 'TOO_MANY_BLOCKS'),
        codes(result.messages)
      );
    }
  }

  @isTest
  static void shouldHandleMalformedAttributeQuotingSafely() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      for (
        String body : new List<String>{
          '{!record.Name fallback="a}b"}',
          '{!record.Name fallback="{!record.Name}"}',
          '{!record.Name fallback=unquoted}',
          '{!record.Name fallback="x" fallback="y"}',
          '{!record.Name  maxLength="5"   format="upper" }',
          '{!record.Name fallback=""}',
          '{!}',
          '{!   }',
          '{!!!}',
          '{!record.}',
          '{!record..Name}',
          '{!related.recent_contacts[-1].Reference_Name__c}',
          '{!related.recent_contacts[99999999999].Reference_Name__c}'
        }
      ) {
        PromptContextDTO.TemplateConfig config = baseConfig();
        config.templateBody = body + ' {!related.recent_contacts.count}';
        try {
          PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
            config
          );
          if (result.isValid) {
            PromptContextService.generate(
              config,
              PromptContextTestDataFactory.selectRootRecord().Id
            );
          }
        } catch (PromptContextException expected) {
          continue;
        } catch (Exception unexpected) {
          Assert.fail(
            body +
              ' raised ' +
              unexpected.getTypeName() +
              ': ' +
              unexpected.getMessage()
          );
        }
      }
    }
  }

  @isTest
  static void shouldHideWhichFieldIsHiddenFromUsersWithoutDiagnostics() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextException hidden = PromptContextException.withReason(
        PromptContextReasonCodes.FIELD_NOT_ACCESSIBLE,
        'Field Salary__c is not readable.'
      );
      PromptContextException configuration = PromptContextException.withReason(
        PromptContextReasonCodes.INVALID_CONFIGURATION,
        'Choose AND or OR.'
      );

      PromptContextAccess.setDiagnosticsForTest(false);
      String ordinary = PromptContextTrace.safeMessage(hidden);
      String ordinaryConfiguration = PromptContextTrace.safeMessage(
        configuration
      );
      PromptContextAccess.setDiagnosticsForTest(true);
      String troubleshooter = PromptContextTrace.safeMessage(hidden);

      Assert.areEqual(Label.PCB_Access_Denied, ordinary);
      Assert.isFalse(ordinary.contains('Salary__c'));
      Assert.areEqual('Choose AND or OR.', ordinaryConfiguration);
      Assert.areEqual(
        'Field Salary__c is not readable.',
        troubleshooter,
        'Troubleshooting users still see the exact field.'
      );
    }
  }

  @isTest
  static void shouldFindEveryRecordFieldAFormulaReads() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Assert.areEqual(
        new Set<String>{
          'Name',
          'Status__c',
          'Account.Owner.Email',
          'Amount',
          'CloseDate'
        },
        PromptContextFormulaAccess.references(
          '/* Amount_Old__c is ignored */ IF(ISPICKVAL(Status__c, "Closed Won"), ' +
            'Name & " " & Account.Owner.Email & TEXT( Amount ), ' +
            '"Not Name__c" & \'x\' & $User.Email & $Label.Greeting & TEXT(CloseDate) & ' +
            'TODAY() + 1.5e3 + TRUE)'
        )
      );
      try {
        PromptContextFormulaAccess.references('Owner:User.FirstName');
        Assert.fail('A polymorphic formula cannot be verified.');
      } catch (PromptContextException expected) {
        Assert.areEqual('FORMULA_INPUT_NOT_VERIFIED', expected.reasonCode);
      }
      Assert.isTrue(
        PromptContextFormulaAccess.references('"a:b" & Name').contains('Name'),
        'A colon inside text is not a relationship.'
      );
    }
  }

  // ---------- Case tables ----------

  private abstract class MisconfiguredCase {
    String label;
    String expectedCode;
    String mention;
    public abstract void apply(PromptContextDTO.TemplateConfig config);
  }

  private class SourceChange extends MisconfiguredCase {
    String property;
    Object value;

    SourceChange(
      String label,
      String expectedCode,
      String property,
      Object value
    ) {
      this.label = label;
      this.expectedCode = expectedCode;
      this.property = property;
      this.value = value;
      if (property == 'relatedObject' && value != null) {
        this.mention = (String) value;
      }
    }

    public override void apply(PromptContextDTO.TemplateConfig config) {
      if (property == 'duplicateAlias') {
        config.sources[1].referenceName = (String) value;
      } else if (property == 'sourceCount') {
        while (config.sources.size() < (Integer) value) {
          PromptContextDTO.SourceConfig copy = config.sources[0].clone();
          copy.referenceName = 'extra_' + config.sources.size();
          config.sources.add(copy);
        }
      } else {
        setSourceProperty(config.sources[0], property, value);
      }
    }
  }

  private class BodyChange extends MisconfiguredCase {
    String body;

    BodyChange(String label, String expectedCode, String body) {
      this.label = label;
      this.expectedCode = expectedCode;
      this.body = body;
      Matcher field = Pattern.compile(
          'record\\.([A-Za-z_.]+__c|CreatedBy[A-Za-z_.]*)'
        )
        .matcher(body);
      if (field.find()) {
        this.mention = field.group(1);
      }
    }

    public override void apply(PromptContextDTO.TemplateConfig config) {
      config.templateBody = body;
    }
  }

  private class FilterChange extends MisconfiguredCase {
    String fieldName;
    String operator;
    String value;
    String logic;

    FilterChange(
      String label,
      String expectedCode,
      String fieldName,
      String operator,
      String value,
      String logic
    ) {
      this.label = label;
      this.expectedCode = expectedCode;
      this.fieldName = fieldName;
      this.operator = operator;
      this.value = value;
      this.logic = logic;
      this.mention = logic == null ? fieldName : null;
    }

    public override void apply(PromptContextDTO.TemplateConfig config) {
      PromptContextDTO.FilterRule rule = config.sources[0].filters[0];
      rule.fieldName = fieldName;
      rule.operator = operator;
      rule.value = value;
      config.sources[0].filterLogic = logic;
    }
  }

  private static List<MisconfiguredCase> misconfiguredCases() {
    return new List<MisconfiguredCase>{
      new BodyChange(
        'unclosed each',
        'UNCLOSED_BLOCK',
        '{!#each related.recent_contacts as="r"}{!r.Reference_Name__c}'
      ),
      new BodyChange(
        'orphan else',
        'ORPHAN_ELSE',
        '{!else}{!related.recent_contacts.count}'
      ),
      new BodyChange(
        'nested each',
        'NESTED_EACH',
        '{!#each related.recent_contacts as="a"}{!#each related.priority_contacts as="b"}{!b.Reference_Name__c}{!/each}{!/each}'
      ),
      new BodyChange(
        'unknown token',
        'UNKNOWN_TOKEN',
        '{!user.Name} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'unknown data set',
        'UNKNOWN_SOURCE',
        '{!related.nope.count} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'field not selected',
        'FIELD_NOT_SELECTED',
        '{!related.recent_contacts[0].Sequence__c}'
      ),
      new BodyChange(
        'missing root field',
        'INVALID_CONFIGURATION',
        '{!record.No_Such_Field__c} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'index past limit',
        'INDEX_OUT_OF_RANGE',
        '{!related.priority_contacts[1].Reference_Name__c} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'bad maxLength',
        'INVALID_MAX_LENGTH',
        '{!record.Name maxLength="0"} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'unknown format',
        'UNSUPPORTED_FORMAT',
        '{!record.Name format="title"} {!related.recent_contacts.count}'
      ),
      new BodyChange(
        'reserved alias',
        'RESERVED_LOCAL_NAME',
        '{!#each related.recent_contacts as="record"}x{!/each}'
      ),
      new BodyChange(
        'six relationships',
        'ROOT_FIELD_ACCESS',
        '{!record.CreatedBy.Manager.Manager.Manager.Manager.Manager.Name} {!related.recent_contacts.count}'
      ),
      new SourceChange(
        'missing object',
        'MISSING_RELATED_OBJECT',
        'relatedObject',
        null
      ),
      new SourceChange(
        'unknown object',
        'INVALID_CONFIGURATION',
        'relatedObject',
        'No_Such_Object__c'
      ),
      new SourceChange(
        'bad reference name',
        'INVALID_REFERENCE',
        'referenceName',
        '1bad-name'
      ),
      new SourceChange('rows zero', 'INVALID_MAX_ROWS', 'maxRows', 0),
      new SourceChange('rows over limit', 'INVALID_MAX_ROWS', 'maxRows', 51),
      new SourceChange('rows missing', 'INVALID_MAX_ROWS', 'maxRows', null),
      new SourceChange(
        'bad mode',
        'INVALID_SOURCE_MODE',
        'sourceMode',
        'EVERYTHING'
      ),
      new SourceChange(
        'bad result mode',
        'INVALID_RESULT_MODE',
        'resultMode',
        'ROWS'
      ),
      new SourceChange(
        'bad join',
        'INVALID_FILTER_GROUP_JOIN',
        'filterGroupJoin',
        'XOR'
      ),
      new SourceChange(
        'match type mismatch',
        'MATCH_FIELD_TYPES_DIFFER',
        'correlationField',
        'Sequence__c'
      ),
      new SourceChange(
        'no fields',
        'MISSING_SELECTED_FIELDS',
        'selectedFields',
        new List<String>()
      ),
      new SourceChange(
        'compound field',
        'COMPOUND_FIELD_NOT_SUPPORTED',
        'selectedFieldsAddress',
        null
      ),
      new FilterChange(
        'unknown operator',
        'INVALID_FILTER',
        'Reference_Name__c',
        'LIKE',
        'x',
        null
      ),
      new FilterChange(
        'missing value',
        'MISSING_FILTER_VALUE',
        'Reference_Name__c',
        'EQ',
        '',
        null
      ),
      new FilterChange(
        'text range',
        'OPERATOR_TYPE_MISMATCH',
        'Reference_Name__c',
        'GT',
        'x',
        null
      ),
      new FilterChange(
        'contains number',
        'OPERATOR_TYPE_MISMATCH',
        'Sequence__c',
        'CONTAINS',
        '1',
        null
      ),
      new FilterChange(
        'not filterable',
        'FIELD_NOT_FILTERABLE',
        'Filters_JSON__c',
        'EQ',
        'x',
        null
      ),
      new FilterChange(
        'number text',
        'INVALID_CONFIGURATION',
        'Sequence__c',
        'EQ',
        'ten',
        null
      ),
      new FilterChange(
        'boolean text',
        'INVALID_CONFIGURATION',
        'Active__c',
        'EQ',
        'yes',
        null
      ),
      new FilterChange(
        'date junk',
        'INVALID_CONFIGURATION',
        'CreatedDate',
        'GT',
        'last week',
        null
      ),
      new FilterChange(
        'list boolean',
        'OPERATOR_TYPE_MISMATCH',
        'Active__c',
        'IN',
        'true',
        null
      ),
      new FilterChange(
        'logic junk',
        'INVALID_FILTER_LOGIC',
        'Reference_Name__c',
        'EQ',
        'x',
        '1 OR Id != null'
      ),
      new FilterChange(
        'logic range',
        'INVALID_FILTER_LOGIC',
        'Reference_Name__c',
        'EQ',
        'x',
        '2'
      ),
      new FilterChange(
        'logic long',
        'INVALID_FILTER_LOGIC',
        'Reference_Name__c',
        'EQ',
        'x',
        '1' + ' OR 1'.repeat(60)
      ),
      new SourceChange(
        'too many filters',
        'TOO_MANY_FILTERS',
        'filterCount',
        11
      ),
      new SourceChange('too many sorts', 'TOO_MANY_SORTS', 'sortCount', 4),
      new SourceChange(
        'too many groups',
        'TOO_MANY_FILTER_GROUPS',
        'groupCount',
        6
      ),
      new SourceChange(
        'bad group name',
        'INVALID_FILTER_GROUP',
        'groupName',
        'has space'
      ),
      new SourceChange(
        'duplicate reference',
        'DUPLICATE_REFERENCE',
        'duplicateAlias',
        'RECENT_CONTACTS'
      ),
      new SourceChange(
        'aggregate text sum',
        'AGGREGATE_TYPE_MISMATCH',
        'aggregateSum',
        'Reference_Name__c'
      ),
      new SourceChange(
        'aggregate bad op',
        'INVALID_AGGREGATE_OPERATION',
        'aggregateOp',
        'MEDIAN'
      ),
      new SourceChange(
        'too many sources',
        'TOO_MANY_SOURCES',
        'sourceCount',
        11
      )
    };
  }

  private class HostileCase {
    String label;
    String property;
    Object value;

    HostileCase(String label, String property, Object value) {
      this.label = label;
      this.property = property;
      this.value = value;
    }

    void apply(PromptContextDTO.TemplateConfig config) {
      setSourceProperty(config.sources[0], property, value);
    }
  }

  private static List<HostileCase> hostileCases() {
    String fragment = 'Id FROM User WHERE Id != null --';
    return new List<HostileCase>{
      new HostileCase('object', 'relatedObject', 'User WHERE Id != null'),
      new HostileCase('selected field', 'selectedFieldsValue', fragment),
      new HostileCase(
        'match field',
        'correlationField',
        'Prompt_Template__c OR Id != null'
      ),
      new HostileCase('root field', 'rootField', 'Id) OR (Id != null'),
      new HostileCase('sort field', 'sortField', 'Reference_Name__c, Id'),
      new HostileCase('sort direction', 'sortDirection', 'ASC, Name DESC'),
      new HostileCase('nulls order', 'nullsOrder', 'LAST, Id'),
      new HostileCase('group join', 'filterGroupJoin', 'OR Id != null OR'),
      new HostileCase('filter field', 'filterField', 'Name = \'x\' OR Name'),
      new HostileCase(
        'filter operator',
        'filterOperator',
        '= \'x\' OR Name !='
      ),
      new HostileCase('filter logic', 'filterLogic', '1) OR (Id != null'),
      new HostileCase('date literal', 'dateLiteral', 'TODAY OR Id != null'),
      new HostileCase('aggregate op', 'aggregateOp', 'COUNT(Id) FROM User --'),
      new HostileCase('aggregate field', 'aggregateSum', 'Id) FROM User --'),
      new HostileCase('reference name', 'referenceName', 'x\' OR \'1\'=\'1'),
      new HostileCase('row limit', 'maxRows', 2147483647)
    };
  }

  // ---------- Helpers ----------

  private static void setSourceProperty(
    PromptContextDTO.SourceConfig source,
    String property,
    Object value
  ) {
    switch on property {
      when 'relatedObject' {
        source.relatedObject = (String) value;
      }
      when 'referenceName' {
        source.referenceName = (String) value;
      }
      when 'maxRows' {
        source.maxRows = (Integer) value;
      }
      when 'sourceMode' {
        source.sourceMode = (String) value;
      }
      when 'resultMode' {
        source.resultMode = (String) value;
      }
      when 'filterGroupJoin' {
        source.filterGroupJoin = (String) value;
      }
      when 'correlationField' {
        source.correlationField = (String) value;
      }
      when 'rootField' {
        source.rootField = (String) value;
      }
      when 'selectedFields' {
        source.selectedFields = (List<String>) value;
      }
      when 'selectedFieldsAddress' {
        source.relatedObject = 'Account';
        source.correlationField = 'Id';
        source.selectedFields = new List<String>{ 'BillingAddress' };
        source.filters.clear();
        source.sorts.clear();
      }
      when 'selectedFieldsValue' {
        source.selectedFields.add((String) value);
      }
      when 'sortField' {
        source.sorts[0].fieldName = (String) value;
      }
      when 'sortDirection' {
        source.sorts[0].direction = (String) value;
      }
      when 'nullsOrder' {
        source.sorts[0].nullsOrder = (String) value;
      }
      when 'filterField' {
        source.filters[0].fieldName = (String) value;
      }
      when 'filterOperator' {
        source.filters[0].operator = (String) value;
      }
      when 'filterLogic' {
        source.filterLogic = (String) value;
      }
      when 'dateLiteral' {
        source.filters[0].fieldName = 'CreatedDate';
        source.filters[0].operator = 'GT';
        source.filters[0].value = (String) value;
      }
      when 'filterCount' {
        while (source.filters.size() < (Integer) value) {
          source.filters.add(source.filters[0].clone());
        }
      }
      when 'sortCount' {
        while (source.sorts.size() < (Integer) value) {
          source.sorts.add(source.sorts[0].clone());
        }
      }
      when 'groupCount' {
        source.filters.clear();
        for (Integer index = 0; index < (Integer) value; index++) {
          PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
          rule.fieldName = 'Reference_Name__c';
          rule.operator = 'EQ';
          rule.value = 'v' + index;
          rule.groupName = 'g' + index;
          source.filters.add(rule);
        }
      }
      when 'groupName' {
        source.filters[0].groupName = (String) value;
      }
      when 'aggregateSum' {
        source.resultMode = 'AGGREGATE';
        source.aggregateOperation = 'SUM';
        source.aggregateField = (String) value;
        source.selectedFields = new List<String>();
        source.sorts.clear();
      }
      when 'aggregateOp' {
        source.resultMode = 'AGGREGATE';
        source.aggregateOperation = (String) value;
        source.aggregateField = null;
        source.selectedFields = new List<String>();
        source.sorts.clear();
      }
    }
  }

  private static PromptContextDTO.TemplateConfig baseConfig() {
    PromptContextDTO.TemplateConfig config = PromptContextTestDataFactory.createTwoSourceConfig();
    return config;
  }

  private static Boolean hasCode(
    List<PromptContextDTO.Message> messages,
    String code
  ) {
    for (PromptContextDTO.Message message : messages) {
      if (message.code == code) {
        return true;
      }
    }
    return false;
  }

  private static Boolean hasCodeMentioning(
    List<PromptContextDTO.Message> messages,
    String code,
    String text
  ) {
    for (PromptContextDTO.Message message : messages) {
      if (message.code == code && (message.text ?? '').contains(text)) {
        return true;
      }
    }
    return false;
  }

  private static String codes(List<PromptContextDTO.Message> messages) {
    List<String> values = new List<String>();
    for (PromptContextDTO.Message message : messages) {
      values.add(message.severity + ':' + message.code);
    }
    return String.join(values, ',');
  }

  @isTest
  static void shouldNameAQuerySalesforceRefusesInsteadOfAPlatformError() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = baseConfig();
      config.sources.remove(1);
      PromptContextDTO.SourceConfig links = config.sources[0];
      links.referenceName = 'links';
      links.sourceMode = 'REFERENCE';
      links.relatedObject = 'ContentDocumentLink';
      links.correlationField = null;
      links.rootField = null;
      links.selectedFields = new List<String>{ 'LinkedEntityId' };
      links.filters.clear();
      links.sorts.clear();
      links.maxRows = 5;
      config.templateBody = '{!related.links.count}';

      try {
        PromptContextService.generate(
          config,
          PromptContextTestDataFactory.selectRootRecord().Id
        );
        Assert.fail('Salesforce requires an Id filter on this object.');
      } catch (PromptContextException expected) {
        Assert.areEqual(
          PromptContextReasonCodes.QUERY_NOT_SUPPORTED,
          expected.reasonCode,
          expected.getMessage()
        );
      }
    }
  }

  @isTest
  static void shouldRefuseObjectKindsThatCannotBeVerified() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      for (
        String objectName : new List<String>{
          'Sales__x',
          'Clicks__b',
          'Faq__kav'
        }
      ) {
        PromptContextDTO.TemplateConfig config = baseConfig();
        config.sources[0].relatedObject = objectName;
        Assert.isTrue(
          hasCode(
            PromptContextValidator.validate(config).messages,
            'OBJECT_KIND_NOT_SUPPORTED'
          ),
          objectName + ' must be refused.'
        );
      }
    }
  }

  @isTest
  static void shouldWarnAboutFilterValuesThatSilentlyMatchNothing() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = baseConfig();
      config.sources[0].filters[0].fieldName = 'Source_Mode__c';
      config.sources[0].filters[0].operator = 'IN';
      config.sources[0].filters[0].value = 'related, Reference_Records';
      config.sources[1].filters[0].value = 'Zulu ';

      List<PromptContextDTO.Message> messages = PromptContextValidator.validate(
          config
        )
        .messages;

      Assert.isTrue(
        hasCode(messages, 'UNKNOWN_PICKLIST_VALUE'),
        codes(messages)
      );
      Assert.isTrue(
        hasCode(messages, 'FILTER_VALUE_WHITESPACE'),
        codes(messages)
      );
      Integer unknownCount = 0;
      for (PromptContextDTO.Message message : messages) {
        if (message.code == 'UNKNOWN_PICKLIST_VALUE') {
          unknownCount++;
          Assert.isTrue(
            message.text.contains('Reference_Records'),
            message.text
          );
        }
      }
      Assert.areEqual(
        1,
        unknownCount,
        'Picklist values match without regard to case; only the unknown value is named.'
      );
    }
  }
}
