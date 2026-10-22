import fs from "node:fs";
import path from "node:path";

const lwcRoot = "force-app/main/default/lwc";

/**
 * Lists the template and controller of Prompt Builder and of every component its templates render,
 * so text checks follow sections that move into child components.
 * @param {string} workspace Repository root
 * @returns {string[]} Workspace-relative .html and .js paths
 */
export function promptBuilderSourceFiles(workspace) {
  const components = ["promptTemplateBuilder"];
  for (const component of components) {
    const template = fs.readFileSync(
      path.join(workspace, lwcRoot, component, `${component}.html`),
      "utf8"
    );
    for (const [, tag] of template.matchAll(/<c-([a-z0-9-]+)/g)) {
      const child = tag.replace(/-([a-z0-9])/g, (_, next) =>
        next.toUpperCase()
      );
      if (!components.includes(child)) {
        components.push(child);
      }
    }
  }
  return components.flatMap((component) =>
    [".html", ".js"].map((extension) =>
      path.posix.join(lwcRoot, component, `${component}${extension}`)
    )
  );
}
