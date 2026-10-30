import { LightningElement, api } from "lwc";

// Large orgs offer thousands of objects; the dropdown shows a short list that typing narrows.
const MAX_SHOWN = 50;

/**
 * Chooses a Salesforce object from a searchable list. Typing an exact API name selects it, and the
 * server validates the saved choice against the same object rule the list uses.
 */
export default class PromptObjectPicker extends LightningElement {
  @api label = "";
  @api name = "";
  @api value = "";
  @api options = [];
  @api required = false;
  @api disabled = false;
  searchText = "";

  get matchingOptions() {
    const term = this.searchText.trim().toLowerCase();
    return term
      ? this.options.filter((option) =>
          option.label.toLowerCase().includes(term)
        )
      : this.options;
  }

  get shownOptions() {
    const shown = this.matchingOptions.slice(0, MAX_SHOWN);
    if (this.value && !shown.some((option) => option.value === this.value)) {
      // Keep the saved choice visible even when the search hides it or it is no longer offered.
      const saved = this.options.find((option) => option.value === this.value);
      shown.unshift(
        saved || { label: `${this.value} (not available)`, value: this.value }
      );
    }
    return shown;
  }

  get countText() {
    const total = this.options.length;
    const matching = this.matchingOptions.length;
    if (matching > MAX_SHOWN) {
      return `Showing ${MAX_SHOWN} of ${matching} objects. Type to narrow the list.`;
    }
    if (this.searchText.trim()) {
      return `${matching} of ${total} objects match.`;
    }
    return "";
  }

  handleSearch(event) {
    // Base component change events cross shadow boundaries; only the chosen object leaves here.
    event.stopPropagation();
    this.searchText = event.target.value || "";
    const typed = this.searchText.trim().toLowerCase();
    const exact = this.options.find(
      (option) => option.value.toLowerCase() === typed
    );
    if (exact && exact.value !== this.value) {
      this.select(exact.value);
    }
  }

  handleChange(event) {
    event.stopPropagation();
    this.select(event.detail.value);
  }

  select(value) {
    this.dispatchEvent(new CustomEvent("change", { detail: { value } }));
  }
}
