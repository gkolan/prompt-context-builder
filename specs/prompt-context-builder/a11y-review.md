# Accessibility review

Reviewed the deployed `promptTemplateBuilder` and `promptGenerator` source against the applicable
WCAG 2.2 Level A/AA criteria. Lightning base components are treated as providing their documented
name, role, value, keyboard, focus, and error behavior when used with explicit labels.

| Success criterion            | Violations | Evidence                                                                                                                                                                                                                                         |
| ---------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1.1.1 Non-text Content       | None       | There are no content images. Every icon-only remove action has `alternative-text`; labeled Lightning buttons expose their visible label.                                                                                                         |
| 1.3.1 Info and Relationships | None       | Form controls have explicit labels. Numbered workflow areas are semantic `section` elements labeled by headings. Source configurations are `article` elements. The access manifest exposes table, row, column-header, and cell roles.            |
| 1.4.1 Use of Color           | None       | Status, errors, warnings, health, and classifications are always present as text; color is not the only carrier.                                                                                                                                 |
| 1.4.3 Contrast (Minimum)     | None       | Custom surfaces use SLDS semantic surface/on-surface tokens, with explicit accessible fallbacks. Text contrast is not weakened by component CSS.                                                                                                 |
| 1.4.10 Reflow                | None       | Grids wrap and the editor changes from two columns to one below 48rem. The access manifest is a data-table exception and uses a contained horizontal scroll area to avoid clipping the page.                                                     |
| 1.4.11 Non-text Contrast     | None       | Controls and focus indicators are Lightning base components. Custom panels use SLDS border/surface tokens; no custom state indicator depends on a low-contrast outline.                                                                          |
| 2.1.1 Keyboard               | None       | All actions use Lightning buttons, button icons, inputs, comboboxes, textareas, accordion, or record picker. There are no click-only `div` or `span` controls and no custom focus order.                                                         |
| 2.4.6 Headings and Labels    | None       | Headings follow the workflow hierarchy; action and field labels describe their purpose and include source-specific context where needed.                                                                                                         |
| 2.5.3 Label in Name          | None       | Visible button text is supplied through each Lightning button's `label`; icon-only controls use matching alternative text and title.                                                                                                             |
| 3.2.1 On Focus               | None       | Focus does not trigger navigation, submission, or context changes.                                                                                                                                                                               |
| 3.2.2 On Input               | None       | Input changes update local configuration only. Destructive or lifecycle changes require an explicit labeled button. Changing a root object clears dependent source configuration by design and the control label communicates the changed scope. |
| 3.3.1 Error Identification   | None       | Validation messages include severity, location, and explanatory text; runtime messages are announced in polite status regions.                                                                                                                   |
| 3.3.2 Labels or Instructions | None       | Required controls are marked, advanced relationships have inline help or adjacent guidance, and the guided source status states what remains.                                                                                                    |
| 3.3.3 Error Suggestion       | None       | Server and client messages state corrective actions without exposing record values, query text, or bind values.                                                                                                                                  |
| 4.1.2 Name, Role, Value      | None       | Semantic HTML and Lightning base components provide programmatic name/role/value. Live status regions use valid `status` and `aria-live="polite"` values.                                                                                        |

## Browser evidence completed

The deployed wide and 390-by-844 journeys in `docs/screenshots/README.md` were visually inspected.
Labels, status text, semantic headings, one-column reflow, and action wrapping remained readable;
there was no page-level horizontal clipping. The access-manifest table keeps its bounded internal
scroll exception. Record generation, validation, preview, and comparison states were also verified
through the browser accessibility tree before package creation.
