import { createElement } from "lwc";
import { byLabel, deepText, query, queryAll } from "./shadowQueries";
import PromptTemplateBuilder from "c/promptTemplateBuilder";
import getObjectOptions from "@salesforce/apex/PromptContextController.getObjectOptions";
import getFieldOptions from "@salesforce/apex/PromptContextController.getFieldOptions";
import getTemplate from "@salesforce/apex/PromptContextController.getTemplate";
import getTemplateSummaryPage from "@salesforce/apex/PromptContextController.getTemplateSummaryPage";
import checkTemplateHealth from "@salesforce/apex/PromptContextController.checkTemplateHealth";
import getTemplateVersions from "@salesforce/apex/PromptContextController.getTemplateVersions";
import compareTemplateVersions from "@salesforce/apex/PromptContextController.compareTemplateVersions";
import saveDraft from "@salesforce/apex/PromptContextController.saveDraft";
import publishTemplate from "@salesforce/apex/PromptContextController.publish";
import restoreTemplateVersion from "@salesforce/apex/PromptContextController.restoreTemplateVersion";
import preview from "@salesforce/apex/PromptContextController.preview";
import deactivateTemplate from "@salesforce/apex/PromptContextController.deactivateTemplate";

jest.mock(
  "@salesforce/apex/PromptContextController.getObjectOptions",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.getFieldOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.getTemplate",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.getTemplateSummaryPage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.checkTemplateHealth",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.getTemplateVersions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.compareTemplateVersions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.saveDraft",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.publish",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.restoreTemplateVersion",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.preview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PromptContextController.deactivateTemplate",
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

describe("c-prompt-template-builder", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    getTemplateVersions.mockResolvedValue([]);
  });

  it("renders the five-step setup path", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    getObjectOptions.emit([{ label: "Account (Account)", value: "Account" }]);
    await flushPromises();

    const headings = [...queryAll(element, "h2")].map(
      (node) => node.textContent
    );
    expect(headings).toEqual([
      "1. Template basics",
      "2. Prompt and merge fields",
      "3. Related data",
      "4. Salesforce Files",
      "5. Validate, preview, and publish"
    ]);
    expect(
      [...queryAll(element, "lightning-button")].map((button) => button.label)
    ).toContain("Insert current record field");
  });

  it("keeps calculated values out of the returned-record budget", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: "a01000000000001", name: "Budget", status: "Draft" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      name: "Budget",
      rootObject: "Account",
      templateBody: "Budget",
      status: "Draft",
      sources: [
        {
          referenceName: "contacts",
          resultMode: "RECORDS",
          maxRows: 25,
          active: true
        },
        {
          referenceName: "contact_count",
          resultMode: "AGGREGATE",
          maxRows: 50,
          active: true
        }
      ]
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const picker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    picker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    expect(query(element, ".source-budget").textContent).toContain(
      "up to 25 returned records · 1 calculated value"
    );
  });

  it("adds a guided related data set", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const buttons = [...queryAll(element, "lightning-button")];
    buttons.find((button) => button.label === "Add related data").click();
    await flushPromises();

    expect(queryAll(element, ".source-card")).toHaveLength(1);
    expect(deepText(element)).toContain("Data set");
  });

  it("shows safe record choices for a new data set", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const addButton = [...queryAll(element, "lightning-button")].find(
      (button) => button.label === "Add related data"
    );
    addButton.click();
    await flushPromises();

    const scope = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Records to include"
    );
    expect(scope.options).toEqual([
      { label: "Match a current record field", value: "RELATED" },
      { label: "Reference records", value: "REFERENCE" }
    ]);
    expect(deepText(element)).toContain("Choose what the prompt can use");
  });

  it("hides record-matching controls for a limited reference list", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Add related data")
      .click();
    await flushPromises();

    const scope = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Records to include"
    );
    scope.dispatchEvent(
      new CustomEvent("change", { detail: { value: "REFERENCE" } })
    );
    await flushPromises();

    const labels = [...queryAll(element, "lightning-combobox")].map(
      (combobox) => combobox.label
    );
    expect(labels).not.toContain("Current record field");
    expect(labels).not.toContain("Related record match field");
    expect(deepText(element)).toContain("Independent of the current record");
  });

  it("clears the stable automation key when a template is duplicated", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [
        {
          id: "a01000000000001",
          name: "Account Context",
          status: "Published"
        }
      ],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      developerKey: "account_context",
      name: "Account Context",
      rootObject: "Account",
      status: "Published",
      version: 2,
      lastHealthStatus: "Healthy",
      lastHealthVersion: 2,
      lastHealthCodes: "OK",
      lastHealthCheckedAt: "2026-09-19T12:00:00.000Z",
      sources: []
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const templatePicker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Duplicate as new")
      .click();
    await flushPromises();

    const automationKey = [...queryAll(element, "lightning-input")].find(
      (input) => input.label === "Automation key"
    );
    expect(automationKey.value).toBeNull();
  });

  it("restores the complete saved template when changes are discarded", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [
        {
          id: "a01000000000001",
          name: "Account Context",
          status: "Draft"
        }
      ],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      developerKey: "account_context",
      name: "Account Context",
      rootObject: "Account",
      templateBody: "Account: {!record.Name}",
      status: "Draft",
      version: 1,
      sources: [
        {
          referenceName: "contacts",
          sourceMode: "RELATED",
          resultMode: "RECORDS",
          relatedObject: "Contact",
          correlationField: "AccountId",
          rootField: "Id",
          selectedFields: ["Name"],
          filters: [],
          sorts: [],
          maxRows: 10,
          sequence: 1,
          active: true
        }
      ]
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const templatePicker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    const body = [...queryAll(element, "lightning-textarea")].find(
      (textarea) => textarea.label === "Template body"
    );
    body.value = "Unsaved body";
    body.dispatchEvent(new CustomEvent("change"));
    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Discard changes")
      .click();
    await flushPromises();
    await flushPromises();

    expect(
      [...queryAll(element, "lightning-textarea")].find(
        (textarea) => textarea.label === "Template body"
      ).value
    ).toBe("Account: {!record.Name}");
    expect(queryAll(element, ".source-card")).toHaveLength(1);
  });

  it("ignores an older template response after a newer selection", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [
        { id: "a01000000000001", name: "Alpha", status: "Draft" },
        { id: "a01000000000002", name: "Beta", status: "Draft" }
      ],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    const alpha = deferred();
    const beta = deferred();
    getTemplate.mockImplementation(({ templateId }) => {
      return templateId === "a01000000000001" ? alpha.promise : beta.promise;
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const templatePicker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000002" }
      })
    );

    beta.resolve({
      id: "a01000000000002",
      name: "Beta",
      rootObject: "Account",
      templateBody: "Beta body",
      status: "Draft",
      version: 1,
      sources: []
    });
    await flushPromises();
    await flushPromises();
    alpha.resolve({
      id: "a01000000000001",
      name: "Alpha",
      rootObject: "Account",
      templateBody: "Alpha body",
      status: "Draft",
      version: 1,
      sources: []
    });
    await flushPromises();
    await flushPromises();

    expect(
      [...queryAll(element, "lightning-input")].find(
        (input) => input.label === "Template name"
      ).value
    ).toBe("Beta");
  });

  it("restores the picker when unsaved changes block a template switch", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [
        { id: "a01000000000001", name: "Alpha", status: "Draft" },
        { id: "a01000000000002", name: "Beta", status: "Draft" }
      ],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      name: "Alpha",
      rootObject: "Account",
      templateBody: "{!record.Name}",
      status: "Draft",
      version: 0,
      sources: []
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const picker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    picker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();
    const body = [...queryAll(element, "lightning-textarea")].find(
      (textarea) => textarea.label === "Template body"
    );
    body.value = "Unsaved {!record.Name}";
    body.dispatchEvent(new CustomEvent("change"));

    picker.value = "a01000000000002";
    picker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000002" } })
    );

    expect(picker.value).toBe("a01000000000001");
    expect(getTemplate).toHaveBeenCalledTimes(1);
  });

  it("loads the next template page with the server cursor", async () => {
    getTemplateSummaryPage
      .mockResolvedValueOnce({
        items: [{ id: "a01000000000001", name: "Alpha", status: "Draft" }],
        hasMore: true,
        nextName: "Alpha",
        nextId: "a01000000000001"
      })
      .mockResolvedValueOnce({
        items: [{ id: "a01000000000002", name: "Beta", status: "Published" }],
        hasMore: false
      });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Load more templates")
      .click();
    await flushPromises();

    expect(getTemplateSummaryPage).toHaveBeenLastCalledWith({
      searchText: null,
      pageSize: 50,
      afterName: "Alpha",
      afterId: "a01000000000001"
    });
    const picker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    expect(picker.options).toHaveLength(3);
  });

  it("searches the paginated catalog using the input value", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const search = [...queryAll(element, "lightning-input")].find(
      (input) => input.label === "Find a template"
    );
    search.value = "Account";
    search.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    expect(getTemplateSummaryPage).toHaveBeenLastCalledWith({
      searchText: "Account",
      pageSize: 50,
      afterName: null,
      afterId: null
    });
  });

  it("applies a starter recipe as editable settings", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    getFieldOptions.mockResolvedValue([
      { label: "Name", value: "Name", dataType: "String" }
    ]);
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const recipe = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Optional starter recipe"
    );
    recipe.dispatchEvent(
      new CustomEvent("change", { detail: { value: "account_contacts" } })
    );
    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Apply starter")
      .click();
    await flushPromises();

    expect(queryAll(element, ".source-card")).toHaveLength(1);
    const body = [...queryAll(element, "lightning-textarea")].find(
      (textarea) => textarea.label === "Template body"
    );
    expect(body.value).toContain("Contacts");
    expect(getFieldOptions).toHaveBeenCalledWith({ objectApiName: "Contact" });
  });

  it("shows required field access without record values", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    checkTemplateHealth.mockResolvedValue({
      isValid: true,
      checkedAt: "2026-09-19T12:00:00.000Z",
      messages: [],
      accessManifest: {
        items: [
          {
            objectApiName: "Account",
            fieldPath: "Name",
            sourceAlias: null,
            usage: "Prompt value",
            dataType: "String",
            sensitivity: null
          }
        ]
      }
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Validate")
      .click();
    await flushPromises();

    expect(checkTemplateHealth).toHaveBeenCalledTimes(1);
    expect(deepText(element)).toContain("Required field access");
    expect(deepText(element)).toContain("Current record");
    expect(deepText(element)).toContain("Account.Name");
    expect(query(element, ".manifest-table").getAttribute("aria-label")).toBe(
      "Required field access for this template"
    );
  });

  it("loads published versions and compares value-free changes", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: "a01000000000001", name: "Account", status: "Published" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      developerKey: "account",
      name: "Account",
      rootObject: "Account",
      templateBody: "{!record.Name}",
      status: "Published",
      version: 2,
      lastHealthStatus: "Healthy",
      lastHealthVersion: 2,
      lastHealthCodes: "OK",
      lastHealthCheckedAt: "2026-09-19T12:00:00.000Z",
      sources: []
    });
    getTemplateVersions.mockResolvedValue([
      { versionNumber: 2, publishedAt: "2026-09-19T12:00:00.000Z" },
      { versionNumber: 1, publishedAt: "2026-09-18T12:00:00.000Z" }
    ]);
    compareTemplateVersions.mockResolvedValue({
      changes: ["Data set contacts changed."]
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const picker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    picker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();
    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Compare")
      .click();
    await flushPromises();

    expect(compareTemplateVersions).toHaveBeenCalledWith({
      templateId: "a01000000000001",
      fromVersion: 1,
      toVersion: 2
    });
    expect(deepText(element)).toContain("Data set contacts changed.");
    expect(deepText(element)).toContain("Scheduled setup check");
  });

  it("saves unsaved editor changes before publishing", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: "a01000000000001", name: "Account", status: "Published" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      developerKey: "account",
      name: "Account",
      rootObject: "Account",
      templateBody: "Old body {!record.Name}",
      status: "Published",
      version: 1,
      draftRevision: 4,
      hasUnpublishedChanges: true,
      sources: []
    });
    saveDraft.mockImplementation(({ configJson }) =>
      Promise.resolve(JSON.parse(configJson))
    );
    publishTemplate.mockResolvedValue({
      prompt: "New body Acme",
      templateVersion: 2,
      fingerprint: "new-fingerprint",
      messages: [],
      accessManifest: { items: [], warnings: [] }
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const templatePicker = [...queryAll(element, "lightning-combobox")].find(
      (combobox) => combobox.label === "Open a template"
    );
    templatePicker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();

    const body = [...queryAll(element, "lightning-textarea")].find(
      (textarea) => textarea.label === "Template body"
    );
    body.value = "New body {!record.Name}";
    body.dispatchEvent(new CustomEvent("change"));
    query(element, "lightning-record-picker").dispatchEvent(
      new CustomEvent("change", {
        detail: { recordId: "001000000000001AAA" }
      })
    );
    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Publish")
      .click();
    await flushPromises();
    await flushPromises();

    expect(saveDraft).toHaveBeenCalledTimes(1);
    expect(JSON.parse(saveDraft.mock.calls[0][0].configJson).templateBody).toBe(
      "New body {!record.Name}"
    );
    expect(saveDraft.mock.invocationCallOrder[0]).toBeLessThan(
      publishTemplate.mock.invocationCallOrder[0]
    );
    // The server refuses to publish when someone saved a newer draft after this review.
    expect(publishTemplate).toHaveBeenCalledWith({
      templateId: "a01000000000001",
      sampleRecordId: "001000000000001AAA",
      draftRevision: 4
    });
    expect(query(element, ".slds-badge").textContent).not.toContain(
      "Saved changes not published"
    );
  });

  it("shows when saved changes to a live template are not published", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: "a01000000000001", name: "Account", status: "Published" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue({
      id: "a01000000000001",
      name: "Account",
      rootObject: "Account",
      templateBody: "{!record.Name}",
      status: "Published",
      version: 3,
      hasUnpublishedChanges: true,
      sources: []
    });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    [...queryAll(element, "lightning-combobox")]
      .find((combobox) => combobox.label === "Open a template")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "a01000000000001" } })
      );
    await flushPromises();
    await flushPromises();

    expect(query(element, ".slds-badge").textContent).toBe(
      "Published · Version 3 · Saved changes not published"
    );
  });

  it("asks for a preview record before publishing", async () => {
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) =>
      toasts.push(event.detail)
    );
    document.body.appendChild(element);
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Publish")
      .click();
    await flushPromises();

    expect(toasts[0].message).toBe(
      "Choose a preview record before publishing."
    );
    expect(publishTemplate).not.toHaveBeenCalled();
  });

  it("warns when a restored version used an older syntax version", async () => {
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: "a01000000000001", name: "Account", status: "Published" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    const template = {
      id: "a01000000000001",
      name: "Account",
      rootObject: "Account",
      templateBody: "{!record.Name}",
      status: "Published",
      version: 2,
      syntaxVersion: 2,
      draftRevision: 5,
      sources: []
    };
    getTemplate.mockResolvedValue(template);
    restoreTemplateVersion.mockResolvedValue({ ...template, draftRevision: 6 });
    getTemplateVersions.mockResolvedValue([
      {
        versionNumber: 2,
        syntaxVersion: 2,
        publishedAt: "2026-10-18T12:00:00.000Z"
      },
      {
        versionNumber: 1,
        syntaxVersion: 1,
        publishedAt: "2026-09-18T12:00:00.000Z"
      }
    ]);
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) =>
      toasts.push(event.detail)
    );
    document.body.appendChild(element);
    await flushPromises();
    [...queryAll(element, "lightning-combobox")]
      .find((combobox) => combobox.label === "Open a template")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "a01000000000001" } })
      );
    await flushPromises();
    await flushPromises();

    [...queryAll(element, "lightning-button")]
      .find((button) => button.label === "Restore as draft")
      .click();
    await flushPromises();
    await flushPromises();

    expect(restoreTemplateVersion).toHaveBeenCalledWith({
      templateId: "a01000000000001",
      versionNumber: 1,
      draftRevision: 5
    });
    const restoredToast = toasts[toasts.length - 1];
    expect(restoredToast.variant).toBe("warning");
    expect(restoredToast.message).toContain("syntax version 1");
  });
  it("asks for a preview record before previewing and shows the merged prompt", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    preview.mockResolvedValue({ prompt: "Hello Acme", messages: [] });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) =>
      toasts.push(event.detail)
    );
    document.body.appendChild(element);
    await flushPromises();

    byLabel(element, "lightning-button", "Preview").click();
    await flushPromises();
    expect(toasts[0].message).toBe("Choose a preview record first.");
    expect(preview).not.toHaveBeenCalled();

    query(element, "lightning-record-picker").dispatchEvent(
      new CustomEvent("change", { detail: { recordId: "001000000000001AAA" } })
    );
    byLabel(element, "lightning-button", "Preview").click();
    await flushPromises();

    expect(preview.mock.calls[0][0].recordId).toBe("001000000000001AAA");
    const generated = byLabel(
      element,
      "lightning-textarea",
      "Generated prompt preview"
    );
    expect(generated.value).toBe("Hello Acme");
    generated.value = "Hello edited";
    generated.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    expect(
      byLabel(element, "lightning-textarea", "Generated prompt preview").value
    ).toBe("Hello edited");
  });

  it("inserts current record and data set fields into the template body", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    getFieldOptions.mockResolvedValue([{ label: "Name", value: "Name" }]);
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    byLabel(
      element,
      "lightning-combobox",
      "Current record field to insert"
    ).dispatchEvent(new CustomEvent("change", { detail: { value: "Name" } }));
    await flushPromises();
    byLabel(element, "lightning-button", "Insert current record field").click();
    byLabel(element, "lightning-button", "Add related data").click();
    await flushPromises();
    byLabel(
      element,
      "lightning-dual-listbox",
      "Fields available to the prompt"
    ).dispatchEvent(new CustomEvent("change", { detail: { value: ["Name"] } }));
    await flushPromises();
    byLabel(element, "lightning-button", "Insert first value").click();
    await flushPromises();

    expect(byLabel(element, "lightning-textarea", "Template body").value).toBe(
      "{!record.Name}\n{!related.related_records_1[0].Name}"
    );
    expect(query(element, ".slds-badge").textContent).toContain(
      "Unsaved changes"
    );
  });

  it("loads fields for the chosen object and clears data sets when the Salesforce object changes", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    getFieldOptions.mockResolvedValue([]);
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    byLabel(element, "lightning-button", "Add related data").click();
    byLabel(element, "lightning-button", "Add related data").click();
    await flushPromises();
    byLabel(element, "lightning-combobox", "Object to query").dispatchEvent(
      new CustomEvent("change", { detail: { value: "Contact" } })
    );
    await flushPromises();
    expect(getFieldOptions).toHaveBeenCalledWith({ objectApiName: "Contact" });
    expect(deepText(element)).toContain("Contact: records where");

    queryAll(element, "lightning-button-icon")
      .find((button) => button.alternativeText === "Remove data set")
      .click();
    await flushPromises();
    expect(queryAll(element, "c-prompt-data-set-editor")).toHaveLength(1);

    byLabel(element, "lightning-combobox", "Salesforce object").dispatchEvent(
      new CustomEvent("change", { detail: { value: "Contact" } })
    );
    await flushPromises();
    expect(queryAll(element, "c-prompt-data-set-editor")).toHaveLength(0);
    expect(deepText(element)).toContain("No related data yet.");
  });

  it("deactivates the open template and refreshes the catalog", async () => {
    const template = {
      id: "a01000000000001",
      name: "Account",
      rootObject: "Account",
      templateBody: "{!record.Name}",
      status: "Published",
      version: 1,
      sources: []
    };
    getTemplateSummaryPage.mockResolvedValue({
      items: [{ id: template.id, name: "Account", status: "Published" }],
      hasMore: false
    });
    getFieldOptions.mockResolvedValue([]);
    getTemplate.mockResolvedValue(template);
    deactivateTemplate.mockResolvedValue({ ...template, status: "Inactive" });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) =>
      toasts.push(event.detail)
    );
    document.body.appendChild(element);
    await flushPromises();
    byLabel(element, "lightning-combobox", "Open a template").dispatchEvent(
      new CustomEvent("change", { detail: { value: template.id } })
    );
    await flushPromises();
    await flushPromises();

    byLabel(element, "lightning-button", "Deactivate").click();
    await flushPromises();
    await flushPromises();

    expect(deactivateTemplate).toHaveBeenCalledWith({
      templateId: template.id
    });
    expect(getTemplateSummaryPage).toHaveBeenCalledTimes(2);
    expect(toasts[toasts.length - 1].title).toBe("Template deactivated");
    expect(query(element, ".slds-badge").textContent).toBe(
      "Inactive · Version 1"
    );
    expect(
      byLabel(element, "lightning-combobox", "Open a template").options[1].label
    ).toBe("Account: Inactive");
  });
});
