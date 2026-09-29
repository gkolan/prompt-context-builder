import fs from "node:fs";
import path from "node:path";

const workspace = process.cwd();
const screenshotDirectory = path.join(workspace, "docs", "screenshots");
const manifestPath = path.join(screenshotDirectory, "manifest.json");
const failures = [];

function fail(message) {
  failures.push(message);
}

function imageType(buffer) {
  if (
    buffer.length >= 8 &&
    buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
  ) {
    return "png";
  }
  if (
    buffer.length >= 3 &&
    buffer[0] === 255 &&
    buffer[1] === 216 &&
    buffer[2] === 255
  ) {
    return "jpg";
  }
  return "unknown";
}

if (!fs.existsSync(manifestPath)) {
  fail("docs/screenshots/manifest.json is missing");
} else {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const entries = Array.isArray(manifest.screenshots)
    ? manifest.screenshots
    : [];
  const policy = manifest.capturePolicy || {};
  const names = new Set();

  if (manifest.schemaVersion !== 1) {
    fail("screenshot manifest schemaVersion must be 1");
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(policy.currentCaptureDate || "")) {
    fail("screenshot manifest needs an ISO currentCaptureDate");
  }
  if (
    !policy.approvedOrgAlias ||
    /@|00D[A-Za-z0-9]{12,15}/.test(policy.approvedOrgAlias)
  ) {
    fail(
      "screenshot manifest must name a safe org alias, not a username or Org ID"
    );
  }
  if (policy.evidenceScope !== "browser-verified deployed-org state") {
    fail(
      "screenshot manifest must keep browser evidence scoped to deployed-org state"
    );
  }

  for (const entry of entries) {
    if (!entry.file || names.has(entry.file)) {
      fail(
        `invalid or duplicate screenshot entry: ${entry.file || "<missing>"}`
      );
      continue;
    }
    names.add(entry.file);
    if (!["current", "historical"].includes(entry.status)) {
      fail(`${entry.file}: status must be current or historical`);
    }
    if (
      entry.status === "current" &&
      (!entry.surface || !entry.state || !entry.viewport)
    ) {
      fail(
        `${entry.file}: current screenshots need surface, state, and viewport metadata`
      );
    }
    if (
      entry.status === "historical" &&
      !/^\d{4}-\d{2}-\d{2}$/.test(entry.capturedOn || "")
    ) {
      fail(`${entry.file}: historical screenshots need an ISO capturedOn date`);
    }

    const imagePath = path.join(screenshotDirectory, entry.file);
    if (!fs.existsSync(imagePath)) {
      fail(`${entry.file}: manifest entry points to a missing image`);
      continue;
    }
    const extension = path.extname(entry.file).slice(1).toLowerCase();
    const expectedType = extension === "jpeg" ? "jpg" : extension;
    const actualType = imageType(fs.readFileSync(imagePath));
    if (actualType !== expectedType) {
      fail(
        `${entry.file}: extension says ${expectedType}, file signature says ${actualType}`
      );
    }
  }

  for (const file of fs.readdirSync(screenshotDirectory)) {
    if (/\.(?:png|jpe?g)$/i.test(file) && !names.has(file)) {
      fail(`${file}: screenshot is not recorded in manifest.json`);
    }
  }

  const markdownFiles = [path.join(workspace, "README.md")];
  const pending = [path.join(workspace, "docs")];
  while (pending.length > 0) {
    const current = pending.pop();
    for (const item of fs.readdirSync(current, { withFileTypes: true })) {
      const itemPath = path.join(current, item.name);
      if (item.isDirectory()) pending.push(itemPath);
      else if (item.name.endsWith(".md")) markdownFiles.push(itemPath);
    }
  }

  const referenced = new Set();
  for (const markdownFile of markdownFiles) {
    const source = fs.readFileSync(markdownFile, "utf8");
    for (const match of source.matchAll(/!\[([^\]]+)\]\(([^)]+)\)/g)) {
      if (!match[1].trim())
        fail(
          `${path.relative(workspace, markdownFile)}: image alt text is empty`
        );
      const target = match[2].trim().replace(/^<|>$/g, "").split("#", 1)[0];
      const resolved = path.resolve(
        path.dirname(markdownFile),
        decodeURIComponent(target)
      );
      if (path.dirname(resolved) === screenshotDirectory) {
        referenced.add(path.basename(resolved));
      }
    }
  }

  for (const file of referenced) {
    if (!names.has(file))
      fail(`${file}: referenced screenshot is absent from manifest.json`);
  }

  const rootReadme = fs.readFileSync(path.join(workspace, "README.md"), "utf8");
  for (const match of rootReadme.matchAll(/docs\/screenshots\/([^)#]+)/g)) {
    const entry = entries.find((candidate) => candidate.file === match[1]);
    if (entry && entry.status !== "current") {
      fail(
        `${entry.file}: repository README may embed only a current screenshot`
      );
    }
  }
}

if (failures.length > 0) {
  console.error("Screenshot contract checks failed:\n" + failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Screenshot contract checks passed.");
}
