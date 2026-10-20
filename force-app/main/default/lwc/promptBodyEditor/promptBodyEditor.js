import { LightningElement, api } from "lwc";

const RECIPES = [
  {
    label: "Record identity",
    value: "record_identity",
    rootObject: null,
    description: "Start with the current record ID on any object.",
    templateBody: "Record ID: {!record.Id}",
    sources: []
  },
  {
    label: "Account overview",
    value: "account_overview",
    rootObject: "Account",
    description: "Summarize standard Account details.",
    templateBody:
      'Summarize this account.\n\nName: {!record.Name}\nIndustry: {!record.Industry fallback="Not provided"}\nDescription: {!record.Description fallback="Not provided"}',
    sources: []
  },
  {
    label: "Account with contacts",
    value: "account_contacts",
    rootObject: "Account",
    description: "Include up to ten Account contacts in name order.",
    templateBody:
      'Account: {!record.Name}\n\nContacts ({!related.contacts.count}):\n{!#each related.contacts as="row"}\n- {!row.Name}: {!row.Email fallback="No email"}\n{!else}\nNo visible contacts were found.\n{!/each}',
    sources: [
      {
        referenceName: "contacts",
        sourceMode: "RELATED",
        relatedObject: "Contact",
        correlationField: "AccountId",
        rootField: "Id",
        selectedFields: ["Name", "Email"],
        filters: [],
        sorts: [{ fieldName: "Name", direction: "ASC", nullsOrder: "LAST" }],
        maxRows: 10,
        sequence: 1,
        active: true
      }
    ]
  }
];

const SYNTAX_EXAMPLES = [
  { key: "root", label: "Current record field", syntax: "{!record.Name}" },
  {
    key: "fallback",
    label: "Fallback",
    syntax: '{!record.Phone fallback="Not provided"}'
  },
  {
    key: "row",
    label: "One related row",
    syntax: "{!related.recent_contacts[0].Email}"
  },
  {
    key: "count",
    label: "Related count",
    syntax: "{!related.recent_contacts.count}"
  },
  {
    key: "aggregate",
    label: "Calculated value",
    syntax: "{!aggregate.open_value.value}"
  },
  {
    key: "each",
    label: "Repeat rows",
    syntax:
      '{!#each related.recent_contacts as="row"} {!row.Name} {!else} None {!/each}'
  },
  {
    key: "if",
    label: "Conditional",
    syntax:
      "{!#if related.recent_contacts.hasRecords} Found records {!else} None {!/if}"
  }
];

/**
 * Edits the template body and offers starter recipes and current-record fields. The builder owns
 * the template and applies configchange, rootfieldchange, textinsert, and recipeapply events.
 */
export default class PromptBodyEditor extends LightningElement {
  @api templateBody = "";
  @api rootObject;
  @api rootFieldOptions = [];
  @api rootMergeField = "";
  @api previewText = "";
  @api disabled = false;
  selectedRecipe = "";
  syntaxExamples = SYNTAX_EXAMPLES;

  get recipeOptions() {
    return [
      { label: "Choose a starter recipe", value: "" },
      ...RECIPES.filter(
        (recipe) => !recipe.rootObject || recipe.rootObject === this.rootObject
      ).map((recipe) => ({
        label: `${recipe.label}: ${recipe.description}`,
        value: recipe.value
      }))
    ];
  }

  get latestPreviewText() {
    return this.previewText || "Run Preview to see the merged prompt here.";
  }

  get editorGuidance() {
    const body = this.templateBody || "";
    const openings = (body.match(/\{!#(?:each|if)\b/g) || []).length;
    const closings = (body.match(/\{!\/(?:each|if)\}/g) || []).length;
    if (openings !== closings) {
      return "A block appears incomplete. Match every each or if opening tag with a closing tag.";
    }
    if (!body.includes("{!")) {
      return "Insert at least one field from the current record or related data.";
    }
    return "The repeat and condition blocks look complete. Select Validate to check fields, access, and related data.";
  }

  get templateCharacterCount() {
    return (this.templateBody || "").length;
  }

  handleRecipeSelection(event) {
    this.selectedRecipe = event.detail.value;
  }

  applyRecipe() {
    const recipe = RECIPES.find((item) => item.value === this.selectedRecipe);
    if (recipe) {
      this.dispatchEvent(
        new CustomEvent("recipeapply", {
          detail: { templateBody: recipe.templateBody, sources: recipe.sources }
        })
      );
    }
  }

  handleRootMergeField(event) {
    this.dispatchEvent(
      new CustomEvent("rootfieldchange", {
        detail: { value: event.detail.value }
      })
    );
  }

  insertRootMerge() {
    if (this.rootMergeField) {
      this.dispatchEvent(
        new CustomEvent("textinsert", {
          detail: { text: `{!record.${this.rootMergeField}}` }
        })
      );
    }
  }

  handleBody(event) {
    this.dispatchEvent(
      new CustomEvent("configchange", {
        detail: {
          changes: { templateBody: event.detail?.value ?? event.target.value }
        }
      })
    );
  }
}
