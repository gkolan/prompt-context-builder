import { createElement } from "lwc";
import PromptFileSettings from "c/promptFileSettings";

function mount(fileInputMode) {
  const element = createElement("c-prompt-file-settings", {
    is: PromptFileSettings
  });
  element.config = { fileInputMode, maxFiles: 3, requireAtLeastOneFile: true };
  const changes = [];
  element.addEventListener("configchange", (event) =>
    changes.push(event.detail.changes)
  );
  document.body.appendChild(element);
  return { element, changes };
}

function control(element, name) {
  return [
    ...element.shadowRoot.querySelectorAll(
      "lightning-input, lightning-combobox"
    )
  ].find((node) => node.name === name);
}

describe("c-prompt-file-settings", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("hides file limits while Files are not included", () => {
    const { element } = mount("DISABLED");

    expect(control(element, "maxFiles")).toBeUndefined();
  });

  it("clears every file setting when Files are turned off", () => {
    const { element, changes } = mount("USER_SELECT");

    const required = control(element, "requireAtLeastOneFile");
    required.checked = false;
    required.dispatchEvent(new CustomEvent("change"));
    control(element, "fileInputMode").dispatchEvent(
      new CustomEvent("change", { detail: { value: "DISABLED" } })
    );

    expect(changes).toEqual([
      { requireAtLeastOneFile: false },
      {
        fileInputMode: "DISABLED",
        maxFiles: null,
        requireAtLeastOneFile: false,
        allowedFileFormats: "",
        providerProfileKey: "",
        fileCitationsEnabled: false
      }
    ]);
  });
});
