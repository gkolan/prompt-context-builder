// Executes every runtime sample and asserts the expected draft/inactive failures.

Account accountRecord = [
  SELECT Id
  FROM Account
  WHERE Name = 'Prompt Context Verification Account'
  LIMIT 1
];
Contact contactRecord = [
  SELECT Id
  FROM Contact
  WHERE AccountId = :accountRecord.Id AND LastName = 'Adams'
  LIMIT 1
];
List<Prompt_Template__c> templateRows = [
  SELECT Id, Name, Root_Object__c, Status__c, Version__c
  FROM Prompt_Template__c
  WHERE Name LIKE 'Verify %'
  ORDER BY Name
];
System.assertEquals(12, templateRows.size(), 'Expected the complete 12-template verification catalog.');

Integer generatedCount = 0;
Integer draftCount = 0;
Integer inactiveCount = 0;
for (Prompt_Template__c templateRow : templateRows) {
  if (templateRow.Status__c == 'Published') {
    Id recordId = templateRow.Root_Object__c == 'Contact'
      ? contactRecord.Id
      : accountRecord.Id;
    PromptContextDTO.PromptResult result = PromptTemplateService.generatePublished(
      templateRow.Id,
      recordId
    );
    System.assert(String.isNotBlank(result.prompt), templateRow.Name + ' returned a blank prompt.');
    System.assertEquals(
      Integer.valueOf(templateRow.Version__c),
      result.templateVersion,
      templateRow.Name + ' did not use its current immutable version.'
    );
    generatedCount++;
    System.debug(
      LoggingLevel.INFO,
      'CATALOG_PASS ' +
        templateRow.Name +
        ' | version=' +
        result.templateVersion +
        ' | characters=' +
        result.prompt.length() +
        ' | counts=' +
        JSON.serialize(result.sourceRecordCounts)
    );
  } else if (templateRow.Status__c == 'Draft') {
    PromptContextDTO.TemplateConfig config = PromptTemplateService.getTemplate(
      templateRow.Id
    );
    PromptContextDTO.TemplateHealth health = PromptTemplateGovernanceService.checkHealth(
      config
    );
    if (templateRow.Name.contains('Intentional Errors')) {
      System.assertEquals(false, health.isValid, 'The intentional-error draft must remain invalid.');
      System.assert(health.messages.size() >= 3, 'Expected multiple actionable validation errors.');
    } else {
      System.assertEquals(true, health.isValid, 'The inactive-source draft should otherwise be valid.');
    }
    Boolean rejectedAtRuntime = false;
    try {
      PromptTemplateService.generatePublished(templateRow.Id, accountRecord.Id);
    } catch (PromptContextException expectedException) {
      rejectedAtRuntime = true;
    }
    System.assert(rejectedAtRuntime, templateRow.Name + ' must not generate while Draft.');
    draftCount++;
    System.debug(
      LoggingLevel.INFO,
      'CATALOG_EXPECTED_DRAFT ' +
        templateRow.Name +
        ' | valid=' +
        health.isValid +
        ' | messages=' +
        JSON.serialize(health.messages)
    );
  } else if (templateRow.Status__c == 'Inactive') {
    Boolean rejectedAtRuntime = false;
    try {
      PromptTemplateService.generatePublished(templateRow.Id, accountRecord.Id);
    } catch (PromptContextException expectedException) {
      rejectedAtRuntime = true;
    }
    System.assert(rejectedAtRuntime, templateRow.Name + ' must not generate while Inactive.');
    inactiveCount++;
    System.debug(LoggingLevel.INFO, 'CATALOG_EXPECTED_INACTIVE ' + templateRow.Name);
  } else {
    System.assert(false, 'Unexpected template status: ' + templateRow.Status__c);
  }
}

System.assertEquals(9, generatedCount, 'Expected nine runtime-ready published templates.');
System.assertEquals(2, draftCount, 'Expected two deliberate draft examples.');
System.assertEquals(1, inactiveCount, 'Expected one inactive example.');

Set<Id> publishedChoiceIds = new Set<Id>();
for (
  PromptContextDTO.TemplateChoice choice : PromptTemplateService.getPublishedChoices(
    'Account'
  )
) {
  publishedChoiceIds.add(choice.id);
}
for (Prompt_Template__c templateRow : templateRows) {
  if (templateRow.Root_Object__c == 'Account') {
    System.assertEquals(
      templateRow.Status__c == 'Published',
      publishedChoiceIds.contains(templateRow.Id),
      templateRow.Name + ' had an unexpected runtime-picker visibility state.'
    );
  }
}

System.debug(
  LoggingLevel.INFO,
  'CATALOG_COMPLETE generated=' +
    generatedCount +
    ', drafts=' +
    draftCount +
    ', inactive=' +
    inactiveCount
);
