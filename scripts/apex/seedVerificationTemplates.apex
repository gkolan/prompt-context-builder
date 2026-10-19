// Creates an idempotent administrator verification catalog.
// Valid examples are published; intentionally invalid examples remain Draft.

List<Account> accounts = [
  SELECT Id, Name
  FROM Account
  WHERE Name = 'Prompt Context Verification Account'
  LIMIT 1
];
Account accountRecord = accounts.isEmpty()
  ? new Account(Name = 'Prompt Context Verification Account')
  : accounts[0];
accountRecord.Industry = 'Technology';
accountRecord.Phone = '312-555-0100';
accountRecord.Website = 'https://example.com';
accountRecord.Description = 'Deterministic sample data for Prompt Context Builder verification.';
accountRecord.NumberOfEmployees = 125;
upsert accountRecord;

Map<String, Contact> contactsByLastName = new Map<String, Contact>();
for (Contact row : [
  SELECT Id, FirstName, LastName
  FROM Contact
  WHERE
    AccountId = :accountRecord.Id
    AND LastName IN ('Adams', 'Brown', 'Clark')
]) {
  contactsByLastName.put(row.LastName, row);
}
List<Contact> contacts = new List<Contact>();
Contact adams = contactsByLastName.containsKey('Adams')
  ? contactsByLastName.get('Adams')
  : new Contact(LastName = 'Adams');
adams.FirstName = 'Avery';
adams.Title = 'Director';
adams.Email = 'avery@example.com';
adams.Phone = '312-555-0101';
adams.AccountId = accountRecord.Id;
contacts.add(adams);
Contact brown = contactsByLastName.containsKey('Brown')
  ? contactsByLastName.get('Brown')
  : new Contact(LastName = 'Brown');
brown.FirstName = 'Jordan';
brown.Title = 'Manager';
brown.Email = 'jordan@example.com';
brown.Phone = null;
brown.AccountId = accountRecord.Id;
contacts.add(brown);
Contact clark = contactsByLastName.containsKey('Clark')
  ? contactsByLastName.get('Clark')
  : new Contact(LastName = 'Clark');
clark.FirstName = 'Morgan';
clark.Title = 'Analyst';
clark.Email = null;
clark.Phone = '312-555-0103';
clark.AccountId = accountRecord.Id;
contacts.add(clark);
upsert contacts;

Map<String, Prompt_Template__c> existingByName = new Map<String, Prompt_Template__c>();
for (Prompt_Template__c row : [
  SELECT Id, Name
  FROM Prompt_Template__c
  WHERE Name LIKE 'Verify %'
]) {
  existingByName.put(row.Name, row);
}
List<PromptContextDTO.TemplateConfig> catalog = new List<PromptContextDTO.TemplateConfig>();

PromptContextDTO.TemplateConfig mergeSyntax = new PromptContextDTO.TemplateConfig();
mergeSyntax.name = 'Verify 01 - Merge Syntax';
mergeSyntax.developerKey = 'verify_01_merge_syntax';
mergeSyntax.description = 'Root fields, indexed rows, count, loops, conditions, fallback, case, and percent formatting.';
mergeSyntax.rootObject = 'Account';
mergeSyntax.templateBody =
  'Account: {!record.Name}\n' +
  'Upper: {!record.Name format="upper"}\n' +
  'Lower: {!record.Name format="lower"}\n' +
  'Fallback: {!record.BillingCity fallback="No city"}\n' +
  'Percent format: {!record.NumberOfEmployees format="percent"}\n' +
  'Count: {!related.contacts.count}\n' +
  'First: {!related.contacts[0].Name fallback="No first contact"}\n' +
  '{!#if related.contacts.hasRecords}Contacts are available.{!else}No contacts.{!/if}\n' +
  '{!#each related.contacts as="row"}- {!row.Name}: {!row.Email fallback="No email"}\n{!else}No rows.{!/each}';
PromptContextDTO.SourceConfig mergeContacts = new PromptContextDTO.SourceConfig();
mergeContacts.referenceName = 'contacts';
mergeContacts.relatedObject = 'Contact';
mergeContacts.correlationField = 'AccountId';
mergeContacts.selectedFields = new List<String>{
  'Name',
  'Email',
  'Phone',
  'Title'
};
mergeContacts.maxRows = 10;
PromptContextDTO.SortRule mergeSort = new PromptContextDTO.SortRule();
mergeSort.fieldName = 'LastName';
mergeSort.direction = 'ASC';
mergeSort.nullsOrder = 'LAST';
mergeContacts.sorts.add(mergeSort);
mergeSyntax.sources.add(mergeContacts);
catalog.add(mergeSyntax);

PromptContextDTO.TemplateConfig textFilters = new PromptContextDTO.TemplateConfig();
textFilters.name = 'Verify 02 - Text and Null Filters';
textFilters.developerKey = 'verify_02_text_null_filters';
textFilters.description = 'EQ, NE, CONTAINS, STARTS_WITH, NOT_NULL, named groups, and OR group joining.';
textFilters.rootObject = 'Account';
textFilters.templateBody = '{!#each related.matches as="row"}{!row.Name} | {!row.Email fallback="No email"} | {!row.Phone fallback="No phone"}\n{!else}No matches.{!/each}';
PromptContextDTO.SourceConfig matchSource = new PromptContextDTO.SourceConfig();
matchSource.referenceName = 'matches';
matchSource.relatedObject = 'Contact';
matchSource.correlationField = 'AccountId';
matchSource.selectedFields = new List<String>{ 'Name', 'Email', 'Phone' };
matchSource.filterGroupJoin = 'OR';
List<List<String>> textRules = new List<List<String>>{
  new List<String>{ 'LastName', 'EQ', 'Adams', 'exact_name' },
  new List<String>{ 'FirstName', 'NE', 'Blocked', 'not_blocked' },
  new List<String>{ 'Email', 'CONTAINS', '@example.com', 'email_domain' },
  new List<String>{ 'LastName', 'STARTS_WITH', 'B', 'starts_b' },
  new List<String>{ 'Phone', 'NOT_NULL', null, 'has_phone' }
};
for (List<String> ruleValues : textRules) {
  PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
  rule.fieldName = ruleValues[0];
  rule.operator = ruleValues[1];
  rule.value = ruleValues[2];
  rule.groupName = ruleValues[3];
  matchSource.filters.add(rule);
}
textFilters.sources.add(matchSource);
catalog.add(textFilters);

PromptContextDTO.TemplateConfig rangeFilters = new PromptContextDTO.TemplateConfig();
rangeFilters.name = 'Verify 03 - Range and Blank Filters';
rangeFilters.developerKey = 'verify_03_range_blank_filters';
rangeFilters.description = 'GT, GTE, LT, LTE, IS_NULL, date-time conversion, and five filter groups.';
rangeFilters.rootObject = 'Account';
rangeFilters.templateBody = '{!#each related.ranged as="row"}- {!row.Name} created {!row.CreatedDate}\n{!else}No rows.{!/each}';
PromptContextDTO.SourceConfig ranged = new PromptContextDTO.SourceConfig();
ranged.referenceName = 'ranged';
ranged.relatedObject = 'Contact';
ranged.correlationField = 'AccountId';
ranged.selectedFields = new List<String>{ 'Name', 'CreatedDate' };
ranged.filterGroupJoin = 'AND';
List<List<String>> rangeRules = new List<List<String>>{
  new List<String>{ 'CreatedDate', 'GT', '2000-01-01T00:00:00Z', 'after_2000' },
  new List<String>{ 'CreatedDate', 'GTE', '2000-01-01T00:00:00Z', 'from_2000' },
  new List<String>{
    'CreatedDate',
    'LT',
    '2100-01-01T00:00:00Z',
    'before_2100'
  },
  new List<String>{
    'CreatedDate',
    'LTE',
    '2100-01-01T00:00:00Z',
    'through_2100'
  },
  new List<String>{ 'Email', 'IS_NULL', null, 'no_email' }
};
for (List<String> ruleValues : rangeRules) {
  PromptContextDTO.FilterRule rule = new PromptContextDTO.FilterRule();
  rule.fieldName = ruleValues[0];
  rule.operator = ruleValues[1];
  rule.value = ruleValues[2];
  rule.groupName = ruleValues[3];
  ranged.filters.add(rule);
}
rangeFilters.sources.add(ranged);
catalog.add(rangeFilters);

PromptContextDTO.TemplateConfig sorting = new PromptContextDTO.TemplateConfig();
sorting.name = 'Verify 04 - Independent Sorting';
sorting.developerKey = 'verify_04_independent_sorting';
sorting.description = 'Two sources for the same object with independent fields, filters, limits, and sort/null ordering.';
sorting.rootObject = 'Account';
sorting.templateBody =
  'Email order:\n{!#each related.email_order as="row"}- {!row.Name}: {!row.Email fallback="No email"}\n{!/each}' +
  'Newest order:\n{!#each related.newest_order as="row"}- {!row.Name}: {!row.CreatedDate}\n{!/each}';
PromptContextDTO.SourceConfig emailOrder = new PromptContextDTO.SourceConfig();
emailOrder.referenceName = 'email_order';
emailOrder.relatedObject = 'Contact';
emailOrder.correlationField = 'AccountId';
emailOrder.selectedFields = new List<String>{ 'Name', 'Email' };
emailOrder.maxRows = 2;
PromptContextDTO.SortRule emailSort = new PromptContextDTO.SortRule();
emailSort.fieldName = 'Email';
emailSort.direction = 'ASC';
emailSort.nullsOrder = 'FIRST';
emailOrder.sorts.add(emailSort);
sorting.sources.add(emailOrder);
PromptContextDTO.SourceConfig newestOrder = new PromptContextDTO.SourceConfig();
newestOrder.referenceName = 'newest_order';
newestOrder.relatedObject = 'Contact';
newestOrder.correlationField = 'AccountId';
newestOrder.selectedFields = new List<String>{ 'Name', 'CreatedDate' };
newestOrder.maxRows = 3;
PromptContextDTO.SortRule createdSort = new PromptContextDTO.SortRule();
createdSort.fieldName = 'CreatedDate';
createdSort.direction = 'DESC';
createdSort.nullsOrder = 'LAST';
newestOrder.sorts.add(createdSort);
sorting.sources.add(newestOrder);
catalog.add(sorting);

PromptContextDTO.TemplateConfig referenceScope = new PromptContextDTO.TemplateConfig();
referenceScope.name = 'Verify 05 - Reference Scope';
referenceScope.developerKey = 'verify_05_reference_scope';
referenceScope.description = 'A bounded non-correlated reference list, still constrained by user-mode security.';
referenceScope.rootObject = 'Account';
referenceScope.templateBody = 'Current: {!record.Name}\nReference accounts:\n{!#each related.accounts as="row"}- {!row.Name} ({!row.Industry fallback="No industry"})\n{!else}No accessible accounts.{!/each}';
PromptContextDTO.SourceConfig referenceAccounts = new PromptContextDTO.SourceConfig();
referenceAccounts.referenceName = 'accounts';
referenceAccounts.sourceMode = 'REFERENCE';
referenceAccounts.relatedObject = 'Account';
referenceAccounts.correlationField = null;
referenceAccounts.rootField = null;
referenceAccounts.selectedFields = new List<String>{ 'Name', 'Industry' };
referenceAccounts.maxRows = 5;
PromptContextDTO.SortRule accountSort = new PromptContextDTO.SortRule();
accountSort.fieldName = 'Name';
accountSort.direction = 'ASC';
accountSort.nullsOrder = 'LAST';
referenceAccounts.sorts.add(accountSort);
referenceScope.sources.add(referenceAccounts);
catalog.add(referenceScope);

PromptContextDTO.TemplateConfig aggregates = new PromptContextDTO.TemplateConfig();
aggregates.name = 'Verify 06 - Aggregate Calculations';
aggregates.developerKey = 'verify_06_aggregates';
aggregates.description = 'COUNT, SUM, AVG, MIN, and MAX aggregate result modes.';
aggregates.rootObject = 'Account';
aggregates.templateBody =
  'Contacts: {!aggregate.contact_count.value}\n' +
  'Accounts: {!aggregate.account_count.value}\n' +
  'Employees sum: {!aggregate.employee_sum.value}\n' +
  'Employees average: {!aggregate.employee_avg.value}\n' +
  'Oldest: {!aggregate.oldest_account.value}\nNewest: {!aggregate.newest_account.value}';
List<List<String>> aggregateRules = new List<List<String>>{
  new List<String>{
    'contact_count',
    'RELATED',
    'Contact',
    'AccountId',
    'Id',
    'COUNT',
    null
  },
  new List<String>{
    'account_count',
    'REFERENCE',
    'Account',
    null,
    null,
    'COUNT',
    null
  },
  new List<String>{
    'employee_sum',
    'REFERENCE',
    'Account',
    null,
    null,
    'SUM',
    'NumberOfEmployees'
  },
  new List<String>{
    'employee_avg',
    'REFERENCE',
    'Account',
    null,
    null,
    'AVG',
    'NumberOfEmployees'
  },
  new List<String>{
    'oldest_account',
    'REFERENCE',
    'Account',
    null,
    null,
    'MIN',
    'CreatedDate'
  },
  new List<String>{
    'newest_account',
    'REFERENCE',
    'Account',
    null,
    null,
    'MAX',
    'CreatedDate'
  }
};
Integer aggregateSequence = 0;
for (List<String> ruleValues : aggregateRules) {
  aggregateSequence++;
  PromptContextDTO.SourceConfig source = new PromptContextDTO.SourceConfig();
  source.referenceName = ruleValues[0];
  source.sourceMode = ruleValues[1];
  source.resultMode = 'AGGREGATE';
  source.relatedObject = ruleValues[2];
  source.correlationField = ruleValues[3];
  source.rootField = ruleValues[4];
  source.aggregateOperation = ruleValues[5];
  source.aggregateField = ruleValues[6];
  source.sequence = aggregateSequence;
  aggregates.sources.add(source);
}
catalog.add(aggregates);

PromptContextDTO.TemplateConfig emptyState = new PromptContextDTO.TemplateConfig();
emptyState.name = 'Verify 07 - Empty and Fallback';
emptyState.developerKey = 'verify_07_empty_fallback';
emptyState.description = 'A deterministic empty result demonstrating indexed fallback and block else branches.';
emptyState.rootObject = 'Account';
emptyState.templateBody =
  'Count: {!related.no_matches.count}\n' +
  'First: {!related.no_matches[0].Name fallback="No first row"}\n' +
  '{!#if related.no_matches.hasRecords}Unexpected row.{!else}Condition empty state.{!/if}\n' +
  '{!#each related.no_matches as="row"}{!row.Name}{!else}Loop empty state.{!/each}';
PromptContextDTO.SourceConfig noMatches = new PromptContextDTO.SourceConfig();
noMatches.referenceName = 'no_matches';
noMatches.relatedObject = 'Contact';
noMatches.correlationField = 'AccountId';
noMatches.selectedFields = new List<String>{ 'Name' };
PromptContextDTO.FilterRule impossible = new PromptContextDTO.FilterRule();
impossible.fieldName = 'LastName';
impossible.operator = 'EQ';
impossible.value = '__NO_MATCH__';
noMatches.filters.add(impossible);
emptyState.sources.add(noMatches);
catalog.add(emptyState);

PromptContextDTO.TemplateConfig inactiveSource = new PromptContextDTO.TemplateConfig();
inactiveSource.name = 'Verify 08 - Inactive Source Draft';
inactiveSource.developerKey = 'verify_08_inactive_source';
inactiveSource.description = 'Draft-only example showing that an inactive source is retained but not queried.';
inactiveSource.rootObject = 'Account';
inactiveSource.templateBody = 'Root-only draft: {!record.Name}';
PromptContextDTO.SourceConfig disabledContacts = new PromptContextDTO.SourceConfig();
disabledContacts.referenceName = 'disabled_contacts';
disabledContacts.relatedObject = 'Contact';
disabledContacts.correlationField = 'AccountId';
disabledContacts.selectedFields = new List<String>{ 'Name' };
disabledContacts.active = false;
inactiveSource.sources.add(disabledContacts);
catalog.add(inactiveSource);

PromptContextDTO.TemplateConfig invalidDraft = new PromptContextDTO.TemplateConfig();
invalidDraft.name = 'Verify 09 - Intentional Errors Draft';
invalidDraft.developerKey = 'verify_09_intentional_errors';
invalidDraft.description = 'Draft-only examples: unknown alias, missing RELATED correlation, and invalid SUM field type.';
invalidDraft.rootObject = 'Account';
invalidDraft.templateBody = 'Unknown alias: {!related.missing_alias.count}';
PromptContextDTO.SourceConfig missingCorrelation = new PromptContextDTO.SourceConfig();
missingCorrelation.referenceName = 'missing_correlation';
missingCorrelation.relatedObject = 'Contact';
missingCorrelation.correlationField = null;
missingCorrelation.selectedFields = new List<String>{ 'Name' };
invalidDraft.sources.add(missingCorrelation);
PromptContextDTO.SourceConfig invalidAggregate = new PromptContextDTO.SourceConfig();
invalidAggregate.referenceName = 'invalid_sum';
invalidAggregate.sourceMode = 'REFERENCE';
invalidAggregate.resultMode = 'AGGREGATE';
invalidAggregate.relatedObject = 'Contact';
invalidAggregate.aggregateOperation = 'SUM';
invalidAggregate.aggregateField = 'LastName';
invalidAggregate.sequence = 2;
invalidDraft.sources.add(invalidAggregate);
catalog.add(invalidDraft);

PromptContextDTO.TemplateConfig parentPaths = new PromptContextDTO.TemplateConfig();
parentPaths.name = 'Verify 10 - Parent Paths';
parentPaths.developerKey = 'verify_10_parent_paths';
parentPaths.description = 'Root relationship traversal plus a source correlated through Contact.AccountId.';
parentPaths.rootObject = 'Contact';
parentPaths.templateBody = 'Contact: {!record.Name}\nParent through root: {!record.Account.Name fallback="No account"}\nParent through source: {!related.parent_account[0].Name fallback="No account"}';
PromptContextDTO.SourceConfig parentAccount = new PromptContextDTO.SourceConfig();
parentAccount.referenceName = 'parent_account';
parentAccount.relatedObject = 'Account';
parentAccount.correlationField = 'Id';
parentAccount.rootField = 'AccountId';
parentAccount.selectedFields = new List<String>{ 'Name', 'Industry' };
parentAccount.maxRows = 1;
parentPaths.sources.add(parentAccount);
catalog.add(parentPaths);

PromptContextDTO.TemplateConfig sourceBoundary = new PromptContextDTO.TemplateConfig();
sourceBoundary.name = 'Verify 11 - Ten Source Boundary';
sourceBoundary.developerKey = 'verify_11_ten_sources';
sourceBoundary.description = 'Maximum ten active sources and the 200-row planned prompt boundary.';
sourceBoundary.rootObject = 'Account';
List<String> boundaryLines = new List<String>();
for (Integer index = 1; index <= 10; index++) {
  String aliasName = 'contacts_' + index;
  boundaryLines.add(aliasName + ': {!related.' + aliasName + '.count}');
  PromptContextDTO.SourceConfig boundarySource = new PromptContextDTO.SourceConfig();
  boundarySource.referenceName = aliasName;
  boundarySource.relatedObject = 'Contact';
  boundarySource.correlationField = 'AccountId';
  boundarySource.selectedFields = new List<String>{ 'Name' };
  boundarySource.maxRows = 20;
  boundarySource.sequence = index;
  sourceBoundary.sources.add(boundarySource);
}
sourceBoundary.templateBody = String.join(boundaryLines, '\n');
catalog.add(sourceBoundary);

PromptContextDTO.TemplateConfig inactiveTemplate = new PromptContextDTO.TemplateConfig();
inactiveTemplate.name = 'Verify 12 - Inactive Template';
inactiveTemplate.developerKey = 'verify_12_inactive_template';
inactiveTemplate.description = 'A valid template that is published and then deliberately deactivated.';
inactiveTemplate.rootObject = 'Account';
inactiveTemplate.templateBody = 'Inactive example for {!record.Name}';
catalog.add(inactiveTemplate);

Set<String> draftOnlyNames = new Set<String>{
  'Verify 08 - Inactive Source Draft',
  'Verify 09 - Intentional Errors Draft'
};
Integer publishedCount = 0;
Integer draftCount = 0;
List<String> failedNames = new List<String>();
for (PromptContextDTO.TemplateConfig config : catalog) {
  if (existingByName.containsKey(config.name)) {
    config.id = existingByName.get(config.name).Id;
    config.draftRevision = PromptTemplateService.getTemplate(config.id)
      .draftRevision;
  }
  PromptContextDTO.TemplateConfig saved = PromptTemplateService.saveDraft(
    config
  );
  if (draftOnlyNames.contains(config.name)) {
    draftCount++;
    continue;
  }
  PromptContextDTO.TemplateHealth health = PromptTemplateGovernanceService.checkHealth(
    saved
  );
  if (!health.isValid) {
    failedNames.add(config.name);
    System.debug(
      LoggingLevel.ERROR,
      'CATALOG_VALIDATION_FAILED ' +
        config.name +
        ': ' +
        JSON.serialize(health.messages)
    );
    continue;
  }
  Id sampleRecordId = config.rootObject == 'Contact'
    ? contacts[0].Id
    : accountRecord.Id;
  PromptTemplateService.publish(saved.id, sampleRecordId);
  publishedCount++;
  if (config.name == 'Verify 12 - Inactive Template') {
    PromptTemplateService.deactivate(saved.id);
  }
}

System.debug(
  LoggingLevel.INFO,
  'Verification catalog ready. Account=' +
    accountRecord.Id +
    ', Contact=' +
    contacts[0].Id +
    ', Published=' +
    publishedCount +
    ', Draft=' +
    draftCount +
    ', Failed=' +
    JSON.serialize(failedNames)
);
