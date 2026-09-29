import { createElement } from "lwc";
import PromptGenerator from "c/promptGenerator";
import getPublishedTemplates from "@salesforce/apex/PromptContextController.getPublishedTemplates";
import getEligibleFiles from "@salesforce/apex/PromptContextController.getEligibleFiles";
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
  "@salesforce/apex/PromptContextController.getEligibleFiles",
  () => ({ default: jest.fn() }),
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
      recordId: "001000000000001AAA",
      selectedContentVersionIds: []
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
          code: "NULL_MATCH_VALUE",
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

  it("lists eligible Files and passes the exact selected versions", async () => {
    getEligibleFiles.mockResolvedValue({
      items: [
        {
          contentVersionId: "068000000000001AAA",
          label: "Proposal.pdf",
          sizeInBytes: 1200
        }
      ],
      hasMore: false
    });
    generatePrompt.mockResolvedValue({
      prompt: "Account: Acme",
      messages: [],
      sourceRecordCounts: {}
    });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      {
        id: "a00000000000001AAA",
        name: "Account Summary",
        version: 1,
        fileInputMode: "USER_SELECT",
        maxFiles: 5,
        allowedFileFormats: "pdf"
      }
    ]);
    await flushPromises();

    element.shadowRoot.querySelector("lightning-checkbox-group").dispatchEvent(
      new CustomEvent("change", {
        detail: { value: ["068000000000001AAA"] }
      })
    );
    element.shadowRoot.querySelector(".generate-button").click();
    await flushPromises();

    expect(getEligibleFiles).toHaveBeenCalledWith({
      templateId: "a00000000000001AAA",
      recordId: "001000000000001AAA",
      afterTitle: null,
      afterId: null
    });
    expect(generatePrompt).toHaveBeenCalledWith({
      templateId: "a00000000000001AAA",
      recordId: "001000000000001AAA",
      selectedContentVersionIds: ["068000000000001AAA"]
    });
  });

  it("loads the next eligible Salesforce File page without clearing selections", async () => {
    getEligibleFiles
      .mockResolvedValueOnce({
        items: [
          {
            contentVersionId: "068000000000001AAA",
            label: "First.pdf",
            sizeInBytes: 1200
          }
        ],
        hasMore: true,
        nextTitle: "First",
        nextId: "068000000000001AAA"
      })
      .mockResolvedValueOnce({
        items: [
          {
            contentVersionId: "068000000000002AAA",
            label: "Second.pdf",
            sizeInBytes: 1300
          }
        ],
        hasMore: false
      });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      {
        id: "a00000000000001AAA",
        name: "Account Summary",
        version: 1,
        fileInputMode: "USER_SELECT",
        maxFiles: 5,
        allowedFileFormats: "pdf"
      }
    ]);
    await flushPromises();

    element.shadowRoot.querySelector("lightning-checkbox-group").dispatchEvent(
      new CustomEvent("change", {
        detail: { value: ["068000000000001AAA"] }
      })
    );
    element.shadowRoot.querySelector(".show-more-files").click();
    await flushPromises();

    expect(getEligibleFiles).toHaveBeenLastCalledWith({
      templateId: "a00000000000001AAA",
      recordId: "001000000000001AAA",
      afterTitle: "First",
      afterId: "068000000000001AAA"
    });
    expect(
      element.shadowRoot.querySelectorAll("lightning-checkbox-group")[0].options
    ).toHaveLength(2);
    expect(
      element.shadowRoot.querySelector("lightning-checkbox-group").value
    ).toEqual(["068000000000001AAA"]);
    expect(element.shadowRoot.querySelector(".show-more-files")).toBeNull();
  });

  it("ignores an eligible-file response after the template changes", async () => {
    const firstFiles = deferred();
    getEligibleFiles
      .mockReturnValueOnce(firstFiles.promise)
      .mockResolvedValueOnce({ items: [], hasMore: false });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      {
        id: "a00000000000001AAA",
        name: "First",
        version: 1,
        fileInputMode: "USER_SELECT",
        maxFiles: 5,
        allowedFileFormats: "pdf"
      },
      {
        id: "a00000000000002AAA",
        name: "Second",
        version: 1,
        fileInputMode: "USER_SELECT",
        maxFiles: 5,
        allowedFileFormats: "pdf"
      }
    ]);
    await flushPromises();

    const picker = element.shadowRoot.querySelector("lightning-combobox");
    picker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a00000000000001AAA" }
      })
    );
    picker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a00000000000002AAA" }
      })
    );
    firstFiles.resolve({
      items: [
        {
          contentVersionId: "068000000000001AAA",
          label: "Stale.pdf",
          sizeInBytes: 1200
        }
      ],
      hasMore: false
    });
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-checkbox-group").options
    ).toEqual([]);
  });

  it("disables required all-eligible generation when no file is eligible", async () => {
    getEligibleFiles.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      {
        id: "a00000000000001AAA",
        name: "Required files",
        version: 1,
        fileInputMode: "ALL_ELIGIBLE",
        maxFiles: 5,
        requireAtLeastOneFile: true,
        allowedFileFormats: "pdf"
      }
    ]);
    await flushPromises();

    expect(element.shadowRoot.querySelector(".generate-button").disabled).toBe(
      true
    );
  });

  it("formats megabyte-sized files in megabytes", async () => {
    getEligibleFiles.mockResolvedValue({
      items: [
        {
          contentVersionId: "068000000000001AAA",
          label: "Large.pdf",
          sizeInBytes: 2 * 1024 * 1024
        }
      ],
      hasMore: false
    });
    const element = createElement("c-prompt-generator", {
      is: PromptGenerator
    });
    element.recordId = "001000000000001AAA";
    element.objectApiName = "Account";
    document.body.appendChild(element);
    getPublishedTemplates.emit([
      {
        id: "a00000000000001AAA",
        name: "Files",
        version: 1,
        fileInputMode: "USER_SELECT",
        maxFiles: 5,
        allowedFileFormats: "pdf"
      }
    ]);
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-checkbox-group").options[0]
        .label
    ).toContain("2.0 MB");
  });
});
