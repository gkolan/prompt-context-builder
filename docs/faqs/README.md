# Frequently asked questions

## Does it call ChatGPT or another model?

No. It builds plain text from Salesforce data. Copying or sending that text elsewhere is a separate
user or integration decision.

## Does it save generated prompts?

No. Published template settings and operation counts are stored. Generated customer text is not.

## Do administrators write database searches?

No. They select Salesforce objects, fields, filters, sorting, and limits. Prompt Context Builder
creates the Salesforce searches from those choices.

## Why did fallback not hide a field-access error?

Fallback applies when a readable field is blank or a requested record is missing. Using fallback
for an inaccessible field would hide a security problem, so generation fails instead.

## What is the difference between related records and a reference list?

Related records match a selected field to a value on the current record. A reference list skips
that match and includes a limited set of shared records the person can access.

## Can two data sets use the same Salesforce object?

Yes. Each data set has its own reference name, fields, filters, order, and limit.

## Why is a template missing from the record page?

It must be Published and its Salesforce object must match the record page object. The user also
needs the generation Permission Set.
