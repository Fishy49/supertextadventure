// The world contract, evaluated in the browser.
//
// Consumes the same two data files the Ruby validator uses
// (app/lib/classic_game/contract/world.schema.json and world.refs.json) and
// produces the same error codes, so the builder and the engine never disagree
// about what a valid world is. The fixture corpus under
// test/fixtures/files/worlds proves the two implementations agree.

const COLLECTIONS = ["rooms", "items", "npcs", "creatures"];
const SINGULAR = { rooms: "room", items: "item", npcs: "NPC", creatures: "creature" };
const CONSUME_ON = ["failure", "success", "any"];

const isObj = v => v !== null && typeof v === "object" && !Array.isArray(v);

// ---------- JSON Schema (the subset the contract uses) ----------

function typeOf(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v;
}
function matchesType(v, t) {
  if (t === "integer") return typeof v === "number" && Number.isInteger(v);
  if (t === "number") return typeof v === "number";
  return typeOf(v) === t;
}
function resolveRef(root, ref) {
  if (!ref.startsWith("#/")) throw new Error("Unsupported $ref: " + ref);
  return ref.slice(2).split("/").reduce((node, key) => node[key.replace(/~1/g, "/").replace(/~0/g, "~")], root);
}

// Returns a list of { pointer, keyword, message, missing } for `data` against `schema`.
export function schemaValidate(schema, data) {
  const errors = [];
  const check = (sub, value, pointer) => {
    if (sub === true) return true;
    if (sub === false) { errors.push({ pointer, keyword: "false", message: "value is not allowed here" }); return false; }
    if (sub.$ref) return check(resolveRef(schema, sub.$ref), value, pointer);
    let ok = true;
    const fail = (keyword, message, extra) => { ok = false; errors.push(Object.assign({ pointer, keyword, message }, extra || {})); };

    if (sub.type !== undefined) {
      const types = Array.isArray(sub.type) ? sub.type : [sub.type];
      if (!types.some(t => matchesType(value, t))) { fail("type", "value at `" + pointer + "` is not " + (types.length > 1 ? "one of " + types.join(", ") : aOrAn(types[0]))); return false; }
    }
    if (sub.const !== undefined && value !== sub.const) fail("const", "value at `" + pointer + "` must be " + JSON.stringify(sub.const));
    if (sub.enum !== undefined && !sub.enum.includes(value)) fail("enum", "value at `" + pointer + "` is not one of: " + sub.enum.map(x => JSON.stringify(x)).join(", "));
    if (typeof value === "number") {
      if (sub.minimum !== undefined && value < sub.minimum) fail("minimum", "number at `" + pointer + "` is less than " + sub.minimum);
      if (sub.exclusiveMinimum !== undefined && value <= sub.exclusiveMinimum) fail("exclusiveMinimum", "number at `" + pointer + "` must be greater than " + sub.exclusiveMinimum);
    }
    if (typeof value === "string") {
      if (sub.minLength !== undefined && value.length < sub.minLength) fail("minLength", "string at `" + pointer + "` is shorter than " + sub.minLength + " character" + (sub.minLength === 1 ? "" : "s"));
      if (sub.pattern !== undefined && !new RegExp(sub.pattern).test(value)) fail("pattern", "string at `" + pointer + "` does not match " + sub.pattern);
    }
    if (Array.isArray(value)) {
      if (sub.minItems !== undefined && value.length < sub.minItems) fail("minItems", "array at `" + pointer + "` needs at least " + sub.minItems + " item" + (sub.minItems === 1 ? "" : "s"));
      if (sub.items !== undefined) value.forEach((v, i) => { if (!check(sub.items, v, pointer + "/" + i)) ok = false; });
    }
    if (isObj(value)) {
      const keys = Object.keys(value);
      if (sub.required) { const missing = sub.required.filter(k => !(k in value)); if (missing.length) fail("required", "object at `" + pointer + "` is missing required properties: " + missing.join(", "), { missing }); }
      if (sub.minProperties !== undefined && keys.length < sub.minProperties) fail("minProperties", "object at `" + pointer + "` needs at least " + sub.minProperties + " propert" + (sub.minProperties === 1 ? "y" : "ies"));
      if (sub.maxProperties !== undefined && keys.length > sub.maxProperties) fail("maxProperties", "object at `" + pointer + "` has more than " + sub.maxProperties + " propert" + (sub.maxProperties === 1 ? "y" : "ies"));
      const props = sub.properties || {};
      for (const k of keys) {
        const esc = k.replace(/~/g, "~0").replace(/\//g, "~1");
        if (k in props) { if (!check(props[k], value[k], pointer + "/" + esc)) ok = false; }
        else if (sub.additionalProperties === false) fail("additionalProperties", "object at `" + pointer + "` has an unexpected property: " + k, { property: k });
        else if (isObj(sub.additionalProperties)) { if (!check(sub.additionalProperties, value[k], pointer + "/" + esc)) ok = false; }
      }
    }
    if (sub.oneOf) {
      const saved = errors.length; let matches = 0;
      for (const alt of sub.oneOf) { const before = errors.length; if (check(alt, value, pointer)) matches++; errors.length = before; }
      errors.length = saved;
      if (matches !== 1) fail("oneOf", "value at `" + pointer + "` " + (matches ? "matches more than one" : "matches none") + " of the allowed shapes");
    }
    return ok;
  };
  check(schema, data, "");
  return errors;
}
function aOrAn(word) { return (/^[aeiou]/.test(word) ? "an " : "a ") + word; }

// ---------- references ----------

// Walks every rule in the refs table. visit receives
// { rule, id, segments, trail, owner } for each string value the rule reaches.
// trail is [{ node, key }, ...] from the root down to the value.
export function walkRefs(world, refsTable, visit) {
  const rules = Array.isArray(refsTable) ? refsTable : (refsTable && refsTable.refs) || [];
  for (const rule of rules) {
    const segs = rule.path.split(".");
    const walk = (node, i, path, trail) => {
      if (i === segs.length) {
        if (typeof node !== "string") return;
        if (rule.when === "string" && typeof node !== "string") return;
        visit({ rule, id: node, segments: path, trail, owner: ownerOf(path) });
        return;
      }
      const seg = segs[i];
      if (seg === "*") {
        if (isObj(node)) for (const k of Object.keys(node)) walk(node[k], i + 1, path.concat(k), trail.concat({ node, key: k }));
        else if (Array.isArray(node)) node.forEach((v, idx) => walk(v, i + 1, path.concat(String(idx)), trail.concat({ node, key: idx })));
      } else if (isObj(node) && Object.prototype.hasOwnProperty.call(node, seg)) {
        walk(node[seg], i + 1, path.concat(seg), trail.concat({ node, key: seg }));
      }
    };
    walk(world, 0, [], []);
  }
}

// Which entity a dotted path belongs to: rooms.x... -> { type: "room", id: "x" }.
export function ownerOf(segments) {
  const s = Array.isArray(segments) ? segments : String(segments).split(".");
  if (s[0] === "meta") return { type: "meta", id: "meta" };
  if (COLLECTIONS.includes(s[0]) && s[1] !== undefined) return { type: s[0].replace(/s$/, ""), id: s[1] };
  return { type: "meta", id: "meta" };
}

function referenceErrors(world, refsTable) {
  const out = [];
  walkRefs(world, refsTable, ({ rule, id, segments }) => {
    const path = segments.join(".");
    const kind = rule.kind;
    if (kind === "flag") return;
    if (kind === "topic") {
      let found;
      if (rule.scope === "npc") found = isObj(dig(world, ["npcs", segments[1], "dialogue", "topics", id]));
      else found = Object.values(isObj(world.npcs) ? world.npcs : {}).some(n => isObj(dig(n, ["dialogue", "topics", id])));
      if (!found) out.push({ code: "topic.missing", path, message: path + " names dialogue topic '" + id + "', which no matching NPC defines." });
      return;
    }
    if (isObj(dig(world, [kind, id]))) return;
    const code = path === "meta.starting_room" ? "starting_room.missing" : "ref.missing";
    out.push({ code, path, message: path + " refers to " + SINGULAR[kind] + " '" + id + "', which is not defined." });
  });
  return out;
}
function dig(obj, keys) { let n = obj; for (const k of keys) { if (!isObj(n)) return undefined; n = n[k]; } return n; }

// ---------- the contract ----------

function schemaCode(err) {
  const p = err.pointer, missing = err.missing || [];
  if (p === "/meta" && missing.includes("starting_room")) return "starting_room.missing";
  if (/^\/creatures\/[^/]+\/attack_condition/.test(p)) return "attack_condition.invalid";
  if (p.endsWith("/dice_roll/consume_on")) return "dice.consume_on";
  if (p.endsWith("/dice_roll") && missing.some(k => k === "on_success" || k === "on_failure")) return "dice.outcomes";
  return "schema.invalid";
}
function schemaMessage(err, path, world) {
  const m = /^\/items\/([^/]+)\/dice_roll/.exec(err.pointer);
  if (m && err.keyword === "required" && (err.missing || []).some(k => k === "on_success" || k === "on_failure")) return "Item '" + m[1] + "' has a dice_roll missing on_success or on_failure.";
  if (m && err.pointer.endsWith("/dice_roll/consume_on")) return "Item '" + m[1] + "' has invalid consume_on '" + dig(world, ["items", m[1], "dice_roll", "consume_on"]) + "' (must be: " + CONSUME_ON.join(", ") + ").";
  return path ? path + ": " + err.message : err.message;
}

// Returns [{ code, path, message }], the same shape and codes as ClassicGame::WorldValidator.
export function validateContract(world, contract) {
  const w = isObj(world) ? world : {};
  const schemaErrors = schemaValidate(contract.schema, w).map(err => {
    const path = err.pointer.replace(/^\//, "").replace(/\//g, ".");
    return { code: schemaCode(err), path, message: schemaMessage(err, path, w) };
  });
  return schemaErrors.concat(referenceErrors(w, contract.refs));
}

export const CONTRACT_CODES = ["schema.invalid", "starting_room.missing", "ref.missing", "topic.missing", "dice.outcomes", "dice.consume_on", "attack_condition.invalid"];
