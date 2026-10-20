import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { BLANK_OPERATORS } from "c/promptFilterSortEditor";

const SOURCE_MODES = [
  { label: "Match a current record field", value: "RELATED" },
  { label: "Reference records", value: "REFERENCE" }
];
const RESULT_MODES = [
  { label: "Records", value: "RECORDS" },
  { label: "One calculated value", value: "AGGREGATE" }
];
const AGGREGATE_OPERATIONS = [
  { label: "Count records", value: "COUNT" },
  { label: "Sum a field", value: "SUM" },
  { label: "Average a field", value: "AVG" },
  { label: "Minimum field value", value: "MIN" },
  { label: "Maximum field value", value: "MAX" }
];

let keySequence = 0;

/**
 * Prepares a saved or starter data set for editing: fills defaults, gives the data set and its rows
 * fresh render keys, and resets the prompt field to insert to the first selected field.
 * @param {object} source Data set from the server or a starter recipe
 * @returns {object} Data set ready for the editor
 */
export function prepareSource(source) {
  return {
    ...source,
    sourceMode: source.sourceMode || "RELATED",
    resultMode: source.resultMode || "RECORDS",
    filterGroupJoin: source.filterGroupJoin || "AND",
    filterLogic: source.filterLogic || "",
    selectedFields: source.selectedFields || [],
    clientKey: `source-${++keySequence}`,
    fieldOptions: source.fieldOptions || [],
    mergeField: source.selectedFields?.[0] || "",
    showAdvanced: source.showAdvanced === true,
    filters: (source.filters || []).map((filter) => ({
      ...filter,
      groupName: source.filterLogic ? "" : filter.groupName || "group_1",
      clientKey: `filter-${++keySequence}`
    })),
    sorts: (source.sorts || []).map((sort) => ({
      ...sort,
      clientKey: `sort-${++keySequence}`
    }))
  };
}

/**
 * Creates an empty data set whose reference name is not used by the existing data sets.
 * @param {object[]} sources Existing data sets
 * @returns {object} New data set ready for the editor
 */
export function createSource(sources) {
  const usedReferenceNames = new Set(
    sources.map((source) => source.referenceName)
  );
  let sourceNumber = sources.length + 1;
  while (usedReferenceNames.has(`related_records_${sourceNumber}`)) {
    sourceNumber += 1;
  }
  return {
    clientKey: `source-${++keySequence}`,
    referenceName: `related_records_${sourceNumber}`,
    sourceMode: "RELATED",
    resultMode: "RECORDS",
    aggregateOperation: null,
    aggregateField: null,
    relatedObject: "",
    correlationField: "",
    rootField: "Id",
    selectedFields: [],
    filters: [],
    filterGroupJoin: "AND",
    filterLogic: "",
    sorts: [],
    maxRows: 10,
    sequence: sourceNumber,
    active: true,
    fieldOptions: [],
    mergeField: "",
    showAdvanced: false
  };
}

/**
 * Summarizes how much data the active data sets request.
 * @param {object[]} sources Data sets of one template
 * @returns {string} Data set, returned record, and calculated value counts
 */
export function describeSourceBudget(sources) {
  const activeSources = sources.filter((source) => source.active !== false);
  const recordSources = activeSources.filter(
    (source) => source.resultMode !== "AGGREGATE"
  );
  const aggregateSources = activeSources.length - recordSources.length;
  const requestedRows = recordSources.reduce(
    (total, source) => total + (Number(source.maxRows) || 0),
    0
  );
  return `${activeSources.length} data set${activeSources.length === 1 ? "" : "s"} included · up to ${requestedRows} returned records · ${aggregateSources} calculated value${aggregateSources === 1 ? "" : "s"} · 200 returned records allowed per template`;
}

/**
 * Returns the stored shape of one data set, without editor-only state.
 * @param {object} source Data set as edited in Prompt Builder
 * @returns {object} Data set as the server saves it
 */
export function toServerSource(source) {
  const filterLogic = source.filterLogic?.trim() || null;
  return {
    id: source.id,
    referenceName: source.referenceName,
    sourceMode: source.sourceMode,
    resultMode: source.resultMode,
    aggregateOperation: source.aggregateOperation,
    aggregateField: source.aggregateField,
    relatedObject: source.relatedObject,
    correlationField: source.correlationField,
    rootField: source.rootField,
    selectedFields: source.selectedFields,
    filters: source.filters.map((filter) => ({
      fieldName: filter.fieldName,
      operator: filter.operator,
      value: BLANK_OPERATORS.includes(filter.operator) ? "" : filter.value,
      groupName: filterLogic ? null : filter.groupName
    })),
    filterGroupJoin: filterLogic ? "AND" : source.filterGroupJoin || "AND",
    filterLogic,
    sorts: source.sorts.map((sort) => ({
      fieldName: sort.fieldName,
      direction: sort.direction,
      nullsOrder: sort.nullsOrder
    })),
    maxRows: source.maxRows,
    sequence: source.sequence,
    active: source.active
  };
}

/**
 * Edits one data set. The builder owns the data set and applies each event:
 * sourcechange marks the template as changed, sourceviewchange only changes what the editor shows,
 * sourceremove deletes the data set, and textinsert adds merge syntax to the template body.
 */
export default class PromptDataSetEditor extends LightningElement {
  @api source;
  @api objectOptions = [];
  @api rootFieldOptions = [];
  @api disabled = false;
  sourceModeOptions = SOURCE_MODES;
  resultModeOptions = RESULT_MODES;
  aggregateOperationOptions = AGGREGATE_OPERATIONS;

  get isAggregate() {
    return this.source.resultMode === "AGGREGATE";
  }

  get isRecords() {
    return !this.isAggregate;
  }

  get isRelated() {
    return this.source.sourceMode !== "REFERENCE";
  }

  get needsAggregateField() {
    return this.isAggregate && this.source.aggregateOperation !== "COUNT";
  }

  get selectedFieldOptions() {
    return (this.source.fieldOptions || []).filter((option) =>
      this.source.selectedFields.includes(option.value)
    );
  }

  get advancedLabel() {
    return this.source.showAdvanced
      ? "Hide optional filters and sorting"
      : "Show optional filters and sorting";
  }

  get completionText() {
    const source = this.source;
    const hasPromptData = this.isAggregate
      ? Boolean(
          source.aggregateOperation &&
          (source.aggregateOperation === "COUNT" || source.aggregateField)
        )
      : source.selectedFields.length > 0;
    return source.relatedObject &&
      hasPromptData &&
      (!this.isRelated || source.correlationField)
      ? "This data set is ready to validate."
      : "Choose the scope, object, match fields, and prompt fields.";
  }

  get modeHelp() {
    return this.isRelated
      ? "Salesforce matches a field on this object to a field on the current record. The objects do not need a lookup relationship."
      : "Independent of the current record. Sharing, field access, filters, sorting, and limits still apply.";
  }

  get querySummary() {
    const source = this.source;
    const filterLogic = source.filterLogic?.trim();
    const filterText = source.filters?.length
      ? filterLogic
        ? `filters combined as ${filterLogic}`
        : `${source.filters.length} filter${source.filters.length === 1 ? "" : "s"}`
      : "no extra filters";
    const sortText = source.sorts?.length
      ? `${source.sorts.length} chosen sort${source.sorts.length === 1 ? "" : "s"}, followed by Id`
      : "Id ascending";
    const scopeText = this.isRelated
      ? `records where ${source.correlationField || "source match field"} equals current record ${source.rootField || "match field"}`
      : "visible reference records";
    const objectText = source.relatedObject || "Choose an object";
    return this.isAggregate
      ? `${objectText}: ${scopeText}; ${filterText}; one ${source.aggregateOperation || "calculated"} value.`
      : `${objectText}: ${scopeText}; ${filterText}; ${sortText}; limit ${source.maxRows || 10}.`;
  }

  handleField(event) {
    const source = this.source;
    const field = event.target.name;
    let value =
      event.target.type === "checkbox"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    if (field === "maxRows" || field === "sequence") {
      value = Number(value);
    }
    const changes = { [field]: value };
    if (field === "sourceMode") {
      Object.assign(changes, {
        correlationField: value === "REFERENCE" ? "" : source.correlationField,
        rootField: value === "REFERENCE" ? "" : source.rootField || "Id"
      });
    }
    if (field === "resultMode") {
      Object.assign(changes, {
        selectedFields: value === "AGGREGATE" ? [] : source.selectedFields,
        sorts: value === "AGGREGATE" ? [] : source.sorts,
        aggregateOperation:
          value === "AGGREGATE" ? source.aggregateOperation || "COUNT" : null,
        aggregateField: value === "AGGREGATE" ? source.aggregateField : null,
        mergeField: value === "AGGREGATE" ? "" : source.mergeField
      });
    }
    if (field === "aggregateOperation" && value === "COUNT") {
      changes.aggregateField = null;
    }
    if (field === "relatedObject") {
      Object.assign(changes, {
        correlationField: "",
        selectedFields: [],
        filters: [],
        sorts: [],
        fieldOptions: [],
        mergeField: ""
      });
    }
    this.notify("sourcechange", changes);
  }

  handleSelectedFields(event) {
    const selectedFields = event.detail.value;
    const currentMergeField = this.source.mergeField;
    this.notify("sourcechange", {
      selectedFields,
      mergeField: selectedFields.includes(currentMergeField)
        ? currentMergeField
        : selectedFields[0] || ""
    });
  }

  handleRulesChange(event) {
    this.notify("sourcechange", event.detail.changes);
  }

  handleMergeField(event) {
    this.notify("sourceviewchange", { mergeField: event.detail.value });
  }

  toggleAdvanced() {
    this.notify("sourceviewchange", {
      showAdvanced: !this.source.showAdvanced
    });
  }

  remove() {
    this.dispatchEvent(new CustomEvent("sourceremove"));
  }

  insertEach() {
    const source = this.source;
    if (this.hasReferenceName()) {
      this.insert(
        `{!#each related.${source.referenceName} as="row"}\n- {!row.${source.mergeField || source.selectedFields?.[0] || "Id"}}\n{!else}\nNo records found.\n{!/each}`
      );
    }
  }

  insertField() {
    const source = this.source;
    const fieldName = source.mergeField || source.selectedFields?.[0];
    if (!source.referenceName || !fieldName) {
      this.toast(
        "Choose a field",
        "Enter a reference name and select at least one prompt field first."
      );
      return;
    }
    this.insert(`{!related.${source.referenceName}[0].${fieldName}}`);
  }

  insertCount() {
    if (this.hasReferenceName()) {
      this.insert(`{!related.${this.source.referenceName}.count}`);
    }
  }

  insertAggregateValue() {
    if (this.hasReferenceName()) {
      this.insert(`{!aggregate.${this.source.referenceName}.value}`);
    }
  }

  hasReferenceName() {
    if (!this.source.referenceName) {
      this.toast(
        "Reference name needed",
        "Enter a reference name for this data set first."
      );
    }
    return Boolean(this.source.referenceName);
  }

  insert(text) {
    this.dispatchEvent(new CustomEvent("textinsert", { detail: { text } }));
  }

  notify(eventName, changes) {
    this.dispatchEvent(new CustomEvent(eventName, { detail: { changes } }));
  }

  toast(title, message) {
    this.dispatchEvent(
      new ShowToastEvent({ title, message, variant: "warning" })
    );
  }
}
