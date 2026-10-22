// Prompt Builder renders its sections in child components, so tests search every shadow root in
// document order.

function collect(scope, selector, matches) {
  for (const element of scope.querySelectorAll("*")) {
    if (element.matches(selector)) {
      matches.push(element);
    }
    if (element.shadowRoot) {
      collect(element.shadowRoot, selector, matches);
    }
  }
  return matches;
}

export function queryAll(element, selector) {
  return collect(element.shadowRoot, selector, []);
}

export function query(element, selector) {
  return queryAll(element, selector)[0];
}

function textOf(node) {
  if (node.nodeType === Node.TEXT_NODE) {
    return node.textContent;
  }
  return [...(node.shadowRoot?.childNodes || []), ...node.childNodes]
    .map(textOf)
    .join("");
}

export function deepText(element) {
  return [...element.shadowRoot.childNodes].map(textOf).join("");
}

export function byLabel(element, selector, label) {
  return queryAll(element, selector).find((node) => node.label === label);
}
