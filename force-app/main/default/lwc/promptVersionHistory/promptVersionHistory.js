import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import compareTemplateVersions from "@salesforce/apex/PromptContextController.compareTemplateVersions";

/**
 * Describes the toast shown after a published version is restored as the draft.
 * @param {object} restoredFrom Version that was restored
 * @param {number} syntaxVersion Syntax version the restored draft will publish with
 * @returns {object} Toast title, message, and variant
 */
export function describeRestore(restoredFrom, syntaxVersion) {
  // Republishing uses the current merge language, which can print the same data differently.
  if (
    restoredFrom?.syntaxVersion &&
    restoredFrom.syntaxVersion < syntaxVersion
  ) {
    return {
      title: "Version restored as draft",
      message: `Version ${restoredFrom.versionNumber} was published with syntax version ${restoredFrom.syntaxVersion}. Publishing this draft uses syntax version ${syntaxVersion}, which prints picklist labels, plain text, and dates differently. Preview it before publishing.`,
      variant: "warning"
    };
  }
  return {
    title: "Version restored as draft",
    message:
      "The published version is unchanged. Review this draft and publish it to create a new version.",
    variant: "success"
  };
}

/**
 * Compares published versions and asks the builder to restore one. Raises busychange while a
 * comparison runs and versionrestore with the chosen version number.
 */
export default class PromptVersionHistory extends LightningElement {
  @api templateId;
  @api disabled = false;
  fromVersion = "";
  toVersion = "";
  comparisonChanges = [];
  publishedVersions = [];

  @api
  get versions() {
    return this.publishedVersions;
  }

  set versions(value) {
    this.publishedVersions = value || [];
    if (this.publishedVersions.length > 0) {
      this.toVersion = String(this.publishedVersions[0].versionNumber);
      this.fromVersion = String(
        this.publishedVersions[Math.min(1, this.publishedVersions.length - 1)]
          .versionNumber
      );
    }
  }

  get versionOptions() {
    return this.publishedVersions.map((version) => ({
      label: `Version ${version.versionNumber}, ${new Intl.DateTimeFormat().format(new Date(version.publishedAt))}`,
      value: String(version.versionNumber)
    }));
  }

  get hasComparison() {
    return this.comparisonChanges.length > 0;
  }

  handleSelection(event) {
    this[event.target.name] = event.detail.value;
    this.comparisonChanges = [];
  }

  async handleCompare() {
    if (!this.templateId || !this.fromVersion || !this.toVersion) {
      this.toast(
        "Versions needed",
        "Choose both versions before comparing.",
        "warning"
      );
      return;
    }
    this.dispatchEvent(
      new CustomEvent("busychange", { detail: { busy: true } })
    );
    try {
      const comparison = await compareTemplateVersions({
        templateId: this.templateId,
        fromVersion: Number(this.fromVersion),
        toVersion: Number(this.toVersion)
      });
      this.comparisonChanges = comparison.changes.map((text, index) => ({
        key: `change-${index}`,
        text
      }));
    } catch (error) {
      this.toast(
        "Unable to complete the action",
        error?.body?.message ||
          error?.message ||
          "An unexpected error occurred.",
        "error"
      );
    } finally {
      this.dispatchEvent(
        new CustomEvent("busychange", { detail: { busy: false } })
      );
    }
  }

  handleRestore() {
    if (!this.templateId || !this.fromVersion) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("versionrestore", {
        detail: { versionNumber: Number(this.fromVersion) }
      })
    );
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
