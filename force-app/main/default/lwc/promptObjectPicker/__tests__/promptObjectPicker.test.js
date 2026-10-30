import { createElement } from "lwc";
import PromptObjectPicker from "c/promptObjectPicker";

const manyObjects = Array.from({ length: 120 }, (_, index) => ({
  label: `Object ${String(index).padStart(3, "0")} (Object_${index}__c)`,
  value: `Object_${index}__c`
}));
const options = [
  { label: "Account (Account)", value: "Account" },
  { label: "Contact (Contact)", value: "Contact" },
  ...manyObjects
];

function mount(props = {}) {
  const element = createElement("c-prompt-object-picker", {
    is: PromptObjectPicker
  });
  Object.assign(element, {
    label: "Salesforce object",
    name: "rootObject",
    options,
    ...props
  });
  const changes = [];
  element.addEventListener("change", (event) =>
    changes.push(event.detail.value)
  );
  document.body.appendChild(element);
  return { element, changes };
}

const combobox = (element) =>
  element.shadowRoot.querySelector("lightning-combobox");
const search = (element) => element.shadowRoot.querySelector("lightning-input");
const countText = (element) =>
  element.shadowRoot.querySelector("p").textContent.trim();

// Base input and combobox change events bubble and cross shadow boundaries, as they do in Salesforce.
async function type(element, text) {
  search(element).value = text;
  search(element).dispatchEvent(
    new CustomEvent("change", {
      detail: { value: text },
      bubbles: true,
      composed: true
    })
  );
  await Promise.resolve();
}

describe("c-prompt-object-picker", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows a short list and says how to narrow it", () => {
    const { element } = mount();

    expect(combobox(element).options).toHaveLength(50);
    expect(combobox(element).label).toBe("Salesforce object");
    expect(countText(element)).toBe(
      "Showing 50 of 122 objects. Type to narrow the list."
    );
  });

  it("filters by label or API name as the user types", async () => {
    const { element, changes } = mount();

    await type(element, "object_11");

    expect(combobox(element).options.map((option) => option.value)).toEqual([
      "Object_11__c",
      "Object_110__c",
      "Object_111__c",
      "Object_112__c",
      "Object_113__c",
      "Object_114__c",
      "Object_115__c",
      "Object_116__c",
      "Object_117__c",
      "Object_118__c",
      "Object_119__c"
    ]);
    expect(countText(element)).toBe("11 of 122 objects match.");
    expect(changes).toEqual([]);
  });

  it("selects an object when its exact API name is typed", async () => {
    const { element, changes } = mount({ value: "Account" });

    await type(element, " contact ");
    await type(element, "Account");

    expect(changes).toEqual(["Contact"]);
  });

  it("keeps the saved choice visible when the search hides it or it is unavailable", async () => {
    const { element } = mount({ value: "Account" });
    await type(element, "object_1");
    expect(combobox(element).options[0].value).toBe("Account");

    const missing = mount({ value: "Retired__c" }).element;
    expect(combobox(missing).options[0]).toEqual({
      label: "Retired__c (not available)",
      value: "Retired__c"
    });
  });

  it("reports a choice from the list and disables both controls", () => {
    const { element, changes } = mount({ disabled: true });

    combobox(element).dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Contact" },
        bubbles: true,
        composed: true
      })
    );

    expect(changes).toEqual(["Contact"]);
    expect(combobox(element).disabled).toBe(true);
    expect(search(element).disabled).toBe(true);
  });
});
