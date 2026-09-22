# Configure Prompt Generator on a record page

The **Prompt Generator** component lets a user choose a published template for the current record,
add optional instructions before and after the generated text, edit the result, and copy the
complete prompt.

## Before you start

- Publish at least one template whose Salesforce object matches the record page object.
- Assign the user the **Prompt Context Generate** Permission Set.
- Preserve the user's ordinary object, field, and record access; the component does not elevate it.

## Add and activate the component

1. Open a record in Lightning Experience.
2. Select **Setup → Edit Page**.
3. Drag **Prompt Generator** onto the page.
4. Save and activate the page for the intended app and record type.
5. Return to a record and refresh the page.

When exactly one matching template exists, the component selects it automatically. When choices
change because the record object or published templates change, an unavailable previous choice and
its generated output are cleared.

## Use the component

1. Choose a published template.
2. Optionally enter text in **Add instructions at the top (optional)**.
3. Select **Generate record context**.
4. Review and edit **Generated record context (editable)**.
5. Optionally enter text in **Add instructions at the bottom (optional)**.
6. Select **Copy complete prompt**.

Copying is an explicit browser action. The component does not save the prompt to Salesforce or
browser storage. **Start over** clears the optional instructions, generated text, messages, and
data set counts. While generation is running, the template and text controls are disabled so the
completed result cannot be combined with edits made for a different request.

A successful generation remains visible even when every merge value renders as blank. In that
case, review the displayed warnings and data set counts before adding text or copying the result.

## Troubleshooting

- **No published templates:** confirm the template is Published and its Salesforce object matches the
  record page.
- **Generate is disabled:** choose a template and use the component on a saved record.
- **Access error:** assign generation capability, then verify read access to every configured
  object and field and visibility to the current record.
- **Copy unavailable:** browser clipboard access can be restricted. Select the text and copy it
  manually.
