import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getObjectOptions from "@salesforce/apex/PromptContextController.getObjectOptions";
import getFieldOptions from "@salesforce/apex/PromptContextController.getFieldOptions";
import getTemplate from "@salesforce/apex/PromptContextController.getTemplate";
import getTemplateSummaryPage from "@salesforce/apex/PromptContextController.getTemplateSummaryPage";
import saveDraft from "@salesforce/apex/PromptContextController.saveDraft";
import preview from "@salesforce/apex/PromptContextController.preview";
import publishTemplate from "@salesforce/apex/PromptContextController.publish";
import deactivateTemplate from "@salesforce/apex/PromptContextController.deactivateTemplate";
import checkTemplateHealth from "@salesforce/apex/PromptContextController.checkTemplateHealth";
import getTemplateVersions from "@salesforce/apex/PromptContextController.getTemplateVersions";
import compareTemplateVersions from "@salesforce/apex/PromptContextController.compareTemplateVersions";
import restoreTemplateVersion from "@salesforce/apex/PromptContextController.restoreTemplateVersion";

const FILTER_OPERATORS = [
  { label: "Equals", value: "EQ" },
  { label: "Does not equal", value: "NE" },
  { label: "Greater than", value: "GT" },
  { label: "Greater than or equal", value: "GTE" },
  { label: "Less than", value: "LT" },
  { label: "Less than or equal", value: "LTE" },
  { label: "Contains", value: "CONTAINS" },
  { label: "Starts with", value: "STARTS_WITH" },
  { label: "Is blank", value: "IS_NULL" },
  { label: "Is not blank", value: "NOT_NULL" }
];

const SORT_DIRECTIONS = [
  { label: "Ascending", value: "ASC" },
  { label: "Descending", value: "DESC" }
];

const NULLS_OPTIONS = [
  { label: "Platform default", value: "" },
  { label: "Blank values first", value: "FIRST" },
  { label: "Blank values last", value: "LAST" }
];

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

const FILTER_GROUP_JOINS = [
  { label: "Every group must match (AND)", value: "AND" },
  { label: "Any group may match (OR)", value: "OR" }
];

const FILE_INPUT_MODES = [
  { label: "Do not include Salesforce Files", value: "DISABLED" },
  { label: "Let the user choose Files", value: "USER_SELECT" },
  { label: "Include all eligible Files", value: "ALL_ELIGIBLE" }
];

const TEMPLATE_PAGE_SIZE = 50;

const RECIPES = [
  {
    label: "Record identity",
    value: "record_identity",
    rootObject: null,
    description: "Start with the current record ID on any object.",
    templateBody: "Record ID: {!record.Id}",
    sources: []
  },
  {
    label: "Account overview",
    value: "account_overview",
    rootObject: "Account",
    description: "Summarize standard Account details.",
    templateBody:
      'Summarize this account.\n\nName: {!record.Name}\nIndustry: {!record.Industry fallback="Not provided"}\nDescription: {!record.Description fallback="Not provided"}',
    sources: []
  },
  {
    label: "Account with contacts",
    value: "account_contacts",
    rootObject: "Account",
    description: "Include up to ten Account contacts in name order.",
    templateBody:
      'Account: {!record.Name}\n\nContacts ({!related.contacts.count}):\n{!#each related.contacts as="row"}\n- {!row.Name}: {!row.Email fallback="No email"}\n{!else}\nNo visible contacts were found.\n{!/each}',
    sources: [
      {
        referenceName: "contacts",
        sourceMode: "RELATED",
        relatedObject: "Contact",
        correlationField: "AccountId",
        rootField: "Id",
        selectedFields: ["Name", "Email"],
        filters: [],
        sorts: [{ fieldName: "Name", direction: "ASC", nullsOrder: "LAST" }],
        maxRows: 10,
        sequence: 1,
        active: true
      }
    ]
  }
];

function newConfig() {
  return {
    id: null,
    developerKey: null,
    name: "",
    description: "",
    rootObject: "Account",
    templateBody: "",
    status: "Draft",
    version: 0,
    fileInputMode: "DISABLED",
    maxFiles: null,
    requireAtLeastOneFile: false,
    allowedFileFormats: "",
    providerProfileKey: "",
    fileCitationsEnabled: false,
    sources: []
  };
}

function getErrorMessage(error) {
  return (
    error?.body?.message || error?.message || "An unexpected error occurred."
  );
}

export default class PromptTemplateBuilder extends LightningElement {
  config = newConfig();
  objectOptions = [];
  rootFieldOptions = [];
  templates = [];
  templateSearch = "";
  templateAfterName = null;
  templateAfterId = null;
  hasMoreTemplates = false;
  isCatalogLoading = false;
  catalogRequestId = 0;
  templateRequestId = 0;
  selectedTemplateId = "";
  rootMergeField = "";
  sampleRecordId = "";
  previewText = "";
  messages = [];
  accessManifest = [];
  healthCheckedAt = null;
  selectedRecipe = "";
  versions = [];
  fromVersion = "";
  toVersion = "";
  comparisonChanges = [];
  isLoading = false;
  isDirty = false;
  filterOperators = FILTER_OPERATORS;
  sortDirections = SORT_DIRECTIONS;
  nullsOptions = NULLS_OPTIONS;
  sourceModeOptions = SOURCE_MODES;
  resultModeOptions = RESULT_MODES;
  aggregateOperationOptions = AGGREGATE_OPERATIONS;
  filterGroupJoinOptions = FILTER_GROUP_JOINS;
  fileInputModeOptions = FILE_INPUT_MODES;
  syntaxExamples = [
    { key: "root", label: "Current record field", syntax: "{!record.Name}" },
    {
      key: "fallback",
      label: "Fallback",
      syntax: '{!record.Phone fallback="Not provided"}'
    },
    {
      key: "row",
      label: "One related row",
      syntax: "{!related.recent_contacts[0].Email}"
    },
    {
      key: "count",
      label: "Related count",
      syntax: "{!related.recent_contacts.count}"
    },
    {
      key: "aggregate",
      label: "Calculated value",
      syntax: "{!aggregate.open_value.value}"
    },
    {
      key: "each",
      label: "Repeat rows",
      syntax:
        '{!#each related.recent_contacts as="row"} {!row.Name} {!else} None {!/each}'
    },
    {
      key: "if",
      label: "Conditional",
      syntax:
        "{!#if related.recent_contacts.hasRecords} Found records {!else} None {!/if}"
    }
  ];
  keySequence = 0;

  @wire(getObjectOptions)
  wiredObjects({ data, error }) {
    if (data) {
      this.objectOptions = data;
      this.loadRootFields();
    } else if (error) {
      this.showError(error);
    }
  }

  connectedCallback() {
    this.refreshTemplates();
  }

  get templateOptions() {
    return [
      { label: "New template", value: "" },
      ...this.templates.map((template) => ({
        label: `${template.name}: ${template.status}`,
        value: template.id
      }))
    ];
  }

  get hasSources() {
    return this.config.sources.length > 0;
  }

  get filesEnabled() {
    return this.config.fileInputMode !== "DISABLED";
  }

  get hasMessages() {
    return this.messages.length > 0;
  }

  get hasPreview() {
    return Boolean(this.previewText);
  }

  get statusText() {
    const dirtyText = this.isDirty ? " · Unsaved changes" : "";
    const healthText = this.config.lastHealthStatus
      ? ` · Health ${this.config.lastHealthStatus}`
      : "";
    return `${this.config.status || "Draft"} · Version ${this.config.version || 0}${healthText}${dirtyText}`;
  }

  get hasStoredHealth() {
    return Boolean(this.config.lastHealthStatus);
  }

  get storedHealthText() {
    if (!this.config.lastHealthStatus) {
      return "";
    }
    const version = this.config.lastHealthVersion
      ? `version ${this.config.lastHealthVersion}`
      : "the published version";
    const checkedAt = this.config.lastHealthCheckedAt
      ? new Intl.DateTimeFormat(undefined, {
          dateStyle: "medium",
          timeStyle: "short"
        }).format(new Date(this.config.lastHealthCheckedAt))
      : "an unknown time";
    const codes = this.config.lastHealthCodes || "OK";
    return `${this.config.lastHealthStatus}: ${version} checked ${checkedAt}. Codes: ${codes}.`;
  }

  get viewMessages() {
    return this.messages.map((message, index) => ({
      ...message,
      key: `${message.severity}-${message.code}-${message.location}-${index}`
    }));
  }

  get isActionDisabled() {
    return this.isLoading;
  }

  get recipeOptions() {
    return [
      { label: "Choose a starter recipe", value: "" },
      ...RECIPES.filter(
        (recipe) =>
          !recipe.rootObject || recipe.rootObject === this.config.rootObject
      ).map((recipe) => ({
        label: `${recipe.label}: ${recipe.description}`,
        value: recipe.value
      }))
    ];
  }

  get hasAccessManifest() {
    return (this.accessManifest || []).length > 0;
  }

  get versionOptions() {
    return (this.versions || []).map((version) => ({
      label: `Version ${version.versionNumber}, ${new Intl.DateTimeFormat().format(new Date(version.publishedAt))}`,
      value: String(version.versionNumber)
    }));
  }

  get hasVersions() {
    return (this.versions || []).length > 0;
  }

  get hasComparison() {
    return (this.comparisonChanges || []).length > 0;
  }

  get latestPreviewText() {
    return this.previewText || "Run Preview to see the merged prompt here.";
  }

  get editorGuidance() {
    const body = this.config.templateBody || "";
    const openings = (body.match(/\{!#(?:each|if)\b/g) || []).length;
    const closings = (body.match(/\{!\/(?:each|if)\}/g) || []).length;
    if (openings !== closings) {
      return "A block appears incomplete. Match every each or if opening tag with a closing tag.";
    }
    if (!body.includes("{!")) {
      return "Insert at least one field from the current record or related data.";
    }
    return "The repeat and condition blocks look complete. Select Validate to check fields, access, and related data.";
  }

  get cannotPublish() {
    return (
      this.isLoading ||
      !this.sampleRecordId ||
      !this.config.name ||
      !this.config.rootObject ||
      !this.config.templateBody
    );
  }

  get publishGuidance() {
    if (
      !this.config.name ||
      !this.config.rootObject ||
      !this.config.templateBody
    ) {
      return "Enter the template name, choose a Salesforce object, and write the prompt before publishing.";
    }
    if (!this.sampleRecordId) {
      return "Choose a preview record. Publishing requires a successful real-record preview.";
    }
    return "Ready to validate and publish. Salesforce checks each person's access whenever the template runs.";
  }

  get cannotDeactivate() {
    return (
      this.isLoading || !this.config.id || this.config.status === "Inactive"
    );
  }

  get templateCharacterCount() {
    return (this.config.templateBody || "").length;
  }

  get sourceBudgetText() {
    const activeSources = this.config.sources.filter(
      (source) => source.active !== false
    );
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

  async refreshTemplates(reset = true) {
    if (!reset && this.isCatalogLoading) {
      return;
    }
    const requestId = ++this.catalogRequestId;
    this.isCatalogLoading = true;
    try {
      const page = await getTemplateSummaryPage({
        searchText: this.templateSearch || null,
        pageSize: TEMPLATE_PAGE_SIZE,
        afterName: reset ? null : this.templateAfterName,
        afterId: reset ? null : this.templateAfterId
      });
      if (requestId !== this.catalogRequestId) {
        return;
      }
      const existing = reset ? [] : this.templates;
      const summariesById = new Map(
        [...existing, ...page.items].map((template) => [template.id, template])
      );
      this.templates = [...summariesById.values()];
      this.hasMoreTemplates = page.hasMore;
      this.templateAfterName = page.nextName || null;
      this.templateAfterId = page.nextId || null;
    } catch (error) {
      if (requestId === this.catalogRequestId) {
        this.showError(error);
      }
    } finally {
      if (requestId === this.catalogRequestId) {
        this.isCatalogLoading = false;
      }
    }
  }

  handleTemplateSearch(event) {
    this.templateSearch = event.target.value || "";
    this.refreshTemplates(true);
  }

  loadMoreTemplates() {
    this.refreshTemplates(false);
  }

  keepCurrentTemplateInCatalog() {
    if (!this.config.id) {
      return;
    }
    const currentSummary = {
      id: this.config.id,
      developerKey: this.config.developerKey,
      name: this.config.name,
      description: this.config.description,
      rootObject: this.config.rootObject,
      status: this.config.status,
      version: this.config.version,
      publishedAt: this.config.publishedAt
    };
    this.templates = [
      currentSummary,
      ...this.templates.filter((template) => template.id !== this.config.id)
    ];
  }

  async loadRootFields() {
    const rootObject = this.config.rootObject;
    if (!rootObject) {
      this.rootFieldOptions = [];
      return;
    }
    try {
      const fieldOptions = await getFieldOptions({
        objectApiName: rootObject
      });
      if (this.config.rootObject === rootObject) {
        this.rootFieldOptions = fieldOptions;
      }
    } catch (error) {
      this.showError(error);
    }
  }

  async loadSourceFields(index) {
    const source = this.config.sources[index];
    if (!source?.relatedObject) {
      return;
    }
    const { clientKey, relatedObject } = source;
    const fieldOptions = await getFieldOptions({
      objectApiName: relatedObject
    });
    const currentIndex = this.config.sources.findIndex(
      (currentSource) => currentSource.clientKey === clientKey
    );
    if (
      currentIndex >= 0 &&
      this.config.sources[currentIndex].relatedObject === relatedObject
    ) {
      this.updateSource(currentIndex, { fieldOptions });
    }
  }

  async handleTemplateSelection(event) {
    const requestId = ++this.templateRequestId;
    const requestedTemplateId = event.detail.value;
    if (this.isDirty && requestedTemplateId !== this.selectedTemplateId) {
      event.target.value = this.selectedTemplateId;
      this.toast(
        "Unsaved changes",
        "Save the draft or use Discard changes before opening another template.",
        "warning"
      );
      return;
    }
    this.selectedTemplateId = requestedTemplateId;
    if (!this.selectedTemplateId) {
      this.config = newConfig();
      this.previewText = "";
      this.messages = [];
      this.sampleRecordId = "";
      this.isDirty = false;
      this.resetGovernanceState();
      this.loadRootFields();
      return;
    }
    this.isLoading = true;
    try {
      const selected = await getTemplate({
        templateId: this.selectedTemplateId
      });
      if (requestId !== this.templateRequestId) {
        return;
      }
      this.config = this.decorateConfig(selected);
      this.previewText = "";
      this.messages = [];
      this.sampleRecordId = "";
      this.isDirty = false;
      this.resetGovernanceState();
      await this.loadRootFields();
      await Promise.all(
        this.config.sources.map((source, index) => this.loadSourceFields(index))
      );
      await this.loadVersions();
    } catch (error) {
      if (requestId === this.templateRequestId) {
        this.showError(error);
      }
    } finally {
      if (requestId === this.templateRequestId) {
        this.isLoading = false;
      }
    }
  }

  handleTemplateField(event) {
    const field = event.target.name;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    this.config = { ...this.config, [field]: value };
    this.markDirty();
    if (field === "rootObject") {
      this.config = { ...this.config, sources: [] };
      this.rootMergeField = "";
      this.sampleRecordId = "";
      this.loadRootFields();
    }
    if (field === "fileInputMode" && value === "DISABLED") {
      this.config = {
        ...this.config,
        maxFiles: null,
        requireAtLeastOneFile: false,
        allowedFileFormats: "",
        providerProfileKey: "",
        fileCitationsEnabled: false
      };
    }
  }

  handleRootMergeField(event) {
    this.rootMergeField = event.detail.value;
  }

  handleRecipeSelection(event) {
    this.selectedRecipe = event.detail.value;
  }

  async applyRecipe() {
    const recipe = RECIPES.find((item) => item.value === this.selectedRecipe);
    if (!recipe) {
      return;
    }
    this.config = this.decorateConfig({
      ...this.config,
      templateBody: recipe.templateBody,
      sources: recipe.sources.map((source) => ({ ...source }))
    });
    this.previewText = "";
    this.messages = [];
    this.accessManifest = [];
    this.isDirty = true;
    await Promise.all(
      this.config.sources.map((source, index) => this.loadSourceFields(index))
    );
    this.toast(
      "Starter applied",
      "Review the fields and record rules, then validate with a real record.",
      "success"
    );
  }

  insertRootMerge() {
    if (!this.rootMergeField) {
      return;
    }
    this.appendTemplateText(`{!record.${this.rootMergeField}}`);
  }

  insertSourceEach(event) {
    const source = this.config.sources[Number(event.target.dataset.index)];
    if (!source?.referenceName) {
      this.toast(
        "Reference name needed",
        "Enter a reference name for this data set first.",
        "warning"
      );
      return;
    }
    this.appendTemplateText(
      `{!#each related.${source.referenceName} as="row"}\n- {!row.${source.mergeField || source.selectedFields?.[0] || "Id"}}\n{!else}\nNo records found.\n{!/each}`
    );
  }

  insertSourceField(event) {
    const source = this.config.sources[Number(event.target.dataset.index)];
    const fieldName = source?.mergeField || source?.selectedFields?.[0];
    if (!source?.referenceName || !fieldName) {
      this.toast(
        "Choose a field",
        "Enter a reference name and select at least one prompt field first.",
        "warning"
      );
      return;
    }
    this.appendTemplateText(
      `{!related.${source.referenceName}[0].${fieldName}}`
    );
  }

  insertSourceCount(event) {
    const source = this.config.sources[Number(event.target.dataset.index)];
    if (!source?.referenceName) {
      this.toast(
        "Reference name needed",
        "Enter a reference name for this data set first.",
        "warning"
      );
      return;
    }
    this.appendTemplateText(`{!related.${source.referenceName}.count}`);
  }

  insertAggregateValue(event) {
    const source = this.config.sources[Number(event.target.dataset.index)];
    if (!source?.referenceName) {
      this.toast(
        "Reference name needed",
        "Enter a reference name for this data set first.",
        "warning"
      );
      return;
    }
    this.appendTemplateText(`{!aggregate.${source.referenceName}.value}`);
  }

  appendTemplateText(text) {
    const separator = this.config.templateBody ? "\n" : "";
    this.config = {
      ...this.config,
      templateBody: `${this.config.templateBody || ""}${separator}${text}`
    };
    this.markDirty();
  }

  addSource() {
    const usedReferenceNames = new Set(
      this.config.sources.map((source) => source.referenceName)
    );
    let sourceNumber = this.config.sources.length + 1;
    while (usedReferenceNames.has(`related_records_${sourceNumber}`)) {
      sourceNumber += 1;
    }
    const source = this.decorateSourceView({
      clientKey: `source-${++this.keySequence}`,
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
      sorts: [],
      maxRows: 10,
      sequence: sourceNumber,
      active: true,
      fieldOptions: [],
      mergeField: ""
    });
    this.config = { ...this.config, sources: [...this.config.sources, source] };
    this.markDirty();
  }

  toggleSourceAdvanced(event) {
    const index = Number(event.target.dataset.index);
    const source = this.config.sources[index];
    this.updateSource(index, { showAdvanced: !source.showAdvanced });
  }

  removeSource(event) {
    const index = Number(event.target.dataset.index);
    this.config = {
      ...this.config,
      sources: this.config.sources.filter(
        (source, sourceIndex) => sourceIndex !== index
      )
    };
    this.markDirty();
  }

  handleSourceField(event) {
    const index = Number(event.target.dataset.index);
    const source = this.config.sources[index];
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
    this.updateSource(index, changes);
    if (field === "relatedObject") {
      this.loadSourceFields(index).catch((error) => this.showError(error));
    }
    this.markDirty();
  }

  handleSelectedFields(event) {
    const index = Number(event.target.dataset.index);
    const selectedFields = event.detail.value;
    const currentMergeField = this.config.sources[index].mergeField;
    this.updateSource(index, {
      selectedFields,
      mergeField: selectedFields.includes(currentMergeField)
        ? currentMergeField
        : selectedFields[0] || ""
    });
    this.markDirty();
  }

  handleMergeField(event) {
    this.updateSource(Number(event.target.dataset.index), {
      mergeField: event.detail.value
    });
  }

  addFilter(event) {
    const index = Number(event.target.dataset.index);
    const source = this.config.sources[index];
    this.updateSource(index, {
      filters: [
        ...source.filters,
        {
          clientKey: `filter-${++this.keySequence}`,
          fieldName: "",
          operator: "EQ",
          value: "",
          groupName: "group_1"
        }
      ]
    });
    this.markDirty();
  }

  handleFilterField(event) {
    this.updateNestedRow("filters", event);
  }

  removeFilter(event) {
    this.removeNestedRow("filters", event);
  }

  addSort(event) {
    const index = Number(event.target.dataset.index);
    const source = this.config.sources[index];
    this.updateSource(index, {
      sorts: [
        ...source.sorts,
        {
          clientKey: `sort-${++this.keySequence}`,
          fieldName: "",
          direction: "ASC",
          nullsOrder: ""
        }
      ]
    });
    this.markDirty();
  }

  handleSortField(event) {
    this.updateNestedRow("sorts", event);
  }

  removeSort(event) {
    this.removeNestedRow("sorts", event);
  }

  updateNestedRow(collectionName, event) {
    const sourceIndex = Number(event.target.dataset.index);
    const rowIndex = Number(event.target.dataset.rowIndex);
    const field = event.target.name;
    const value = event.detail?.value ?? event.target.value;
    const source = this.config.sources[sourceIndex];
    const rows = source[collectionName].map((row, index) => {
      return index === rowIndex ? { ...row, [field]: value } : row;
    });
    this.updateSource(sourceIndex, { [collectionName]: rows });
    this.markDirty();
  }

  removeNestedRow(collectionName, event) {
    const sourceIndex = Number(event.target.dataset.index);
    const rowIndex = Number(event.target.dataset.rowIndex);
    const source = this.config.sources[sourceIndex];
    this.updateSource(sourceIndex, {
      [collectionName]: source[collectionName].filter(
        (row, index) => index !== rowIndex
      )
    });
    this.markDirty();
  }

  updateSource(index, changes) {
    this.config = {
      ...this.config,
      sources: this.config.sources.map((source, sourceIndex) => {
        return sourceIndex === index
          ? this.decorateSourceView({ ...source, ...changes })
          : source;
      })
    };
  }

  handleSampleRecord(event) {
    this.sampleRecordId = event.detail.recordId || "";
  }

  async discardChanges() {
    await this.runAction(async () => {
      const selected = this.selectedTemplateId
        ? await getTemplate({ templateId: this.selectedTemplateId })
        : null;
      this.config = selected ? this.decorateConfig(selected) : newConfig();
      this.previewText = "";
      this.messages = [];
      this.sampleRecordId = "";
      this.isDirty = false;
      this.resetGovernanceState();
      await this.loadRootFields();
      await Promise.all(
        this.config.sources.map((source, index) => this.loadSourceFields(index))
      );
      await this.loadVersions();
    });
  }

  duplicateTemplate() {
    this.config = {
      ...this.decorateConfig(this.config),
      id: null,
      developerKey: null,
      name: `${this.config.name || "Template"} Copy`,
      status: "Draft",
      version: 0,
      fingerprint: null,
      publishedAt: null
    };
    this.selectedTemplateId = "";
    this.previewText = "";
    this.messages = [];
    this.resetGovernanceState();
    this.isDirty = true;
  }

  async handleValidate() {
    await this.runAction(async () => {
      const result = await checkTemplateHealth({
        configJson: JSON.stringify(this.toServerConfig())
      });
      this.messages = result.messages;
      this.healthCheckedAt = result.checkedAt;
      this.setAccessManifest(result.accessManifest);
      this.toast(
        result.isValid
          ? "Configuration is valid"
          : "Configuration needs attention",
        result.isValid
          ? "No blocking problems were found."
          : "Review the messages below.",
        result.isValid ? "success" : "error"
      );
    });
  }

  async handlePreview() {
    if (!this.sampleRecordId) {
      this.toast(
        "Sample record needed",
        "Enter a current record ID to preview.",
        "warning"
      );
      return;
    }
    await this.runAction(async () => {
      const result = await preview({
        configJson: JSON.stringify(this.toServerConfig()),
        recordId: this.sampleRecordId
      });
      this.previewText = result.prompt;
      this.messages = result.messages;
    });
  }

  async handleSave() {
    await this.runAction(async () => {
      const saved = await saveDraft({
        configJson: JSON.stringify(this.toServerConfig())
      });
      this.config = this.decorateConfig(saved);
      this.selectedTemplateId = saved.id;
      await this.refreshTemplates();
      this.keepCurrentTemplateInCatalog();
      this.isDirty = false;
      this.toast(
        "Draft saved",
        "The template and related sources were saved.",
        "success"
      );
    });
  }

  async handlePublish() {
    if (!this.sampleRecordId) {
      this.toast(
        "Sample record needed",
        "Enter a current record ID before publishing.",
        "warning"
      );
      return;
    }
    await this.runAction(async () => {
      if (!this.config.id || this.isDirty) {
        const saved = await saveDraft({
          configJson: JSON.stringify(this.toServerConfig())
        });
        this.config = this.decorateConfig(saved);
        this.selectedTemplateId = saved.id;
      }
      const result = await publishTemplate({
        templateId: this.config.id,
        sampleRecordId: this.sampleRecordId
      });
      this.previewText = result.prompt;
      this.config = {
        ...this.config,
        status: "Published",
        version: result.templateVersion,
        fingerprint: result.fingerprint
      };
      this.messages = result.messages;
      this.setAccessManifest(result.accessManifest);
      await this.loadVersions();
      await this.refreshTemplates();
      this.keepCurrentTemplateInCatalog();
      this.isDirty = false;
      this.toast(
        "Template published",
        "The successful preview is now available on matching record pages.",
        "success"
      );
    });
  }

  async loadVersions() {
    const templateId = this.config.id;
    if (!templateId) {
      this.versions = [];
      return;
    }
    const versions = await getTemplateVersions({ templateId });
    if (this.config.id !== templateId) {
      return;
    }
    this.versions = versions;
    if (this.versions.length > 0) {
      this.toVersion = String(this.versions[0].versionNumber);
      this.fromVersion = String(
        this.versions[Math.min(1, this.versions.length - 1)].versionNumber
      );
    }
  }

  handleVersionSelection(event) {
    this[event.target.name] = event.detail.value;
    this.comparisonChanges = [];
  }

  async handleCompareVersions() {
    if (!this.config.id || !this.fromVersion || !this.toVersion) {
      this.toast(
        "Versions needed",
        "Choose both versions before comparing.",
        "warning"
      );
      return;
    }
    await this.runAction(async () => {
      const comparison = await compareTemplateVersions({
        templateId: this.config.id,
        fromVersion: Number(this.fromVersion),
        toVersion: Number(this.toVersion)
      });
      this.comparisonChanges = comparison.changes.map((text, index) => ({
        key: `change-${index}`,
        text
      }));
    });
  }

  async handleRestoreVersion() {
    if (!this.config.id || !this.fromVersion) {
      return;
    }
    await this.runAction(async () => {
      const restored = await restoreTemplateVersion({
        templateId: this.config.id,
        versionNumber: Number(this.fromVersion)
      });
      this.config = this.decorateConfig(restored);
      this.previewText = "";
      this.messages = [];
      this.accessManifest = [];
      this.isDirty = false;
      await Promise.all(
        this.config.sources.map((source, index) => this.loadSourceFields(index))
      );
      this.toast(
        "Version restored as draft",
        "The published version is unchanged. Review this draft and publish it to create a new version.",
        "success"
      );
    });
  }

  async handleDeactivate() {
    if (!this.config.id) {
      return;
    }
    await this.runAction(async () => {
      const inactive = await deactivateTemplate({ templateId: this.config.id });
      this.config = this.decorateConfig(inactive);
      this.isDirty = false;
      await this.refreshTemplates();
      this.keepCurrentTemplateInCatalog();
      this.toast(
        "Template deactivated",
        "People can no longer choose it when building a prompt.",
        "success"
      );
    });
  }

  handlePreviewEdit(event) {
    this.previewText = event.target.value;
  }

  async copyPreview() {
    if (!this.previewText) {
      return;
    }
    try {
      await navigator.clipboard.writeText(this.previewText);
      this.toast(
        "Copied",
        "The generated prompt was copied to the clipboard.",
        "success"
      );
    } catch {
      this.toast(
        "Copy unavailable",
        "Select the preview text and copy it manually.",
        "warning"
      );
    }
  }

  async runAction(action) {
    this.isLoading = true;
    try {
      await action();
    } catch (error) {
      this.showError(error);
    } finally {
      this.isLoading = false;
    }
  }

  decorateConfig(config) {
    return {
      ...config,
      sources: (config.sources || []).map((source) =>
        this.decorateSourceView({
          ...source,
          sourceMode: source.sourceMode || "RELATED",
          resultMode: source.resultMode || "RECORDS",
          clientKey: `source-${++this.keySequence}`,
          fieldOptions: source.fieldOptions || [],
          mergeField: source.selectedFields?.[0] || "",
          filters: (source.filters || []).map((filter) => ({
            ...filter,
            groupName: filter.groupName || "group_1",
            clientKey: `filter-${++this.keySequence}`
          })),
          sorts: (source.sorts || []).map((sort) => ({
            ...sort,
            clientKey: `sort-${++this.keySequence}`
          }))
        })
      )
    };
  }

  decorateSourceView(source) {
    const sourceMode = source.sourceMode || "RELATED";
    const resultMode = source.resultMode || "RECORDS";
    const isAggregate = resultMode === "AGGREGATE";
    const selectedFields = source.selectedFields || [];
    const fieldOptions = source.fieldOptions || [];
    const selectedFieldOptions = fieldOptions.filter((option) =>
      selectedFields.includes(option.value)
    );
    const filterText = source.filters?.length
      ? `${source.filters.length} filter${source.filters.length === 1 ? "" : "s"}`
      : "no extra filters";
    const sortText = source.sorts?.length
      ? `${source.sorts.length} chosen sort${source.sorts.length === 1 ? "" : "s"}, followed by Id`
      : "Id ascending";
    const scopeText =
      sourceMode === "REFERENCE"
        ? "visible reference records"
        : `records where ${source.correlationField || "source match field"} equals current record ${source.rootField || "match field"}`;
    return {
      ...source,
      sourceMode,
      resultMode,
      isAggregate,
      isRecords: !isAggregate,
      needsAggregateField: isAggregate && source.aggregateOperation !== "COUNT",
      filterGroupJoin: source.filterGroupJoin || "AND",
      selectedFields,
      fieldOptions,
      selectedFieldOptions,
      showAdvanced: source.showAdvanced === true,
      advancedLabel: source.showAdvanced
        ? "Hide optional filters and sorting"
        : "Show optional filters and sorting",
      completionText:
        source.relatedObject &&
        (isAggregate
          ? Boolean(
              source.aggregateOperation &&
              (source.aggregateOperation === "COUNT" || source.aggregateField)
            )
          : selectedFields.length > 0) &&
        (sourceMode === "REFERENCE" || source.correlationField)
          ? "This data set is ready to validate."
          : "Choose the scope, object, match fields, and prompt fields.",
      isRelated: sourceMode !== "REFERENCE",
      modeHelp:
        sourceMode === "REFERENCE"
          ? "Independent of the current record. Sharing, field access, filters, sorting, and limits still apply."
          : "Salesforce matches a field on this object to a field on the current record. The objects do not need a lookup relationship.",
      querySummary: isAggregate
        ? `${source.relatedObject || "Choose an object"}: ${scopeText}; ${filterText}; one ${source.aggregateOperation || "calculated"} value.`
        : `${source.relatedObject || "Choose an object"}: ${scopeText}; ${filterText}; ${sortText}; limit ${source.maxRows || 10}.`
    };
  }

  toServerConfig() {
    return {
      ...this.config,
      sources: this.config.sources.map((source) => ({
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
          value: filter.value,
          groupName: filter.groupName
        })),
        filterGroupJoin: source.filterGroupJoin || "AND",
        sorts: source.sorts.map((sort) => ({
          fieldName: sort.fieldName,
          direction: sort.direction,
          nullsOrder: sort.nullsOrder
        })),
        maxRows: source.maxRows,
        sequence: source.sequence,
        active: source.active
      }))
    };
  }

  showError(error) {
    this.toast(
      "Unable to complete the action",
      getErrorMessage(error),
      "error"
    );
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  markDirty() {
    this.isDirty = true;
    this.previewText = "";
    this.accessManifest = [];
    this.healthCheckedAt = null;
  }

  resetGovernanceState() {
    this.accessManifest = [];
    this.healthCheckedAt = null;
    this.versions = [];
    this.fromVersion = "";
    this.toVersion = "";
    this.comparisonChanges = [];
  }

  setAccessManifest(manifest) {
    this.accessManifest = (manifest?.items || []).map((item, index) => ({
      ...item,
      key: `${item.objectApiName}-${item.sourceAlias || "root"}-${item.fieldPath}-${item.usage}-${index}`,
      sourceLabel: item.sourceAlias || "Current record",
      sensitivityLabel: item.sensitivity || "Standard"
    }));
  }
}
