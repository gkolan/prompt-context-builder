/**
 * Runs realistic prompts against package-owned data: everyday templates, complex filter logic,
 * deep relationship paths, limits, empty data, and Unicode. Expected results are computed from the
 * fixture definition, never from the implementation.
 */
@isTest
private class PromptContextScenarioTest {
  private static final Integer ROW_COUNT = 60;
  private static final String MAIN = 'Main Root';
  private static final String EMPTY = 'Empty Root';
  private static final String UNICODE = 'Ünïcødé 😀 "q" <b>b</b> {!record.Name} $1 \\ end';
  private static final String LONG_NAME = 'L'.repeat(80);
  private static final List<String> UNICODE_ROWS = new List<String>{
    'Emoji 😀🎉',
    'مرحبا بالعالم',
    '漢字かな',
    'O\'Brien',
    '100% done',
    'a_b',
    'c\\d',
    'line1\nline2',
    'tab\there',
    '$1.00 and $2'
  };

  @TestSetup
  static void setupData() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      List<Prompt_Template__c> roots = new List<Prompt_Template__c>();
      for (String name : new List<String>{ MAIN, EMPTY, UNICODE, LONG_NAME }) {
        Prompt_Template__c root = PromptContextTestDataFactory.createRootRecord(
          false
        );
        root.Name = name;
        root.Developer_Key__c = 'scenario_' + roots.size();
        root.File_Input_Mode__c = 'USER_SELECT';
        roots.add(root);
      }
      insert roots;
      List<Prompt_Context_Source__c> rows = new List<Prompt_Context_Source__c>();
      for (Integer index = 0; index < ROW_COUNT; index++) {
        rows.add(
          new Prompt_Context_Source__c(
            Prompt_Template__c = roots[0].Id,
            Reference_Name__c = rowName(index),
            Related_Object__c = Math.mod(index, 2) == 0
              ? 'even@example.com'
              : 'odd@sample.org',
            Max_Rows__c = Math.mod(index, 10),
            Sequence__c = index,
            Active__c = Math.mod(index, 3) != 0,
            Source_Mode__c = Math.mod(index, 5) == 0 ? 'REFERENCE' : 'RELATED',
            Result_Mode__c = 'RECORDS',
            Filter_Group_Join__c = 'AND'
          )
        );
      }
      for (Integer index = 0; index < UNICODE_ROWS.size(); index++) {
        rows.add(
          new Prompt_Context_Source__c(
            Prompt_Template__c = roots[2].Id,
            Reference_Name__c = UNICODE_ROWS[index],
            Related_Object__c = 'unicode',
            Max_Rows__c = 1,
            Sequence__c = index,
            Active__c = true,
            Source_Mode__c = 'RELATED',
            Result_Mode__c = 'RECORDS',
            Filter_Group_Join__c = 'AND'
          )
        );
      }
      insert rows;
    }
  }

  // ---------- Regular templates ----------

  @isTest
  static void shouldBuildAnEverydayPromptWithEveryTokenKind() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'Account: {!record.Name}\n' +
          'Active rows: {!related.active.count}\n' +
          'Top: {!related.active[0].Reference_Name__c fallback="none"}\n' +
          '{!#each related.active as="r"}- {!r.Reference_Name__c} ({!r.Sequence__c}){!/each}\n' +
          '{!#if related.active.hasRecords}has active{!else}no active{!/if}\n' +
          'Count {!aggregate.total.value} Sum {!aggregate.limits.value} Min {!aggregate.low.value} ' +
          'Max {!aggregate.high.value}'
      );
      addSource(
        config,
        records('active', 3, 'Sequence__c', 'DESC')
          .withFilter('Active__c', 'EQ', 'true')
      );
      addSource(
        config,
        aggregate('total', 'COUNT', null).withFilter('Active__c', 'EQ', 'true')
      );
      addSource(
        config,
        aggregate('limits', 'SUM', 'Max_Rows__c')
          .withFilter('Active__c', 'EQ', 'true')
      );
      addSource(config, aggregate('low', 'MIN', 'Sequence__c'));
      addSource(config, aggregate('high', 'MAX', 'Sequence__c'));

      Integer activeCount = 0;
      Integer limitSum = 0;
      List<Integer> activeDescending = new List<Integer>();
      for (Integer index = ROW_COUNT - 1; index >= 0; index--) {
        if (Math.mod(index, 3) != 0) {
          activeCount++;
          limitSum += Math.mod(index, 10);
          activeDescending.add(index);
        }
      }
      String expectedRows = '';
      for (Integer position = 0; position < 3; position++) {
        expectedRows +=
          '- ' +
          rowName(activeDescending[position]) +
          ' (' +
          activeDescending[position] +
          ')';
      }

      PromptContextDTO.PromptResult result = generate(config, MAIN);

      Assert.areEqual(
        'Account: Main Root\n' +
          'Active rows: 3\n' +
          'Top: ' +
          rowName(activeDescending[0]) +
          '\n' +
          expectedRows +
          '\n' +
          'has active\n' +
          'Count ' +
          activeCount +
          ' Sum ' +
          limitSum +
          ' Min 0 Max ' +
          (ROW_COUNT - 1),
        result.prompt
      );
      Assert.isTrue(
        hasWarning(result, 'SOURCE_TRUNCATED'),
        'More rows matched than the limit allows.'
      );
    }
  }

  @isTest
  static void shouldKeepTwoDataSetsOnTheSameObjectIndependent() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'E:{!#each related.evens as="e"}{!e.Sequence__c},{!/each}' +
        '|O:{!#each related.odds as="o"}{!o.Sequence__c},{!/each}'
      );
      addSource(
        config,
        records('evens', 3, 'Sequence__c', 'ASC')
          .withFilter('Related_Object__c', 'STARTS_WITH', 'even')
      );
      addSource(
        config,
        records('odds', 3, 'Sequence__c', 'DESC')
          .withFilter('Related_Object__c', 'STARTS_WITH', 'odd')
      );

      Assert.areEqual('E:0,2,4,|O:59,57,55,', generate(config, MAIN).prompt);
    }
  }

  @isTest
  static void shouldReadAReferenceListIndependentOfTheCurrentRecord() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.refs as="r"}{!r.Sequence__c};{!/each}'
      );
      SourceBuilder refs = records('refs', 5, 'Sequence__c', 'ASC')
        .withFilter('Related_Object__c', 'EQ', 'odd@sample.org');
      refs.source.sourceMode = 'REFERENCE';
      refs.source.correlationField = null;
      refs.source.rootField = null;
      addSource(config, refs);

      Assert.areEqual(
        '1;3;5;7;9;',
        generate(config, EMPTY).prompt,
        'A reference list ignores which record is current.'
      );
    }
  }

  @isTest
  static void shouldApplyTenFilterNestedLogicExactly() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.picked as="r"}{!r.Sequence__c},{!/each}'
      );
      SourceBuilder picked = records('picked', 50, 'Sequence__c', 'ASC')
        .withFilter('Active__c', 'EQ', 'true') // 1
        .withFilter('Related_Object__c', 'CONTAINS', 'example') // 2
        .withFilter('Sequence__c', 'LT', '20') // 3
        .withFilter('Sequence__c', 'GTE', '40') // 4
        .withFilter('Max_Rows__c', 'IN', '1, 3, 7') // 5
        .withFilter('Source_Mode__c', 'EQ', 'REFERENCE') // 6
        .withFilter('Sequence__c', 'NOT_IN', '41,47') // 7
        .withFilter('CreatedDate', 'EQ', 'TODAY') // 8
        .withFilter('Reference_Name__c', 'STARTS_WITH', 'Row') // 9
        .withFilter('Prompt_Template__r.Name', 'EQ', MAIN); // 10
      picked.source.filterLogic = '8 AND 9 AND 10 AND ((1 AND 2 AND (3 OR 4)) OR (NOT 1 AND (5 OR 6) AND 7))';
      addSource(config, picked);

      List<String> expected = new List<String>();
      for (Integer index = 0; index < ROW_COUNT; index++) {
        Boolean active = Math.mod(index, 3) != 0;
        Boolean even = Math.mod(index, 2) == 0;
        Integer maxRows = Math.mod(index, 10);
        Boolean reference = Math.mod(index, 5) == 0;
        Boolean first = active && even && (index < 20 || index >= 40);
        Boolean second =
          !active &&
          (maxRows == 1 ||
          maxRows == 3 ||
          maxRows == 7 ||
          reference) &&
          index != 41 &&
          index != 47;
        if (first || second) {
          expected.add(String.valueOf(index));
        }
      }

      Assert.areEqual(
        String.join(expected, ',') + ',',
        generate(config, MAIN).prompt,
        'Rendered rows must equal an independent evaluation of the logic.'
      );
    }
  }

  @isTest
  static void shouldReuseOneFilterSeveralTimesInLogic() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!related.picked.count}'
      );
      SourceBuilder picked = records('picked', 50, 'Sequence__c', 'ASC')
        .withFilter('Sequence__c', 'LT', '10')
        .withFilter('Active__c', 'EQ', 'true');
      picked.source.filterLogic = '(1 AND 2) OR (1 AND NOT 2)';
      addSource(config, picked);

      Assert.areEqual('10', generate(config, MAIN).prompt);
    }
  }

  @isTest
  static void shouldFilterAndSortThroughParentRelationships() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.byParent as="r"}{!r.Prompt_Template__r.Name}:{!r.Sequence__c};{!/each}'
      );
      SourceBuilder byParent = records(
          'byParent',
          2,
          'Prompt_Template__r.Name',
          'ASC'
        )
        .withFilter('Prompt_Template__r.Name', 'EQ', MAIN)
        .withFilter('Prompt_Template__r.CreatedBy.IsActive', 'EQ', 'true');
      byParent.source.selectedFields.add('Prompt_Template__r.Name');
      byParent.source.sorts.add(sort('Sequence__c', 'DESC'));
      addSource(config, byParent);

      Assert.areEqual(
        MAIN + ':59;' + MAIN + ':58;',
        generate(config, MAIN).prompt
      );
    }
  }

  @isTest
  static void shouldResolveFourAndFiveRelationshipPaths() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Prompt_Input_Log__c log = savedInputLog();
      PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
      config.name = 'Deep paths';
      config.rootObject = 'Prompt_Input_Log__c';
      config.templateBody =
        '{!record.Prompt_Template_Version__r.Prompt_Template__r.CreatedBy.Profile.Name}|' +
        '{!record.Prompt_Template_Version__r.Prompt_Template__r.CreatedBy.Manager.Profile.Name fallback="no manager"}';

      PromptContextDTO.PromptResult result = PromptContextService.generate(
        config,
        log.Id
      );

      String profileName = [
        SELECT Profile.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ]
      .Profile.Name;
      Assert.isTrue(
        result.prompt.startsWith(profileName + '|'),
        'A four-relationship path must resolve: ' + result.prompt
      );
    }
  }

  @isTest
  static void shouldRejectASixRelationshipPath() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
      config.name = 'Too deep';
      config.rootObject = 'Prompt_Input_Log__c';
      config.templateBody = '{!record.Prompt_Template_Version__r.Prompt_Template__r.CreatedBy.Manager.Manager.Profile.Name}';

      Assert.isFalse(PromptContextValidator.validate(config).isValid);
    }
  }

  @isTest
  static void shouldPrintPicklistLabelsInsideLoops() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.modes as="r"}{!r.Source_Mode__c};{!/each}'
      );
      SourceBuilder modes = records('modes', 2, 'Sequence__c', 'ASC')
        .withFilter('Sequence__c', 'IN', '0,1');
      modes.source.selectedFields.add('Source_Mode__c');
      addSource(config, modes);

      Assert.areEqual(
        'Reference records;Related to current record;',
        generate(config, MAIN).prompt
      );
    }
  }

  // ---------- Edge cases ----------

  @isTest
  static void shouldRenderEveryEmptyStateCleanly() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'C={!related.rows.count};I={!related.rows[0].Reference_Name__c fallback="none"};' +
          'E={!#each related.rows as="r"}{!r.Reference_Name__c}{!else}empty{!/each};' +
          'F={!#if related.rows.hasRecords}yes{!else}no{!/if};' +
          'N={!aggregate.n.value};S={!aggregate.s.value fallback="0"};' +
          'X={!aggregate.x.value fallback="-"}'
      );
      addSource(config, records('rows', 5, 'Sequence__c', 'ASC'));
      addSource(config, aggregate('n', 'COUNT', null));
      addSource(config, aggregate('s', 'SUM', 'Max_Rows__c'));
      addSource(config, aggregate('x', 'MAX', 'Sequence__c'));

      Assert.areEqual(
        'C=0;I=none;E=empty;F=no;N=0;S=0;X=-',
        generate(config, EMPTY).prompt
      );
    }
  }

  @isTest
  static void shouldPassUnicodeAndSpecialCharactersThroughUnchanged() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '[{!record.Name}]{!#each related.rows as="r"}<{!r.Reference_Name__c}>{!/each}'
      );
      addSource(config, records('rows', 20, 'Sequence__c', 'ASC'));

      // Salesforce stores a newline typed into a single-line text field as a space, so compare
      // with what was actually saved.
      String expected = '[' + UNICODE + ']';
      for (Prompt_Context_Source__c row : [
        SELECT Reference_Name__c
        FROM Prompt_Context_Source__c
        WHERE Related_Object__c = 'unicode'
        ORDER BY Sequence__c ASC
      ]) {
        expected += '<' + row.Reference_Name__c + '>';
      }

      Assert.areEqual(expected, generate(config, UNICODE).prompt);
    }
  }

  @isTest
  static void shouldNeverSplitAnEmojiWhenShortening() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.rows as="r"}{!r.Reference_Name__c maxLength="7"}|{!/each}'
      );
      addSource(
        config,
        records('rows', 1, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'STARTS_WITH', 'Emoji')
      );

      String prompt = generate(config, UNICODE).prompt;

      for (Integer index = 0; index < prompt.length(); index++) {
        Integer unit = prompt.charAt(index);
        Boolean high = unit >= 55296 && unit <= 56319;
        Boolean low = unit >= 56320 && unit <= 57343;
        if (high) {
          Integer next = index + 1 < prompt.length()
            ? prompt.charAt(index + 1)
            : 0;
          Assert.isTrue(
            next >= 56320 && next <= 57343,
            'A shortened value must not end with half an emoji: ' + prompt
          );
          index++;
        } else {
          Assert.isFalse(low, 'A lone low surrogate is invalid text.');
        }
      }
      Assert.isTrue(prompt.startsWith('Emoji '), prompt);
    }
  }

  @isTest
  static void shouldTreatLikeWildcardsAndQuotesAsLiteralText() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'P={!related.pct.count};U={!related.under.count};Q={!related.quote.count};' +
        'B={!related.slash.count};I={!related.inject.count}'
      );
      addSource(
        config,
        records('pct', 20, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'CONTAINS', '%')
      );
      addSource(
        config,
        records('under', 20, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'CONTAINS', '_')
      );
      addSource(
        config,
        records('quote', 20, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'EQ', 'O\'Brien')
      );
      addSource(
        config,
        records('slash', 20, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'CONTAINS', '\\')
      );
      addSource(
        config,
        records('inject', 20, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'EQ', '\' OR Name != \'')
      );

      Assert.areEqual('P=1;U=1;Q=1;B=1;I=0', generate(config, UNICODE).prompt);
    }
  }

  @isTest
  static void shouldAllowAPromptOfExactlyTheCharacterLimit() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Integer padding =
        PromptContextContract.MAX_PROMPT_CHARACTERS - LONG_NAME.length();
      PromptContextDTO.TemplateConfig config = config(
        'x'.repeat(padding) + '{!record.Name}'
      );

      Assert.areEqual(
        PromptContextContract.MAX_PROMPT_CHARACTERS,
        generate(config, LONG_NAME).prompt.length()
      );
    }
  }

  @isTest
  static void shouldRefuseAPromptOneCharacterOverTheLimit() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      Integer padding =
        PromptContextContract.MAX_PROMPT_CHARACTERS -
        LONG_NAME.length() -
        1;
      PromptContextDTO.TemplateConfig config = config(
        'x'.repeat(padding) + '{!record.Name}!!'
      );

      try {
        generate(config, LONG_NAME);
        Assert.fail('A prompt over the limit must not be returned.');
      } catch (PromptContextException expected) {
        Assert.isTrue(
          expected.getMessage()
            .contains(PromptContextContract.MAX_PROMPT_CHARACTERS.format())
        );
      }
    }
  }

  @isTest
  static void shouldCapRowsPerDataSetAndAcrossThePrompt() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'A{!related.a.count} B{!related.b.count} C{!related.c.count} D{!related.d.count} E{!related.e.count}'
      );
      for (String alias : new List<String>{ 'a', 'b', 'c', 'd', 'e' }) {
        addSource(
          config,
          records(
            alias,
            PromptContextContract.MAX_ROWS_PER_SOURCE,
            'Sequence__c',
            'ASC'
          )
        );
      }

      PromptContextDTO.PromptResult result = generate(config, MAIN);

      Assert.areEqual('A50 B50 C50 D50 E0', result.prompt);
      Assert.isTrue(hasWarning(result, 'SOURCE_TRUNCATED'));
      Assert.isTrue(
        hasWarning(result, 'TOTAL_ROW_LIMIT'),
        'The fifth data set must report the combined cap.'
      );
    }
  }

  @isTest
  static void shouldRenderConditionalsNestedInsideLoopsAndEachOther() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.rows as="r"}[{!#if related.rows.hasRecords}' +
          '{!#if related.none.hasRecords}bad{!else}{!#if related.rows.hasRecords}{!r.Sequence__c}{!/if}{!/if}' +
          '{!/if}]{!/each}'
      );
      addSource(config, records('rows', 3, 'Sequence__c', 'ASC'));
      addSource(
        config,
        records('none', 1, 'Sequence__c', 'ASC')
          .withFilter('Reference_Name__c', 'EQ', 'no such row')
      );

      Assert.areEqual('[0][1][2]', generate(config, MAIN).prompt);
    }
  }

  @isTest
  static void shouldRenderALoopWithAVeryLargeBody() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      String filler = 'Long instruction text. '.repeat(600);
      PromptContextDTO.TemplateConfig config = config(
        '{!#each related.rows as="r"}' + filler + '{!r.Sequence__c}{!/each}'
      );
      addSource(config, records('rows', 1, 'Sequence__c', 'ASC'));

      Assert.areEqual(filler + '0', generate(config, MAIN).prompt);
    }
  }

  @isTest
  static void shouldHandleTheMaximumNumberOfMergeFields() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      String token = '{!record.Name}';
      Integer count =
        PromptContextContract.MAX_TEMPLATE_CHARACTERS / token.length();
      PromptContextDTO.TemplateConfig config = config(token.repeat(count));

      Assert.areEqual(
        MAIN.repeat(count),
        generate(config, MAIN).prompt,
        'A template made only of merge fields must render within limits.'
      );
    }
  }

  @isTest
  static void shouldKeepLineBreaksTabsAndDollarSignsExactly() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      PromptContextDTO.TemplateConfig config = config(
        'a\r\n\tb $0 $1 \\1 {!record.Name}\r\n'
      );

      Assert.areEqual(
        'a\r\n\tb $0 $1 \\1 Main Root\r\n',
        generate(config, MAIN).prompt
      );
    }
  }

  @isTest
  static void shouldPrepareTwoHundredComplexPromptsInOneBulkCall() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      grantAll();
      PromptContextDTO.TemplateConfig config = config(
        '{!record.Name}|{!related.rows.count}|{!aggregate.total.value}|' +
        '{!#each related.rows as="r"}{!r.Reference_Name__c};{!/each}'
      );
      SourceBuilder rows = records('rows', 3, 'Sequence__c', 'ASC')
        .withFilter('Active__c', 'EQ', 'true')
        .withFilter('Reference_Name__c', 'STARTS_WITH', 'Row');
      rows.source.filterLogic = '1 OR 2';
      addSource(config, rows);
      addSource(config, aggregate('total', 'COUNT', null));
      config.developerKey = 'scenario_bulk';
      PromptTemplateService.publish(
        PromptTemplateService.saveDraft(config).id,
        rootId(MAIN)
      );
      List<Prompt_Template__c> roots = PromptContextTestDataFactory.createRootRecords(
        PromptContextContract.MAX_RECORDS_PER_REQUEST - 1
      );
      roots.add(new Prompt_Template__c(Id = rootId(MAIN)));
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
      for (Prompt_Template__c root : roots) {
        PromptContextInputApi.Request request = new PromptContextInputApi.Request();
        request.templateDeveloperKey = 'scenario_bulk';
        request.recordId = root.Id;
        request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
        requests.add(request);
      }

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepare(
        requests
      );
      Test.stopTest();

      Map<String, Integer> outcomes = new Map<String, Integer>();
      for (PromptContextInputApi.Result result : results) {
        outcomes.put(
          result.reasonCode,
          (outcomes.get(result.reasonCode) ?? 0) + 1
        );
      }
      Assert.areEqual(
        new Map<String, Integer>{
          'SUCCESS' => PromptContextContract.MAX_RECORDS_PER_REQUEST
        },
        outcomes,
        'Every record in a full bulk call must be prepared.'
      );
      Assert.areEqual(
        MAIN +
          '|3|' +
          ROW_COUNT +
          '|' +
          rowName(0) +
          ';' +
          rowName(1) +
          ';' +
          rowName(2) +
          ';',
        results[results.size() - 1].prompt
      );
    }
  }

  // ---------- Helpers ----------

  private class SourceBuilder {
    PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();

    SourceBuilder withFilter(String fieldName, String operator, String value) {
      PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
      rule.fieldName = fieldName;
      rule.operator = operator;
      rule.value = value;
      source.filters.add(rule);
      return this;
    }
  }

  private static SourceBuilder records(
    String alias,
    Integer maxRows,
    String sortField,
    String direction
  ) {
    SourceBuilder builder = new SourceBuilder();
    builder.source.referenceName = alias;
    builder.source.relatedObject = 'Prompt_Context_Source__c';
    builder.source.correlationField = 'Prompt_Template__c';
    builder.source.rootField = 'Id';
    builder.source.selectedFields = new List<String>{
      'Reference_Name__c',
      'Sequence__c'
    };
    builder.source.maxRows = maxRows;
    builder.source.sorts.add(sort(sortField, direction));
    return builder;
  }

  private static SourceBuilder aggregate(
    String alias,
    String operation,
    String fieldName
  ) {
    SourceBuilder builder = records(alias, 1, 'Sequence__c', 'ASC');
    builder.source.resultMode = 'AGGREGATE';
    builder.source.aggregateOperation = operation;
    builder.source.aggregateField = fieldName;
    builder.source.selectedFields = new List<String>();
    builder.source.sorts.clear();
    return builder;
  }

  private static PromptContextDTO.SortRule sort(
    String fieldName,
    String direction
  ) {
    PromptContextDTO.SortRule rule = new PromptContextDTO.SortRule();
    rule.fieldName = fieldName;
    rule.direction = direction;
    rule.nullsOrder = 'LAST';
    return rule;
  }

  private static PromptContextDTO.TemplateConfig config(String body) {
    PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
    config.name = 'Scenario';
    config.rootObject = 'Prompt_Template__c';
    config.templateBody = body;
    return config;
  }

  private static void addSource(
    PromptContextDTO.TemplateConfig config,
    SourceBuilder builder
  ) {
    config.sources.add(builder.source);
  }

  private static void grantAll() {
    PromptContextAccess.setConfigureForTest(true);
    PromptContextAccess.setGenerateForTest(true);
    PromptContextAccess.setSaveInputForTest(true);
  }

  private static PromptContextDTO.PromptResult generate(
    PromptContextDTO.TemplateConfig config,
    String rootName
  ) {
    return PromptContextService.generate(config, rootId(rootName));
  }

  private static Id rootId(String rootName) {
    return [
      SELECT Id
      FROM Prompt_Template__c
      WHERE Name = :rootName AND Developer_Key__c LIKE 'scenario_%'
      LIMIT 1
    ]
    .Id;
  }

  private static String rowName(Integer index) {
    return 'Row ' + String.valueOf(index).leftPad(2, '0');
  }

  private static Boolean hasWarning(
    PromptContextDTO.PromptResult result,
    String code
  ) {
    for (PromptContextDTO.Message message : result.messages) {
      if (message.code == code) {
        return true;
      }
    }
    return false;
  }

  private static Prompt_Input_Log__c savedInputLog() {
    grantAll();
    PromptContextDTO.TemplateConfig config = config('{!record.Name}');
    config.developerKey = 'scenario_log';
    PromptTemplateService.publish(
      PromptTemplateService.saveDraft(config).id,
      rootId(MAIN)
    );
    PromptContextInputApi.Request request = new PromptContextInputApi.Request();
    request.templateDeveloperKey = 'scenario_log';
    request.recordId = rootId(MAIN);
    request.deliveryChoice = PromptContextInputApi.SAVE_TO_LOG;
    request.requestKey = 'scenario-log';
    Id logId = PromptContextInputApi.prepare(
        new List<PromptContextInputApi.Request>{ request }
      )[0]
      .inputLogId;
    return [SELECT Id FROM Prompt_Input_Log__c WHERE Id = :logId];
  }

  @isTest
  static void shouldStayWithinLimitsForTwoHundredRecordsWithFiveDataSets() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      grantAll();
      PromptContextDTO.TemplateConfig config = config(
        '{!record.Name maxLength="40"}\n' +
          '{!#each related.a as="r"}{!r.Reference_Name__c}:{!r.Sequence__c};{!/each}\n' +
          '{!#each related.b as="r"}{!r.Reference_Name__c};{!else}none{!/each}\n' +
          'First {!related.c[0].Reference_Name__c fallback="-"} of {!related.c.count}\n' +
          'Total {!aggregate.n.value} Sum {!aggregate.s.value fallback="0"}'
      );
      SourceBuilder a = records('a', 5, 'Sequence__c', 'DESC')
        .withFilter('Active__c', 'EQ', 'true')
        .withFilter('Sequence__c', 'LT', '4')
        .withFilter('Reference_Name__c', 'STARTS_WITH', 'Stress');
      a.source.filterLogic = '3 AND (1 AND 2)';
      addSource(config, a);
      addSource(
        config,
        records('b', 3, 'Reference_Name__c', 'ASC')
          .withFilter('Sequence__c', 'IN', '0,2,4')
      );
      addSource(
        config,
        records('c', 1, 'Sequence__c', 'ASC')
          .withFilter('CreatedDate', 'EQ', 'TODAY')
      );
      addSource(config, aggregate('n', 'COUNT', null));
      addSource(
        config,
        aggregate('s', 'SUM', 'Sequence__c')
          .withFilter('Active__c', 'EQ', 'true')
      );
      config.developerKey = 'scenario_stress';
      PromptTemplateService.publish(
        PromptTemplateService.saveDraft(config).id,
        rootId(MAIN)
      );
      List<Prompt_Template__c> roots = PromptContextTestDataFactory.createRootRecords(
        PromptContextContract.MAX_RECORDS_PER_REQUEST
      );
      List<Prompt_Context_Source__c> children = new List<Prompt_Context_Source__c>();
      for (Prompt_Template__c root : roots) {
        for (Integer index = 0; index < 5; index++) {
          children.add(
            new Prompt_Context_Source__c(
              Prompt_Template__c = root.Id,
              Reference_Name__c = 'Stress ' + index,
              Related_Object__c = 'stress',
              Max_Rows__c = 1,
              Sequence__c = index,
              Active__c = Math.mod(index, 2) == 0,
              Source_Mode__c = 'RELATED',
              Result_Mode__c = 'RECORDS',
              Filter_Group_Join__c = 'AND'
            )
          );
        }
      }
      insert children;
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
      for (Prompt_Template__c root : roots) {
        PromptContextInputApi.Request request = new PromptContextInputApi.Request();
        request.templateDeveloperKey = 'scenario_stress';
        request.recordId = root.Id;
        request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
        requests.add(request);
      }

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepareForFlow(
        requests
      );
      Integer cpu = Limits.getCpuTime();
      Integer heap = Limits.getHeapSize();
      Integer queries = Limits.getQueries();
      Test.stopTest();

      Map<String, Integer> outcomes = new Map<String, Integer>();
      for (PromptContextInputApi.Result result : results) {
        outcomes.put(
          result.reasonCode,
          (outcomes.get(result.reasonCode) ?? 0) + 1
        );
      }
      Assert.areEqual(
        new Map<String, Integer>{ 'SUCCESS' => roots.size() },
        outcomes,
        'Every record must be prepared. cpu=' +
          cpu +
          ' heap=' +
          heap +
          ' queries=' +
          queries
      );
      Assert.areEqual(
        'Stress 2:2;Stress 0:0;',
        results[0].prompt.split('\n')[1],
        'Filter logic must hold for every record in bulk.'
      );
      Assert.isTrue(
        results[0].prompt.endsWith('Total 5 Sum 6'),
        results[0].prompt
      );
      Assert.isTrue(
        cpu < Limits.getLimitCpuTime() / 2 &&
          heap < Limits.getLimitHeapSize() / 2,
        'A full bulk call must leave half the transaction for the caller. cpu=' +
          cpu +
          ' heap=' +
          heap +
          ' queries=' +
          queries
      );
    }
  }

  @isTest
  static void shouldApplyEachTemplatesOwnRulesInOneMixedBulkCall() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      grantAll();
      Id v2Template = insertPublication('mixed_v2', 2);
      Id v1Template = insertPublication('mixed_v1', 1);
      Id mainId = rootId(MAIN);
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
      for (
        String key : new List<String>{
          'mixed_v2',
          'mixed_v1',
          'mixed_v2',
          'mixed_v1'
        }
      ) {
        PromptContextInputApi.Request request = new PromptContextInputApi.Request();
        request.templateDeveloperKey = key;
        request.recordId = mainId;
        request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
        requests.add(request);
      }

      Test.startTest();
      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepareForFlow(
        requests
      );
      Test.stopTest();

      Assert.areEqual('Mode: User Selects Files', results[0].prompt);
      Assert.areEqual('Mode: USER_SELECT', results[1].prompt);
      Assert.areEqual(
        results[0].prompt,
        results[2].prompt,
        'A later group must not inherit another template\'s rules.'
      );
      Assert.areEqual(results[1].prompt, results[3].prompt);
      Assert.areEqual(2, results[0].syntaxVersion);
      Assert.areEqual(1, results[1].syntaxVersion);
      Assert.isNotNull(v2Template);
      Assert.isNotNull(v1Template);
    }
  }

  @isTest
  static void shouldRefuseMoreThanTenTemplatesInOneTransaction() {
    System.runAs(PromptContextTestDataFactory.createConfiguratorUser()) {
      grantAll();
      Id mainId = rootId(MAIN);
      List<PromptContextInputApi.Request> requests = new List<PromptContextInputApi.Request>();
      for (
        Integer index = 0;
        index <= PromptContextContract.MAX_FLOW_GROUPS;
        index++
      ) {
        insertPublication('many_' + index, 2);
        PromptContextInputApi.Request request = new PromptContextInputApi.Request();
        request.templateDeveloperKey = 'many_' + index;
        request.recordId = mainId;
        request.deliveryChoice = PromptContextInputApi.RETURN_TO_APEX;
        requests.add(request);
      }

      List<PromptContextInputApi.Result> results = PromptContextInputApi.prepareForFlow(
        requests
      );

      for (PromptContextInputApi.Result result : results) {
        Assert.areEqual(
          PromptContextReasonCodes.FLOW_GROUP_LIMIT_EXCEEDED,
          result.reasonCode
        );
        Assert.isNull(result.prompt);
      }
    }
  }

  /** Inserts a published template and its fixed version directly, with a chosen syntax version. */
  private static Id insertPublication(
    String developerKey,
    Integer syntaxVersion
  ) {
    String body = 'Mode: {!record.File_Input_Mode__c}';
    Datetime publishedAt = Datetime.newInstanceGmt(2026, 9, 1, 0, 0, 0);
    Prompt_Template__c templateRecord = new Prompt_Template__c(
      Name = developerKey,
      Developer_Key__c = developerKey,
      Root_Object__c = 'Prompt_Template__c',
      Template_Body__c = body,
      Status__c = 'Published',
      Version__c = 1,
      Published_At__c = publishedAt,
      File_Input_Mode__c = 'DISABLED'
    );
    insert templateRecord;
    insert new Prompt_Template_Version__c(
      Prompt_Template__c = templateRecord.Id,
      Version_Key__c = developerKey + ':1',
      Version_Number__c = 1,
      Syntax_Version__c = syntaxVersion,
      Contract_Version__c = PromptContextContract.CONTRACT_VERSION,
      Root_Object__c = 'Prompt_Template__c',
      Template_Body__c = body,
      Fingerprint__c = developerKey,
      Published_At__c = publishedAt,
      File_Input_Mode__c = 'DISABLED'
    );
    return templateRecord.Id;
  }
}
