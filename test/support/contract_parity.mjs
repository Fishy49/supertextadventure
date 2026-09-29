// Runs the JavaScript contract validator over the fixture corpus and prints
// { "<kind>/<file>": [codes] } as JSON. ClassicGame::ContractParityTest
// compares the result with the Ruby validator.
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { validateContract } from "../../app/javascript/world_builder/contract.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const read = p => JSON.parse(readFileSync(p, "utf8"));
const contract = {
  schema: read(join(root, "app/lib/classic_game/contract/world.schema.json")),
  refs: read(join(root, "app/lib/classic_game/contract/world.refs.json"))
};
const out = {};
for (const kind of ["valid", "invalid"]) {
  const dir = join(root, "test/fixtures/files/worlds", kind);
  for (const file of readdirSync(dir).sort()) {
    if (!file.endsWith(".json") || file.endsWith(".expected.json")) continue;
    const codes = validateContract(read(join(dir, file)), contract).map(e => e.code);
    out[`${kind}/${file}`] = [...new Set(codes)].sort();
  }
}
for (const file of readdirSync(join(root, "games")).sort()) {
  if (!file.endsWith(".json")) continue;
  const codes = validateContract(read(join(root, "games", file)), contract).map(e => e.code);
  out[`games/${file}`] = [...new Set(codes)].sort();
}
process.stdout.write(JSON.stringify(out));
