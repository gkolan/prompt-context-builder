# Merge syntax

Prompt Context Builder uses a closed, versioned text grammar. Resolved record values are appended
as inert text and are never parsed again.

## Values

```text
{!record.Name}
{!record.Owner.Email fallback="No owner email"}
{!related.contacts[0].Name}
{!related.contacts.count}
{!aggregate.open_contact_count.value fallback="0"}
```

Indexes are zero-based. The configured source must expose every referenced related field.

## Blocks

```text
{!#each related.contacts as="contact"}
- {!contact.Name}: {!contact.Email fallback="No email"}
{!else}
No visible contacts were found.
{!/each}

{!#if related.openCases.hasRecords}
Open cases: {!related.openCases.count}
{!else}
No visible open cases were found.
{!/if}
```

Loop aliases exist only inside their block. An `each` block cannot be nested inside another `each`
block. `if` blocks may be nested, and `else` belongs to the nearest compatible open block.

## Attributes

- `fallback="text"` applies to a readable null value or missing row position.
- `format="upper"`, `format="lower"`, and `format="percent"` are supported.
- Unknown, repeated, unquoted, malformed, or inapplicable attributes are validation errors.

Fallback and `else` do not recover from missing object, field, or record access. Access failures
abort generation without returning a partial prompt.
