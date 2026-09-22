import { readFileSync } from 'node:fs';

const project = JSON.parse(readFileSync('sfdx-project.json', 'utf8'));
const scratchDefinition = JSON.parse(
  readFileSync('config/promptcontextbuilder-namespaced-scratch-def.json', 'utf8')
);
const defaultPage = readFileSync(
  'force-app/main/default/flexipages/Prompt_Context_Account_Record_Page.flexipage-meta.xml',
  'utf8'
);
const namespacedPage = readFileSync(
  'integration-tests/namespaced/main/default/flexipages/Prompt_Context_Account_Record_Page.flexipage-meta.xml',
  'utf8'
);

const errors = [];

if (project.namespace !== '') {
  errors.push('The shipping project must remain namespace-free.');
}

if (scratchDefinition.namespace !== 'rhc') {
  errors.push('The isolated namespace fixture must target the registered rhc namespace.');
}

if (!defaultPage.includes('<componentName>c:promptGenerator</componentName>')) {
  errors.push('The shipping FlexiPage must use c:promptGenerator.');
}

if (defaultPage.includes('<componentName>rhc:promptGenerator</componentName>')) {
  errors.push('The shipping FlexiPage must not contain the integration namespace.');
}

if (!namespacedPage.includes('<componentName>rhc:promptGenerator</componentName>')) {
  errors.push('The namespaced FlexiPage fixture must use rhc:promptGenerator.');
}

if (namespacedPage.includes('<componentName>c:promptGenerator</componentName>')) {
  errors.push('The namespaced FlexiPage fixture must not use the local c namespace.');
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`Namespace fixture error: ${error}`);
  }
  process.exitCode = 1;
} else {
  console.log('Namespace fixture contract passed.');
}
