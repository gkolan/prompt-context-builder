import fs from "node:fs";
import path from "node:path";

const reportPath = path.join(process.cwd(), "coverage", "coverage-final.json");
const expectedFiles = [
  "force-app/main/default/lwc/promptGenerator/promptGenerator.js",
  "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.js"
];

if (!fs.existsSync(reportPath)) {
  throw new Error("LWC coverage report is missing.");
}

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const measuredFiles = Object.keys(report).map((file) =>
  file.replaceAll(path.sep, "/")
);
const missingFiles = expectedFiles.filter(
  (expectedFile) =>
    !measuredFiles.some((measuredFile) => measuredFile.endsWith(expectedFile))
);

if (missingFiles.length) {
  throw new Error(
    `Coverage data is missing for shipped components: ${missingFiles.join(", ")}`
  );
}

console.log(
  `LWC coverage includes all ${expectedFiles.length} shipped component controllers.`
);
