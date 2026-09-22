# Quality gates

`npm run ci:gates` is the local pull-request gate. It verifies formatting, documentation links and
navigation, the Permission Set custom-permission boundary, the namespace fixture contract, LWC
lint, LWC Jest behavior, and enforced JavaScript coverage floors.

The coverage command disables Jest's transform cache and then verifies that both shipped LWC
controllers are present in `coverage-final.json`. A green percentage threshold is not accepted when
coverage data for a component is missing.

## Evidence by change type

| Change            | Required evidence                                                                     |
| ----------------- | ------------------------------------------------------------------------------------- |
| JavaScript or LWC | ESLint, focused Jest regression, complete Jest suite                                  |
| Apex              | Focused Apex regression, `RunLocalTests`, coverage result, static analysis            |
| Metadata          | Formatter, namespace fixture gate, deployment validation in an approved org           |
| Documentation     | Formatter, local-link validation, source review of every exact claim                  |
| Package boundary  | Package-version test and clean install/upgrade evidence approved by the release owner |

Code Analyzer uses `code-analyzer.yml` to apply the repository's ESLint configuration and keep
Node-only repository scripts out of LWC rule scope. Do not suppress a finding merely because it is
inconvenient; document and narrowly bound any genuine engine false positive.

## Regression-first rule

For a bug fix, record the observable failing behavior, run the focused test against the broken
implementation, apply the smallest fix, and rerun the focused and complete gates. Include ordinary,
empty, boundary, error, permission, bulk, namespace, and platform variants when they can affect the
behavior.

## Evidence boundaries

- Formatting proves formatting only.
- Jest proves client behavior in its test environment, not Salesforce deployment.
- Apex tests prove behavior of the source deployed to the target org.
- A source deploy is not an installed-package upgrade.
- Static analysis findings require review; severity alone does not prove a defect.
