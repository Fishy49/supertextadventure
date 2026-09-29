// Runs the JavaScript contract over the fixture corpus and prints
// { "<kind>/<file>": { errors: [codes], lint: ["code path"] } } as JSON.
// ClassicGame::ContractParityTest compares the result with the Ruby
// validator and linter.
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { validateContract, lintWorld } from "../../app/javascript/world_builder/contract.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const read = p => JSON.parse(readFileSync(p, "utf8"));
const contract = {
  schema: read(join(root, "app/lib/classic_game/contract/world.schema.json")),
  refs: read(join(root, "app/lib/classic_game/contract/world.refs.json"))
};
const unique = list => [...new Set(list)].sort();
const results = world => ({
  errors: unique(validateContract(world, contract).map(e => e.code)),
  lint: unique(lintWorld(world, contract).filter(p => p.level !== "error").map(p => `${p.code} ${p.path}`))
});
const out = {};
for (const kind of ["valid", "invalid", "lint"]) {
  const dir = join(root, "test/fixtures/files/worlds", kind);
  for (const file of readdirSync(dir).sort()) {
    if (!file.endsWith(".json") || file.endsWith(".expected.json")) continue;
    out[`${kind}/${file}`] = results(read(join(dir, file)));
  }
}
for (const file of readdirSync(join(root, "games")).sort()) {
  if (!file.endsWith(".json")) continue;
  out[`games/${file}`] = results(read(join(root, "games", file)));
}
process.stdout.write(JSON.stringify(out));
