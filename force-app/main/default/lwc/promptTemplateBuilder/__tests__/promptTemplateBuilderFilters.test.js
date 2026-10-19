import { createElement } from "lwc";
import PromptTemplateBuilder, {
  describeFilterValue
} from "c/promptTemplateBuilder";
import getFieldOptions from "@salesforce/apex/PromptContextController.getFieldOptions";
import getTemplate from "@salesforce/apex/PromptContextController.getTemplate";
import getTemplateSummaryPage from "@salesforce/apex/PromptContextController.getTemplateSummaryPage";
import getTemplateVersions from "@salesforce/apex/PromptContextController.getTemplateVersions";
import saveDraft from "@salesforce/apex/PromptContextController.saveDraft";

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

const FIELD_OPTIONS = [
  { label: "Active", value: "Active__c", dataType: "BOOLEAN" },
  {
    label: "Stage",
    value: "Stage__c",
    dataType: "PICKLIST",
    picklistValues: [
      { label: "Closed Won", value: "Closed_Won" },
      { label: "Open", value: "Open" }
    ]
  },
  { label: "Close Date", value: "Close_Date__c", dataType: "DATE" },
  { label: "Amount", value: "Amount__c", dataType: "CURRENCY" },
  { label: "Name", value: "Name", dataType: "STRING" }
];

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
};

async function openTemplate(source) {
  getTemplateSummaryPage.mockResolvedValue({
    items: [{ id: "a01000000000001", name: "Deals", status: "Draft" }],
    hasMore: false
  });
  getTemplateVersions.mockResolvedValue([]);
  getFieldOptions.mockResolvedValue(FIELD_OPTIONS);
  getTemplate.mockResolvedValue({
    id: "a01000000000001",
    developerKey: "deals",
    name: "Deals",
    rootObject: "Account",
    templateBody: "{!record.Name}",
    status: "Draft",
    version: 0,
    draftRevision: 7,
    sources: [
      {
        referenceName: "deals",
        sourceMode: "RELATED",
        resultMode: "RECORDS",
        relatedObject: "Deal__c",
        correlationField: "Account__c",
        rootField: "Id",
        selectedFields: ["Name"],
        filterGroupJoin: "AND",
        sorts: [],
        maxRows: 5,
        sequence: 1,
        active: true,
        ...source
      }
    ]
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
  [...element.shadowRoot.querySelectorAll("lightning-button")]
    .find((button) => button.label === "Show optional filters and sorting")
    .click();
  await flushPromises();
  return element;
}

function valueInputs(element) {
  return [
    ...element.shadowRoot.querySelectorAll(
      "lightning-input[data-row-index], lightning-combobox[data-row-index]"
    )
  ].filter((input) => input.name === "value");
}

describe("c-prompt-template-builder filters", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("describes how to enter each value type", () => {
    const fieldByName = Object.fromEntries(
      FIELD_OPTIONS.map((option) => [option.value, option])
    );
    expect(
      describeFilterValue(
        { operator: "EQ", fieldName: "Active__c" },
        fieldByName.Active__c
      ).kind
    ).toBe("boolean");
    expect(
      describeFilterValue(
        { operator: "EQ", fieldName: "Stage__c" },
        fieldByName.Stage__c
      ).choices
    ).toHaveLength(2);
    const dateView = describeFilterValue(
      { operator: "GT" },
      fieldByName.Close_Date__c
    );
    expect(dateView.placeholder).toContain("LAST_N_DAYS:30");
    expect(dateView.help).toContain("YYYY-MM-DD");
    expect(
      describeFilterValue({ operator: "GT" }, fieldByName.Amount__c).help
    ).toContain("without currency symbols");
    const listView = describeFilterValue(
      { operator: "IN" },
      fieldByName.Stage__c
    );
    expect(listView.kind).toBe("text");
    expect(listView.help).toContain("commas");
    expect(listView.help).toContain("Closed_Won");
    expect(describeFilterValue({ operator: "IS_NULL" }, null).kind).toBe(
      "none"
    );
    expect(describeFilterValue({ operator: "EQ" }, undefined).kind).toBe(
      "text"
    );
  });

  it("offers list rules and typed value inputs", async () => {
    const element = await openTemplate({
      filters: [
        { fieldName: "Active__c", operator: "EQ", value: "true" },
        { fieldName: "Stage__c", operator: "EQ", value: "Open" },
        { fieldName: "Close_Date__c", operator: "GT", value: "TODAY" },
        { fieldName: "Name", operator: "IS_NULL", value: "" }
      ]
    });

    const ruleOptions = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.name === "operator").options;
    expect(ruleOptions.map((option) => option.value)).toEqual(
      expect.arrayContaining(["IN", "NOT_IN"])
    );
    const inputs = valueInputs(element);
    expect(inputs[0].tagName).toBe("LIGHTNING-COMBOBOX");
    expect(inputs[0].options.map((option) => option.value)).toEqual([
      "true",
      "false"
    ]);
    expect(inputs[1].options.map((option) => option.label)).toContain(
      "Closed Won"
    );
    expect(inputs[2].placeholder).toContain("LAST_N_DAYS:30");
    expect(inputs[3].disabled).toBe(true);
    expect(element.shadowRoot.textContent).toContain("Filter 4");
  });

  it("sends filter logic without groups and keeps the draft revision", async () => {
    saveDraft.mockImplementation(({ configJson }) =>
      Promise.resolve(JSON.parse(configJson))
    );
    const element = await openTemplate({
      filters: [
        { fieldName: "Name", operator: "EQ", value: "A", groupName: "g1" },
        { fieldName: "Name", operator: "EQ", value: "B", groupName: "g2" },
        { fieldName: "Name", operator: "IS_NULL", value: "stale" }
      ],
      filterGroupJoin: "OR"
    });
    const logicInput = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].find((input) => input.name === "filterLogic");
    logicInput.value = " 1 AND (2 OR 3) ";
    logicInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    const groupInputs = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].filter((input) => input.name === "groupName");
    expect(groupInputs.every((input) => input.disabled)).toBe(true);
    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Save draft")
      .click();
    await flushPromises();

    const sent = JSON.parse(saveDraft.mock.calls[0][0].configJson);
    expect(sent.draftRevision).toBe(7);
    expect(sent.sources[0].filterLogic).toBe("1 AND (2 OR 3)");
    expect(sent.sources[0].filterGroupJoin).toBe("AND");
    expect(
      sent.sources[0].filters.every((filter) => filter.groupName === null)
    ).toBe(true);
    expect(sent.sources[0].filters[2].value).toBe(
      "",
      "A blank rule never sends a stale value."
    );
  });
});
