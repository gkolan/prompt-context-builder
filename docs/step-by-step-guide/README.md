# Create and publish a prompt template

This guide is for a Salesforce administrator with the **Prompt Context Configure** Permission Set.
The example creates Account context with a consistently ordered list of visible Contacts.

## Before you start

- Choose an Account that has at least one Contact.
- Confirm you can read `Account.Name`, `Contact.AccountId`, `Contact.Name`, and `Contact.Email`.
- Open **App Launcher → Prompt Context Builder → Prompt Builder**.

## 1. Create the template

Set these fields:

| Field in Prompt Builder | Value                   |
| ----------------------- | ----------------------- |
| Template name           | Account contact context |
| Salesforce object       | Account                 |

A new template starts as Draft. Prompt Builder creates its **Automation key** when you first save.

Enter this text in **Template body**:

```text
Account: {!record.Name fallback="Unknown account"}

{!#each related.contacts as="contact"}
- {!contact.Name}: {!contact.Email fallback="No email"}
{!else}
No visible contacts were found.
{!/each}
```

## 2. Add related data

Select **Add related data**, then set:

| Field in Prompt Builder        | Value                                          |
| ------------------------------ | ---------------------------------------------- |
| Reference name                 | `contacts`                                     |
| Records to include             | Match a current record field                   |
| Result type                    | Records                                        |
| Object to query                | Contact                                        |
| Current record field           | `Id`                                           |
| Source match field             | `AccountId`                                    |
| Fields available to the prompt | Move `Name` and `Email` to **Selected fields** |
| Maximum records                | 10                                             |

Then select **Add sort** and set **Field** to `Name` and **Direction** to Ascending.

The reference name appears in the inserted field code. It is separate from the object name and lets
two data sets include Contact records with different filters or sorting.

![Contact data set using current-record field matching](../screenshots/prompt-builder-related-data-current.png)

Deployed scratch-org screenshot, September 26, 2026; see [screenshot evidence](../screenshots/README.md).

## 3. Validate and preview

Validate the Draft, then preview it with the chosen Account. A successful preview shows the
generated text, data set record counts, validation messages, and the required field access list.
Preview uses the current user's access and does not save the generated prompt.

Correct every blocking error. Warnings require review but do not represent permission to bypass a
limit or security check.

## 4. Publish

Publish only after preview succeeds. Publishing creates a fixed version and records its version
signature. Saving later edits changes the editable settings. A live template keeps its Published
status, and generation continues to use the latest fixed version until the edits are previewed and
published as a new version.

While saved edits wait to be published, the status badge shows **Saved changes not published**.

If someone else saved the template after you opened it, Publish stops with `DRAFT_CHANGED` and
publishes nothing. Reload the template, preview their changes, then publish again. **Restore as
draft** follows the same rule.

## 5. Verify positive and negative outcomes

- Generate against the Account used for preview. Expect the Account name and visible Contacts in
  name order.
- Generate against an Account with no visible Contacts. Expect the `else` text.
- Test as a user without access to one required field. Expect an access failure and no partial
  prompt.
- Deactivate the template and retry. Expect generation to refuse the inactive template.

Next, [configure the record-page component](../lightning-record-page/README.md) or use the
[Flow and Apex API](../developer-guides/README.md).
