import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path) => readFileSync(join(root, path), "utf8");
const bulk = read(
  "force-app/main/default/classes/PromptContextBulkService.cls"
);
const query = read("force-app/main/default/classes/PromptContextQuery.cls");
const tests = read(
  "force-app/main/default/classes/PromptContextBulkServiceTest.cls"
);
const validatorTests = read(
  "force-app/main/default/classes/PromptContextValidatorTest.cls"
);

const failures = [];
for (const required of ["buildBulk(", "buildAggregateBulk("]) {
  if (!query.includes(required)) {
    failures.push(`PromptContextQuery.cls must include ${required}`);
  }
}
for (const required of [
  "public static List<Outcome> generate(",
  "NULL_MATCH_VALUE",
  "INVALID_MATCH_VALUE",
  "MAX_ROWS_PER_PROMPT"
]) {
  if (!bulk.includes(required)) {
    failures.push(`PromptContextBulkService.cls must enforce ${required}`);
  }
}
for (const testName of [
  "shouldMatchSharedFieldValueWithOneGroupedSourceQuery",
  "shouldSkipSourceQueryWhenEveryMatchValueIsBlank",
  "shouldGroupAggregateValuesForEveryCurrentRecord",
  "shouldReadOneReferenceDataSetForTheWholeCollection",
  "shouldRejectAStringThatCannotBeUsedAsAnIdMatch"
]) {
  if (!tests.includes(testName)) {
    failures.push(`PromptContextBulkServiceTest.cls must include ${testName}`);
  }
}
for (const testName of [
  "shouldRequireCurrencyBoundaryInMultiCurrencyOrg",
  "shouldAcceptMandatoryCurrencyBoundary",
  "shouldRejectCurrencyBoundaryInsideOptionalOrGroups"
]) {
  if (!validatorTests.includes(testName)) {
    failures.push(`PromptContextValidatorTest.cls must include ${testName}`);
  }
}

if (failures.length > 0) {
  console.error("Field-value matching checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log("Field-value matching and grouped-query checks passed.");
