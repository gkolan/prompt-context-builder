import { createElement } from "lwc";
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

    const headings = [...element.shadowRoot.querySelectorAll("h2")].map(
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
      [...element.shadowRoot.querySelectorAll("lightning-button")].map(
        (button) => button.label
      )
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

    const picker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    picker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".source-budget").textContent
    ).toContain("up to 25 returned records · 1 calculated value");
  });

  it("adds a guided related data set", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const buttons = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ];
    buttons.find((button) => button.label === "Add related data").click();
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".source-card")).toHaveLength(1);
    expect(element.shadowRoot.textContent).toContain("Data set");
  });

  it("shows safe record choices for a new data set", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const addButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Add related data");
    addButton.click();
    await flushPromises();

    const scope = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Records to include");
    expect(scope.options).toEqual([
      { label: "Match a current record field", value: "RELATED" },
      { label: "Reference records", value: "REFERENCE" }
    ]);
    expect(element.shadowRoot.textContent).toContain(
      "Choose what the prompt can use"
    );
  });

  it("hides record-matching controls for a limited reference list", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Add related data")
      .click();
    await flushPromises();

    const scope = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Records to include");
    scope.dispatchEvent(
      new CustomEvent("change", { detail: { value: "REFERENCE" } })
    );
    await flushPromises();

    const labels = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].map((combobox) => combobox.label);
    expect(labels).not.toContain("Current record field");
    expect(labels).not.toContain("Related record match field");
    expect(element.shadowRoot.textContent).toContain(
      "Independent of the current record"
    );
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

    const templatePicker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Duplicate as new")
      .click();
    await flushPromises();

    const automationKey = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].find((input) => input.label === "Automation key");
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

    const templatePicker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    templatePicker.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001" }
      })
    );
    await flushPromises();
    await flushPromises();

    const body = [
      ...element.shadowRoot.querySelectorAll("lightning-textarea")
    ].find((textarea) => textarea.label === "Template body");
    body.value = "Unsaved body";
    body.dispatchEvent(new CustomEvent("change"));
    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Discard changes")
      .click();
    await flushPromises();
    await flushPromises();

    expect(
      [...element.shadowRoot.querySelectorAll("lightning-textarea")].find(
        (textarea) => textarea.label === "Template body"
      ).value
    ).toBe("Account: {!record.Name}");
    expect(element.shadowRoot.querySelectorAll(".source-card")).toHaveLength(1);
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

    const templatePicker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
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
      [...element.shadowRoot.querySelectorAll("lightning-input")].find(
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

    const picker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    picker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();
    const body = [
      ...element.shadowRoot.querySelectorAll("lightning-textarea")
    ].find((textarea) => textarea.label === "Template body");
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

    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Load more templates")
      .click();
    await flushPromises();

    expect(getTemplateSummaryPage).toHaveBeenLastCalledWith({
      searchText: null,
      pageSize: 50,
      afterName: "Alpha",
      afterId: "a01000000000001"
    });
    const picker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    expect(picker.options).toHaveLength(3);
  });

  it("searches the paginated catalog using the input value", async () => {
    getTemplateSummaryPage.mockResolvedValue({ items: [], hasMore: false });
    const element = createElement("c-prompt-template-builder", {
      is: PromptTemplateBuilder
    });
    document.body.appendChild(element);
    await flushPromises();

    const search = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].find((input) => input.label === "Find a template");
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

    const recipe = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Optional starter recipe");
    recipe.dispatchEvent(
      new CustomEvent("change", { detail: { value: "account_contacts" } })
    );
    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Apply starter")
      .click();
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll(".source-card")).toHaveLength(1);
    const body = [
      ...element.shadowRoot.querySelectorAll("lightning-textarea")
    ].find((textarea) => textarea.label === "Template body");
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

    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Validate")
      .click();
    await flushPromises();

    expect(checkTemplateHealth).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.textContent).toContain("Required field access");
    expect(element.shadowRoot.textContent).toContain("Current record");
    expect(element.shadowRoot.textContent).toContain("Account.Name");
    expect(
      element.shadowRoot
        .querySelector(".manifest-table")
        .getAttribute("aria-label")
    ).toBe("Required field access for this template");
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

    const picker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    picker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();
    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Compare")
      .click();
    await flushPromises();

    expect(compareTemplateVersions).toHaveBeenCalledWith({
      templateId: "a01000000000001",
      fromVersion: 1,
      toVersion: 2
    });
    expect(element.shadowRoot.textContent).toContain(
      "Data set contacts changed."
    );
    expect(element.shadowRoot.textContent).toContain("Scheduled setup check");
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

    const templatePicker = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.label === "Open a template");
    templatePicker.dispatchEvent(
      new CustomEvent("change", { detail: { value: "a01000000000001" } })
    );
    await flushPromises();
    await flushPromises();

    const body = [
      ...element.shadowRoot.querySelectorAll("lightning-textarea")
    ].find((textarea) => textarea.label === "Template body");
    body.value = "New body {!record.Name}";
    body.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector("lightning-record-picker").dispatchEvent(
      new CustomEvent("change", {
        detail: { recordId: "001000000000001AAA" }
      })
    );
    [...element.shadowRoot.querySelectorAll("lightning-button")]
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
    expect(
      element.shadowRoot.querySelector(".slds-badge").textContent
    ).not.toContain("Saved changes not published");
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

    [...element.shadowRoot.querySelectorAll("lightning-combobox")]
      .find((combobox) => combobox.label === "Open a template")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "a01000000000001" } })
      );
    await flushPromises();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".slds-badge").textContent).toBe(
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

    [...element.shadowRoot.querySelectorAll("lightning-button")]
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
    [...element.shadowRoot.querySelectorAll("lightning-combobox")]
      .find((combobox) => combobox.label === "Open a template")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "a01000000000001" } })
      );
    await flushPromises();
    await flushPromises();

    [...element.shadowRoot.querySelectorAll("lightning-button")]
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
});
