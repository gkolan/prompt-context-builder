import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const sourceRoot = join(root, "force-app/main/default");
const logObject = join(
  sourceRoot,
  "objects/Prompt_Input_Log__c/Prompt_Input_Log__c.object-meta.xml"
);
const apiClass = join(sourceRoot, "classes/PromptContextInputApi.cls");
const appFile = join(
  sourceRoot,
  "applications/Prompt_Context_Builder.app-meta.xml"
);
const forbiddenPaths = [
  "objects/Prompt_Input_File__c",
  "objects/Prompt_Input_File_Version__c",
  "objects/Prompt_Context_Destination__mdt",
  "flexipages/Prompt_Context_Account_Record_Page.flexipage-meta.xml",
  "classes/PromptContextApi.cls",
  "classes/PromptContextApi.cls-meta.xml"
];
const requiredFields = [
  "Request_Key__c",
  "Input_Verification_Value__c",
  "Source_Record_Id__c",
  "Prompt_Template_Version__c",
  "Prompt_Text__c",
  "Selected_Files_JSON__c",
  "Input_Format_Version__c",
  "Status__c",
  "Available_At__c",
  "Processing_Expires_At__c",
  "Attempt_Count__c",
  "Last_Reason_Code__c",
  "Retain_Until__c"
];
const forbiddenFields = [
  "DeliveryChoice__c",
  "FileCount__c",
  "TotalFileBytes__c",
  "ProviderProfileKey__c",
  "TrackingId__c"
];
const metadataRequiredFields = [
  "Request_Key__c",
  "Input_Verification_Value__c",
  "Source_Record_Id__c",
  "Prompt_Template_Version__c",
  "Input_Format_Version__c",
  "Status__c",
  "Available_At__c",
  "Attempt_Count__c",
  "Retain_Until__c"
];
const inputPermissionSets = [
  "permissionsets/Prompt_Context_Configure.permissionset-meta.xml",
  "permissionsets/Prompt_Context_Save_Input.permissionset-meta.xml",
  "permissionsets/Prompt_Context_Process_Input.permissionset-meta.xml"
];

const failures = [];

if (!existsSync(logObject)) {
  failures.push("Prompt_Input_Log__c must be the one saved-input object.");
} else {
  const objectSource = readFileSync(logObject, "utf8");
  if (!objectSource.includes("<sharingModel>Private</sharingModel>")) {
    failures.push("Prompt Input Logs must use private sharing.");
  }
  if (
    !objectSource.includes(
      "<externalSharingModel>Private</externalSharingModel>"
    )
  ) {
    failures.push("Prompt Input Logs must use private external sharing.");
  }
}

for (const relativePath of [
  "classes/PromptContextInputLifecycle.cls",
  "customPermissions/Prompt_Context_Process_Input.customPermission-meta.xml",
  "permissionsets/Prompt_Context_Process_Input.permissionset-meta.xml"
]) {
  if (!existsSync(join(sourceRoot, relativePath))) {
    failures.push(`Saved-input processing is missing ${relativePath}.`);
  }
}

for (const fieldName of requiredFields) {
  const fieldPath = join(
    sourceRoot,
    `objects/Prompt_Input_Log__c/fields/${fieldName}.field-meta.xml`
  );
  if (!existsSync(fieldPath)) {
    failures.push(`Prompt Input Log is missing ${fieldName}.`);
  }
}

for (const longTextField of ["Prompt_Text__c", "Selected_Files_JSON__c"]) {
  const fieldSource = readFileSync(
    join(
      sourceRoot,
      `objects/Prompt_Input_Log__c/fields/${longTextField}.field-meta.xml`
    ),
    "utf8"
  );
  if (fieldSource.includes("<required>true</required>")) {
    failures.push(
      `${longTextField} is a Long Text Area and Salesforce does not allow required metadata.`
    );
  }
}

for (const permissionSet of inputPermissionSets) {
  const permissionSource = readFileSync(
    join(sourceRoot, permissionSet),
    "utf8"
  );
  for (const fieldName of metadataRequiredFields) {
    if (permissionSource.includes(`Prompt_Input_Log__c.${fieldName}`)) {
      failures.push(
        `${permissionSet} must not declare field permissions for required field ${fieldName}.`
      );
    }
  }
}

for (const fieldName of forbiddenFields) {
  const fieldPath = join(
    sourceRoot,
    `objects/Prompt_Input_Log__c/fields/${fieldName}.field-meta.xml`
  );
  if (existsSync(fieldPath)) {
    failures.push(`Prompt Input Log must not duplicate ${fieldName}.`);
  }
}

for (const relativePath of forbiddenPaths) {
  if (existsSync(join(sourceRoot, relativePath))) {
    failures.push(
      `${relativePath} must not be part of the day-one data model.`
    );
  }
}

if (!existsSync(apiClass)) {
  failures.push(
    "PromptContextInputApi.cls must be the one public preparation entry."
  );
} else {
  const apiSource = readFileSync(apiClass, "utf8");
  for (const expectedText of [
    "SAVE_TO_LOG",
    "RETURN_TO_APEX",
    "PromptContextPreparationService.execute",
    "PromptContextInputLogService.save"
  ]) {
    if (!apiSource.includes(expectedText)) {
      failures.push(`PromptContextInputApi.cls must contain ${expectedText}.`);
    }
  }
  for (const forbiddenText of ["SEND_TO_DESTINATION", "CUSTOM_SINK"]) {
    if (apiSource.includes(forbiddenText)) {
      failures.push(
        `PromptContextInputApi.cls must not contain ${forbiddenText}.`
      );
    }
  }
}

const appSource = readFileSync(appFile, "utf8");
for (const forbiddenText of [
  "<actionOverrides>",
  "<tabs>Prompt_Context_Source__c</tabs>",
  "<tabs>standard-Account</tabs>",
  "<tabs>standard-Contact</tabs>"
]) {
  if (appSource.includes(forbiddenText)) {
    failures.push(
      `Prompt Context Builder app must not contain ${forbiddenText}.`
    );
  }
}

if (failures.length > 0) {
  console.error(
    "Prompt Input Log contract checks failed:\n" + failures.join("\n")
  );
  process.exit(1);
}

console.log("Prompt Input Log contract check passed.");
