# Public release checklist

Use this checklist before changing the GitHub repository visibility or creating a release.

## Repository owner decisions

- [ ] Select an open-source license and copyright holder, or explicitly approve a source-visible,
      all-rights-reserved release.
- [ ] Confirm the GitHub owner and repository name used by the workflow badge and security-advisory
      link.
- [ ] Decide whether the public repository starts with a clean snapshot or retains private
      development history after reviewing that history for sensitive data.

## Local evidence

- [ ] Run `npm ci` with Node.js 22.
- [ ] Run `npm run ci:gates`.
- [ ] Run `npm audit --audit-level=high` and review lower-severity advisories.
- [ ] Run Salesforce Code Analyzer and keep generated JSON and logs outside the repository.
- [ ] Confirm `git status --short --ignored` shows local Salesforce state, dependencies, coverage,
      and analyzer output as ignored.

## Salesforce evidence

- [ ] Follow the public scratch-org demo from a clean clone and record the final
      `CATALOG_COMPLETE generated=9, drafts=2, inactive=1` result.
- [ ] For Apex or metadata changes, validate the deployment and run `RunLocalTests` in an
      identified, approved org.
- [ ] Record source-deploy, installed-package, namespace, browser, and local evidence separately.
- [ ] Do not create, delete, promote, or publish an org or package version without the responsible
      owner's explicit approval.
- [ ] If distributing a package, publish one exact approved subscriber package version and verify
      the documented sandbox and production installation destinations.

## GitHub settings

- [ ] Require the `local-gates` status check on the default branch.
- [ ] Enable private vulnerability reporting, dependency graph, Dependabot alerts, and secret
      scanning where the repository plan supports them.
- [ ] Review issue templates, pull-request guidance, support guidance, and the security-advisory
      link after publication.
- [ ] Confirm the Code of Conduct reporting routes and CODEOWNERS account resolve correctly after
      publication.
- [ ] Create a release from an immutable tag only after the tagged commit's checks pass.
