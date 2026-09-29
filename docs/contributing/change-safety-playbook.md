# Change safety playbook

Use this playbook for every Apex, Salesforce metadata, test-fixture, validation, or deployment
change. Its outcome is a change whose local evidence, org validation, deployment state, and recovery
state are explicit and reproducible.

This page owns the repository's change-safety procedure. `AGENTS.md` contains the mandatory summary
that repository-aware agents receive at session start. The quality-gate page defines which parts are
automated. This page explains the complete workflow and the reasons behind it.

## Why these rules exist

Several failure modes can appear unrelated even though they share one cause: a test or deployment
relied on state that the source did not own.

| Failure observed                                                         | Root cause                                                                                       | Durable rule                                                                                             |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| Tests fail only in an established org                                    | Test setup inserted standard records affected by subscriber validation rules, flows, or triggers | Deploy-critical tests do not perform DML on `Account`, `Contact`, or `User`                              |
| A published-template test resolves a draft fixture                       | A broad `LIMIT 1` query assumed only one record existed                                          | Test queries identify the intended semantic record explicitly                                            |
| A valid check-only deployment cannot be deployed                         | Local and org source tracking disagree                                                           | Inspect and resolve source conflicts; never bypass them without explicit overwrite approval              |
| An Apex class cannot be compiled during deployment                       | A scheduled job still references the class                                                       | Inventory affected jobs, pause only what is necessary, and restore every job after validation or failure |
| Static analysis reports hundreds of findings without a useful conclusion | Style debt, possible defects, and engine false positives were treated as one category            | Review findings by severity and relevance, fix defects, and report remaining advisory debt honestly      |
| A green local command is described as deployed behavior                  | Evidence from different environments was combined                                                | Keep local, validation, deployment, browser, and package evidence separate                               |

These rules reduce known risk. They do not prove that no defect exists, and they do not make every
Salesforce org identical.

## Session-start checklist

Before changing Apex, metadata, Apex tests, or deployment automation:

1. Read `AGENTS.md` and this playbook.
2. Inspect `git status --short` and preserve changes that already belong to the user.
3. Identify the exact requested outcome and whether it authorizes org mutation.
4. Identify the focused local test, Apex test class, or gate that can reproduce the failure.
5. Identify the approved target org before running an org command.
6. Separate planned evidence into local, validation, deployment, browser, and package categories.
7. Check whether the affected Apex classes are referenced by Scheduled Apex or other active async
   work.

Documentation-only and most local JavaScript changes do not require an org. Do not create, delete,
or replace a scratch org unless the user or release owner authorizes that specific operation.

## Preserve existing work

The repository may contain uncommitted work from the user or another task. Treat every unexplained
change as owned by the user.

- Inspect the working tree before editing.
- Do not reset, revert, delete, format, or include unrelated files.
- Format only the files in scope unless the repository gate explicitly requires a wider operation.
- Distinguish pre-existing changes from changes made for the current request in the handoff.
- Generated analyzer output, coverage output, authentication state, and logs do not belong in the
  repository.

## Regression-first implementation

Every behavior fix leaves an executable guard:

1. Write or identify a focused test that observes the failure through a supported boundary.
2. Run it against the broken implementation and record the expected failing result.
3. Apply the smallest complete correction.
4. Preserve the regression and cover affected empty, boundary, permission, bulk, namespace, and
   asynchronous paths.
5. Run the focused test, the relevant structural checks, and `npm run ci:gates`.
6. Run Salesforce validation when Apex or metadata changed.

A test that can pass while the original failure remains is not a regression guard. A source scan can
support a behavioral test, but it does not replace one when the behavior can be executed.

## Org-independent Apex test data

### Prohibited subscriber-record DML

Deploy-critical package tests do not insert, update, upsert, delete, or undelete these records:

- `Account`
- `Contact`
- `User`

Those records can be constructed without DML when a parser, renderer, describe operation, or schema
validator needs their types. Keeping an `Account` or `Contact` in memory does not invoke subscriber
automation.

Tests reuse the running test user. They must not depend on profile display names, locale-specific
profile availability, org email policies, User validation rules, or User automation. Permission
tests can use package Permission Sets, custom-permission test overrides, or a deliberately scoped
test seam that does not weaken production authorization.

The current executable guard is `npm run check:test-data-isolation`. It scans every `*Test.cls` file
and `PromptContextTestDataFactory.cls`. A passing scan proves only the patterns the scanner covers;
reviewers must still inspect indirect factory calls, multiline DML, `SObject` aliases, dynamic Apex,
and newly introduced subscriber object types.

### Package-owned fixtures

Persist package-owned fixture records only when the behavior requires database semantics. Give each
fixture a unique stable key and query it by that key. Keep fixture creation centralized in
`PromptContextTestDataFactory`.

Package-owned records lower exposure to customer business-object automation, but they do not create
an absolute any-org guarantee. An unlocked installation can contain subscriber additions on package
objects, and an org can differ by edition, feature, license, namespace, installed package, or
permission configuration. State the tested org shape and evidence precisely.

### Deterministic record selection

Do not use a broad test query such as the following when more than one semantic record can exist:

```apex
[SELECT Id FROM Prompt_Template__c LIMIT 1]
```

Select the intended record by a semantic discriminator:

```apex
[
  SELECT Id, Developer_Key__c
  FROM Prompt_Template__c
  WHERE Status__c = 'Published'
  AND Developer_Key__c = :expectedDeveloperKey
  LIMIT 1
]
```

Use an explicit `ORDER BY` when the test intentionally selects the first record from a set. A
`LIMIT` bounds rows; it does not define which row is selected. Tests should remain correct when a
sibling fixture is added to the same object.

### Test isolation review questions

Before accepting an Apex test change, answer all of these:

- Can subscriber validation rules, flows, triggers, duplicate rules, or required fields affect the
  inserted record?
- Does the test create a User or depend on a profile name?
- Does a query select by meaning, or does it assume the org contains one record?
- Does the test depend on records outside its transaction or use `SeeAllData=true`?
- Are package Permission Sets and custom permissions referenced by stable API name?
- Are asynchronous assertions performed after `Test.stopTest()`?
- Can a new fixture make an existing assertion select or count the wrong record?

## Static analysis

Run Salesforce Code Analyzer for Apex or metadata changes using the repository configuration and the
current supported CLI syntax. Save results to a timestamped temporary output, review the parsed
results immediately, and remove generated output before handoff.

Review order:

1. Critical and high findings.
2. Security, sharing, CRUD, FLS, injection, and unsafe dynamic-query findings.
3. Findings in changed production files.
4. Findings in changed tests and test infrastructure.
5. Existing advisory documentation, naming, and complexity debt.

Do not suppress a finding because the count is inconvenient. If an engine cannot understand a safe
platform pattern, document the reason and use the narrowest suppression supported by the rule. A
zero critical/high result is not proof that no bugs exist. Report remaining findings by severity and
category.

Analyzer JSON and logs are generated evidence. Keep them outside commits; the public-release gate
rejects `code-analyzer-results-*` artifacts.

## Local gates and their boundary

Run:

```bash
npm run ci:gates
```

The local gate covers formatting, documentation, repository contracts, Apex test-data isolation,
LWC lint, LWC Jest behavior, and LWC coverage completeness. It does not authenticate to Salesforce,
compile Apex in an org, run `RunLocalTests`, deploy metadata, inspect Scheduled Apex, resolve source
tracking, verify a browser, or install a package version.

Never report a local gate as org validation or deployment evidence.

## Approved-org validation

### Identify the target

Before validation:

1. List available orgs without creating a new one.
2. Resolve the exact alias to its username and org identity.
3. Confirm the org is active and purpose-appropriate.
4. Record the alias in working notes and the handoff. Do not commit usernames, access tokens, full
   Org IDs, or environment-specific record IDs.
5. Confirm the user authorized validation or deployment against that org.

### Validate the exact deployment source set

Use a check-only deployment for the same source scope intended for deployment. For Apex changes, run
`RunLocalTests` unless a stricter release process applies. Record:

- target alias;
- check-only deployment job ID in private working evidence;
- final Salesforce status;
- components validated;
- tests completed and failures;
- component errors;
- coverage warnings.

Do not infer success from command exit alone when an asynchronous job is involved. Read the final
deployment report.

## Source tracking and conflicts

A successful check-only deployment proves compilation and tests for that source set. It does not
grant permission to overwrite divergent org source.

When Salesforce reports source conflicts:

1. Stop the mutating deployment.
2. Narrow the requested deployment to the smallest complete metadata set.
3. Inspect source tracking and retrieve or compare the org version without overwriting local files.
4. Determine whether the org difference is expected task state, another person's work, or unknown.
5. Report the exact conflicting components and the overwrite risk.
6. Obtain explicit user approval before using `--ignore-conflicts` or another operation that can
   overwrite org-side changes.

Authorization to deploy is not automatically authorization to bypass conflict protection. Do not
reset source tracking, use Metadata API as a bypass, or change command shape to evade the approval
requirement.

After approval, deploy the narrow validated source set. Run the required tests again during the
actual deployment and read the final report.

## Scheduled Apex lifecycle

Salesforce can block compilation when a changed class is referenced by a scheduled or active async
job. Treat scheduler state as customer-visible org state.

Before pausing a job:

1. Query the exact `CronTrigger` and `CronJobDetail` records related to the changed class.
2. Record job name, state, schedule, and next fire time in private working evidence.
3. Confirm that pausing or aborting the job is within the authorized deployment scope.
4. Prepare the exact restoration operation before changing the job.

During the deployment:

- Pause or abort only the blocking job.
- Do not delete unrelated jobs.
- Keep the job stopped only for the shortest necessary interval.
- If validation or deployment fails, restore the job before handing control back unless the user
  explicitly requests it remain stopped.

After validation or deployment:

1. Restore the schedule with the reviewed application entry point.
2. Query the restored `CronTrigger`.
3. Verify the expected name, `WAITING` state, and next fire time.
4. Record restoration separately from deployment success.

Use cleanup logic or an explicit recovery checklist so an interrupted command does not leave the org
without its scheduled operation.

## Deployment sequence

Use this sequence for an authorized Apex or metadata deployment:

1. Confirm the working tree and exact source scope.
2. Run focused regressions.
3. Run static analysis and review findings.
4. Run `npm run ci:gates`.
5. Resolve the approved target org.
6. Inventory Scheduled Apex and async blockers.
7. Run an exact check-only deployment with required tests.
8. Read the completed validation report.
9. Inspect source conflicts before any mutating deployment.
10. Obtain explicit overwrite approval if conflict protection must be bypassed.
11. Pause only necessary scheduled work.
12. Deploy the same narrow source set with required tests.
13. Read the completed deployment report.
14. Restore scheduled work and verify its state.
15. Report local, validation, deployment, schedule, browser, and package evidence separately.

If a step fails, preserve the failure output, restore temporary org state, correct the cause, and
repeat the affected validation. Do not describe the earlier successful check-only job as a later
successful deployment.

## Evidence vocabulary

Use these terms consistently:

| Term             | Required proof                                                                        |
| ---------------- | ------------------------------------------------------------------------------------- |
| Source-reviewed  | Relevant source and metadata were inspected                                           |
| Locally tested   | The named local command completed successfully                                        |
| Org-validated    | A check-only Salesforce deployment completed successfully in the named approved alias |
| Deployed         | A mutating Salesforce deployment completed successfully in the named approved alias   |
| Browser-verified | The named user flow was exercised in a browser against the identified deployment      |
| Package-verified | The exact package version passed the stated install or upgrade scenario               |

Do not substitute one term for another. Include counts and job outcomes when they materially clarify
the evidence.

## Screenshot evidence

Screenshots are browser evidence only when they come from an identified deployed source or package
state and the documented user flow was exercised. A browser image cannot prove that a different
working tree was deployed.

For every new or replaced UI screenshot:

1. Identify the approved org alias and whether the org contains source deployment or an installed
   package. Never record its username, full Org ID, session URL, or access token.
2. Record the capture date, viewport, product surface, visible state, and evidence scope in
   `docs/screenshots/manifest.json`.
3. Use deterministic demonstration records with no customer or personal data.
4. Capture the smallest view that proves the documented behavior. Include surrounding Salesforce
   context only when it helps a reader locate the component.
5. Inspect the pixels for secrets, record IDs, unrelated tabs, extensions, dialogs, stale labels,
   clipping, and personal information.
6. Update the user-task owner page and `docs/screenshots/README.md`. Keep obsolete captures only
   when they are explicitly marked historical and still serve a design-history purpose.
7. Run `npm run check:screenshots`. Then review the rendered Markdown because the automated check
   cannot determine whether the image is accurate, readable, current, or sensitive.

When source conflicts prevent the current working tree from being deployed, label the capture as a
deployed-org baseline and state that the workspace changes remain undeployed. Do not manufacture a
release screenshot from a local mock and describe it as Salesforce browser verification.

## Meaning of any-org compatibility

Do not claim that an Apex test works in every Salesforce org without qualification. A defensible
claim states the controlled dependencies:

- no DML on subscriber-owned business or User records covered by the isolation contract;
- no `SeeAllData=true` dependency;
- no profile-display-name dependency;
- deterministic fixture lookup;
- stable package API names;
- explicit feature, edition, namespace, and Permission Set prerequisites;
- successful `RunLocalTests` in an identified org shape.

When only one org shape has been tested, say so. Additional package, namespace, upgrade, and feature
variants require their own evidence.

## Handoff checklist

Before calling an Apex or metadata change complete, report:

- focused regression and outcome;
- `npm run ci:gates` outcome;
- analyzer severity summary and unresolved relevant findings;
- isolation-gate outcome;
- approved org alias and validation outcome;
- actual deployment outcome, if deployment was authorized;
- source conflicts and their resolution;
- Scheduled Apex changes and verified restoration;
- browser or package evidence only when actually exercised;
- screenshot manifest, visual inspection, and evidence scope when UI captures changed;
- remaining limitations or unverified org variants.

If deployment is blocked on overwrite approval, state that the source is validated but not deployed.
