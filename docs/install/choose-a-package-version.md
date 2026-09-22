# Choose a package version

Use this page to distinguish package-build history from an approved public release. For the current
public evaluation path, deploy repository source by following [Install and verify](./README.md) or
the [prepared scratch-org demo](./try-demo-scratch-org.md).

## Current distribution status

This repository does not currently advertise a public package installer. Do not select a package
version from build-history prose or infer support from an alias in `sfdx-project.json`.

Before this page can name a public package version, the release owner must:

1. approve the exact subscriber package version;
2. confirm that it is promoted and installable by an external subscriber;
3. validate a clean installation and the documented user journey;
4. record supported upgrade paths; and
5. publish sandbox and production installation destinations.

Until those steps are recorded, source deployment is the supported evaluation procedure in this
repository.

## After a package release is approved

Use an approved released package version for a sandbox or production installation. Use repository
source only for development and review.

The package aliases in `sfdx-project.json` map human-readable build versions to Salesforce package
version IDs. Confirm the intended version in a maintained public release record; a `.NEXT` version
is source development state, not a released package.

Install an approved version in a sandbox with:

```bash
sf package install --package "Prompt Context Builder@VERSION" \
  --target-org TARGET_ALIAS \
  --security-type AdminsOnly \
  --upgrade-type Mixed \
  --wait 30 \
  --publish-wait 10 \
  --no-prompt
```

Replace `VERSION` and `TARGET_ALIAS` with values from the approved public release record. Do not
copy an old package version ID from historical prose.

After installation, assign Permission Sets and follow the verification steps in
[Install in a sandbox](./README.md).
