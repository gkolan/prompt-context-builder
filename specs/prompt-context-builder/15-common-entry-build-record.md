# Common preparation entry and Prompt Input Log: build record

Status: Local source and repository checks complete. Salesforce validation and Apex tests passed in
the existing `pcb-package-test` scratch org. The increment was deployed there in job
`0AfRL00000i7CCn0AM`. No new package-version creation or browser verification was performed.

Date: September 24, 2026

## Delivered in local source

- `PromptContextInputApi` is the one public Flow and Apex entry.
- `PromptContextPreparationService.execute()` owns the common preparation process.
- `RETURN_TO_APEX` returns prepared input and creates no package record.
- `SAVE_TO_LOG` creates or safely reuses one private `Prompt_Input_Log__c` record.
- A save requires the separate Prompt Context Save Input permission and a caller Request Key.
- The stored key is a user-scoped SHA-256 value. The raw caller key is not retained.
- A second verification value detects a reused key with different prepared input.
- The log points to the exact published template version and stores prompt text, input format,
  retention, processing state, and one managed selected-file JSON list.
- `Selected_Files_JSON__c` stores zero through five server-built exact Salesforce File version entries.
  No file child object, file body, destination registry, or callback type is present.
- The record-page picker returns 50 eligible Files at a time and **Show more Files** requests the
  next stable page without clearing the user's selections.
- Related and calculated-value sources use grouped bulk queries. A source can match its Salesforce
  match field to a same-type field value on the current record; reference sources are loaded once
  and reused for the request group.
- Saved logs can be claimed, completed, retried within the firm limit, cancelled, expired, and
  purged through `PromptContextInputLifecycle`.
- The Lightning app no longer overrides the Account record page and no longer exposes Account,
  Contact, or Prompt Data Set as navigation items.
- Repository checks protect the common-entry boundary and the single-log-object contract.
- Every shipped custom field now has an administrator-readable metadata description, enforced by
  `npm run check:field-descriptions`.

## Red evidence

The common-entry check was added before the common service existed.

```text
Error: PromptContextPreparationService.cls must own the common prompt-preparation process.
```

The Prompt Input Log check was added before the object, fields, API, and simplified navigation
existed. It failed for the missing `Prompt_Input_Log__c` contract and the old app surface. These
failures established that the guards could detect the behavior this increment needed to add.

The first Salesforce validation exposed two metadata rules that the local contract did not yet
enforce:

```text
Can not specify 'required' for a CustomField of type LongTextArea
You cannot deploy to a required field: Prompt_Input_Log__c.Retain_Until__c
```

The Long Text Area fields no longer declare metadata-required values, and the permission sets no
longer declare field permissions for object-required fields. `check:input-log` now rejects either
regression. Application code still requires complete prompt and selected-file values before save.

The next validation ran 19 focused tests. One test failed because its setup created only two records
that matched a two-row data-set limit, so it could not exercise truncation. The test now adds a third
matching record and preserves the expected `SOURCE_TRUNCATED` assertion.

## Local green evidence

- `npm run check:common-entry` passed after the Lightning runtime controller was routed through the
  common preparation service.
- `npm run check:input-log` passed.
- `npm run ci:gates` passed: formatting, documentation, Salesforce language, contract checks,
  release hygiene, permissions, namespace fixtures, LWC lint, and 22 LWC tests.
- Salesforce Code Analyzer completed against `force-app` with 0 Critical, 0 High, and 0
  Security-tagged findings. It reported 203 Moderate, 443 Low, and 4 Informational maintainability
  findings across the full source tree.
- `git diff --check` passed.
- Focused validation job `0AfRL00000i5wYH0AY` compiled all 162 components and passed all 19 focused
  tests after the test-data correction. Salesforce still required wider deployment coverage, as
  expected for a full-source validation.
- Full validation job `0AfRL00000i62p00AA` passed against the existing clean validation scratch org
  `pcb-package-test`: 204 of 204 components, 41 of 41 Apex tests, zero component errors, zero test
  failures, and zero coverage warnings.
- Final explicit all-test job `0AfRL00000i66UQ0AY` passed: 204/204 components, 112/112 repository
  Apex tests, zero component or test errors, no coverage warnings, and 85.79% aggregate coverage.
- Full source deployment `0AfRL00000i7CCn0AM` succeeded in `pcb-package-test`: 204/204 components,
  42/42 local Apex tests, zero component errors, and zero test failures.
- Destructive validation `0AfRL00000i7BJy0AM` deleted nothing and failed because the retired Account
  record FlexiPage is still active. Until it is deactivated, that page, the two retired API classes,
  and the retired Prompt Context Source tab remain in the scratch org.

The development scratch org `promptcontextbuilder` was not changed. Its existing scheduled Prompt
Template Health job blocks deployment while the org's deployment setting remains off. The job was
not cancelled and the setting was not changed; validation used the repository-designated clean
scratch org instead.

## Not delivered in this increment

- reading Salesforce File bodies;
- uploading, scanning, or temporarily storing files in AWS;
- an Amazon Bedrock request or provider response;
- AWS cleanup and operations alerts;
- a browser-verified version of this source; or
- a new package version or promotion.

## Day-one rule

There is no compatibility layer, deprecated public API, legacy delivery choice, or data migration
requirement. Before the first release, temporary source can be replaced without a wrapper. Every
stored configuration and input log must satisfy the complete day-one contract.

## Next authorized build increment

After the security owner approves the exact AWS account, encryption, malware scanning, retention,
Named Credential, region, model, and failure ownership, implement stages 5 through 8 of the File
input specification. File bodies must never be copied into `Prompt_Input_Log__c`.
