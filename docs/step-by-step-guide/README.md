# Create and publish a prompt template

This guide is for a Salesforce administrator with the **Prompt Context Configure** Permission Set.
The example creates Account context with a consistently ordered list of visible Contacts.

## Before you start

- Choose an Account that has at least one Contact.
- Confirm you can read `Account.Name`, `Contact.AccountId`, `Contact.Name`, and `Contact.Email`.
- Open **App Launcher → Prompt Context Builder → Prompt Builder**.

## 1. Create the template

Create a template with these values:

| Setting           | Value                   |
| ----------------- | ----------------------- |
| Name              | Account contact context |
| Automation key    | Created after you save  |
| Salesforce object | Account                 |
| Status            | Draft                   |

Use this body:

```text
Account: {!record.Name fallback="Unknown account"}

{!#each related.contacts as="contact"}
- {!contact.Name}: {!contact.Email fallback="No email"}
{!else}
No visible contacts were found.
{!/each}
```

## 2. Add related data

Add one data set:

| Setting                    | Value           |
| -------------------------- | --------------- |
| Reference name             | `contacts`      |
| Records to include         | Related         |
| Related object             | Contact         |
| Current record field       | `Id`            |
| Related record match field | `AccountId`     |
| Prompt fields              | `Name`, `Email` |
| Sort                       | Name, Ascending |
| Maximum records            | 10              |

The reference name appears in the inserted field code. It is separate from the object name and lets
two data sets include Contact records with different filters or sorting.

## 3. Validate and preview

Validate the Draft, then preview it with the chosen Account. A successful preview shows the
generated text, data set record counts, validation messages, and the required field access list.
Preview uses the current user's access and does not save the generated prompt.

Correct every blocking error. Warnings require review but do not represent permission to bypass a
limit or security check.

## 4. Publish

Publish only after preview succeeds. Publishing creates a fixed version and records its version
signature. Later edits occur in a Draft and do not change the published version used by existing
automation.

## 5. Verify positive and negative outcomes

- Generate against the Account used for preview. Expect the Account name and visible Contacts in
  name order.
- Generate against an Account with no visible Contacts. Expect the `else` text.
- Test as a user without access to one required field. Expect an access failure and no partial
  prompt.
- Deactivate the template and retry. Expect generation to refuse the inactive template.

Next, [configure the record-page component](../lightning-record-page/README.md) or use the
[Flow and Apex API](../developer-guides/README.md).
