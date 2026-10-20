import { LightningElement, api } from "lwc";

const FILTER_OPERATORS = [
  { label: "Equals", value: "EQ" },
  { label: "Does not equal", value: "NE" },
  { label: "Greater than", value: "GT" },
  { label: "Greater than or equal", value: "GTE" },
  { label: "Less than", value: "LT" },
  { label: "Less than or equal", value: "LTE" },
  { label: "Contains", value: "CONTAINS" },
  { label: "Starts with", value: "STARTS_WITH" },
  { label: "Is one of", value: "IN" },
  { label: "Is not one of", value: "NOT_IN" },
  { label: "Is blank", value: "IS_NULL" },
  { label: "Is not blank", value: "NOT_NULL" }
];

const BOOLEAN_VALUES = [
  { label: "True", value: "true" },
  { label: "False", value: "false" }
];
const NUMBER_TYPES = ["CURRENCY", "DOUBLE", "INTEGER", "LONG", "PERCENT"];
const LIST_OPERATORS = ["IN", "NOT_IN"];
export const BLANK_OPERATORS = ["IS_NULL", "NOT_NULL"];

const SORT_DIRECTIONS = [
  { label: "Ascending", value: "ASC" },
  { label: "Descending", value: "DESC" }
];

const NULLS_OPTIONS = [
  { label: "Platform default", value: "" },
  { label: "Blank values first", value: "FIRST" },
  { label: "Blank values last", value: "LAST" }
];

const FILTER_GROUP_JOINS = [
  { label: "Every group must match (AND)", value: "AND" },
  { label: "Any group may match (OR)", value: "OR" }
];

/**
 * Describes how one filter value should be entered for its field type and rule.
 * @param {object} filter Filter row
 * @param {object} fieldOption Field option with dataType and picklist values
 * @returns {object} Input kind, placeholder, help text, and choices
 */
export function describeFilterValue(filter, fieldOption) {
  const dataType = fieldOption?.dataType || "";
  const isList = LIST_OPERATORS.includes(filter.operator);
  const picklistValues = fieldOption?.picklistValues || [];
  if (BLANK_OPERATORS.includes(filter.operator)) {
    return {
      kind: "none",
      placeholder: "No value needed",
      help: "This rule does not use a value."
    };
  }
  if (dataType === "BOOLEAN" && !isList) {
    return { kind: "boolean", choices: BOOLEAN_VALUES, help: "" };
  }
  if (dataType === "PICKLIST" && !isList && picklistValues.length) {
    return {
      kind: "choice",
      choices: picklistValues,
      help: "Choose a value. Prompt Context Builder stores its API name."
    };
  }
  let placeholder = "Value";
  let help = "";
  if (dataType === "DATE") {
    placeholder = "2026-10-19 or LAST_N_DAYS:30";
    help =
      "Use YYYY-MM-DD or a relative date such as TODAY, THIS_QUARTER, or LAST_N_DAYS:30.";
  } else if (dataType === "DATETIME") {
    placeholder = "2026-10-19T09:00:00Z or THIS_WEEK";
    help =
      "Use an ISO date and time with a time zone, or a relative date such as THIS_WEEK or LAST_N_DAYS:30.";
  } else if (NUMBER_TYPES.includes(dataType)) {
    placeholder = "2500.50";
    help = "Use a number without currency symbols or thousands separators.";
  } else if (dataType === "PICKLIST" || dataType === "MULTIPICKLIST") {
    help = picklistValues.length
      ? `Use API values: ${picklistValues
          .slice(0, 10)
          .map((option) => option.value)
          .join(", ")}${picklistValues.length > 10 ? ", …" : ""}`
      : "Use the picklist API value, not its label.";
  }
  if (isList) {
    placeholder = "First, Second, Third";
    help = `Separate up to 50 values with commas. ${help}`.trim();
  }
  return { kind: "text", placeholder, help };
}

let keySequence = 0;

/**
 * Edits the filter groups and sort order of one data set. Every edit is raised as a ruleschange
 * event; the builder applies it to the data set.
 */
export default class PromptFilterSortEditor extends LightningElement {
  @api source;
  @api disabled = false;
  filterOperators = FILTER_OPERATORS;
  sortDirections = SORT_DIRECTIONS;
  nullsOptions = NULLS_OPTIONS;
  filterGroupJoinOptions = FILTER_GROUP_JOINS;

  get usesFilterLogic() {
    return Boolean(this.source.filterLogic?.trim());
  }

  get filters() {
    const fieldOptions = this.source.fieldOptions || [];
    return (this.source.filters || []).map((filter, rowIndex) => {
      const valueView = describeFilterValue(
        filter,
        fieldOptions.find((option) => option.value === filter.fieldName)
      );
      return {
        ...filter,
        number: rowIndex + 1,
        groupDisabled: this.usesFilterLogic,
        isTextValue: valueView.kind === "text" || valueView.kind === "none",
        valueDisabled: valueView.kind === "none",
        valueChoices: valueView.choices || [],
        valuePlaceholder: valueView.placeholder || "",
        valueHelp: valueView.help || ""
      };
    });
  }

  handleSetting(event) {
    this.notify({
      [event.target.name]: event.detail?.value ?? event.target.value
    });
  }

  addFilter() {
    this.notify({
      filters: [
        ...this.source.filters,
        {
          clientKey: `added-filter-${++keySequence}`,
          fieldName: "",
          operator: "EQ",
          value: "",
          groupName: this.usesFilterLogic ? "" : "group_1"
        }
      ]
    });
  }

  addSort() {
    this.notify({
      sorts: [
        ...this.source.sorts,
        {
          clientKey: `added-sort-${++keySequence}`,
          fieldName: "",
          direction: "ASC",
          nullsOrder: ""
        }
      ]
    });
  }

  handleRowField(event) {
    const { collection } = event.target.dataset;
    const rowIndex = Number(event.target.dataset.rowIndex);
    const field = event.target.name;
    const value = event.detail?.value ?? event.target.value;
    this.notify({
      [collection]: this.source[collection].map((row, index) => {
        return index === rowIndex ? { ...row, [field]: value } : row;
      })
    });
  }

  removeRow(event) {
    const { collection } = event.target.dataset;
    const rowIndex = Number(event.target.dataset.rowIndex);
    this.notify({
      [collection]: this.source[collection].filter(
        (row, index) => index !== rowIndex
      )
    });
  }

  notify(changes) {
    this.dispatchEvent(new CustomEvent("ruleschange", { detail: { changes } }));
  }
}
