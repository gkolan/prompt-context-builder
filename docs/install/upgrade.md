# Upgrade Prompt Context Builder

Use the procedure that matches how Prompt Context Builder entered the org. A source deployment and
an unlocked-package installation have different upgrade and recovery behavior. Prove the exact
transition in a representative sandbox before production.

## Before you start

1. Record whether the org contains repository source or an installed package.
2. Record the current source revision or installed package version.
3. Export the records that hold template configuration and published history:
   - `Prompt_Template__c`
   - `Prompt_Context_Source__c`
   - `Prompt_Template_Version__c`
   - `Prompt_Context_Source_Version__c`
4. Capture the health state of active Published templates.
5. Identify Lightning pages, Flow actions, and Apex callers that depend on the product.
6. Read `CHANGELOG.md` and the target release documentation for contract or migration changes.

Keep exported configuration under the organization's approved data-handling controls. Template
bodies and filter values can contain sensitive business instructions even though generated prompts
are not stored by the product.

In the commands below, replace `TARGET_ALIAS` with the authenticated destination alias,
`TARGET_TAG_OR_COMMIT` with the reviewed source revision, and `VERSION` with an exact version from
an approved public package release record.

## Upgrade a source deployment

Check out one reviewed target revision. Do not upgrade a controlled environment from an
unreviewed moving branch.

```bash
git fetch --tags
git checkout TARGET_TAG_OR_COMMIT
npm ci
npm run ci:gates
```

In a representative sandbox, validate the source with local Apex tests:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org TARGET_ALIAS \
  --dry-run \
  --test-level RunLocalTests \
  --wait 60
```

After the dry run succeeds and its findings are reviewed, deploy the same checked-out revision:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org TARGET_ALIAS \
  --test-level RunLocalTests \
  --wait 60
```

A source deployment overwrites matching metadata but does not automatically delete components
removed from a later checkout. If the target release removes metadata, use only its reviewed,
release-specific destructive-change procedure. This repository does not provide a generic delete
manifest because deleting the custom objects also deletes stored template data.

## Upgrade an installed package

Use this path only after the repository publishes an approved package version and supported
upgrade path. Select the exact version from that public release record, not from historical aliases.

```bash
sf package install \
  --package "Prompt Context Builder@VERSION" \
  --target-org TARGET_ALIAS \
  --security-type AdminsOnly \
  --upgrade-type Mixed \
  --wait 30 \
  --publish-wait 10 \
  --no-prompt
```

Package-install success proves only that Salesforce installed the metadata. It does not prove the
configuration, security, record-page, Flow, or Apex journey.

## Verify the upgraded environment

1. Confirm existing Draft, Published, and Inactive templates still load.
2. Confirm published version signatures and version history remain present.
3. Run template health checks and investigate every new error.
4. Preview a representative template against a readable record.
5. Generate from the intended Lightning page as a person with generation access.
6. Repeat with one required field inaccessible and confirm that no partial prompt is returned.
7. Run representative Flow and Apex callers and verify the documented response fields.
8. Record local, deployment, package, browser, and prompt-generation evidence separately.

## Recovery

- If a source dry run fails, preserve the result and do not deploy.
- If a package installation fails, preserve the package version and installation result before
  retrying.
- If verification fails before production rollout, stop promotion and keep production on its
  current version.
- Prefer a forward correction over assuming an in-place package downgrade will succeed.
- Restoring exported configuration is a separate operation from restoring metadata. Test both in a
  sandbox before relying on them.

See [Production operations](../production-operations/README.md) for health checks and failure
response, and [Uninstall](./uninstall.md) when the capability must be removed.
