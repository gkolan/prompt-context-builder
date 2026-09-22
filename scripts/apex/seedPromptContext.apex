List<Account> sampleAccounts = [
  SELECT Id, Name
  FROM Account
  WHERE Id IN (SELECT AccountId FROM Contact WHERE AccountId != NULL)
  ORDER BY Name
  LIMIT 1
];
if (sampleAccounts.isEmpty()) {
  Account sampleAccount = new Account(Name = 'Prompt Context Sample Account');
  insert sampleAccount;
  insert new List<Contact>{
    new Contact(
      FirstName = 'Avery',
      LastName = 'Adams',
      Email = 'avery@example.com',
      AccountId = sampleAccount.Id
    ),
    new Contact(
      FirstName = 'Jordan',
      LastName = 'Brown',
      Email = 'jordan@example.com',
      AccountId = sampleAccount.Id
    ),
    new Contact(
      FirstName = 'Morgan',
      LastName = 'Clark',
      AccountId = sampleAccount.Id
    )
  };
  sampleAccounts.add(sampleAccount);
}

PromptContextDTO.TemplateConfig config = new PromptContextDTO.TemplateConfig();
config.name = 'Account Contact Context';
config.developerKey = 'account_contact_context';
List<Prompt_Template__c> existingTemplates = [
  SELECT Id
  FROM Prompt_Template__c
  WHERE Name = :config.name
  ORDER BY CreatedDate
  LIMIT 1
];
if (!existingTemplates.isEmpty()) {
  config.id = existingTemplates[0].Id;
}
config.description = 'Starter example with two Contact sources that use different filters, limits, and sort orders.';
config.rootObject = 'Account';
config.templateBody =
  'Analyze this account context.\n\nAccount: {!record.Name}\n\n' +
  'All contacts ({!related.all_contacts.count}):\n' +
  '{!#each related.all_contacts as="row"}- {!row.Name} — {!row.Email fallback="No email"}\n{!else}No contacts found.\n{!/each}\n' +
  'Most recently created contacts with email:\n' +
  '{!#each related.contacts_with_email as="row"}- {!row.Name} — {!row.Email}\n{!else}No contacts with email.\n{!/each}';

PromptContextDTO.SourceConfig allContacts = new PromptContextDTO.SourceConfig();
allContacts.referenceName = 'all_contacts';
allContacts.sourceMode = 'RELATED';
allContacts.relatedObject = 'Contact';
allContacts.correlationField = 'AccountId';
allContacts.rootField = 'Id';
allContacts.selectedFields = new List<String>{ 'Name', 'Email' };
allContacts.maxRows = 5;
allContacts.sequence = 1;
PromptContextDTO.SortRule alphabetical = new PromptContextDTO.SortRule();
alphabetical.fieldName = 'LastName';
alphabetical.direction = 'ASC';
alphabetical.nullsOrder = 'LAST';
allContacts.sorts.add(alphabetical);
config.sources.add(allContacts);

PromptContextDTO.SourceConfig contactsWithEmail = new PromptContextDTO.SourceConfig();
contactsWithEmail.referenceName = 'contacts_with_email';
contactsWithEmail.sourceMode = 'RELATED';
contactsWithEmail.relatedObject = 'Contact';
contactsWithEmail.correlationField = 'AccountId';
contactsWithEmail.rootField = 'Id';
contactsWithEmail.selectedFields = new List<String>{
  'Name',
  'Email',
  'CreatedDate'
};
contactsWithEmail.maxRows = 3;
contactsWithEmail.sequence = 2;
PromptContextDTO.FilterRule hasEmail = new PromptContextDTO.FilterRule();
hasEmail.fieldName = 'Email';
hasEmail.operator = 'NOT_NULL';
contactsWithEmail.filters.add(hasEmail);
PromptContextDTO.SortRule newestFirst = new PromptContextDTO.SortRule();
newestFirst.fieldName = 'CreatedDate';
newestFirst.direction = 'DESC';
newestFirst.nullsOrder = 'LAST';
contactsWithEmail.sorts.add(newestFirst);
config.sources.add(contactsWithEmail);

PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(config);
PromptContextDTO.PromptResult published = PromptTemplateService.publish(
  saved.id,
  sampleAccounts[0].Id
);
System.debug(
  LoggingLevel.INFO,
  'Seeded template ' +
    saved.id +
    ' for sample Account ' +
    sampleAccounts[0].Id +
    '. Prompt length: ' +
    published.prompt.length()
);
