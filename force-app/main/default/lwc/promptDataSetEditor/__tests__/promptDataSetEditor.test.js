import { createElement } from "lwc";
import PromptDataSetEditor, {
  createSource,
  describeSourceBudget,
  prepareSource,
  toServerSource
} from "c/promptDataSetEditor";

const SOURCE = prepareSource({
  referenceName: "contacts",
  relatedObject: "Contact",
  correlationField: "AccountId",
  rootField: "Id",
  selectedFields: ["Name", "Email"],
  aggregateField: "Amount",
  sorts: [{ fieldName: "Name", direction: "ASC", nullsOrder: "" }],
  maxRows: 10,
  sequence: 1,
  active: true,
  fieldOptions: [
    { label: "Name", value: "Name" },
    { label: "Email", value: "Email" }
  ]
});

function mount(source = SOURCE) {
  const element = createElement("c-prompt-data-set-editor", {
    is: PromptDataSetEditor
  });
  element.source = source;
  const events = [];
  for (const name of [
    "sourcechange",
    "sourceviewchange",
    "sourceremove",
    "textinsert",
    "lightning__showtoast"
  ]) {
    element.addEventListener(name, (event) =>
      events.push({ name, detail: event.detail })
    );
  }
  document.body.appendChild(element);
  return { element, events };
}

function control(element, selector, name) {
  return [...element.shadowRoot.querySelectorAll(selector)].find(
    (node) => node.name === name || node.label === name
  );
}

function change(node, value) {
  node.dispatchEvent(new CustomEvent("change", { detail: { value } }));
}

describe("c-prompt-data-set-editor", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("clears the settings that no longer apply when the scope or result changes", () => {
    const { element, events } = mount();

    change(control(element, "lightning-combobox", "sourceMode"), "REFERENCE");
    change(control(element, "lightning-combobox", "resultMode"), "AGGREGATE");
    change(control(element, "lightning-combobox", "relatedObject"), "Lead");

    expect(events.map((event) => event.detail.changes)).toEqual([
      { sourceMode: "REFERENCE", correlationField: "", rootField: "" },
      {
        resultMode: "AGGREGATE",
        selectedFields: [],
        sorts: [],
        aggregateOperation: "COUNT",
        aggregateField: "Amount",
        mergeField: ""
      },
      {
        relatedObject: "Lead",
        correlationField: "",
        selectedFields: [],
        filters: [],
        sorts: [],
        fieldOptions: [],
        mergeField: ""
      }
    ]);
  });

  it("describes a calculated value and clears the field for a count", () => {
    const { element, events } = mount({
      ...SOURCE,
      sourceMode: "REFERENCE",
      resultMode: "AGGREGATE",
      aggregateOperation: "SUM",
      showAdvanced: true
    });

    expect(element.shadowRoot.textContent).toContain(
      "Contact: visible reference records; no extra filters; one SUM value."
    );
    expect(control(element, "lightning-input", "maxRows")).toBeUndefined();
    expect(
      element.shadowRoot.querySelector("c-prompt-filter-sort-editor")
    ).toBeNull();
    change(
      control(element, "lightning-combobox", "aggregateOperation"),
      "COUNT"
    );
    control(element, "lightning-button", "Insert calculated value").click();

    expect(events[0].detail.changes).toEqual({
      aggregateOperation: "COUNT",
      aggregateField: null
    });
    expect(events[1].detail.text).toBe("{!aggregate.contacts.value}");
  });

  it("stores numbers and the active flag from the optional settings", () => {
    const { element, events } = mount({ ...SOURCE, showAdvanced: true });

    const maxRows = control(element, "lightning-input", "maxRows");
    maxRows.value = "25";
    maxRows.dispatchEvent(new CustomEvent("change"));
    const active = control(element, "lightning-input", "active");
    active.checked = false;
    active.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot
      .querySelector("c-prompt-filter-sort-editor")
      .dispatchEvent(
        new CustomEvent("ruleschange", {
          detail: { changes: { filterLogic: "1" } }
        })
      );

    expect(events.map((event) => event.detail.changes)).toEqual([
      { maxRows: 25 },
      { active: false },
      { filterLogic: "1" }
    ]);
  });

  it("keeps the chosen prompt field while it stays selected", () => {
    const { element, events } = mount({ ...SOURCE, mergeField: "Email" });
    const listbox = control(
      element,
      "lightning-dual-listbox",
      "Fields available to the prompt"
    );

    change(listbox, ["Email"]);
    change(listbox, ["Name"]);
    change(
      control(element, "lightning-combobox", "Prompt field to insert"),
      "Name"
    );
    control(
      element,
      "lightning-button",
      "Show optional filters and sorting"
    ).click();

    expect(events.map(({ name, detail }) => [name, detail.changes])).toEqual([
      ["sourcechange", { selectedFields: ["Email"], mergeField: "Email" }],
      ["sourcechange", { selectedFields: ["Name"], mergeField: "Name" }],
      ["sourceviewchange", { mergeField: "Name" }],
      ["sourceviewchange", { showAdvanced: true }]
    ]);
  });

  it("inserts merge syntax for the data set", () => {
    const { element, events } = mount({ ...SOURCE, mergeField: "Email" });

    for (const label of [
      "Insert first value",
      "Insert count",
      "Insert repeat block"
    ]) {
      control(element, "lightning-button", label).click();
    }
    element.shadowRoot.querySelector("lightning-button-icon").click();

    expect(events.map((event) => event.detail?.text)).toEqual([
      "{!related.contacts[0].Email}",
      "{!related.contacts.count}",
      '{!#each related.contacts as="row"}\n- {!row.Email}\n{!else}\nNo records found.\n{!/each}',
      undefined
    ]);
    expect(events[3].name).toBe("sourceremove");
  });

  it("asks for a reference name and prompt field before inserting", () => {
    const { element, events } = mount({
      ...SOURCE,
      referenceName: "",
      selectedFields: [],
      mergeField: ""
    });

    control(element, "lightning-button", "Insert count").click();
    control(element, "lightning-button", "Insert repeat block").click();
    control(element, "lightning-button", "Insert first value").click();

    expect(events.map((event) => event.detail.title)).toEqual([
      "Reference name needed",
      "Reference name needed",
      "Choose a field"
    ]);
  });

  it("creates, summarizes, and serializes data sets", () => {
    const first = createSource([]);
    const second = createSource([{ referenceName: "related_records_2" }]);
    expect(first.referenceName).toBe("related_records_1");
    expect(second.referenceName).toBe("related_records_3");
    expect(first.clientKey).not.toBe(second.clientKey);

    expect(
      describeSourceBudget([
        { resultMode: "RECORDS", maxRows: 25, active: true },
        { resultMode: "AGGREGATE", maxRows: 50, active: true },
        { resultMode: "RECORDS", maxRows: 10, active: false }
      ])
    ).toBe(
      "2 data sets included · up to 25 returned records · 1 calculated value · 200 returned records allowed per template"
    );

    const saved = toServerSource({
      ...SOURCE,
      filterGroupJoin: "OR",
      filters: [{ fieldName: "Name", operator: "NOT_NULL", value: "stale" }]
    });
    expect(saved.filters).toEqual([
      {
        fieldName: "Name",
        operator: "NOT_NULL",
        value: "",
        groupName: undefined
      }
    ]);
    expect(saved.filterGroupJoin).toBe("OR");
    expect(saved.filterLogic).toBeNull();
    expect(saved).not.toHaveProperty("fieldOptions");
    expect(saved).not.toHaveProperty("mergeField");
  });
});
