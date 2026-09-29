# Sample template verification catalog

Status: seeded and verified in a dedicated scratch org on 2026-09-19

Run the catalog when an administrator, developer, or tester wants working examples of every
supported option family. Valid runtime examples are published. Teaching examples that are unsafe
or incomplete remain Draft, and the lifecycle example remains Inactive.

## Sample data

- Account: **Prompt Context Verification Account**
- Contacts: Avery Adams, Jordan Brown, and Morgan Clark
- Contact data intentionally includes populated and blank Email/Phone combinations.

The seed is repeatable: it reuses the named Account, Contacts, and templates. Publishing again
creates a new immutable version, as expected from the versioning contract.

## Template catalog

| Template                             | Final state | Options demonstrated                                                                                             |
| ------------------------------------ | ----------- | ---------------------------------------------------------------------------------------------------------------- |
| Verify 01 - Merge Syntax             | Published   | Root values; indexed row; count; `each`/`else`; `if`/`else`; fallback; `upper`, `lower`, and `percent` formats   |
| Verify 02 - Text and Null Filters    | Published   | `EQ`, `NE`, `CONTAINS`, `STARTS_WITH`, `NOT_NULL`; five named groups joined with `OR`                            |
| Verify 03 - Range and Blank Filters  | Published   | `GT`, `GTE`, `LT`, `LTE`, `IS_NULL`; DateTime typed values; five named groups joined with `AND`                  |
| Verify 04 - Independent Sorting      | Published   | Two Contact sources on one template; independent selected fields, limits, `ASC`/`DESC`, and `NULLS FIRST`/`LAST` |
| Verify 05 - Reference Scope          | Published   | Limited, non-correlated `REFERENCE` source with access and unfiltered-reference warnings                         |
| Verify 06 - Aggregate Calculations   | Published   | `AGGREGATE` sources using `COUNT`, `SUM`, `AVG`, `MIN`, and `MAX`                                                |
| Verify 07 - Empty and Fallback       | Published   | Zero-row source; count zero; indexed fallback; false `if` branch; empty `each` branch                            |
| Verify 08 - Inactive Source Draft    | Draft       | A retained source with Active off; root-only template remains valid and the source is not queried                |
| Verify 09 - Intentional Errors Draft | Draft       | Unknown alias, missing RELATED matching, nonnumeric `SUM`, unused-source warnings, and publication protection    |
| Verify 10 - Parent Paths             | Published   | Root relationship traversal and source matching from `Contact.AccountId` to `Account.Id`                         |
| Verify 11 - Ten Source Boundary      | Published   | Maximum 10 active sources and planned 200-row boundary (10 sources × 20 rows)                                    |
| Verify 12 - Inactive Template        | Inactive    | Valid publish followed by deactivation; excluded from choices and rejected at runtime                            |

Together these templates cover both source modes (`RELATED`, `REFERENCE`), both result modes
(`RECORDS`, `AGGREGATE`), every aggregate operation, every filter operator, both filter-group joins,
both sort directions, all null-order choices used by an explicit sort, active/inactive sources,
all template lifecycle states, multi-source same-object behavior, empty results, parent paths,
formatting, limits, and security-preserving invalid states. Platform-default null ordering is the
absence of a null-order setting and is exercised by sources that have no explicit sort.

## Seed and verify

```bash
sf apex run \
  --file scripts/apex/seedVerificationTemplates.apex \
  --target-org TARGET_ALIAS

sf apex run \
  --file scripts/apex/verifyVerificationTemplates.apex \
  --target-org TARGET_ALIAS
```

The verification script asserts:

1. Exactly 12 catalog templates exist.
2. All nine Published templates generate a nonblank prompt from their immutable current version.
3. Both Draft templates and the Inactive template are rejected by the published-runtime API.
4. The intentional-error draft has multiple actionable validation errors.
5. The inactive-source draft is otherwise valid.
6. Only Published Account templates appear in the runtime template picker.

## Recorded verification result

The 2026-09-19 run compiled and executed successfully:

- 9 Published templates generated successfully.
- 2 Draft examples produced the expected validation/runtime behavior.
- 1 Inactive example was excluded and rejected as expected.
- Same-object independent sources returned separate counts (`email_order=2`, `newest_order=3`).
- The empty source returned zero rows.
- The parent source returned one row.
- All ten boundary sources executed and returned independently.
- The invalid draft returned `MISSING_CORRELATION_FIELD`, `AGGREGATE_TYPE_MISMATCH`, and
  `UNKNOWN_SOURCE`, plus the expected warnings.

## Junior-admin walkthrough

Open the **Prompt Context Builder** app, select **Prompt Builder**, and search for `Verify`. Start
with Verify 01, select the verification Account, and preview. Then move through the numbered list.
For Verify 09, choose **Validate** and confirm the errors are explained next to the relevant source
or template. Do not try to publish that entry; its purpose is to demonstrate safe failure.
