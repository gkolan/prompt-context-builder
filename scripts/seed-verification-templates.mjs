import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Seeds the verification catalog one batch per anonymous Apex transaction, because publishing every
// template at once exceeds the SOQL limit. Arguments pass through to `sf apex run`, for example
// `npm run demo:setup-source -- --target-org pcb-demo`. Stops at the first batch that fails.
const seedFile = "scripts/apex/seedVerificationTemplates.apex";
const batchLine = /^Integer seedBatch = 1;$/m;
const source = readFileSync(seedFile, "utf8");
if (!batchLine.test(source)) {
  console.error(`${seedFile}: missing the "Integer seedBatch = 1;" line.`);
  process.exit(1);
}

const directory = mkdtempSync(join(tmpdir(), "pcb-seed-"));
try {
  let batchCount = 1;
  for (let batch = 1; batch <= batchCount; batch++) {
    const file = join(directory, `seed-batch-${batch}.apex`);
    writeFileSync(
      file,
      source.replace(batchLine, `Integer seedBatch = ${batch};`)
    );
    const result = spawnSync(
      "sf",
      ["apex", "run", "--file", file, ...process.argv.slice(2)],
      { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 }
    );
    const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
    // The batch count is known once the first batch reports it.
    const label =
      batch === 1 ? "Seed batch 1" : `Seed batch ${batch} of ${batchCount}`;
    if (result.status !== 0) {
      console.error(output.slice(-4000));
      console.error(
        `${label} failed (${result.error?.message ?? `exit ${result.status}`}).`
      );
      process.exit(1);
    }
    const done = /SEED_BATCH_COMPLETE batch=(\d+) of=(\d+)/.exec(output);
    if (!done || Number(done[1]) !== batch) {
      console.error(output.slice(-4000));
      console.error(`${label} did not report completion.`);
      process.exit(1);
    }
    batchCount = Number(done[2]);
    const left = /queriesLeft=(\d+)/.exec(output.slice(done.index))?.[1];
    console.log(
      `Seed batch ${batch} of ${batchCount} complete${left ? ` (${left} SOQL queries left)` : ""}.`
    );
  }
  console.log(
    `Verification catalog seeded in ${batchCount} batches. Run npm run demo:verify-source next.`
  );
} finally {
  rmSync(directory, { recursive: true, force: true });
}
