import { LightningElement, api } from "lwc";

const FILE_INPUT_MODES = [
  { label: "Do not include Salesforce Files", value: "DISABLED" },
  { label: "Let the user choose Files", value: "USER_SELECT" },
  { label: "Include all eligible Files", value: "ALL_ELIGIBLE" }
];

/**
 * Edits the Salesforce Files settings of a template. Each edit is raised as a configchange event
 * that the builder applies to the template.
 */
export default class PromptFileSettings extends LightningElement {
  @api config;
  fileInputModeOptions = FILE_INPUT_MODES;

  get filesEnabled() {
    return this.config.fileInputMode !== "DISABLED";
  }

  handleField(event) {
    const field = event.target.name;
    const value =
      event.target.type === "checkbox"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    const changes = { [field]: value };
    if (field === "fileInputMode" && value === "DISABLED") {
      Object.assign(changes, {
        maxFiles: null,
        requireAtLeastOneFile: false,
        allowedFileFormats: "",
        providerProfileKey: "",
        fileCitationsEnabled: false
      });
    }
    this.dispatchEvent(
      new CustomEvent("configchange", { detail: { changes } })
    );
  }
}
