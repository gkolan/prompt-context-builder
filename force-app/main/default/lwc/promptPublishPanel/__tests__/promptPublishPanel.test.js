import { createElement } from "lwc";
import PromptPublishPanel from "c/promptPublishPanel";

const READY_CONFIG = {
  name: "Account",
  rootObject: "Account",
  templateBody: "{!record.Name}"
};

function mount(properties) {
  const element = createElement("c-prompt-publish-panel", {
    is: PromptPublishPanel
  });
  Object.assign(element, { config: READY_CONFIG, ...properties });
  const events = [];
  for (const name of [
    "validate",
    "preview",
    "save",
    "publish",
    "samplechange",
    "lightning__showtoast"
  ]) {
    element.addEventListener(name, (event) =>
      events.push({ name, detail: event.detail })
    );
  }
  document.body.appendChild(element);
  return { element, events };
}

function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (node) => node.label === label
  );
}

describe("c-prompt-publish-panel", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    delete navigator.clipboard;
  });

  it("explains what publishing still needs", () => {
    const missingBody = mount({
      config: { ...READY_CONFIG, templateBody: "" }
    });
    const missingRecord = mount({});
    const ready = mount({ sampleRecordId: "001000000000001AAA" });

    const guidance = (panel) =>
      panel.element.shadowRoot.querySelector(".publish-guidance").textContent;
    expect(guidance(missingBody)).toContain("write the prompt");
    expect(guidance(missingRecord)).toContain("Choose a preview record.");
    expect(guidance(ready)).toContain("Ready to validate and publish.");
    expect(button(missingRecord.element, "Publish").disabled).toBe(true);
    expect(button(ready.element, "Publish").disabled).toBe(false);
  });

  it("raises one event per action and for the preview record", () => {
    const { element, events } = mount({});

    for (const label of ["Validate", "Preview", "Save draft", "Publish"]) {
      button(element, label).click();
    }
    element.shadowRoot
      .querySelector("lightning-record-picker")
      .dispatchEvent(new CustomEvent("change", { detail: { recordId: null } }));

    expect(events.map((event) => event.name)).toEqual([
      "validate",
      "preview",
      "save",
      "publish",
      "samplechange"
    ]);
    expect(events[4].detail.recordId).toBe("");
  });

  it("copies the preview and explains when copying is unavailable", async () => {
    navigator.clipboard = { writeText: jest.fn().mockResolvedValue() };
    const { element, events } = mount({ previewText: "Hello Acme" });

    button(element, "Copy preview").click();
    await Promise.resolve();
    navigator.clipboard.writeText.mockRejectedValue(new Error("Denied"));
    button(element, "Copy preview").click();
    await Promise.resolve();
    await Promise.resolve();

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith("Hello Acme");
    expect(events.map((event) => event.detail.title)).toEqual([
      "Copied",
      "Copy unavailable"
    ]);
  });
});
