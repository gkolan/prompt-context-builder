import { createElement } from "lwc";
import PromptVersionHistory, { describeRestore } from "c/promptVersionHistory";
import compareTemplateVersions from "@salesforce/apex/PromptContextController.compareTemplateVersions";

jest.mock(
  "@salesforce/apex/PromptContextController.compareTemplateVersions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const VERSIONS = [
  { versionNumber: 3, syntaxVersion: 2, publishedAt: "2026-10-18T12:00:00Z" },
  { versionNumber: 2, syntaxVersion: 1, publishedAt: "2026-09-18T12:00:00Z" }
];

function mount(templateId) {
  const element = createElement("c-prompt-version-history", {
    is: PromptVersionHistory
  });
  Object.assign(element, { templateId, versions: VERSIONS });
  const events = [];
  for (const name of ["busychange", "versionrestore", "lightning__showtoast"]) {
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

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-prompt-version-history", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("restores the earlier version selected by default", () => {
    const { element, events } = mount("a01000000000001");

    const versionPickers =
      element.shadowRoot.querySelectorAll("lightning-combobox");
    expect(versionPickers[0].value).toBe("2");
    expect(versionPickers[1].value).toBe("3");
    button(element, "Restore as draft").click();

    expect(events).toEqual([
      { name: "versionrestore", detail: { versionNumber: 2 } }
    ]);
  });

  it("reports a failed comparison and stays busy only while it runs", async () => {
    compareTemplateVersions.mockRejectedValue({ body: { message: "Nope" } });
    const { element, events } = mount("a01000000000001");

    button(element, "Compare").click();
    await flushPromises();

    expect(
      events.map((event) => event.detail.busy ?? event.detail.message)
    ).toEqual([true, "Nope", false]);
  });

  it("needs a saved template before comparing or restoring", () => {
    const { element, events } = mount(null);

    button(element, "Compare").click();
    button(element, "Restore as draft").click();

    expect(compareTemplateVersions).not.toHaveBeenCalled();
    expect(events.map((event) => event.detail.title)).toEqual([
      "Versions needed"
    ]);
  });

  it("warns only when the restored version used an older syntax", () => {
    expect(describeRestore(VERSIONS[1], 2).variant).toBe("warning");
    expect(describeRestore(VERSIONS[0], 2)).toEqual({
      title: "Version restored as draft",
      message:
        "The published version is unchanged. Review this draft and publish it to create a new version.",
      variant: "success"
    });
    expect(describeRestore(undefined, 2).variant).toBe("success");
  });
});
