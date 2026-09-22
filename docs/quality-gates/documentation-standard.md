# Documentation quality and accuracy standard

Use this standard for every page in `docs`.

## Verify before writing

1. Read the page from beginning to end.
2. Identify the single Salesforce task or reference contract the page owns.
3. Verify labels, API names, permissions, defaults, limits, signatures, and result behavior against
   package source or executable configuration.
4. State any org, browser, packaging, or release claim that has not been exercised as unverified.
5. Update navigation and every affected contract surface.

## Write for the reader's task

- Start with the outcome and when to use it.
- State prerequisites before steps or code.
- Use exact Salesforce labels and format API names as code.
- Give steps in execution order and state the expected result.
- Explain recovery for a relevant failure.
- Keep release procedures in contributor documentation and product behavior in user guides.

A task guide, architecture page, and exact reference should not use identical structures. A task
guide teaches an outcome; architecture explains boundaries and flow; reference defines precise
values and contracts.

## Make examples safe

- Identify where every sample record ID, automation key, and Apex variable comes from.
- Use placeholders such as `TARGET_ALIAS` where an environment-specific value is required.
- State required Permission Sets and customer-data access before the example.
- Branch on `success` before reading an API response's `prompt`.
- Never encourage logging prompt content or customer values.
- Distinguish a health or domain result from a Salesforce job or test result.

## Give each task one owner

Do not create competing end-to-end walkthroughs. Folder indexes route readers to the owner page;
reference pages provide exact contracts without duplicating the entire procedure. When behavior
changes, update its owner page, relevant reference, architecture/security description, tests, and
navigation in the same change.

## Validate

Run `npm run check:docs` and `npm run prettier:verify`. Then read each changed page in rendered
order and confirm a junior Salesforce administrator or developer can complete the task without
guessing. Passing a link or formatting check does not verify a technical claim.
