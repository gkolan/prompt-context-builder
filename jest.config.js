const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // Other files in __tests__ folders are shared test helpers.
  testMatch: ["**/__tests__/**/*.test.js"],
  collectCoverageFrom: [
    "force-app/main/default/lwc/promptGenerator/promptGenerator.js",
    "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.js",
    "force-app/main/default/lwc/promptTemplateHeader/promptTemplateHeader.js",
    "force-app/main/default/lwc/promptBodyEditor/promptBodyEditor.js",
    "force-app/main/default/lwc/promptDataSetEditor/promptDataSetEditor.js",
    "force-app/main/default/lwc/promptFilterSortEditor/promptFilterSortEditor.js",
    "force-app/main/default/lwc/promptFileSettings/promptFileSettings.js",
    "force-app/main/default/lwc/promptPublishPanel/promptPublishPanel.js",
    "force-app/main/default/lwc/promptVersionHistory/promptVersionHistory.js"
  ],
  coverageThreshold: {
    global: {
      branches: 50,
      functions: 60,
      lines: 60,
      statements: 60
    },
    "force-app/main/default/lwc/promptGenerator/promptGenerator.js": {
      lines: 85
    },
    "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.js":
      {
        lines: 90
      },
    // Prompt Builder sections. Each child keeps its own floor so a gap cannot hide behind the parent.
    "force-app/main/default/lwc/prompt{TemplateHeader,BodyEditor,DataSetEditor,FilterSortEditor,FileSettings,PublishPanel,VersionHistory}/*.js":
      {
        lines: 85
      }
  }
};
