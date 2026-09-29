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

// ---------- lint ----------

export const LINT_CODES = [
  "flag.never_set", "flag.never_checked",
  "exit.key_unplaced", "exit.flag_never_set", "exit.redundant_use_item", "room.unreachable", "room.describes_takeable",
  "item.unplaced", "item.message_without_text", "item.reveals_unknown_exit",
  "container.no_unlock", "container.locked_but_open", "item.contents_without_container", "item.consumable_not_takeable",
  "movement.bad_duration",
  "npc.unplaced", "dialogue.empty", "topic.no_text", "topic.no_keywords", "topic.gated_without_locked_text",
  "npc.gives_without_accepts",
  "creature.unplaced", "creature.condition_without_hostile"
];

// Everything worth telling an author: contract errors at level "error", plus
// warnings and infos about worlds that validate but will not play well.
// Returns [{ code, level, path, message, target: { type, id } }], the same
// codes and paths as ClassicGame::WorldLinter.
export function lintWorld(world, contract) {
  const w = isObj(world) ? world : {};
  const out = validateContract(w, contract).map(e => ({ code: e.code, level: "error", path: e.path, message: e.message, target: ownerOf(e.path) }));
  const meta = isObj(w.meta) ? w.meta : {};
  const rooms = isObj(w.rooms) ? w.rooms : {};
  const items = isObj(w.items) ? w.items : {};
  const npcs = isObj(w.npcs) ? w.npcs : {};
  const creatures = isObj(w.creatures) ? w.creatures : {};
  const truthy = v => !(v === undefined || v === null || v === false || v === 0 || v === "");
  const itemName = id => (isObj(items[id]) && truthy(items[id].name) ? items[id].name : id);
  const report = (level, code, path, message, target) => out.push({ code, level, path, message, target: target || ownerOf(path) });

  const placed = { item: new Set(), npc: new Set(), creature: new Set() };
  const flags = {};
  walkRefs(w, contract.refs, ({ rule, id, segments }) => {
    const kind = rule.kind === "flag" || rule.kind === "topic" ? rule.kind : rule.kind.replace(/s$/, "");
    const mode = rule.mode || "ref";
    if (mode === "place" && placed[kind]) placed[kind].add(id);
    if (kind === "flag") { const e = flags[id] || (flags[id] = { set: [], check: [] }); e[mode === "set" ? "set" : "check"].push(segments.join(".")); }
  });
  const flagSet = f => !!(flags[f] && flags[f].set.length);

  const start = meta.starting_room;
  const reachable = new Set();
  if (truthy(rooms[start])) {
    const queue = [start]; reachable.add(start);
    while (queue.length) {
      const r = rooms[queue.shift()]; if (!isObj(r)) continue;
      const exits = isObj(r.exits) ? r.exits : {};
      for (const d in exits) { const ex = exits[d]; const to = typeof ex === "string" ? ex : (isObj(ex) ? ex.to : null); if (truthy(to) && truthy(rooms[to]) && !reachable.has(to)) { reachable.add(to); queue.push(to); } }
    }
  }

  for (const f in flags) {
    const e = flags[f]; const target = { type: "flag", id: f };
    if (!e.set.length) report("warn", "flag.never_set", e.check.slice().sort()[0], 'Flag "' + f + '" is checked but nothing ever sets it (' + e.check.join(", ") + ").", target);
    else if (!e.check.length) report("info", "flag.never_checked", e.set.slice().sort()[0], 'Flag "' + f + '" is set but never checked.', target);
  }

  const hiddenDirs = new Set();
  for (const rid in rooms) {
    const r = rooms[rid]; if (!isObj(r)) continue;
    const exits = isObj(r.exits) ? r.exits : {};
    for (const d in exits) {
      const ex = exits[d]; if (!isObj(ex)) continue;
      const base = "rooms." + rid + ".exits." + d;
      if (truthy(ex.hidden)) hiddenDirs.add(d);
      const keyField = truthy(ex.use_item) ? "use_item" : "requires"; const key = ex[keyField];
      if (truthy(key) && isObj(items[key]) && !placed.item.has(key)) report("warn", "exit.key_unplaced", base + "." + keyField, "Exit " + d + ' is locked and its key "' + itemName(key) + '" is never placed anywhere.');
      if (truthy(ex.requires_flag) && !flagSet(ex.requires_flag)) report("warn", "exit.flag_never_set", base + ".requires_flag", "Exit " + d + ' is gated on flag "' + ex.requires_flag + '", which nothing ever sets.');
      if (truthy(ex.use_item) && truthy(ex.requires) && ex.use_item === ex.requires) report("info", "exit.redundant_use_item", base, "Exit " + d + " sets both requires and use_item to the same item; requires alone already lets the player through.");
    }
    if (typeof r.description === "string" && Array.isArray(r.items)) {
      const text = r.description.toLowerCase();
      for (const iid of r.items) {
        const it = items[iid]; if (!isObj(it) || it.takeable === false) continue;
        const term = mentionedTerm(text, it);
        if (term) report("info", "room.describes_takeable", "rooms." + rid + ".description", 'Description mentions "' + term + '", but ' + itemName(iid) + " is takeable and the text will not change once it is taken.");
      }
    }
    if (truthy(start) && truthy(rooms[start]) && !reachable.has(rid)) report("warn", "room.unreachable", "rooms." + rid, "Room is unreachable from the starting room by any exit.");
  }

  for (const iid in items) {
    const it = items[iid]; if (!isObj(it)) continue;
    const base = "items." + iid;
    if (!placed.item.has(iid)) report("warn", "item.unplaced", base, "Item is never placed: not in a room, container, loot list, or given by an NPC.");
    if (isObj(it.on_use) && it.on_use.type === "message" && !truthy(it.on_use.text)) report("warn", "item.message_without_text", base + ".on_use", "on_use of type message has no text.");
    if (isObj(it.reveals_exit) && truthy(it.reveals_exit.direction) && !hiddenDirs.has(it.reveals_exit.direction)) report("warn", "item.reveals_unknown_exit", base + ".reveals_exit", 'reveals_exit "' + it.reveals_exit.direction + '" but no room has a hidden exit in that direction.');
    if (isObj(it.on_examine) && truthy(it.on_examine.reveals_exit) && !hiddenDirs.has(it.on_examine.reveals_exit)) report("warn", "item.reveals_unknown_exit", base + ".on_examine", 'on_examine reveals "' + it.on_examine.reveals_exit + '" but no room has a hidden exit in that direction.');
    if (truthy(it.is_container) && truthy(it.locked)) {
      const itemOk = truthy(it.unlock_item) && isObj(items[it.unlock_item]) && placed.item.has(it.unlock_item);
      const flagOk = truthy(it.unlock_flag) && flagSet(it.unlock_flag);
      const reasons = [];
      if (!truthy(it.unlock_item) && !truthy(it.unlock_flag)) reasons.push("no unlock_item or unlock_flag");
      else {
        if (truthy(it.unlock_item) && !itemOk) reasons.push(isObj(items[it.unlock_item]) ? 'unlock item "' + itemName(it.unlock_item) + '" is never placed' : 'unlock item "' + it.unlock_item + '" does not exist');
        if (truthy(it.unlock_flag) && !flagOk) reasons.push('flag "' + it.unlock_flag + '" is never set');
      }
      if (!itemOk && !flagOk) report("warn", "container.no_unlock", base, "Container is locked and nothing can unlock it (" + reasons.join("; ") + ").");
      if (it.starts_closed === false) report("warn", "container.locked_but_open", base, "Container is locked but starts open (starts_closed: false), so the lock never engages.");
    }
    if (!truthy(it.is_container) && Array.isArray(it.contents) && it.contents.length) report("warn", "item.contents_without_container", base, "Item has contents but is_container is not true.");
    if (it.takeable === false && truthy(it.consumable)) report("info", "item.consumable_not_takeable", base, "Item is not takeable but is consumable; it can only be used from the floor.");
  }

  const hasMovement = e => isObj(e.movement) && truthy(e.movement.type);
  const patrolCheck = (base, m) => {
    if (!(isObj(m) && m.type === "patrol" && Array.isArray(m.schedule))) return;
    m.schedule.forEach((s, i) => { if (isObj(s) && !(typeof s.duration === "number" && s.duration > 0)) report("warn", "movement.bad_duration", base + ".movement.schedule." + i, "Patrol stop " + (i + 1) + " should have a positive duration in turns."); });
  };

  for (const nid in npcs) {
    const n = npcs[nid]; if (!isObj(n)) continue;
    const base = "npcs." + nid;
    if (!placed.npc.has(nid) && !hasMovement(n)) report("warn", "npc.unplaced", base, "NPC is not placed in any room and has no movement.");
    if (isObj(n.dialogue)) {
      const dlg = n.dialogue;
      if (!truthy(dlg.greeting) && !truthy(dlg.default)) report("warn", "dialogue.empty", base + ".dialogue", 'Dialogue has neither greeting nor default; "talk to" will say nothing useful.');
      const topics = isObj(dlg.topics) ? dlg.topics : {};
      for (const tk in topics) {
        const t = topics[tk]; if (!isObj(t)) continue;
        const path = base + ".dialogue.topics." + tk;
        if (!truthy(t.text)) report("warn", "topic.no_text", path, 'Topic "' + tk + '" has no text.');
        if (!(Array.isArray(t.keywords) && t.keywords.length)) report("warn", "topic.no_keywords", path, 'Topic "' + tk + '" has no keywords, so players cannot ask about it.');
        if ((truthy(t.requires_flag) || truthy(t.requires_item)) && !truthy(t.locked_text)) report("info", "topic.gated_without_locked_text", path, 'Topic "' + tk + '" is gated but has no locked_text.');
      }
    }
    if (truthy(n.gives_item) && !truthy(n.accepts_item)) report("warn", "npc.gives_without_accepts", base, "gives_item without accepts_item never triggers.");
    patrolCheck(base, n.movement);
  }

  for (const cid in creatures) {
    const c = creatures[cid]; if (!isObj(c)) continue;
    const base = "creatures." + cid;
    if (!placed.creature.has(cid) && !hasMovement(c)) report("warn", "creature.unplaced", base, "Creature is not placed in any room and has no movement.");
    if (truthy(c.attack_condition) && !truthy(c.hostile)) report("info", "creature.condition_without_hostile", base, "attack_condition has no effect unless hostile is true.");
    patrolCheck(base, c.movement);
  }
  return out;
}

// The first of an item's name and keywords that appears as a whole word in the text.
function mentionedTerm(text, item) {
  const terms = [item.name].concat(Array.isArray(item.keywords) ? item.keywords : []);
  return terms.find(t => typeof t === "string" && t.length && new RegExp("\\b" + t.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b").test(text));
}
