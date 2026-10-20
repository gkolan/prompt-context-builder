const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  // Nested git worktrees under .claude hold other branches' copies of force-app.
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver", "<rootDir>/.claude/"],
  testPathIgnorePatterns: [
    ...jestConfig.testPathIgnorePatterns,
    "<rootDir>/.claude/"
  ],
  collectCoverageFrom: [
    "force-app/main/default/lwc/promptGenerator/promptGenerator.js",
    "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.js"
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
        lines: 57
      }
  }
};
