import { createElement } from "lwc";
import PromptGenerator from "c/promptGenerator";
import getPublishedTemplates from "@salesforce/apex/PromptContextController.getPublishedTemplates";
import generatePrompt from "@salesforce/apex/PromptContextController.generatePrompt";

jest.mock(
  "@salesforce/apex/PromptContextController.getPublishedTemplates",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.generatePrompt",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

const deferred = () => {
  let resolve;
  const promise = new Promise((resolvePromise) => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
};

describe("c-prompt-generator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows an empty state when no published template matches", async () => {
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([]);
    await flushPromises();

    expect(element.shadowRoot.querySelector(".empty-state")).not.toBeNull();
  });

  it("generates editable record context from the selected template", async () => {
    generatePrompt.mockResolvedValue({
      prompt: "Account: Acme",
      messages: [],
      sourceRecordCounts: { contacts: 2 }
    });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Account Summary", version: 1 }
    ]);
    await flushPromises();

    const generateButton = element.shadowRoot.querySelector(".generate-button");
    generateButton.click();
    await flushPromises();

    expect(generatePrompt).toHaveBeenCalledWith({
      templateId: "a00000000000001AAA",
      recordId: "001000000000001AAA"
    });
    expect(element.shadowRoot.querySelector(".prompt-area").value).toBe(
      "Account: Acme"
    );
    expect(
      element.shadowRoot.querySelector(".source-summary").textContent
    ).toContain("contacts: 2");
  });

  it("shows a successful generated result when the rendered context is empty", async () => {
    generatePrompt.mockResolvedValue({
      prompt: "",
      messages: [
        {
          code: "NULL_CORRELATION_VALUE",
          text: "No related rows were queried."
        }
      ],
      sourceRecordCounts: { contacts: 0 }
    });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Blank Summary", version: 1 }
    ]);
    await flushPromises();

    element.shadowRoot.querySelector(".generate-button").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".prompt-area")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".prompt-area").value).toBe("");
    expect(
      element.shadowRoot.querySelector(".message-panel").textContent
    ).toContain("No related rows were queried.");
  });

  it("clears an auto-selected template when the available choices change", async () => {
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Account Summary", version: 1 }
    ]);
    await flushPromises();

    getPublishedTemplates.emit([
      { id: "a00000000000002AAA", name: "Contact Summary", version: 1 },
      { id: "a00000000000003AAA", name: "Contact Detail", version: 2 }
    ]);
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-combobox").value).toBe(
      ""
    );
    expect(element.shadowRoot.querySelector(".generate-button").disabled).toBe(
      true
    );
  });

  it("does not keep stale template choices after a wire error", async () => {
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Account Summary", version: 1 }
    ]);
    await flushPromises();

    getPublishedTemplates.error({ body: { message: "Access denied" } });
    await flushPromises();

    expect(element.shadowRoot.querySelector(".empty-state")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".generate-button")).toBeNull();
  });

  it("ignores a generation response after the template changes", async () => {
    const pendingGeneration = deferred();
    generatePrompt.mockReturnValue(pendingGeneration.promise);
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Summary", version: 1 },
      { id: "a00000000000002AAA", name: "Detail", version: 1 }
    ]);
    await flushPromises();

    const templatePicker =
      element.shadowRoot.querySelector("lightning-combobox");
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a00000000000001AAA" }
      })
    );
    element.shadowRoot.querySelector(".generate-button").click();
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a00000000000002AAA" }
      })
    );
    pendingGeneration.resolve({
      prompt: "Stale summary",
      messages: [],
      sourceRecordCounts: {}
    });
    await flushPromises();

    expect(element.shadowRoot.querySelector(".prompt-area")).toBeNull();
  });

  it("disables editable controls while generation is pending", async () => {
    const pendingGeneration = deferred();
    generatePrompt.mockReturnValue(pendingGeneration.promise);
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Account Summary", version: 1 }
    ]);
    await flushPromises();

    element.shadowRoot.querySelector(".generate-button").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-combobox").disabled
    ).toBe(true);
    expect(
      element.shadowRoot.querySelector("lightning-textarea").disabled
    ).toBe(true);

    pendingGeneration.resolve({
      prompt: "Account: Acme",
      messages: [],
      sourceRecordCounts: {}
    });
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-combobox").disabled
    ).toBe(false);
  });

  it("clears generated context and source details when starting over", async () => {
    generatePrompt.mockResolvedValue({
      prompt: "Account: Acme",
      messages: [],
      sourceRecordCounts: { contacts: 2 }
    });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      { id: "a00000000000001AAA", name: "Account Summary", version: 1 }
    ]);
    await flushPromises();

    element.shadowRoot.querySelector(".generate-button").click();
    await flushPromises();
    element.shadowRoot.querySelector(".start-over-button").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".prompt-area")).toBeNull();
    expect(element.shadowRoot.querySelector(".source-summary")).toBeNull();
  });
});
