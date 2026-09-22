Prompt_Template__c templateRecord = [
  SELECT Id
  FROM Prompt_Template__c
  WHERE Name = 'Account Contact Context' AND Status__c = 'Published'
  ORDER BY CreatedDate
  LIMIT 1
];
Account sampleAccount = [
  SELECT Id
  FROM Account
  WHERE Id IN (SELECT AccountId FROM Contact WHERE AccountId != NULL)
  ORDER BY Name
  LIMIT 1
];

PromptContextDTO.PromptResult result = PromptTemplateService.generatePublished(
  templateRecord.Id,
  sampleAccount.Id
);

System.Assert.isNotNull(
  result.prompt,
  'The generated prompt must not be null.'
);
System.Assert(
  result.prompt.length() > 0,
  'The generated prompt must not be empty.'
);
System.Assert.isNotNull(
  result.fingerprint,
  'Published generation must return its fingerprint.'
);
System.Assert(
  result.templateVersion >= 1,
  'The seeded template should have at least one published version.'
);
System.Assert(result.sourceRecordCounts.containsKey('all_contacts'));
System.Assert(result.sourceRecordCounts.containsKey('contacts_with_email'));
System.Assert(
  result.sourceRecordCounts.get('all_contacts') >=
  result.sourceRecordCounts.get('contacts_with_email'),
  'The filtered source cannot contain more records than the unfiltered source.'
);

System.debug(
  LoggingLevel.INFO,
  'Prompt Context Builder verification passed. Prompt length: ' +
    result.prompt.length() +
    '; source aliases: ' +
    result.sourceRecordCounts.keySet().size()
);
