import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

/**
 * Shows the preview record, the validate, preview, save, and publish actions, and their results.
 * The builder runs each action: this panel raises samplechange, validate, preview, save, publish,
 * and previewedit events.
 */
export default class PromptPublishPanel extends LightningElement {
  @api config;
  @api sampleRecordId = "";
  @api messages = [];
  @api accessManifest = [];
  @api previewText = "";
  @api disabled = false;

  get cannotPublish() {
    return (
      this.disabled ||
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

  get hasMessages() {
    return this.messages.length > 0;
  }

  get viewMessages() {
    return this.messages.map((message, index) => ({
      ...message,
      key: `${message.severity}-${message.code}-${message.location}-${index}`
    }));
  }

  get hasAccessManifest() {
    return this.accessManifest.length > 0;
  }

  get manifestRows() {
    return this.accessManifest.map((item, index) => ({
      ...item,
      key: `${item.objectApiName}-${item.sourceAlias || "root"}-${item.fieldPath}-${item.usage}-${index}`,
      sourceLabel: item.sourceAlias || "Current record",
      sensitivityLabel: item.sensitivity || "Standard"
    }));
  }

  get hasPreview() {
    return Boolean(this.previewText);
  }

  handleSampleRecord(event) {
    this.dispatchEvent(
      new CustomEvent("samplechange", {
        detail: { recordId: event.detail.recordId || "" }
      })
    );
  }

  handleAction(event) {
    this.dispatchEvent(new CustomEvent(event.target.dataset.action));
  }

  handlePreviewEdit(event) {
    this.dispatchEvent(
      new CustomEvent("previewedit", { detail: { value: event.target.value } })
    );
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

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
