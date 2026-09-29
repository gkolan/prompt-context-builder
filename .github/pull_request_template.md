# Pull request

## Summary

<!-- Explain what changed and why. Link the issue when one exists. -->

## Type of change

- [ ] Bug fix
- [ ] Feature
- [ ] Documentation
- [ ] Build or tooling

## Verification

<!-- Paste the relevant commands and outcomes. Keep local, org, browser, and package evidence distinct. -->

- [ ] `npm run ci:gates` passes locally.
- [ ] Every behavior change has a focused regression.
- [ ] Apex or metadata changes passed validation and `RunLocalTests` in an approved org.
- [ ] Apex tests avoid `Account`, `Contact`, and `User` DML and select fixtures deterministically.
- [ ] Code Analyzer findings for Apex or metadata changes were reviewed and summarized.
- [ ] Source conflicts were absent, resolved without overwrite, or overwritten only with explicit approval.
- [ ] Scheduled Apex paused for validation or deployment was restored and verified.
- [ ] Public behavior changes update documentation and `CHANGELOG.md`.
- [ ] UI changes update the owner guide, screenshot gallery, and screenshot manifest, or explain why
      a new browser capture is not required.
- [ ] Screenshot evidence names the capture date, safe org alias, viewport, visible state, and
      evidence category; every image was inspected for secrets and unrelated content.
- [ ] No prompt content, customer values, credentials, session IDs, or full Org IDs appear in evidence.
