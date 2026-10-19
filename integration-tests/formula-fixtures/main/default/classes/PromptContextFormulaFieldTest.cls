/**
 * Runs real formula fields through templates: a cross-object formula that reads another formula,
 * HYPERLINK and IMAGE formulas, a formula over a field the user cannot read, a polymorphic formula,
 * a formula that Salesforce cannot calculate, and a formula match field that cannot be grouped.
 * Uses the test-only fields in integration-tests/formula-fixtures. Not packaged.
 */
@isTest
private class PromptContextFormulaFieldTest {
  private static final String ROOT_KEY = 'formula_root';

  @TestSetup
  static void setupData() {
    insert new PermissionSetAssignment(
      AssigneeId = UserInfo.getUserId(),
      PermissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'PCB_Test_Formula_Fixtures'
        LIMIT 1
      ]
      .Id
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Prompt_Template__c root = new Prompt_Template__c(
        Name = 'Formula Root',
        Developer_Key__c = ROOT_KEY,
        Root_Object__c = 'Prompt_Template__c',
        Template_Body__c = '{!record.Name}',
        Status__c = 'Draft',
        Version__c = 4,
        File_Input_Mode__c = 'DISABLED',
        Test_Secret__c = 'TOP-SECRET'
      );
      Prompt_Template__c other = root.clone();
      other.Name = 'Other Root';
      other.Developer_Key__c = 'formula_other';
      insert new List<Prompt_Template__c>{ root, other };
      insert new List<Prompt_Context_Source__c>{
        child(root.Id, 'Alpha', 1),
        child(root.Id, 'Bravo', 2),
        child(root.Id, 'Charlie', 3)
      };
    }
  }

  @isTest
  static void shouldRenderACrossObjectFormulaThatReadsAnotherFormula() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      PromptContextDTO.TemplateConfig config = config(
        '{!record.Test_Name_Label__c} v{!record.Test_Version_Plus__c}\n' +
        '{!#each related.rows as="r"}{!r.Test_Parent_Label__c}={!r.Test_Double_Sequence__c};{!/each}'
      );
      PromptContextDTO.SourceConfig rows = rows();
      rows.selectedFields.addAll(
        new List<String>{ 'Test_Parent_Label__c', 'Test_Double_Sequence__c' }
      );
      rows.filters.add(filter('Test_Double_Sequence__c', 'GT', '2'));
      rows.sorts.add(sortRule('Test_Double_Sequence__c', 'DESC'));
      config.sources.add(rows);

      Assert.areEqual(
        'Formula Root [Draft] v5\n' +
        'Formula Root [Draft] / Charlie=6;Formula Root [Draft] / Bravo=4;',
        generate(config)
      );
    }
  }

  @isTest
  static void shouldKeepTheUrlOfAHyperlinkFormulaAndTheAltTextOfAnImage() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Assert.areEqual(
        'Formula Root (https://example.com/t/formula_root) | [Image: Company logo]',
        generate(config('{!record.Test_Link__c} | {!record.Test_Image__c}'))
      );
    }
  }

  @isTest
  static void shouldRefuseAFormulaThatReadsAFieldTheUserCannotRead() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Assert.isFalse(
        Prompt_Template__c.Test_Secret__c.getDescribe().isAccessible(),
        'Precondition: the fixture permission set must not grant Test Secret.'
      );
      Assert.isTrue(
        Prompt_Template__c.Test_Secret_Echo__c.getDescribe().isAccessible(),
        'Precondition: the formula field itself is readable.'
      );
      PromptContextDTO.TemplateConfig config = config(
        'Leak? {!record.Test_Secret_Echo__c}'
      );

      PromptContextDTO.ValidationResult result = PromptContextValidator.validate(
        config
      );

      Assert.isTrue(
        hasCode(result.messages, 'FIELD_NOT_ACCESSIBLE'),
        'A formula must not reveal a field the user cannot read: ' +
        result.messages
      );
      try {
        generate(config);
        Assert.fail('No prompt may contain the hidden value.');
      } catch (PromptContextException expected) {
        Assert.isFalse(expected.getMessage().contains('TOP-SECRET'));
      }
    }
  }

  @isTest
  static void shouldFailClosedForAPolymorphicFormula() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Assert.isTrue(
        hasCode(
          PromptContextValidator.validate(
              config('{!record.Test_Owner_Name__c}')
            )
            .messages,
          'FORMULA_INPUT_NOT_VERIFIED'
        )
      );
    }
  }

  @isTest
  static void shouldCalculateOverANumberFormulaField() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      PromptContextDTO.TemplateConfig config = config(
        'Sum={!aggregate.total.value};Max={!aggregate.top.value}'
      );
      config.sources.add(aggregate('total', 'SUM', 'Test_Double_Sequence__c'));
      config.sources.add(aggregate('top', 'MAX', 'Test_Double_Sequence__c'));

      Assert.areEqual(
        'Sum=12;Max=6',
        generate(config),
        'Salesforce can calculate a number formula; the result must match the stored values.'
      );
    }
  }

  @isTest
  static void shouldCalculateTheSameValuesOnARecordPageAndInBulkWithAFormulaMatch() {
    PromptContextAccess.setConfigureForTest(true);
    PromptContextAccess.setGenerateForTest(true);
    System.runAs(new User(Id = UserInfo.getUserId())) {
      PromptContextDTO.TemplateConfig config = config(
        'N={!aggregate.n.value};S={!aggregate.s.value fallback="none"};' +
        'L={!aggregate.l.value fallback="none"}'
      );
      for (
        PromptContextDTO.SourceConfig source : new List<PromptContextDTO.SourceConfig>{
          aggregate('n', 'COUNT', null),
          aggregate('s', 'SUM', 'Sequence__c'),
          aggregate('l', 'MAX', 'Sequence__c')
        }
      ) {
        source.correlationField = 'Test_Parent_Key__c';
        source.rootField = 'Developer_Key__c';
        config.sources.add(source);
      }
      config.developerKey = 'formula_bulk';
      Id rootId = rootId(ROOT_KEY);
      Id otherId = rootId('formula_other');
      Assert.isFalse(
        Prompt_Context_Source__c.Test_Parent_Key__c.getDescribe().isGroupable(),
        'Precondition: Salesforce cannot group by a formula field.'
      );
      PromptTemplateService.publish(
        PromptTemplateService.saveDraft(config).id,
        rootId
      );

      Test.startTest();
      List<PromptContextInputApi.Result> bulkResults = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{
          request(rootId),
          request(otherId)
        }
      );
      String single = PromptContextService.generate(config, rootId).prompt;
      Test.stopTest();

      Assert.isTrue(
        bulkResults[0].success,
        bulkResults[0].reasonCode + ' ' + bulkResults[0].message
      );
      Assert.areEqual('N=3;S=6;L=3', bulkResults[0].prompt);
      Assert.areEqual(
        single,
        bulkResults[0].prompt,
        'Flow and Batch must calculate exactly what the record page shows.'
      );
      Assert.areEqual('N=0;S=none;L=none', bulkResults[1].prompt);
    }
  }

  // ---------- Helpers ----------

  private static Prompt_Context_Source__c child(
    Id parentId,
    String name,
    Integer sequence
  ) {
    return new Prompt_Context_Source__c(
      Prompt_Template__c = parentId,
      Reference_Name__c = name,
      Related_Object__c = 'formula',
      Max_Rows__c = 1,
      Sequence__c = sequence,
      Active__c = true,
      Source_Mode__c = 'RELATED',
      Result_Mode__c = 'RECORDS',
      Filter_Group_Join__c = 'AND'
    );
  }

  private static PromptContextDTO.TemplateConfig config(String body) {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Formula scenario';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = body;
    return config;
  }

  private static PromptContextDTO.SourceConfig rows() {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
    source.referenceName = 'rows';
    source.relatedObject = 'Prompt_Context_Source__c';
    source.correlationField = 'Prompt_Template__c';
    source.rootField = 'Id';
    source.selectedFields = new List<String>{ 'Reference_Name__c' };
    source.maxRows = 10;
    return source;
  }

  private static PromptContextDTO.SourceConfig aggregate(
    String alias,
    String operation,
    String fieldName
  ) {
    PromptContextDTO.SourceConfig source = rows();
    source.referenceName = alias;
    source.resultMode = 'AGGREGATE';
    source.aggregateOperation = operation;
    source.aggregateField = fieldName;
    source.selectedFields = new List<String>();
    source.maxRows = 1;
    return source;
  }

  private static PromptContextDTO.FilterRule filter(
    String fieldName,
    String operator,
    String value
  ) {
    PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
    rule.fieldName = fieldName;
    rule.operator = operator;
    rule.value = value;
    return rule;
  }

  private static PromptContextDTO.SortRule sortRule(
    String fieldName,
    String direction
  ) {
    PromptContextDTO.SortRule rule = new PromptContextDTO.SortRule();
    rule.fieldName = fieldName;
    rule.direction = direction;
    rule.nullsOrder = 'LAST';
    return rule;
  }

  private static PromptContextInputApi.Request request(Id recordId) {
    PromptContextInputApi.Request value = new PromptContextInputApi.Request();
    value.templateDeveloperKey = 'formula_bulk';
    value.recordId = recordId;
    value.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
    return value;
  }

  private static String generate(PromptContextDTO.TemplateConfig config) {
    return PromptContextService.generate(config, rootId(ROOT_KEY)).prompt;
  }

  private static Id rootId(String developerKey) {
    return [
      SELECT Id
      FROM Prompt_Template__c
      WHERE Developer_Key__c = :developerKey
      LIMIT 1
    ]
    .Id;
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
}
