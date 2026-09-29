# Break-review remediation plan

## Purpose

This record turns the September 2026 breakage review into regression-first implementation work.
The review is source analysis, not org evidence. Read-confirmed failures are fixed behind executable
guards; platform-dependent findings remain hypotheses until an identified org reproduces them.

## Working rules

- Preserve the current uncommitted feature work as the baseline and avoid unrelated rewrites.
- Add or identify a focused regression before each behavioral fix.
- Keep record-page, Flow/Apex, local, org, and package evidence distinct.
- Preserve sharing-aware Apex, user-mode data access, schema-validated identifiers, typed binds,
  resource limits, and request-wide permission failures.
- Run focused checks while working and `npm run ci:gates` before handoff.

## Execution order

### Phase 1: prompt correctness and isolation

- Prevent rendered record values from being parsed again as merge syntax.
- Normalize supported token and block whitespace consistently between validation, dependency
  extraction, and rendering.
- Correct the block-iteration boundary and reject unknown local aliases.
- Restore truncation semantics in grouped generation and isolate render failures per record.
- Make empty grouped COUNT results agree with the single-record path.
- Parse Date and Datetime filter values strictly and without user-time-zone drift.

### Phase 2: publication and governance

- Keep a published template available while its editable draft changes.
- Save current editor state before publishing.
- Compare stable publication content while excluding record/version identities, including file
  settings.
- Make health checks return actionable validation messages when fields have disappeared or become
  unreadable.
- Continue the nightly health chain after partial-save failures.

### Phase 3: common-entry result contract and telemetry

- Preserve record and template identities on Flow preflight failures.
- Clear all success-only fields when a later step changes a response to failure.
- Restore record-page failure metrics, including failures before template resolution where the
  event schema permits them.
- Replace message-text classification with explicit reason-bearing exceptions.
- Update verification scripts to exercise the production preparation path.

### Phase 4: files, upgrade compatibility, and resource bounds

- Treat blank legacy File Input Mode values as `DISABLED` at every persisted mapping boundary.
- Bulk-load file eligibility instead of issuing queries per record, or reject a request before it
  can exceed the query budget.
- Reject stale ContentVersion selections with the documented reason code.
- Guard asynchronous file-list responses, enforce the effective provider limit in the UI, and
  keep checkbox state aligned with accepted selections.
- Define limit-aware behavior for `ALL_ELIGIBLE` when more files exist than can be sent.

### Phase 5: validator, UI, lifecycle, and cleanup

- Make null-body and invalid-alias validation deterministic; validate typed filter values early.
- Correct response-size accounting, search wildcard escaping, template/source picker rollback, unique
  source naming, byte formatting, and duplicate LWC keys.
- Resolve retry/claim semantics and permission-set write boundaries for input logs and immutable
  versions.
- Remove or consolidate dead and duplicated helpers only after behavioral regressions pass.
- Correct documentation that describes unsupported nesting or outcomes not emitted by code.

## Verification matrix

| Evidence                  | Required result                                                   |
| ------------------------- | ----------------------------------------------------------------- |
| Focused Jest/static tests | Each changed UI or contract behavior has a local regression       |
| Apex tests                | Added for every Apex behavior; execution requires an approved org |
| `npm run ci:gates`        | Must pass before handoff                                          |
| Salesforce validation     | Run only against an identified, authorized org                    |
| Package/browser evidence  | Not inferred from local or source-only success                    |

## Status

- Implemented all read-confirmed high and medium findings with focused Apex or Jest regressions:
  merge-value isolation, syntax normalization, block bounds, local-alias validation, published-draft
  continuity, save-before-publish, stable version comparison, grouped COUNT parity, deterministic
  truncation, per-record render isolation, file-query admission, strict typed filters, actionable
  health results, continuing health chains, uncertain-delivery handling, explicit reason-bearing
  failures, and current file-version enforcement.
- Closed the code-review additions: legacy blank file modes default to Disabled, Flow preflight
  failures keep identities, pre-template and record-page failures emit privacy-safe metrics, failed
  results clear success-only fields, verification scripts use the production preparation service,
  and response indexes default to input order.
- Added conservative guards for platform-dependent risks: calculated data sets first select at most
  1,001 candidate Ids and reject more than 1,000 input rows; bulk match keys normalize Id casing and
  decimal scale; mutable builder reads are not client-cacheable; and a duplicate user-mode input-log
  insert can recover only the exact user-scoped key with a matching verification digest.
- Closed the low-severity correctness list: reserved aliases, stable LWC keys, file-picker rollback
  and request guards, provider-effective file limits, MB formatting, picker rollback, unique source
  names, each-only source use, reference-target validation, Flow response-size accounting, limited All
  Eligible selection, typed polymorphic errors, reusable health schedules, pre-template metrics,
  safe repeat saves after sharing changes, permission boundaries, accurate budget wording, and merge-syntax
  documentation.
- Cleanup completed where it reduces drift without removing compatibility surfaces: validation
  message mapping is shared, stable reason constants replace literals, the file-selector pass-through
  was removed, and the resource planner no longer contains the impossible zero-row branch. Public
  `generatePublished` remains as a compatibility wrapper even though production entry points use the
  preparation service. The combined-file-byte guard and stable reason code remain as defense in
  depth if either per-file or count limits change later.
- Rejected `related.X.count` as a bug: the product contract defines it as the number of returned
  rows after configured truncation; authors use an aggregate COUNT when they need the full matched
  total. The other rejected claims from the review remain rejected for the documented reasons.
- Local completion evidence: `npm run ci:gates` passed on September 25, 2026, including formatting,
  documentation, contract checks, permission checks, lint, all 28 LWC tests, and the LWC coverage
  completeness check. Apex compilation, Apex test execution, browser checks, and deployment
  validation remain separate evidence and require an identified, explicitly authorized Salesforce
  org.
