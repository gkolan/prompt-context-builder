import { createElement } from "lwc";
import PromptFilterSortEditor from "c/promptFilterSortEditor";

const FILTER = {
  clientKey: "filter-1",
  fieldName: "Name",
  operator: "EQ",
  value: "Acme",
  groupName: "group_1"
};
const SORT = {
  clientKey: "sort-1",
  fieldName: "Name",
  direction: "ASC",
  nullsOrder: ""
};

function mount(source) {
  const element = createElement("c-prompt-filter-sort-editor", {
    is: PromptFilterSortEditor
  });
  element.source = {
    filters: [FILTER],
    sorts: [SORT],
    filterGroupJoin: "AND",
    filterLogic: "",
    fieldOptions: [{ label: "Name", value: "Name", dataType: "STRING" }],
    ...source
  };
  const changes = [];
  element.addEventListener("ruleschange", (event) =>
    changes.push(event.detail.changes)
  );
  document.body.appendChild(element);
  return { element, changes };
}

function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (node) => node.label === label
  );
}

function rowControl(element, collection, name) {
  return [
    ...element.shadowRoot.querySelectorAll(`[data-collection="${collection}"]`)
  ].find((node) => node.name === name);
}

describe("c-prompt-filter-sort-editor", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("adds filters to a group unless filter logic is used", () => {
    const grouped = mount({});
    button(grouped.element, "Add filter").click();
    const withLogic = mount({ filterLogic: " 1 " });
    button(withLogic.element, "Add filter").click();

    expect(grouped.changes[0].filters[1]).toMatchObject({
      fieldName: "",
      operator: "EQ",
      value: "",
      groupName: "group_1"
    });
    expect(withLogic.changes[0].filters[1].groupName).toBe("");
    expect(
      grouped.changes[0].filters[1].clientKey !==
        withLogic.changes[0].filters[1].clientKey
    ).toBe(true);
  });

  it("edits and removes filter and sort rows", () => {
    const { element, changes } = mount({});

    rowControl(element, "filters", "operator").dispatchEvent(
      new CustomEvent("change", { detail: { value: "NE" } })
    );
    rowControl(element, "sorts", "direction").dispatchEvent(
      new CustomEvent("change", { detail: { value: "DESC" } })
    );
    button(element, "Add sort").click();
    for (const removeButton of element.shadowRoot.querySelectorAll(
      "lightning-button-icon"
    )) {
      removeButton.click();
    }

    expect(changes).toEqual([
      { filters: [{ ...FILTER, operator: "NE" }] },
      { sorts: [{ ...SORT, direction: "DESC" }] },
      {
        sorts: [
          SORT,
          expect.objectContaining({
            fieldName: "",
            direction: "ASC",
            nullsOrder: ""
          })
        ]
      },
      { filters: [] },
      { sorts: [] }
    ]);
  });

  it("disables groups while filter logic is entered", () => {
    const { element, changes } = mount({ filterLogic: "1" });

    expect(rowControl(element, "filters", "groupName").disabled).toBe(true);
    const join = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((node) => node.name === "filterGroupJoin");
    expect(join.disabled).toBe(true);
    join.dispatchEvent(new CustomEvent("change", { detail: { value: "OR" } }));
    expect(changes).toEqual([{ filterGroupJoin: "OR" }]);
  });
  it("shows only filters for a calculated value", () => {
    const { element } = mount();
    element.hideSorts = true;
    return Promise.resolve().then(() => {
      const text = element.shadowRoot.textContent;
      expect(text).not.toContain("Sort order");
      expect(
        [...element.shadowRoot.querySelectorAll("lightning-button")].some(
          (candidate) => candidate.label === "Add filter"
        )
      ).toBe(true);
    });
  });
});
