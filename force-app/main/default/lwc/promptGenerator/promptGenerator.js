import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getPublishedTemplates from "@salesforce/apex/PromptContextController.getPublishedTemplates";
import generatePrompt from "@salesforce/apex/PromptContextController.generatePrompt";
import generatorTitle from "@salesforce/label/c.PCB_Generator_Title";
import generatingPrompt from "@salesforce/label/c.PCB_Generating_Prompt";
import publishedTemplate from "@salesforce/label/c.PCB_Published_Template";
import prefixLabel from "@salesforce/label/c.PCB_Prefix_Label";
import generateContext from "@salesforce/label/c.PCB_Generate_Context";
import generatedContextLabel from "@salesforce/label/c.PCB_Generated_Context";
import suffixLabel from "@salesforce/label/c.PCB_Suffix_Label";
import sourceSummary from "@salesforce/label/c.PCB_Source_Summary";
import copyCompletePrompt from "@salesforce/label/c.PCB_Copy_Complete_Prompt";
import startOver from "@salesforce/label/c.PCB_Start_Over";
import noPublishedTemplates from "@salesforce/label/c.PCB_No_Published_Templates";
import recordContextCount from "@salesforce/label/c.PCB_Record_Context_Count";
import recordUnavailableTitle from "@salesforce/label/c.PCB_Record_Unavailable_Title";
import recordUnavailableMessage from "@salesforce/label/c.PCB_Record_Unavailable_Message";
import chooseTemplateTitle from "@salesforce/label/c.PCB_Choose_Template_Title";
import chooseTemplateMessage from "@salesforce/label/c.PCB_Choose_Template_Message";
import copiedTitle from "@salesforce/label/c.PCB_Copied_Title";
import copiedMessage from "@salesforce/label/c.PCB_Copied_Message";
import copyUnavailableTitle from "@salesforce/label/c.PCB_Copy_Unavailable_Title";
import copyUnavailableMessage from "@salesforce/label/c.PCB_Copy_Unavailable_Message";
import unableToGenerate from "@salesforce/label/c.PCB_Unable_To_Generate";
import generationFailed from "@salesforce/label/c.PCB_Generation_Failed";

function formatLabel(value, replacements) {
  return replacements.reduce(
    (formatted, replacement, index) =>
      formatted.replace(`{${index}}`, String(replacement)),
    value
  );
}

function getErrorMessage(error) {
  return error?.body?.message || error?.message || generationFailed;
}

export default class PromptGenerator extends LightningElement {
  @api recordId;
  @api objectApiName;

  templateChoices = [];
  selectedTemplateId = "";
  prefix = "";
  generatedContext = "";
  hasGeneratedResult = false;
  suffix = "";
  messages = [];
  sourceRecordCounts = {};
  isLoading = false;
  generationRequestId = 0;
  label = {
    generatorTitle,
    generatingPrompt,
    publishedTemplate,
    prefixLabel,
    generateContext,
    generatedContextLabel,
    suffixLabel,
    sourceSummary,
    copyCompletePrompt,
    startOver,
    noPublishedTemplates
  };

  @wire(getPublishedTemplates, { rootObject: "$objectApiName" })
  wiredTemplates({ data, error }) {
    if (data || error) {
      this.invalidateGeneration();
    }
    if (data) {
      this.templateChoices = data.map((template) => ({
        label: `${template.name} · v${template.version}`,
        value: template.id,
        description: template.description
      }));
      const selectedTemplateIsAvailable = this.templateChoices.some(
        (template) => template.value === this.selectedTemplateId
      );
      const nextTemplateId =
        this.templateChoices.length === 1
          ? this.templateChoices[0].value
          : selectedTemplateIsAvailable
            ? this.selectedTemplateId
            : "";
      if (nextTemplateId !== this.selectedTemplateId) {
        this.resetGeneratedOutput();
      }
      this.selectedTemplateId = nextTemplateId;
    } else if (error) {
      this.templateChoices = [];
      this.selectedTemplateId = "";
      this.resetGeneratedOutput();
      this.showError(error);
    }
  }

  get hasTemplates() {
    return this.templateChoices.length > 0;
  }

  get hasPrompt() {
    return this.hasGeneratedResult;
  }

  get hasMessages() {
    return this.messages.length > 0;
  }

  get selectedTemplateDescription() {
    return (
      this.templateChoices.find(
        (template) => template.value === this.selectedTemplateId
      )?.description || ""
    );
  }

  get contextCharacterCount() {
    return this.generatedContext.length;
  }

  get finalCharacterCount() {
    return this.finalPrompt.length;
  }

  get characterCountText() {
    return formatLabel(recordContextCount, [
      this.contextCharacterCount,
      this.finalCharacterCount
    ]);
  }

  get sourceCounts() {
    return Object.entries(this.sourceRecordCounts).map(([alias, count]) => ({
      alias,
      count
    }));
  }

  get hasSourceCounts() {
    return this.sourceCounts.length > 0;
  }

  get generateDisabled() {
    return this.isLoading || !this.selectedTemplateId || !this.recordId;
  }

  get finalPrompt() {
    return [this.prefix, this.generatedContext, this.suffix]
      .filter((section) => section?.trim())
      .join("\n\n");
  }

  handleTemplate(event) {
    this.invalidateGeneration();
    this.selectedTemplateId = event.detail.value;
    this.resetGeneratedOutput();
  }

  handlePrefix(event) {
    this.prefix = event.target.value;
  }

  handleContext(event) {
    this.generatedContext = event.target.value;
  }

  handleSuffix(event) {
    this.suffix = event.target.value;
  }

  async handleGenerate() {
    if (!this.recordId) {
      this.toast(recordUnavailableTitle, recordUnavailableMessage, "error");
      return;
    }
    if (!this.selectedTemplateId) {
      this.toast(chooseTemplateTitle, chooseTemplateMessage, "warning");
      return;
    }
    const requestId = ++this.generationRequestId;
    const requestedTemplateId = this.selectedTemplateId;
    const requestedRecordId = this.recordId;
    this.resetGeneratedOutput();
    this.isLoading = true;
    try {
      const result = await generatePrompt({
        templateId: requestedTemplateId,
        recordId: requestedRecordId
      });
      if (
        requestId !== this.generationRequestId ||
        requestedTemplateId !== this.selectedTemplateId ||
        requestedRecordId !== this.recordId
      ) {
        return;
      }
      this.generatedContext = result.prompt;
      this.hasGeneratedResult = true;
      this.messages = result.messages;
      this.sourceRecordCounts = result.sourceRecordCounts || {};
    } catch (error) {
      if (requestId === this.generationRequestId) {
        this.showError(error);
      }
    } finally {
      if (requestId === this.generationRequestId) {
        this.isLoading = false;
      }
    }
  }

  handleStartOver() {
    this.invalidateGeneration();
    this.prefix = "";
    this.resetGeneratedOutput();
    this.suffix = "";
  }

  resetGeneratedOutput() {
    this.generatedContext = "";
    this.hasGeneratedResult = false;
    this.messages = [];
    this.sourceRecordCounts = {};
  }

  invalidateGeneration() {
    this.generationRequestId += 1;
    this.isLoading = false;
  }

  async handleCopy() {
    try {
      await navigator.clipboard.writeText(this.finalPrompt);
      this.toast(copiedTitle, copiedMessage, "success");
    } catch {
      this.toast(copyUnavailableTitle, copyUnavailableMessage, "warning");
    }
  }

  showError(error) {
    this.toast(unableToGenerate, getErrorMessage(error), "error");
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
