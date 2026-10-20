import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getObjectOptions from "@salesforce/apex/PromptContextController.getObjectOptions";
import getFieldOptions from "@salesforce/apex/PromptContextController.getFieldOptions";
import getTemplate from "@salesforce/apex/PromptContextController.getTemplate";
import saveDraft from "@salesforce/apex/PromptContextController.saveDraft";
import preview from "@salesforce/apex/PromptContextController.preview";
import publishTemplate from "@salesforce/apex/PromptContextController.publish";
import deactivateTemplate from "@salesforce/apex/PromptContextController.deactivateTemplate";
import checkTemplateHealth from "@salesforce/apex/PromptContextController.checkTemplateHealth";
import getTemplateVersions from "@salesforce/apex/PromptContextController.getTemplateVersions";
import restoreTemplateVersion from "@salesforce/apex/PromptContextController.restoreTemplateVersion";
import {
  createSource,
  describeSourceBudget,
  prepareSource,
  toServerSource
} from "c/promptDataSetEditor";
import { describeRestore } from "c/promptVersionHistory";

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

/**
 * Prompt Builder. Owns the template configuration, its draft revision, and every save, preview,
 * validation, publish, and lifecycle call. The section components raise events; this component
 * applies them to the configuration.
 */
export default class PromptTemplateBuilder extends LightningElement {
  config = newConfig();
  objectOptions = [];
  rootFieldOptions = [];
  templateRequestId = 0;
  selectedTemplateId = "";
  rootMergeField = "";
  sampleRecordId = "";
  previewText = "";
  messages = [];
  accessManifest = [];
  versions = [];
  isLoading = false;
  isDirty = false;

  @wire(getObjectOptions)
  wiredObjects({ data, error }) {
    if (data) {
      this.objectOptions = data;
      this.loadRootFields();
    } else if (error) {
      this.showError(error);
    }
  }

  get hasSources() {
    return this.config.sources.length > 0;
  }

  get hasVersions() {
    return (this.versions || []).length > 0;
  }

  get sourceBudgetText() {
    return describeSourceBudget(this.config.sources);
  }

  async loadRootFields() {
    const rootObject = this.config.rootObject;
    if (!rootObject) {
      this.rootFieldOptions = [];
      return;
    }
    try {
      const fieldOptions = await getFieldOptions({ objectApiName: rootObject });
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

  loadAllSourceFields() {
    return Promise.all(
      this.config.sources.map((source, index) => this.loadSourceFields(index))
    );
  }

  async handleTemplateSelection(event) {
    const requestId = ++this.templateRequestId;
    const requestedTemplateId = event.detail.value;
    if (this.isDirty && requestedTemplateId !== this.selectedTemplateId) {
      event.preventDefault();
      this.toast(
        "Unsaved changes",
        "Save the draft or use Discard changes before opening another template.",
        "warning"
      );
      return;
    }
    this.selectedTemplateId = requestedTemplateId;
    if (!requestedTemplateId) {
      this.openConfig(null);
      return;
    }
    this.isLoading = true;
    try {
      const selected = await getTemplate({ templateId: requestedTemplateId });
      if (requestId !== this.templateRequestId) {
        return;
      }
      await this.openConfig(selected);
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

  async openConfig(config) {
    this.config = config ? this.decorateConfig(config) : newConfig();
    this.resetEditor();
    await this.loadRootFields();
    await this.loadAllSourceFields();
    await this.loadVersions();
  }

  handleTemplateField(event) {
    const field = event.target.name;
    this.config = {
      ...this.config,
      [field]: event.detail?.value ?? event.target.value
    };
    this.markDirty();
    if (field === "rootObject") {
      this.config = { ...this.config, sources: [] };
      this.rootMergeField = "";
      this.sampleRecordId = "";
      this.loadRootFields();
    }
  }

  handleConfigChange(event) {
    this.config = { ...this.config, ...event.detail.changes };
    this.markDirty();
  }

  handleRootMergeField(event) {
    this.rootMergeField = event.detail.value;
  }

  async applyRecipe(event) {
    const { templateBody, sources } = event.detail;
    this.config = this.decorateConfig({
      ...this.config,
      templateBody,
      sources
    });
    this.clearResults();
    this.isDirty = true;
    await this.loadAllSourceFields();
    this.toast(
      "Starter applied",
      "Review the fields and record rules, then validate with a real record.",
      "success"
    );
  }

  handleTextInsert(event) {
    const separator = this.config.templateBody ? "\n" : "";
    this.config = {
      ...this.config,
      templateBody: `${this.config.templateBody || ""}${separator}${event.detail.text}`
    };
    this.markDirty();
  }

  addSource() {
    this.config = {
      ...this.config,
      sources: [...this.config.sources, createSource(this.config.sources)]
    };
    this.markDirty();
  }

  handleSourceChange(event) {
    const index = Number(event.target.dataset.index);
    const { changes } = event.detail;
    this.updateSource(index, changes);
    if ("relatedObject" in changes) {
      this.loadSourceFields(index).catch((error) => this.showError(error));
    }
    this.markDirty();
  }

  handleSourceViewChange(event) {
    this.updateSource(Number(event.target.dataset.index), event.detail.changes);
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

  updateSource(index, changes) {
    this.config = {
      ...this.config,
      sources: this.config.sources.map((source, sourceIndex) => {
        return sourceIndex === index ? { ...source, ...changes } : source;
      })
    };
  }

  handleSampleRecord(event) {
    this.sampleRecordId = event.detail.recordId;
  }

  async discardChanges() {
    await this.runAction(async () => {
      const selected = this.selectedTemplateId
        ? await getTemplate({ templateId: this.selectedTemplateId })
        : null;
      await this.openConfig(selected);
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
    this.clearResults();
    this.versions = [];
    this.isDirty = true;
  }

  async handleValidate() {
    await this.runAction(async () => {
      const result = await checkTemplateHealth({
        configJson: JSON.stringify(this.toServerConfig())
      });
      this.messages = result.messages;
      this.accessManifest = result.accessManifest?.items || [];
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
        "Preview record needed",
        "Choose a preview record first.",
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
      await this.saveConfig();
      await this.refreshCatalog();
      this.isDirty = false;
      this.toast(
        "Draft saved",
        "The template and related sources were saved.",
        "success"
      );
    });
  }

  async saveConfig() {
    const saved = await saveDraft({
      configJson: JSON.stringify(this.toServerConfig())
    });
    this.config = this.decorateConfig(saved);
    this.selectedTemplateId = saved.id;
  }

  async handlePublish() {
    if (!this.sampleRecordId) {
      this.toast(
        "Preview record needed",
        "Choose a preview record before publishing.",
        "warning"
      );
      return;
    }
    await this.runAction(async () => {
      if (!this.config.id || this.isDirty) {
        await this.saveConfig();
      }
      // The server refuses the publication when a newer draft was saved after this one.
      const result = await publishTemplate({
        templateId: this.config.id,
        sampleRecordId: this.sampleRecordId,
        draftRevision: this.config.draftRevision
      });
      this.previewText = result.prompt;
      this.config = {
        ...this.config,
        status: "Published",
        version: result.templateVersion,
        fingerprint: result.fingerprint,
        hasUnpublishedChanges: false
      };
      this.messages = result.messages;
      this.accessManifest = result.accessManifest?.items || [];
      await this.loadVersions();
      await this.refreshCatalog();
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
    if (this.config.id === templateId) {
      this.versions = versions;
    }
  }

  handleBusyChange(event) {
    this.isLoading = event.detail.busy;
  }

  async handleRestoreVersion(event) {
    const { versionNumber } = event.detail;
    await this.runAction(async () => {
      const restored = await restoreTemplateVersion({
        templateId: this.config.id,
        versionNumber,
        draftRevision: this.config.draftRevision
      });
      this.config = this.decorateConfig(restored);
      this.clearResults();
      this.isDirty = false;
      await this.loadAllSourceFields();
      const { title, message, variant } = describeRestore(
        this.versions.find(
          (version) => version.versionNumber === versionNumber
        ),
        this.config.syntaxVersion
      );
      this.toast(title, message, variant);
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
      await this.refreshCatalog();
      this.toast(
        "Template deactivated",
        "People can no longer choose it when building a prompt.",
        "success"
      );
    });
  }

  handlePreviewEdit(event) {
    this.previewText = event.detail.value;
  }

  refreshCatalog() {
    return this.template
      .querySelector("c-prompt-template-header")
      .refresh(this.config);
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
    return { ...config, sources: (config.sources || []).map(prepareSource) };
  }

  toServerConfig() {
    return {
      ...this.config,
      sources: this.config.sources.map(toServerSource)
    };
  }

  showError(error) {
    this.toast(
      "Unable to complete the action",
      error?.body?.message || error?.message || "An unexpected error occurred.",
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
  }

  resetEditor() {
    this.clearResults();
    this.sampleRecordId = "";
    this.isDirty = false;
    this.versions = [];
  }

  clearResults() {
    this.previewText = "";
    this.messages = [];
    this.accessManifest = [];
  }
}
