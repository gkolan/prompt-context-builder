import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTemplateSummaryPage from "@salesforce/apex/PromptContextController.getTemplateSummaryPage";

const TEMPLATE_PAGE_SIZE = 50;

/**
 * Finds templates, shows the open template's status, and offers its lifecycle actions. The builder
 * decides whether a templateselect may proceed and runs duplicate, discard, and deactivate.
 */
export default class PromptTemplateHeader extends LightningElement {
  @api value = "";
  @api config;
  @api isDirty = false;
  @api disabled = false;
  templates = [];
  templateSearch = "";
  templateAfterName = null;
  templateAfterId = null;
  hasMoreTemplates = false;
  isCatalogLoading = false;
  catalogRequestId = 0;

  connectedCallback() {
    this.loadTemplates();
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

  get statusText() {
    // Saved edits to a live template stay invisible to users until they are published.
    const unpublishedText =
      !this.isDirty && this.config.hasUnpublishedChanges
        ? " · Saved changes not published"
        : "";
    const dirtyText = this.isDirty ? " · Unsaved changes" : "";
    const healthText = this.config.lastHealthStatus
      ? ` · Health ${this.config.lastHealthStatus}`
      : "";
    return `${this.config.status || "Draft"} · Version ${this.config.version || 0}${healthText}${unpublishedText}${dirtyText}`;
  }

  get hasStoredHealth() {
    return Boolean(this.config.lastHealthStatus);
  }

  get storedHealthText() {
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

  get cannotDeactivate() {
    return (
      this.disabled || !this.config.id || this.config.status === "Inactive"
    );
  }

  /**
   * Reloads the first catalog page and keeps the open template listed even when it is not on it.
   * @param {object} openTemplate Configuration of the open template
   * @returns {Promise<void>} Resolves when the catalog is current
   */
  @api
  async refresh(openTemplate) {
    await this.loadTemplates();
    if (!openTemplate?.id) {
      return;
    }
    const currentSummary = {
      id: openTemplate.id,
      developerKey: openTemplate.developerKey,
      name: openTemplate.name,
      description: openTemplate.description,
      rootObject: openTemplate.rootObject,
      status: openTemplate.status,
      version: openTemplate.version,
      publishedAt: openTemplate.publishedAt
    };
    this.templates = [
      currentSummary,
      ...this.templates.filter((template) => template.id !== openTemplate.id)
    ];
  }

  async loadTemplates(reset = true) {
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
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Unable to complete the action",
            message:
              error?.body?.message ||
              error?.message ||
              "An unexpected error occurred.",
            variant: "error"
          })
        );
      }
    } finally {
      if (requestId === this.catalogRequestId) {
        this.isCatalogLoading = false;
      }
    }
  }

  handleSearch(event) {
    this.templateSearch = event.target.value || "";
    this.loadTemplates(true);
  }

  loadMoreTemplates() {
    this.loadTemplates(false);
  }

  handleSelection(event) {
    const selection = new CustomEvent("templateselect", {
      cancelable: true,
      detail: { value: event.detail.value }
    });
    this.dispatchEvent(selection);
    if (selection.defaultPrevented) {
      // The open template did not change, so rendering would not reset the picker.
      event.target.value = this.value;
    }
  }

  duplicate() {
    this.dispatchEvent(new CustomEvent("duplicate"));
  }

  discard() {
    this.dispatchEvent(new CustomEvent("discard"));
  }

  deactivate() {
    this.dispatchEvent(new CustomEvent("deactivate"));
  }
}
