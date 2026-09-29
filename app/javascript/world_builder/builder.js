// STA World Builder: a map-first editor for Classic Game Engine worlds.
// Mount it into a host element with mountWorldBuilder(root, host); see the host comment below.
// The same file runs inside the Rails app (via Stimulus) and as the offline page on the static site.
import { lintWorld, walkRefs, ownerOf } from "world_builder/contract";

const TEMPLATE = `
<div class="app" id="app">
  <div class="topbar">
    <div class="brand">STA WORLD BUILDER<span class="cursor"></span></div>
    <input class="worldname" id="worldName" aria-label="World name" placeholder="Untitled world" spellcheck="false">
    <div class="spacer"></div>
    <div class="toolbar">
      <button class="btn ghost sm" id="btnUndo" title="Undo (Ctrl+Z)" disabled>Undo</button>
      <button class="btn ghost sm" id="btnRedo" title="Redo (Ctrl+Shift+Z)" disabled>Redo</button>
      <div class="relwrap">
        <button class="btn sm" id="btnLoad">Load &#9662;</button>
        <div class="menu" id="loadMenu">
          <button id="btnImport">Import JSON file...<small>Or drag a .json file anywhere onto the page</small></button>
        </div>
      </div>
      <button class="btn sm" id="btnCopy" title="Copy the world JSON to the clipboard">Copy JSON</button>
      <button class="btn sm" id="btnOpenFile" hidden title="Open a world file from disk">Open file...</button>
      <button class="btn primary sm" id="btnSaveFile" hidden title="Save the world to disk (Ctrl+S)">Save file</button>
      <button class="btn primary sm" id="btnSave" hidden title="Save to the server (Ctrl+S)">Save</button>
      <span class="hint" id="saveState"></span>
      <button class="btn sm" id="btnProblems" title="Open the Problems tab"><span id="problemsBadge" class="badge ok">0</span> problems</button>
    </div>
  </div>

  <div class="main" id="main" data-view="canvas">
    <aside class="sidebar">
      <div class="filters" id="typeFilters" role="group" aria-label="Filter by type">
        <button class="fchip active" data-type="">All</button>
        <button class="fchip t-room" data-type="room">Rooms</button>
        <button class="fchip t-item" data-type="item">Items</button>
        <button class="fchip t-npc" data-type="npc">NPCs</button>
        <button class="fchip t-creature" data-type="creature">Creatures</button>
        <button class="fchip t-flag" data-type="flag">Flags</button>
        <button class="fchip" data-type="problems" title="Only entries with problems">!</button>
      </div>
      <input class="in search" id="search" placeholder="Filter by name or id" aria-label="Filter entities">
      <div class="scroll" id="sidebarList"></div>
    </aside>

    <section class="center">
      <div class="draftbanner" id="draftBanner" hidden></div>
      <div class="tabs" role="tablist">
        <button class="tab active" data-tab="map">Map</button>
        <button class="tab" data-tab="flags">Flags <span class="badge" id="flagCount">0</span></button>
        <button class="tab" data-tab="json">JSON</button>
        <button class="tab" data-tab="problems">Problems <span class="badge" id="problemTabBadge">0</span></button>
      </div>

      <div class="tabpane active" id="pane-map">
        <div class="map-tools">
          <button class="btn sm" id="btnAddRoom">+ Room</button>
          <button class="btn sm" id="btnConnect" title="Click a source room, then a destination room">Connect rooms</button>
          <div class="relwrap">
            <button class="btn sm" id="btnDecor" title="Add a visual-only shape or label to the map">+ Decor &#9662;</button>
            <div class="menu wide" id="decorMenu"></div>
          </div>
          <button class="btn ghost sm" id="btnAutoLayout" title="Re-run the compass layout from the starting room">Auto layout</button>
          <button class="btn ghost sm" id="btnFit">Fit</button>
          <span class="spacer"></span>
          <span id="mapHint">Drag to arrange, corner handle resizes, double-click empty space adds a room, scroll zooms.</span>
        </div>
        <div class="map-wrap" id="mapWrap">
          <svg id="map" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
                <path d="M 0 0 L 10 5 L 0 10 z" style="fill: var(--fg-dim)"></path>
              </marker>
              <marker id="arrowLocked" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
                <path d="M 0 0 L 10 5 L 0 10 z" style="fill: var(--c-flag)"></path>
              </marker>
              <marker id="arrowBroken" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
                <path d="M 0 0 L 10 5 L 0 10 z" style="fill: var(--err)"></path>
              </marker>
            </defs>
            <g id="viewport"></g>
          </svg>
          <div class="legend">
            <span><i></i> exit</span>
            <span><i class="locked"></i> locked or gated</span>
            <span><i class="hidden"></i> hidden</span>
            <span><i class="unreach"></i> unreachable from start</span>
          </div>
          <div class="maphint" id="connectHint" hidden>Connect: click the source room, then the destination room. <kbd>Esc</kbd> cancels.</div>
          <div class="popover" id="connectPop" hidden></div>
        </div>
      </div>

      <div class="tabpane" id="pane-flags">
        <div class="jsonbar"><span class="status">Every flag the world sets or checks. A flag checked but never set is a dead gate.</span></div>
        <div class="tablewrap" id="flagsTable"></div>
      </div>

      <div class="tabpane jsonpane" id="pane-json">
        <div class="jsonbar">
          <span class="status" id="jsonStatus">In sync with the editor.</span>
          <label class="check" title="meta.editor holds map positions, sizes, glyphs and decor. The engine ignores it."><input type="checkbox" id="includeEditor" checked> <span>Include map layout</span></label>
          <button class="btn sm" id="btnApplyJson">Apply changes</button>
          <button class="btn ghost sm" id="btnRevertJson">Revert</button>
        </div>
        <textarea id="jsonText" spellcheck="false" aria-label="World JSON"></textarea>
      </div>

      <div class="tabpane" id="pane-problems">
        <div class="jsonbar"><span class="status">Errors will break the engine. Warnings are probably mistakes. Click one to jump to it.</span></div>
        <div class="scroll" id="problemsList"></div>
      </div>
    </section>

    <aside class="inspector">
      <div class="scroll" id="inspector"></div>
    </aside>
  </div>

  <div class="statusbar" id="statusbar"></div>
  <nav class="bottomnav" id="bottomnav">
    <button data-view="browse">Browse</button>
    <button data-view="canvas" class="active">Map</button>
    <button data-view="edit">Edit</button>
  </nav>
</div>
<div class="toast" id="toast"></div>
<div class="dropzone" id="dropzone">Drop world JSON to import</div>
<input type="file" id="fileInput" accept=".json,application/json" hidden>
`;

/* host: { mode: "rails" | "file", world, contract: { schema, refs }, samples: [{ key, name, description, world }],
           storageKey, save(json, world) -> Promise<{ ok, errors }> } */
export function mountWorldBuilder(root, host) {
  host = host || {}; root.innerHTML = TEMPLATE;
  const contract = host.contract || { schema: {}, refs: [] };
  const STORAGE_KEY = host.storageKey || 'sta-wb-world';
  const canSave = typeof host.save === 'function';
  const fileMode = host.mode === 'file';
  let dirty = false, fileHandle = null;

  /* ---------- Constants from the Classic Game Engine docs ---------- */
  const DIRS = ['north','south','east','west','northeast','northwest','southeast','southwest','up','down','in','out'];
  const DIR_ABBR = { north:'N', south:'S', east:'E', west:'W', northeast:'NE', northwest:'NW', southeast:'SE', southwest:'SW', up:'U', down:'D', in:'IN', out:'OUT' };
  const OPPOSITE = { north:'south', south:'north', east:'west', west:'east', northeast:'southwest', southwest:'northeast', northwest:'southeast', southeast:'northwest', up:'down', down:'up', in:'out', out:'in' };
  const DIR_VEC = { north:[0,-1], south:[0,1], east:[1,0], west:[-1,0], northeast:[1,-1], northwest:[-1,-1], southeast:[1,1], southwest:[-1,1], up:[0.45,-1], down:[-0.45,1], in:[1,0.5], out:[-1,-0.5] };
  const TYPES = ['room','item','npc','creature'];
  const PLURAL = { room:'rooms', item:'items', npc:'npcs', creature:'creatures' };
  const LABEL = { room:'Room', item:'Item', npc:'NPC', creature:'Creature', meta:'World', flag:'Flag', decor:'Decor' };
  const CONSUME_ON = ['failure','success','any'];
  const ON_USE_TYPES = ['unlock','message','heal'];
  const TIERS = [
    { name:'Trivial', max:9,  color:'var(--fg-dim)' },
    { name:'Easy',    max:15, color:'var(--ok)' },
    { name:'Medium',  max:30, color:'var(--c-room)' },
    { name:'Hard',    max:60, color:'var(--warn)' },
    { name:'Boss',    max:Infinity, color:'var(--err)' }
  ];

  /* ---------- State ---------- */
  let W = null;            // the world JSON
  let layout = {};         // roomId -> {x,y} grid coordinates for the map
  let sel = null;          // {type, id}
  let tab = 'map';
  let undoStack = [], redoStack = [];
  let focusSnap = null;    // snapshot taken when an inspector field gains focus
  let problems = [];
  let refs = [];
  let flagIndex = {};
  let reachable = new Set();
  let lightTimer = null;

  const $ = (s, el) => (el || document).querySelector(s);
  const $$ = (s, el) => Array.from((el || document).querySelectorAll(s));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const clone = o => JSON.parse(JSON.stringify(o));
  const isObj = o => o && typeof o === 'object' && !Array.isArray(o);

  function el(tag, attrs, ...children) {
    const e = document.createElement(tag);
    if (attrs) for (const k in attrs) {
      const v = attrs[k];
      if (v == null || v === false) continue;
      if (k === 'class') e.className = v;
      else if (k === 'html') e.innerHTML = v;
      else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
      else if (k === 'dataset') Object.assign(e.dataset, v);
      else if (k in e && typeof v !== 'string') e[k] = v;
      else e.setAttribute(k, v === true ? '' : v);
    }
    for (const c of children.flat()) if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(c));
    return e;
  }

  function toast(msg, ms) {
    const t = $('#toast'); t.textContent = msg; t.classList.add('show');
    clearTimeout(toast._t); toast._t = setTimeout(() => t.classList.remove('show'), ms || 2200);
  }

  function ensureShape(w) {
    w.meta = isObj(w.meta) ? w.meta : {};
    for (const t of TYPES) w[PLURAL[t]] = isObj(w[PLURAL[t]]) ? w[PLURAL[t]] : {};
    for (const id in w.rooms) { const r = w.rooms[id]; if (!isObj(r)) continue; if (!isObj(r.exits)) r.exits = {}; }
    return w;
  }

  function slug(name, existing) {
    let base = String(name || 'new').toLowerCase().replace(/['"]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'new';
    let id = base, n = 2;
    while (existing && existing[id] !== undefined) id = base + '_' + (n++);
    return id;
  }

  function entityName(type, id) {
    if (type === 'meta') return W.meta.name || 'World';
    if (type === 'flag') return id;
    if (type === 'decor') { const dd = decorById(id); return dd ? (dd.label || (dd.shape === 'label' ? 'Label' : dd.shape) || 'decor') : id; }
    const e = W[PLURAL[type]] && W[PLURAL[type]][id];
    return (e && e.name) || id;
  }

  /* ---------- Reference index ----------
     Every place an id is used. Each ref knows how to rename or remove itself,
     which powers safe rename and cascade delete. */
  function refLabel(s) {
    if (s[0] === 'meta') return 'starting_room';
    const t = s.slice(2);
    if (t[0] === 'exits') return 'exit ' + t[1] + (t[2] ? ' ' + t[2] : '');
    if (t[0] === 'items' || t[0] === 'npcs' || t[0] === 'creatures') return 'in room';
    if (t[0] === 'contents') return 'inside container';
    if (t[0] === 'loot') return 'loot of';
    if (t[0] === 'gives_item') return 'given by';
    if (t[0] === 'accepts_item') return 'accepts_item';
    if (t[0] === 'sets_flag') return 'trade sets_flag';
    if (t[0] === 'sets_flag_on_defeat') return 'sets_flag_on_defeat';
    if (t[0] === 'unlock_item' || t[0] === 'unlock_flag') return 'container ' + t[0];
    if (t[0] === 'on_use') return 'on_use ' + t[1];
    if (t[0] === 'dice_roll') return 'dice ' + t[1] + ' ' + (t[2] === 'unlocks_exit' ? 'unlocks_exit room' : t[2]);
    if (t[0] === 'dialogue' && t[1] === 'topics') return 'topic "' + t[2] + '" ' + t[3];
    if (t[0] === 'dialogue') return 'dialogue greeting ' + t[1];
    if (t[0] === 'movement' && t[1] === 'schedule') return 'patrol stop ' + (Number(t[2]) + 1) + (t[3] === 'blocked_while_player_in' ? ' blocked_while_player_in' : '');
    if (t[0] === 'movement') return 'movement ' + t[1];
    return t.filter(x => !/^\d+$/.test(x)).join(' ');
  }
  /* Every place an id is used, built from the shared refs table. Each record can rename or remove
     itself, which powers safe rename and cascade delete. */
  function collectRefs() {
    const out = [];
    walkRefs(W, contract.refs, ({ rule, id, segments, trail, owner }) => {
      const kind = rule.kind === 'flag' || rule.kind === 'topic' ? rule.kind : rule.kind.replace(/s$/, '');
      const mode = rule.mode || 'ref';
      const last = trail[trail.length - 1];
      const set = v => { last.node[last.key] = v; };
      const remove = () => {
        if (rule.path === 'meta.starting_room') { W.meta.starting_room = Object.keys(W.rooms)[0] || ''; return; }
        if (rule.path === 'rooms.*.exits.*.to') { const ex = trail[trail.length - 2]; delete ex.node[ex.key]; return; }
        if (Array.isArray(last.node)) { const i = last.node.indexOf(id); if (i >= 0) last.node.splice(i, 1); } else delete last.node[last.key];
      };
      out.push({ kind, id, mode, scope: rule.scope, owner, path: segments.join('.'), label: refLabel(segments), set, remove });
    });
    return out;
  }
  function buildFlagIndex() {
    const idx = {};
    for (const r of refs) if (r.kind === 'flag') { (idx[r.id] = idx[r.id] || { set: [], check: [] })[r.mode === 'set' ? 'set' : 'check'].push(r); }
    return idx;
  }

  function computeReachable() {
    const seen = new Set(); const start = W.meta.starting_room; if (!W.rooms[start]) return seen;
    const q = [start]; seen.add(start);
    while (q.length) { const id = q.shift(); const r = W.rooms[id]; if (!isObj(r)) continue; for (const d in r.exits || {}) { const ex = r.exits[d]; const to = typeof ex === 'string' ? ex : (isObj(ex) ? ex.to : null); if (to && W.rooms[to] && !seen.has(to)) { seen.add(to); q.push(to); } } }
    return seen;
  }

  /* ---------- Validation ----------
     Errors, warnings, and infos all come from the shared contract (lintWorld), so the
     builder, the Ruby validator, and bin/world check agree on every problem. */
  function validate() {
    return lintWorld(W, contract).map(p => ({ level: p.level, msg: p.message, target: p.target, code: p.code }));
  }

  function problemsFor(type, id) { return problems.filter(p => p.target.type === type && p.target.id === id); }
  function worstLevel(list) { return list.some(p => p.level === 'error') ? 'error' : list.some(p => p.level === 'warn') ? 'warn' : null; }

  /* ---------- Analysis (recomputed after every change) ---------- */
  function analyze() {
    refs = collectRefs();
    flagIndex = buildFlagIndex();
    reachable = computeReachable();
    problems = validate();
  }

  /* ---------- Persistence, undo ---------- */
  function save() {
    dirty = true; renderSaveState();
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ savedAt: Date.now(), world: W })); } catch (e) { /* storage unavailable */ }
  }
  function clearDraft() { try { localStorage.removeItem(STORAGE_KEY); } catch (e) { /* storage unavailable */ } }
  function readDraft() { try { const s = localStorage.getItem(STORAGE_KEY); if (!s) return null; const d = JSON.parse(s); return isObj(d) && isObj(d.world) ? d : (isObj(d) && d.meta ? { savedAt: 0, world: d } : null); } catch (e) { return null; } }
  function renderSaveState() {
    const st = $('#saveState'); const btn = $('#btnSave'); const fbtn = $('#btnSaveFile');
    btn.hidden = !canSave; fbtn.hidden = !fileMode; $('#btnOpenFile').hidden = !fileMode;
    if (canSave) { btn.disabled = !dirty; st.textContent = dirty ? 'Unsaved changes' : 'Saved'; }
    else if (fileMode) { st.textContent = fileHandle ? (dirty ? 'Unsaved changes in ' + fileHandle.name : fileHandle.name) : (dirty ? 'Not saved to a file yet' : ''); }
    else st.textContent = '';
  }
  async function doSave() {
    if (fileMode) return saveToFile();
    if (!canSave) return;
    const btn = $('#btnSave'); btn.disabled = true; $('#saveState').textContent = 'Saving...';
    try {
      const res = await host.save(exportJson(), W);
      if (res && res.ok === false) { toast('Not saved: ' + ((res.errors && res.errors.join('; ')) || 'the server rejected the world'), 6000); }
      else { dirty = false; clearDraft(); toast('Saved'); }
    } catch (e) { toast('Save failed: ' + e.message, 6000); }
    renderSaveState();
  }
  async function saveToFile() {
    const json = exportJson();
    try {
      if (!fileHandle && window.showSaveFilePicker) fileHandle = await window.showSaveFilePicker({ suggestedName: (slug(W.meta.name || 'world') || 'world') + '.json', types: [{ description: 'World JSON', accept: { 'application/json': ['.json'] } }] });
      if (fileHandle) { const w = await fileHandle.createWritable(); await w.write(json); await w.close(); dirty = false; toast('Saved ' + fileHandle.name); renderSaveState(); return; }
    } catch (e) { if (e && e.name === 'AbortError') return; toast('Could not write the file: ' + e.message, 5000); }
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([json], { type: 'application/json' })); a.download = (slug(W.meta.name || 'world') || 'world') + '.json'; document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000); dirty = false; renderSaveState(); toast('Downloaded ' + a.download);
  }
  async function openFromFile() {
    if (window.showOpenFilePicker) { try { const [h] = await window.showOpenFilePicker({ types: [{ description: 'World JSON', accept: { 'application/json': ['.json'] } }] }); const f = await h.getFile(); importFile(f, h); } catch (e) { if (e && e.name !== 'AbortError') toast('Could not open the file: ' + e.message, 5000); } }
    else $('#fileInput').click();
  }
  function checkDraft() {
    const d = readDraft(); const banner = $('#draftBanner'); banner.hidden = true; banner.innerHTML = '';
    if (!d || !host.world) return;
    const strip = w => { const c = clone(w); if (isObj(c.meta)) delete c.meta.editor; return c; };
    if (JSON.stringify(strip(d.world)) === JSON.stringify(strip(host.world))) { clearDraft(); return; }
    const when = d.savedAt ? new Date(d.savedAt).toLocaleString() : 'an earlier session';
    banner.hidden = false;
    banner.append(el('span', {}, 'This browser has unsaved changes to this world from ' + when + '.'), el('button', { class: 'btn sm', onclick: () => { loadWorld(d.world); dirty = true; renderSaveState(); select('room', W.meta.starting_room); banner.hidden = true; toast('Draft restored. Save to keep it.'); } }, 'Restore draft'), el('button', { class: 'btn ghost sm', onclick: () => { clearDraft(); banner.hidden = true; } }, 'Discard'));
  }
  function pushUndo(snapshot) {
    undoStack.push(snapshot || JSON.stringify(W)); if (undoStack.length > 80) undoStack.shift(); redoStack = []; updateUndoButtons();
  }
  function undo() { if (!undoStack.length) return; redoStack.push(JSON.stringify(W)); W = ensureShape(JSON.parse(undoStack.pop())); afterReplace(); toast('Undone'); }
  function redo() { if (!redoStack.length) return; undoStack.push(JSON.stringify(W)); W = ensureShape(JSON.parse(redoStack.pop())); afterReplace(); toast('Redone'); }
  function updateUndoButtons() { $('#btnUndo').disabled = !undoStack.length; $('#btnRedo').disabled = !redoStack.length; }
  function afterReplace() { updateUndoButtons(); layout = readEditorRooms(); if (sel && sel.type !== 'meta' && sel.type !== 'flag' && sel.type !== 'decor' && !W[PLURAL[sel.type]][sel.id]) sel = null; if (sel && sel.type === 'decor' && !decorById(sel.id)) sel = null; commit({ inspector: true, layout: true }); }

  /* commit(): call after any mutation. opts.inspector re-renders the form (structural changes only). */
  function commit(opts) {
    opts = opts || {};
    if (opts.inspector) normalizeExits(W);
    if (opts.layout) autoLayout(false);
    syncEditor(); analyze(); save();
    renderSidebar(); renderMap(); renderBadges(); renderStatus();
    if (tab === 'json') renderJson(); if (tab === 'flags') renderFlags(); if (tab === 'problems') renderProblems();
    if (opts.inspector) renderInspector();
  }
  function lightCommit() { clearTimeout(lightTimer); lightTimer = setTimeout(() => commit({}), 120); }

  /* ---------- Entity operations ---------- */
  function newEntityData(type, name) {
    const defaults = { room: { name:'New Room', description:'', exits:{}, items:[], npcs:[], creatures:[] }, item: { name:'New Item', description:'', keywords:[] }, npc: { name:'New Character', description:'', keywords:[] }, creature: { name:'New Creature', description:'', keywords:[], health:10, attack:3, defense:0, hostile:false } };
    const d = defaults[type]; if (name) d.name = name; return d;
  }
  function quickCreate(type, name) { const coll = W[PLURAL[type]]; const id = slug(name, coll); coll[id] = newEntityData(type, name); return id; }
  function createEntity(type, data) {
    pushUndo();
    const coll = W[PLURAL[type]];
    const obj = Object.assign(newEntityData(type), data || {});
    const id = slug(obj.name, coll); coll[id] = obj;
    if (type === 'room' && !W.meta.starting_room) W.meta.starting_room = id;
    select(type, id); commit({ inspector: true }); return id;
  }
  function renameEntity(type, oldId, newId) {
    newId = slug(newId); if (!newId || newId === oldId) return oldId;
    const coll = W[PLURAL[type]]; if (coll[newId]) { toast('A ' + LABEL[type].toLowerCase() + ' with id "' + newId + '" already exists.'); return oldId; }
    pushUndo();
    const rebuilt = {}; for (const k in coll) rebuilt[k === oldId ? newId : k] = coll[k]; W[PLURAL[type]] = rebuilt;
    let n = 0; for (const r of collectRefs()) if (r.kind === type && r.id === oldId) { r.set(newId); n++; }
    if (type === 'room' && layout[oldId]) { layout[newId] = layout[oldId]; delete layout[oldId]; }
    if (sel && sel.type === type && sel.id === oldId) sel.id = newId;
    toast('Renamed to "' + newId + '"' + (n ? ', updated ' + n + ' reference' + (n === 1 ? '' : 's') : ''));
    commit({ inspector: true }); return newId;
  }
  function deleteEntity(type, id) {
    pushUndo();
    const rs = collectRefs().filter(r => r.kind === type && r.id === id); rs.forEach(r => r.remove());
    delete W[PLURAL[type]][id]; if (type === 'room') delete layout[id];
    if (sel && sel.type === type && sel.id === id) sel = null;
    toast('Deleted ' + LABEL[type].toLowerCase() + ' "' + id + '"' + (rs.length ? ' and ' + rs.length + ' reference' + (rs.length === 1 ? '' : 's') : ''));
    commit({ inspector: true });
  }
  function renameFlag(oldF, newF) {
    newF = String(newF || '').trim(); if (!newF || newF === oldF) return;
    pushUndo(); let n = 0; for (const r of collectRefs()) if (r.kind === 'flag' && r.id === oldF) { r.set(newF); n++; }
    if (sel && sel.type === 'flag') sel.id = newF; toast('Renamed flag in ' + n + ' place' + (n === 1 ? '' : 's')); commit({ inspector: true });
  }
  function duplicateEntity(type, id) {
    const src = W[PLURAL[type]][id]; if (!src) return; pushUndo();
    const copy = clone(src); copy.name = (copy.name || id) + ' copy'; const nid = slug(copy.name, W[PLURAL[type]]); W[PLURAL[type]][nid] = copy;
    if (type === 'room') { copy.items = []; copy.npcs = []; copy.creatures = []; if (layout[id]) layout[nid] = Object.assign({}, layout[id], { x: layout[id].x + 1, y: layout[id].y + 1 }); }
    select(type, nid); commit({ inspector: true });
  }
  function select(type, id) { sel = type ? { type, id } : null; renderSidebar(); renderMap(); renderInspector(); if (window.innerWidth <= 900 && type) setView('edit'); }

  function loadWorld(w, opts) {
    opts = opts || {}; W = ensureShape(w); sel = null; layout = readEditorRooms();
    if (!opts.keepHistory) { undoStack = []; redoStack = []; }
    updateUndoButtons(); $('#worldName').value = W.meta.name || '';
    analyze(); if (!Object.keys(layout).length) autoLayout(true); syncEditor(); renderSaveState();
    renderSidebar(); renderMap(true); renderBadges(); renderStatus(); renderInspector(); renderJson(); renderFlags(); renderProblems();
  }



  /* ---------- Map: compass-aware room graph on SVG, plus editor-only decor ----------
     Visual metadata lives under meta.editor: rooms[id] = {x, y, w, h, glyph, outline}, decor = [{id, shape, x, y, w, h, r, label}].
     The engine ignores it; the builder can always rebuild positions without it. */
  const NODE_W = 156, NODE_H = 58, STEP_X = 220, STEP_Y = 132;
  const LAYOUT_VEC = { north:[0,-1], south:[0,1], east:[1,0], west:[-1,0], northeast:[1,-1], northwest:[-1,-1], southeast:[1,1], southwest:[-1,1], up:[1,-1], down:[-1,1], in:[1,1], out:[-1,-1] };
  const SYMBOLS = {
    house: 'M3 12 L12 4 L21 12 M5 11 V20 H19 V11 M10 20 V14 H14 V20',
    tavern: 'M5 6 H16 V19 H5 Z M16 9 H19 V15 H16 M5 10 H16',
    shop: 'M3 10 L5 5 H19 L21 10 Z M4 10 V20 H20 V10 M10 20 V14 H14 V20',
    castle: 'M3 20 V9 H6 V6 H9 V9 H15 V6 H18 V9 H21 V20 Z M10 20 V14 H14 V20',
    tower: 'M8 21 V7 H10 V4 H12 V7 H14 V4 H16 V21 Z M11 21 V15 H13 V21',
    gate: 'M6 21 V8 C6 5 18 5 18 8 V21 M4 21 H20 M12 8 V21',
    cave: 'M3 21 C3 10 8 5 12 5 C16 5 21 10 21 21 Z M9 21 C9 15 10 13 12 13 C14 13 15 15 15 21',
    forest: 'M6 21 V17 M3 17 L6 9 L9 17 Z M4.5 12 L6 5 L7.5 12 M16 21 V16 M12 16 L16 6 L20 16 Z M13.5 10 L16 3 L18.5 10',
    mountain: 'M2 20 L8 8 L12 14 L15 6 L22 20 Z M9.5 11 L11 13 M14 9 L16.5 13',
    water: 'M2 8 C5 5 8 11 11 8 C14 5 17 11 20 8 M2 13 C5 10 8 16 11 13 C14 10 17 16 20 13 M2 18 C5 15 8 21 11 18 C14 15 17 21 20 18',
    bridge: 'M2 16 C6 8 18 8 22 16 M2 19 H22 M6 12.5 V19 M12 10 V19 M18 12.5 V19',
    road: 'M4 21 L10 3 M20 21 L14 3 M12 8 V11 M12 14 V17',
    skull: 'M12 3 C7 3 5 7 5 11 C5 14 7 15 8 16 V20 H16 V16 C17 15 19 14 19 11 C19 7 17 3 12 3 Z M9 11 A1.5 1.5 0 1 0 9.01 11 M15 11 A1.5 1.5 0 1 0 15.01 11 M10.5 20 V17 M13.5 20 V17'
  };
  const SYMBOL_LIST = Object.keys(SYMBOLS);
  const OUTLINES = ['box', 'rounded', 'pill', 'hexagon'];
  let view = { x: 40, y: 40, k: 1 };
  let connectMode = false, connectSrc = null;
  const svg = $('#map'), viewport = $('#viewport'), mapWrap = $('#mapWrap');
  const NS = 'http://www.w3.org/2000/svg';
  const sv = (tag, attrs, ...kids) => { const e = document.createElementNS(NS, tag); for (const k in attrs || {}) if (attrs[k] != null) e.setAttribute(k, attrs[k]); for (const k of kids) if (k != null) e.append(k.nodeType ? k : document.createTextNode(k)); return e; };
  const ckey = p => Math.round(p.x) + ',' + Math.round(p.y);
  (function injectSymbols() { const defs = svg.querySelector('defs'); for (const k in SYMBOLS) { const s = sv('symbol', { id: 'sym-' + k, viewBox: '0 0 24 24' }); s.append(sv('path', { d: SYMBOLS[k], fill: 'none', stroke: 'currentColor', 'stroke-width': 1.6, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' })); defs.append(s); } })();

  /* editor metadata in and out of the world */
  function readEditorRooms() {
    const ed = W.meta.editor, out = {}; if (!isObj(ed) || !isObj(ed.rooms)) return out;
    for (const id in ed.rooms) { const e = ed.rooms[id]; if (!isObj(e) || !Number.isFinite(e.x) || !Number.isFinite(e.y) || !W.rooms[id]) continue; const l = { x: e.x, y: e.y }; if (e.w > 0) l.w = e.w; if (e.h > 0) l.h = e.h; if (SYMBOLS[e.glyph]) l.glyph = e.glyph; if (OUTLINES.includes(e.outline) && e.outline !== 'box') l.outline = e.outline; out[id] = l; }
    return out;
  }
  function syncEditor() {
    if (!W) return; const ed = isObj(W.meta.editor) ? W.meta.editor : {};
    const rooms = {}; for (const id in W.rooms) { const l = layout[id]; if (!l) continue; const e = { x: l.x, y: l.y }; if (l.w > 0) e.w = l.w; if (l.h > 0) e.h = l.h; if (l.glyph) e.glyph = l.glyph; if (l.outline && l.outline !== 'box') e.outline = l.outline; rooms[id] = e; }
    if (Object.keys(rooms).length) ed.rooms = rooms; else delete ed.rooms;
    if (!Array.isArray(ed.decor) || !ed.decor.length) delete ed.decor;
    if (Object.keys(ed).length) W.meta.editor = ed; else delete W.meta.editor;
  }
  function decorList() { const ed = W.meta.editor; if (!isObj(ed) || !Array.isArray(ed.decor)) return []; return ed.decor.filter((d, i) => { if (!isObj(d)) return false; if (!d.id) d.id = 'decor_' + (i + 1); return true; }); }
  function decorById(id) { return decorList().find(d => d.id === id); }
  function addDecor(shape) {
    pushUndo(); W.meta.editor = isObj(W.meta.editor) ? W.meta.editor : {}; const list = W.meta.editor.decor = Array.isArray(W.meta.editor.decor) ? W.meta.editor.decor : [];
    const wr = mapWrap.getBoundingClientRect(); const c = toWorld(wr.left + mapWrap.clientWidth / 2, wr.top + mapWrap.clientHeight / 2);
    const id = 'decor_' + Date.now().toString(36); const isLabel = shape === 'label';
    list.push({ id, shape, x: Math.round(c.x / STEP_X * 4) / 4, y: Math.round(c.y / STEP_Y * 4) / 4, w: isLabel ? 140 : 72, h: isLabel ? 26 : 72, r: 0, label: isLabel ? 'New label' : '' });
    select('decor', id); commit({ inspector: true });
  }
  function deleteDecor(id) { pushUndo(); const ed = W.meta.editor; if (isObj(ed) && Array.isArray(ed.decor)) ed.decor = ed.decor.filter(d => !isObj(d) || d.id !== id); if (sel && sel.type === 'decor' && sel.id === id) sel = null; commit({ inspector: true }); }
  function setLayout(id, patch) { pushUndo(); const l = Object.assign({}, layout[id] || { x: 0, y: 0 }, patch); for (const k in l) if (l[k] === undefined || l[k] === '' || l[k] === null) delete l[k]; layout[id] = l; commit({ inspector: true }); }

  function autoLayout(reset) {
    const ids = Object.keys(W.rooms); const coords = {}; const occupied = new Map();
    if (!reset) for (const id of ids) if (layout[id]) { coords[id] = { x: layout[id].x, y: layout[id].y }; occupied.set(ckey(coords[id]), id); }
    const place = (id, x, y) => {
      let best = null;
      for (let r = 0; r < 12 && !best; r++) for (let dy = -r; dy <= r && !best; dy++) for (let dx = -r; dx <= r; dx++) { if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue; const c = { x: Math.round(x) + dx, y: Math.round(y) + dy }; if (!occupied.has(ckey(c))) { best = c; break; } }
      best = best || { x: Math.round(x), y: Math.round(y) }; coords[id] = best; occupied.set(ckey(best), id);
    };
    const start = W.rooms[W.meta.starting_room] ? W.meta.starting_room : ids[0];
    const queue = Object.keys(coords); if (start && !coords[start]) { place(start, 0, 0); queue.push(start); }
    const seen = new Set(queue);
    while (queue.length) { const id = queue.shift(); const r = W.rooms[id]; if (!isObj(r) || !isObj(r.exits)) continue; for (const dir in r.exits) { const ex = r.exits[dir]; const to = typeof ex === 'string' ? ex : (isObj(ex) ? ex.to : null); if (!to || !W.rooms[to] || seen.has(to)) continue; const v = LAYOUT_VEC[dir] || [1, 1]; place(to, coords[id].x + v[0], coords[id].y + v[1]); seen.add(to); queue.push(to); } }
    const rest = ids.filter(id => !coords[id]);
    if (rest.length) { let maxY = -1, minX = 0; for (const id in coords) { maxY = Math.max(maxY, coords[id].y); minX = Math.min(minX, coords[id].x); } rest.forEach((id, i) => place(id, minX + i, maxY + 2)); }
    const next = {}; for (const id of ids) next[id] = Object.assign({}, layout[id] || {}, coords[id]); layout = next;
  }

  function nodePx(id) { const p = layout[id] || { x: 0, y: 0 }; return { x: p.x * STEP_X, y: p.y * STEP_Y }; }
  function nodeSize(id) { const l = layout[id] || {}; return { w: l.w > 0 ? l.w : NODE_W, h: l.h > 0 ? l.h : NODE_H }; }
  function borderPoint(c, tx, ty, w, h) { const dx = tx - c.x, dy = ty - c.y; if (!dx && !dy) return c; const t = Math.min(w / 2 / Math.abs(dx || 1e-9), h / 2 / Math.abs(dy || 1e-9)); return { x: c.x + dx * t, y: c.y + dy * t }; }
  function trunc(s, n) { s = String(s || ''); return s.length > n ? s.slice(0, n - 1) + '…' : s; }
  function wrapWords(s, maxChars, maxLines) { const words = String(s || '').split(/\s+/).filter(Boolean); const lines = []; let cur = ''; for (const w of words) { if (!cur) cur = w; else if ((cur + ' ' + w).length <= maxChars) cur += ' ' + w; else { lines.push(cur); cur = w; } } if (cur) lines.push(cur); if (lines.length > maxLines) { const keep = lines.slice(0, maxLines); keep[maxLines - 1] = trunc(keep[maxLines - 1] + ' ' + lines.slice(maxLines).join(' '), maxChars); return keep; } return lines.length ? lines : ['']; }

  function buildEdges() {
    const map = new Map();
    for (const rid in W.rooms) { const r = W.rooms[rid]; if (!isObj(r) || !isObj(r.exits)) continue;
      for (const dir in r.exits) { const ex = r.exits[dir]; const to = typeof ex === 'string' ? ex : (isObj(ex) ? ex.to : null); if (!to) continue;
        const locked = isObj(ex) && !!(ex.requires || ex.requires_flag || ex.use_item); const hidden = isObj(ex) && !!ex.hidden; const broken = !W.rooms[to];
        const k = rid < to ? rid + '|' + to : to + '|' + rid; let e = map.get(k); if (!e) { e = { a: rid < to ? rid : to, b: rid < to ? to : rid, ab: [], ba: [], locked: false, hidden: false, broken: false }; map.set(k, e); }
        (rid === e.a ? e.ab : e.ba).push(dir); e.locked = e.locked || locked; e.hidden = e.hidden || hidden; e.broken = e.broken || broken; if (broken) e.brokenTo = to; }
    }
    return Array.from(map.values());
  }
  function outlineShape(c, w, h, outline) {
    const x = c.x - w / 2, y = c.y - h / 2;
    if (outline === 'hexagon') { const k = Math.min(18, w / 4); return sv('polygon', { class: 'box', points: [[x + k, y], [x + w - k, y], [x + w, y + h / 2], [x + w - k, y + h], [x + k, y + h], [x, y + h / 2]].map(p => p.join(',')).join(' ') }); }
    return sv('rect', { class: 'box', x, y, width: w, height: h, rx: outline === 'rounded' ? 14 : outline === 'pill' ? h / 2 : 4 });
  }

  function renderMap(fit) {
    if (!W) return;
    if (Object.keys(W.rooms).some(id => !layout[id])) autoLayout(false);
    viewport.innerHTML = '';
    viewport.setAttribute('transform', 'translate(' + view.x + ',' + view.y + ') scale(' + view.k + ')');
    const gD = sv('g', { class: 'decor-layer' }), gE = sv('g', { class: 'edges' }), gN = sv('g', { class: 'nodes' }); viewport.append(gD, gE, gN);
    for (const d of decorList()) {
      const cx = d.x * STEP_X, cy = d.y * STEP_Y, w = d.w > 0 ? d.w : 72, h = d.h > 0 ? d.h : 72, r = d.r || 0; const isSel = sel && sel.type === 'decor' && sel.id === d.id;
      const g = sv('g', { class: 'decor' + (isSel ? ' selected' : ''), transform: 'translate(' + cx + ',' + cy + ') rotate(' + r + ')', 'data-id': d.id });
      g.append(sv('rect', { class: 'hit', x: -w / 2, y: -h / 2, width: w, height: h }));
      if (d.shape === 'label') g.append(sv('text', { class: 'decor-label', 'text-anchor': 'middle', y: h * 0.3, style: 'font-size:' + Math.max(12, Math.round(h * 0.75)) + 'px' }, d.label || 'Label'));
      else { g.append(sv('use', { href: '#sym-' + (SYMBOLS[d.shape] ? d.shape : 'house'), x: -w / 2, y: -h / 2, width: w, height: h })); if (d.label) g.append(sv('text', { class: 'decor-label', 'text-anchor': 'middle', y: h / 2 + 15 }, d.label)); }
      if (isSel) { g.append(sv('rect', { class: 'selbox', x: -w / 2 - 4, y: -h / 2 - 4, width: w + 8, height: h + 8 }), sv('line', { class: 'rotline', x1: 0, y1: -h / 2 - 4, x2: 0, y2: -h / 2 - 20 }), sv('circle', { class: 'handle rotate', cx: 0, cy: -h / 2 - 25, r: 6, 'data-mode': 'rotate', 'data-id': d.id }), sv('rect', { class: 'handle resize', x: w / 2 - 1, y: h / 2 - 1, width: 10, height: 10, 'data-mode': 'resize-decor', 'data-id': d.id })); }
      gD.append(g);
    }
    for (const e of buildEdges()) {
      const A = nodePx(e.a), SA = nodeSize(e.a); const g = sv('g', { class: 'edge' + (e.locked ? ' locked' : '') + (e.hidden ? ' hidden' : '') + (e.broken ? ' broken' : '') });
      const marker = e.broken ? 'url(#arrowBroken)' : e.locked ? 'url(#arrowLocked)' : 'url(#arrow)';
      if (e.a === e.b) { const top = A.y - SA.h / 2; g.append(sv('path', { d: 'M' + (A.x + 30) + ',' + top + ' C' + (A.x + 60) + ',' + (top - 50) + ' ' + (A.x - 60) + ',' + (top - 50) + ' ' + (A.x - 30) + ',' + top, 'marker-end': marker }), sv('text', { x: A.x, y: top - 40, 'text-anchor': 'middle' }, e.ab.map(d => DIR_ABBR[d] || d).join('/'))); gE.append(g); continue; }
      const B = e.broken ? { x: A.x + 170, y: A.y + 90 } : nodePx(e.b); const SB = e.broken ? { w: 0, h: 0 } : nodeSize(e.b);
      const p1 = borderPoint(A, B.x, B.y, SA.w, SA.h); const p2 = e.broken ? B : borderPoint(B, A.x, A.y, SB.w, SB.h);
      g.append(sv('path', { d: 'M' + p1.x + ',' + p1.y + ' L' + p2.x + ',' + p2.y, 'marker-end': e.ab.length ? marker : null, 'marker-start': e.ba.length ? marker : null }));
      const len = Math.hypot(p2.x - p1.x, p2.y - p1.y) || 1; const ux = (p2.x - p1.x) / len, uy = (p2.y - p1.y) / len; const nx = -uy * 9, ny = ux * 9;
      const lab = (dirs, px, py) => { if (!dirs.length) return; g.append(sv('text', { x: px + nx, y: py + ny + 3, 'text-anchor': 'middle' }, dirs.map(d => DIR_ABBR[d] || d).join('/'))); };
      lab(e.ab, p1.x + ux * 22, p1.y + uy * 22); lab(e.ba, p2.x - ux * 22, p2.y - uy * 22);
      if (e.locked || e.hidden) g.append(sv('text', { class: 'glyph', x: (p1.x + p2.x) / 2 - nx * 1.4, y: (p1.y + p2.y) / 2 - ny * 1.4 + 4, 'text-anchor': 'middle' }, e.locked ? '⚿' : '?'));
      if (e.broken) g.append(sv('text', { x: B.x + 6, y: B.y + 4, style: 'fill: var(--err)' }, 'missing: ' + e.brokenTo));
      gE.append(g);
    }
    const start = W.meta.starting_room;
    for (const id in W.rooms) {
      const r = W.rooms[id]; if (!isObj(r)) continue; const c = nodePx(id); const { w, h } = nodeSize(id); const l = layout[id] || {}; const left = c.x - w / 2, top = c.y - h / 2;
      const probs = worstLevel(problemsFor('room', id)); const unreach = W.rooms[start] && !reachable.has(id); const isSel = sel && sel.type === 'room' && sel.id === id;
      const g = sv('g', { class: 'node' + (isSel ? ' selected' : '') + (id === start ? ' start' : '') + (unreach ? ' unreachable' : '') + (connectSrc === id ? ' connect-src' : ''), 'data-id': id });
      g.append(outlineShape(c, w, h, l.outline));
      const pad = l.outline === 'hexagon' ? 16 : l.outline === 'pill' ? 18 : 10; const glyphW = l.glyph ? 24 : 0;
      const maxChars = Math.max(5, Math.floor((w - pad * 2 - glyphW) / 7.3)); const maxLines = Math.max(1, Math.floor((h - 26) / 14));
      const lines = wrapWords(r.name || id, maxChars, maxLines);
      const title = sv('text', { class: 'title', x: left + pad, y: top + 17 }); lines.forEach((ln, i) => title.append(sv('tspan', { x: left + pad, dy: i ? 14 : 0 }, ln))); g.append(title);
      const counts = []; const ni = (r.items || []).length, nn = (r.npcs || []).length, nc = (r.creatures || []).length; const nx2 = Object.keys(r.exits || {}).length;
      if (ni) counts.push(ni + ' item' + (ni > 1 ? 's' : '')); if (nn) counts.push(nn + ' npc' + (nn > 1 ? 's' : '')); if (nc) counts.push(nc + ' creature' + (nc > 1 ? 's' : '')); if (!counts.length) counts.push(nx2 ? 'empty' : 'dead end');
      g.append(sv('text', { class: 'sub', x: left + pad, y: top + h - 9 }, trunc(counts.join(' · '), Math.max(8, Math.floor((w - pad * 2) / 6.3)))));
      if (l.glyph) g.append(sv('use', { class: 'glyph', href: '#sym-' + l.glyph, x: left + w - pad - 18, y: top + 6, width: 18, height: 18 }));
      if (id === start) g.append(sv('text', { class: 'startlbl', x: left + 2, y: top - 5 }, '▶ START'));
      if (probs) g.append(sv('circle', { class: probs === 'error' ? 'errmark' : 'warnmark', cx: left + w - 8 - (l.glyph ? 22 : 0), cy: top + 8, r: 4 }));
      if (isSel) g.append(sv('rect', { class: 'handle resize', x: left + w - 5, y: top + h - 5, width: 10, height: 10, 'data-mode': 'resize-room', 'data-id': id }));
      const t = sv('title'); t.textContent = (r.name || id) + '  [' + id + ']' + (unreach ? '\nUnreachable from the starting room' : ''); g.append(t);
      gN.append(g);
    }
    if (fit) fitMap();
  }

  function fitMap() {
    const ids = Object.keys(W.rooms); const dec = decorList(); if (!ids.length && !dec.length) return;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const id of ids) { const c = nodePx(id), s = nodeSize(id); x0 = Math.min(x0, c.x - s.w / 2); y0 = Math.min(y0, c.y - s.h / 2 - 20); x1 = Math.max(x1, c.x + s.w / 2); y1 = Math.max(y1, c.y + s.h / 2); }
    for (const d of dec) { const cx = d.x * STEP_X, cy = d.y * STEP_Y, hw = (d.w || 72) / 2, hh = (d.h || 72) / 2; x0 = Math.min(x0, cx - hw); y0 = Math.min(y0, cy - hh); x1 = Math.max(x1, cx + hw); y1 = Math.max(y1, cy + hh); }
    const bw = mapWrap.clientWidth || 800, bh = mapWrap.clientHeight || 500; const pad = 40;
    const k = Math.min(1.4, Math.max(0.25, Math.min((bw - pad * 2) / (x1 - x0 || 1), (bh - pad * 2) / (y1 - y0 || 1))));
    view = { k, x: (bw - (x1 - x0) * k) / 2 - x0 * k, y: (bh - (y1 - y0) * k) / 2 - y0 * k };
    viewport.setAttribute('transform', 'translate(' + view.x + ',' + view.y + ') scale(' + view.k + ')');
  }
  function toWorld(px, py) { const b = svg.getBoundingClientRect(); return { x: (px - b.left - view.x) / view.k, y: (py - b.top - view.y) / view.k }; }

  /* pointer interaction: pan, drag, resize, rotate, click, connect */
  let drag = null;
  svg.addEventListener('pointerdown', ev => {
    if (ev.button !== 0 && ev.pointerType === 'mouse') return;
    hideConnectPop();
    const handle = ev.target.closest('.handle'), node = ev.target.closest('.node'), dec = ev.target.closest('.decor');
    const base = { sx: ev.clientX, sy: ev.clientY, moved: false, snap: JSON.stringify(W) };
    if (handle) { const mode = handle.dataset.mode, id = handle.dataset.id; drag = Object.assign(base, { mode, id, start: mode === 'resize-room' ? Object.assign({}, nodeSize(id)) : clone(decorById(id) || {}) }); }
    else if (node) drag = Object.assign(base, { mode: 'node', id: node.dataset.id, start: Object.assign({}, layout[node.dataset.id]) });
    else if (dec) drag = Object.assign(base, { mode: 'decor', id: dec.dataset.id, start: clone(decorById(dec.dataset.id) || {}) });
    else { drag = Object.assign(base, { mode: 'pan', ox: view.x, oy: view.y }); svg.classList.add('panning'); }
    svg.setPointerCapture(ev.pointerId);
  });
  svg.addEventListener('pointermove', ev => {
    if (!drag) return; const dx = ev.clientX - drag.sx, dy = ev.clientY - drag.sy;
    if (!drag.moved && Math.hypot(dx, dy) < 4) return; drag.moved = true;
    if (drag.mode === 'pan') { view.x = drag.ox + dx; view.y = drag.oy + dy; viewport.setAttribute('transform', 'translate(' + view.x + ',' + view.y + ') scale(' + view.k + ')'); return; }
    if (drag.mode === 'node') { layout[drag.id] = Object.assign({}, drag.start, { x: drag.start.x + dx / view.k / STEP_X, y: drag.start.y + dy / view.k / STEP_Y }); }
    else if (drag.mode === 'resize-room') { const l = layout[drag.id]; l.w = Math.max(110, Math.round((drag.start.w + dx / view.k) / 2) * 2); l.h = Math.max(44, Math.round((drag.start.h + dy / view.k) / 2) * 2); }
    else { const d = decorById(drag.id); if (!d) return;
      if (drag.mode === 'decor') { d.x = drag.start.x + dx / view.k / STEP_X; d.y = drag.start.y + dy / view.k / STEP_Y; }
      else if (drag.mode === 'resize-decor') { d.w = Math.max(16, Math.round((drag.start.w || 72) + dx / view.k)); d.h = Math.max(14, Math.round((drag.start.h || 72) + dy / view.k)); }
      else if (drag.mode === 'rotate') { const p = toWorld(ev.clientX, ev.clientY); const ang = Math.atan2(p.y - d.y * STEP_Y, p.x - d.x * STEP_X) * 180 / Math.PI + 90; d.r = ((Math.round(ang / 5) * 5) % 360 + 360) % 360; } }
    renderMap();
  });
  svg.addEventListener('pointerup', ev => {
    if (!drag) return; svg.classList.remove('panning'); const d = drag; drag = null;
    if (d.mode === 'pan') return;
    if (d.moved) {
      if (d.mode === 'node') { const p = layout[d.id]; p.x = Math.round(p.x * 2) / 2; p.y = Math.round(p.y * 2) / 2; }
      if (d.mode === 'decor') { const dd = decorById(d.id); if (dd) { dd.x = Math.round(dd.x * 4) / 4; dd.y = Math.round(dd.y * 4) / 4; } }
      pushUndo(d.snap); syncEditor(); save(); renderMap(); if (sel && sel.id === d.id && (sel.type === 'room' || sel.type === 'decor')) renderInspector(); if (tab === 'json') renderJson();
      return;
    }
    if (d.mode === 'node') { if (connectMode) connectClick(d.id, ev); else select('room', d.id); }
    else if (d.mode === 'decor') select('decor', d.id);
  });
  svg.addEventListener('pointercancel', () => { drag = null; svg.classList.remove('panning'); });
  svg.addEventListener('wheel', ev => { ev.preventDefault(); const f = Math.exp(-ev.deltaY * 0.0012); const k2 = Math.min(3, Math.max(0.2, view.k * f)); const b = svg.getBoundingClientRect(); const mx = ev.clientX - b.left, my = ev.clientY - b.top; view.x = mx - (mx - view.x) * (k2 / view.k); view.y = my - (my - view.y) * (k2 / view.k); view.k = k2; viewport.setAttribute('transform', 'translate(' + view.x + ',' + view.y + ') scale(' + view.k + ')'); }, { passive: false });
  svg.addEventListener('dblclick', ev => { if (ev.target.closest('.node') || ev.target.closest('.decor')) return; const p = toWorld(ev.clientX, ev.clientY); const id = createEntity('room', {}); layout[id] = { x: Math.round(p.x / STEP_X * 2) / 2, y: Math.round(p.y / STEP_Y * 2) / 2 }; syncEditor(); renderMap(); save(); });

  function setConnectMode(on) { connectMode = on; connectSrc = null; svg.classList.toggle('connect', on); $('#btnConnect').classList.toggle('active', on); $('#connectHint').hidden = !on; hideConnectPop(); renderMap(); }
  function inferDir(a, b) { const A = nodePx(a), B = nodePx(b); const ang = Math.atan2(B.y - A.y, B.x - A.x) * 180 / Math.PI; const list = [['east', 0], ['southeast', 45], ['south', 90], ['southwest', 135], ['west', 180], ['northwest', -135], ['north', -90], ['northeast', -45]]; let best = 'north', bd = 999; for (const [d, deg] of list) { const diff = Math.abs(((ang - deg + 540) % 360) - 180); if (diff < bd) { bd = diff; best = d; } } return best; }
  function connectClick(id, ev) {
    if (!connectSrc) { connectSrc = id; renderMap(); $('#connectHint').textContent = 'Now click the destination room for "' + entityName('room', id) + '". Esc cancels.'; return; }
    if (connectSrc === id) { toast('Pick a different room as the destination.'); return; }
    showConnectPop(connectSrc, id, ev.clientX, ev.clientY);
  }
  function showConnectPop(a, b, cx, cy) {
    const pop = $('#connectPop'); pop.innerHTML = ''; pop.hidden = false;
    const dir = inferDir(a, b); const used = new Set(Object.keys(W.rooms[a].exits || {}));
    let dirVal = dir;
    const dirPick = picker({ value: dir, options: DIRS.map(d => ({ value: d, label: d + (used.has(d) ? ' (taken)' : ''), sub: DIR_ABBR[d] })), none: false, allowCustom: true, onChange: v => { dirVal = v; } });
    const back = el('input', { type: 'checkbox', id: 'connectBack', checked: true });
    const backLbl = el('label', { class: 'check' }, back, el('span', {}, 'Also add the way back'));
    const row = el('div', { class: 'addrow' }, el('button', { class: 'btn primary sm', onclick: () => { if (used.has(dirVal)) { toast('"' + entityName('room', a) + '" already has a ' + dirVal + ' exit.'); return; } addExit(a, b, dirVal, back.checked); hideConnectPop(); setConnectMode(false); } }, 'Add exit'), el('button', { class: 'btn ghost sm', onclick: () => { hideConnectPop(); connectSrc = null; renderMap(); } }, 'Cancel'));
    pop.append(el('div', { class: 'lbl' }, entityName('room', a) + ' → ' + entityName('room', b)), el('div', { class: 'field' }, el('span', { class: 'lbl' }, 'Direction'), dirPick), backLbl, row);
    const wr = mapWrap.getBoundingClientRect(); pop.style.left = Math.min(cx - wr.left + 8, wr.width - 250) + 'px'; pop.style.top = Math.min(cy - wr.top + 8, wr.height - 200) + 'px';
  }
  function hideConnectPop() { closePicker(); $('#connectPop').hidden = true; }
  function addExit(a, b, dir, withBack) {
    pushUndo(); const ra = W.rooms[a]; ra.exits = isObj(ra.exits) ? ra.exits : {}; ra.exits[dir] = b;
    if (withBack) { const rb = W.rooms[b]; rb.exits = isObj(rb.exits) ? rb.exits : {}; const od = OPPOSITE[dir]; if (od && rb.exits[od] === undefined) rb.exits[od] = a; else if (od) toast('"' + entityName('room', b) + '" already has a ' + od + ' exit; only the forward exit was added.'); }
    select('room', a); commit({ inspector: true }); toast('Connected ' + entityName('room', a) + ' → ' + entityName('room', b) + ' (' + dir + ')');
  }
  $('#btnConnect').addEventListener('click', () => setConnectMode(!connectMode));
  $('#btnAutoLayout').addEventListener('click', () => { pushUndo(); autoLayout(true); syncEditor(); renderMap(true); save(); if (tab === 'json') renderJson(); toast('Laid out from the starting room by compass direction'); });
  $('#btnFit').addEventListener('click', () => fitMap());
  $('#btnAddRoom').addEventListener('click', () => { createEntity('room', {}); autoLayout(false); syncEditor(); renderMap(); save(); });
  document.addEventListener('keydown', ev => { if (ev.key === 'Escape' && connectMode) setConnectMode(false); });
  (function buildDecorMenu() {
    const menu = $('#decorMenu');
    const mk = (shape, label) => { const b = el('button', { onclick: () => { menu.classList.remove('open'); addDecor(shape); } }); if (shape !== 'label') { const ic = sv('svg', { viewBox: '0 0 24 24', class: 'mi' }); ic.append(sv('use', { href: '#sym-' + shape })); b.append(ic); } else b.append(el('span', { class: 'mi', style: 'font-family: var(--font-display); font-size: 16px; display: inline-block; width: 16px' }, 'Aa')); b.append(label); return b; };
    menu.append(mk('label', 'Text label')); for (const k of SYMBOL_LIST) menu.append(mk(k, k[0].toUpperCase() + k.slice(1)));
    $('#btnDecor').addEventListener('click', ev => { ev.stopPropagation(); menu.classList.toggle('open'); });
    document.addEventListener('click', ev => { if (!ev.target.closest('#decorMenu')) menu.classList.remove('open'); });
  })();

  /* ---------- Inspector: schema-aware forms ----------
     Fields write straight into the world object. Empty values delete the key so the JSON stays clean. */
  const insp = $('#inspector');

  /* ---------- Picker: in-house replacement for native selects and datalists ----------
     o: { id, value, options: [{value, label, sub, type, meta}], none (label or false), allowCustom, placeholder,
          type (dot colour), onCreate(query) -> new id, onChange(value), small } */
  const pickPop = el('div', { class: 'pickpop', hidden: true }); document.body.append(pickPop);
  let pickState = null;
  function closePicker() { if (!pickState) return; const b = pickState.btn; pickState = null; pickPop.hidden = true; pickPop.innerHTML = ''; if (b && document.contains(b)) b.focus({ preventScroll: true }); }
  function picker(o) {
    const btn = el('button', { type: 'button', class: 'pick', id: o.id || null, title: o.title || null });
    const dot = el('span', { class: 'dot' }); const val = el('span', { class: 'val' }); btn.append(dot, val, el('span', { class: 'caret' }, '▾'));
    const paint = () => { const v = o.value == null ? '' : o.value; const opt = o.options.find(x => x.value === v); const empty = !opt && v === ''; btn.classList.toggle('empty', empty); if (empty) { val.textContent = o.placeholder || o.none || '(none)'; dot.hidden = true; } else { val.textContent = opt ? opt.label : (o.allowCustom ? v : v + ' (unknown)'); const t = (opt && opt.type) || o.type; dot.hidden = !t; dot.className = 'dot' + (t ? ' bg-' + t : ''); } };
    paint();
    btn.addEventListener('click', () => { if (pickState && pickState.btn === btn) { closePicker(); return; } openPicker(btn, o, v => { o.value = v; paint(); }); });
    btn.addEventListener('keydown', ev => { if (ev.key === 'ArrowDown' || ev.key === ' ') { ev.preventDefault(); btn.click(); } });
    return btn;
  }
  function openPicker(btn, o, commitVal) {
    closePicker(); pickPop.innerHTML = ''; pickPop.hidden = false;
    const search = el('input', { class: 'in', placeholder: o.allowCustom ? 'Type a name or pick one' : (o.onCreate ? 'Search, or type a name to create' : 'Search'), spellcheck: 'false', 'aria-label': 'Search options' });
    const list = el('div', { class: 'list', role: 'listbox' }); pickPop.append(search, list);
    let hi = 0, rows = [];
    const choose = v => { closePicker(); commitVal(v); o.onChange(v); };
    const hilite = () => { rows.forEach((r, i) => r.classList.toggle('hi', i === hi)); const r = rows[hi]; if (r && r.scrollIntoView) r.scrollIntoView({ block: 'nearest' }); };
    const render = () => {
      const raw = search.value.trim(), q = raw.toLowerCase(); list.innerHTML = ''; rows = [];
      const add = (act, cls, kids) => { const e = el('div', { class: 'pickrow' + (cls ? ' ' + cls : ''), role: 'option' }, ...kids); e.act = act; e.addEventListener('click', act); e.addEventListener('mousemove', () => { const i = rows.indexOf(e); if (i >= 0 && hi !== i) { hi = i; hilite(); } }); rows.push(e); list.append(e); };
      if (o.allowCustom && q && !o.options.some(x => String(x.value).toLowerCase() === q)) add(() => choose(raw), 'action', ['Use "' + raw + '"']);
      if (o.none !== false && !q) add(() => choose(''), 'none', [o.none || '(none)']);
      const matches = o.options.filter(x => !q || x.label.toLowerCase().includes(q) || String(x.value).toLowerCase().includes(q) || (x.sub && x.sub.toLowerCase().includes(q)));
      for (const x of matches) add(() => choose(x.value), x.value === o.value ? 'current' : '', [x.type ? el('span', { class: 'dot bg-' + x.type }) : null, el('span', { class: 'lab' }, x.label), x.sub && x.sub !== x.label ? el('span', { class: 'sub' }, x.sub) : null, x.meta ? el('span', { class: 'meta' }, x.meta) : null]);
      if (!matches.length && !o.allowCustom && !o.onCreate) list.append(el('div', { class: 'pickrow dim' }, 'No matches'));
      if (o.onCreate && q) add(() => { closePicker(); const nv = o.onCreate(raw); if (nv) { commitVal(nv); o.onChange(nv); } }, 'action', ['+ Create ' + (o.type ? LABEL[o.type].toLowerCase() + ' ' : '') + '"' + raw + '"']);
      const cur = rows.findIndex(r => r.classList.contains('current')); hi = (!q && cur >= 0) ? cur : Math.min(hi, Math.max(0, rows.length - 1)); hilite();
    };
    search.addEventListener('input', () => { hi = 0; render(); });
    search.addEventListener('keydown', ev => { if (ev.key === 'ArrowDown') { ev.preventDefault(); hi = Math.min(rows.length - 1, hi + 1); hilite(); } else if (ev.key === 'ArrowUp') { ev.preventDefault(); hi = Math.max(0, hi - 1); hilite(); } else if (ev.key === 'Enter') { ev.preventDefault(); const r = rows[hi]; if (r) r.act(); } else if (ev.key === 'Escape') { ev.preventDefault(); closePicker(); } else if (ev.key === 'Tab') closePicker(); });
    render();
    const place = init => { const r = btn.getBoundingClientRect(), vw = window.innerWidth, vh = window.innerHeight; pickPop.style.cssText = ''; pickPop.classList.toggle('sheet', vw <= 600); if (vw <= 600) return; if (!init && (r.bottom < 0 || r.top > vh)) { closePicker(); return; } const w = Math.max(r.width, 280); pickPop.style.width = w + 'px'; pickPop.style.left = Math.max(8, Math.min(r.left, vw - w - 8)) + 'px'; const below = vh - r.bottom; if (below < 300 && r.top > below) { pickPop.style.bottom = (vh - r.top + 4) + 'px'; pickPop.style.maxHeight = (r.top - 12) + 'px'; } else { pickPop.style.top = (r.bottom + 4) + 'px'; pickPop.style.maxHeight = (below - 12) + 'px'; } };
    pickState = { btn, place: () => place(false) }; if (btn.scrollIntoView) btn.scrollIntoView({ block: 'nearest' }); place(true); search.focus();
  }
  document.addEventListener('pointerdown', ev => { if (pickState && !pickPop.contains(ev.target) && !pickState.btn.contains(ev.target)) closePicker(); }, true);
  window.addEventListener('resize', () => { if (pickState) pickState.place(); });
  insp.addEventListener('scroll', () => { if (pickState) pickState.place(); }, { passive: true });
  function setVal(obj, key, v) { if (v === '' || v == null || (Array.isArray(v) && !v.length)) delete obj[key]; else obj[key] = v; }
  function undoOnBlur(input) {
    input.addEventListener('focus', () => { focusSnap = JSON.stringify(W); });
    input.addEventListener('change', () => { if (focusSnap && focusSnap !== JSON.stringify(W)) pushUndo(focusSnap); focusSnap = null; });
  }
  function lbl(text, o) { o = o || {}; return el('span', { class: 'lbl' }, text, o.required ? el('span', { class: 'req', title: 'Required' }, '*') : null, o.key ? el('span', { class: 'key' }, o.key) : null); }
  function field(label, input, o) { o = o || {}; return el('div', { class: 'field' }, lbl(label, o), input, o.hint ? el('span', { class: 'hint' }, o.hint) : null); }

  function fText(obj, key, label, o) {
    o = o || {};
    const input = o.textarea ? el('textarea', { class: 'in', id: 'f_' + key + '_' + (o.uid || ''), rows: o.rows || 3, placeholder: o.placeholder || '' }) : el('input', { class: 'in', id: 'f_' + key + '_' + (o.uid || ''), placeholder: o.placeholder || '', spellcheck: o.spell === false ? 'false' : null });
    input.value = obj[key] == null ? '' : obj[key];
    input.addEventListener('input', () => { setVal(obj, key, input.value); if (o.onInput) o.onInput(input.value); lightCommit(); });
    undoOnBlur(input);
    return field(label, input, Object.assign({ key: o.showKey === false ? null : key }, o));
  }
  function fNum(obj, key, label, o) {
    o = o || {};
    const input = el('input', { class: 'in', type: 'number', id: 'f_' + key + '_' + (o.uid || ''), min: o.min, max: o.max, step: o.step || 1, placeholder: o.placeholder || (o.def != null ? 'default ' + o.def : '') });
    input.value = obj[key] == null ? '' : obj[key];
    input.addEventListener('input', () => { const v = input.value === '' ? '' : Number(input.value); setVal(obj, key, Number.isNaN(v) ? '' : v); if (o.onInput) o.onInput(v); lightCommit(); });
    undoOnBlur(input);
    return field(label, input, Object.assign({ key }, o));
  }
  function fBool(obj, key, label, o) {
    o = o || {}; const def = !!o.def;
    const cb = el('input', { type: 'checkbox', id: 'f_' + key + '_' + (o.uid || '') }); cb.checked = obj[key] == null ? def : !!obj[key];
    cb.addEventListener('change', () => { const snap = JSON.stringify(W); if (cb.checked === def && !o.explicit) delete obj[key]; else obj[key] = cb.checked; pushUndo(snap); if (o.onChange) o.onChange(cb.checked); commit({ inspector: !!o.rerender }); });
    const w = el('label', { class: 'check' }, cb, el('span', {}, label), o.key !== false ? el('span', { class: 'key hint' }, key) : null);
    return o.hint ? el('div', { class: 'field' }, w, el('span', { class: 'hint' }, o.hint)) : w;
  }
  function fSelect(obj, key, label, options, o) {
    o = o || {};
    const opts = options.map(x => Array.isArray(x) ? { value: x[0], label: x[1] } : (typeof x === 'string' ? { value: x, label: x } : x));
    const p = picker({ id: 'f_' + key + '_' + (o.uid || ''), value: obj[key] == null ? '' : String(obj[key]), options: opts, none: o.allowNone === false ? false : (o.noneLabel || '(none)'), type: o.type, allowCustom: o.allowCustom, onCreate: o.onCreate, placeholder: o.placeholder,
      onChange: v => { const snap = JSON.stringify(W); setVal(obj, key, v); pushUndo(snap); if (o.onChange) o.onChange(v); commit({ inspector: !!o.rerender }); } });
    return field(label, p, Object.assign({ key }, o));
  }
  function refOptions(kind, exclude) { const coll = W[PLURAL[kind]]; return Object.keys(coll).filter(id => id !== exclude).sort((a, b) => entityName(kind, a).localeCompare(entityName(kind, b))).map(id => ({ value: id, label: entityName(kind, id), sub: id, type: kind })); }
  function fRef(obj, key, kind, label, o) { o = o || {}; return fSelect(obj, key, label, refOptions(kind, o.exclude), Object.assign({ type: kind, noneLabel: o.noneLabel || '(none)', onCreate: o.create === false ? null : (q => { pushUndo(); return quickCreate(kind, q); }) }, o)); }
  function fFlag(obj, key, label, o) {
    o = o || {};
    const status = el('span', { class: 'hint' });
    const upd = () => { const f = obj[key]; if (!f) { status.textContent = o.mode === 'set' ? 'Sets a global flag to true.' : 'Requires a global flag to be true.'; status.style.color = ''; return; } const fi = flagIndex[f]; const sN = fi ? fi.set.length : 0, c = fi ? fi.check.length : 0; status.textContent = 'Set in ' + sN + ' place' + (sN === 1 ? '' : 's') + ', checked in ' + c + '.' + (o.mode !== 'set' && !sN ? ' Nothing sets this yet.' : ''); status.style.color = (o.mode !== 'set' && !sN) ? 'var(--warn)' : ''; };
    const opts = Object.keys(flagIndex).sort().map(f => ({ value: f, label: f, type: 'flag', meta: 'set ' + flagIndex[f].set.length + ' · checked ' + flagIndex[f].check.length }));
    const p = picker({ id: 'f_' + key + '_' + (o.uid || ''), value: obj[key] || '', options: opts, none: '(none)', allowCustom: true, type: 'flag', placeholder: 'flag_name', onChange: v => { const snap = JSON.stringify(W); setVal(obj, key, v.trim()); pushUndo(snap); commit({}); upd(); } });
    upd();
    return el('div', { class: 'field' }, lbl(label, { key }), p, status);
  }
  function fTags(obj, key, label, o) {
    o = o || {};
    const input = el('input', { class: 'in', id: 'f_' + key + '_' + (o.uid || ''), placeholder: o.placeholder || 'comma, separated, words', spellcheck: 'false' }); input.value = Array.isArray(obj[key]) ? obj[key].join(', ') : '';
    input.addEventListener('input', () => { setVal(obj, key, input.value.split(',').map(s => s.trim()).filter(Boolean)); lightCommit(); });
    undoOnBlur(input);
    return field(label, input, Object.assign({ key }, o));
  }
  function idList(obj, key, kind, label, o) {
    o = o || {}; const wrap = el('div', { class: 'field' });
    const chips = el('div', { class: 'chips' }); const arr = Array.isArray(obj[key]) ? obj[key] : [];
    arr.forEach((id, i) => { const missing = !W[PLURAL[kind]][id]; chips.append(el('span', { class: 'chip link', style: missing ? 'border-color: var(--err)' : '' }, el('span', { class: 'dot bg-' + kind }), el('span', { onclick: () => { if (!missing) select(kind, id); } }, missing ? id + ' (missing)' : entityName(kind, id)), el('span', { class: 'x', title: 'Remove', onclick: () => { pushUndo(); obj[key].splice(i, 1); if (!obj[key].length && o.keepEmpty !== true) delete obj[key]; commit({ inspector: true }); } }, '×'))); });
    const add = picker({ value: '', options: refOptions(kind, o.exclude).filter(x => !arr.includes(x.value)), none: false, type: kind, placeholder: 'Add ' + LABEL[kind].toLowerCase() + '...', onCreate: o.create ? (q => { pushUndo(); return quickCreate(kind, q); }) : null,
      onChange: v => { if (!v) return; if (!o.create) pushUndo(); (obj[key] = Array.isArray(obj[key]) ? obj[key] : []).push(v); commit({ inspector: true }); } });
    wrap.append(lbl(label, { key: o.key === false ? null : key }), chips.childElementCount ? chips : el('span', { class: 'hint' }, o.empty || 'Nothing yet.'), el('div', { class: 'addrow' }, add), o.hint ? el('span', { class: 'hint' }, o.hint) : '');
    return wrap;
  }
  /* A feature block: switch on to add a sub-object with defaults, off to remove it. */
  function block(title, isOn, onOn, onOff, buildBody, o) {
    o = o || {}; const b = el('div', { class: 'block' + (isOn ? '' : ' off') });
    const sw = el('span', { class: 'sw' + (isOn ? ' on' : ''), role: 'switch', 'aria-checked': isOn ? 'true' : 'false' });
    const head = el('div', { class: 'block-head', onclick: () => { pushUndo(); if (isOn) onOff(); else onOn(); commit({ inspector: true }); } }, lbl(title, { key: o.key }), o.hint ? el('span', { class: 'hint' }, o.hint) : null, sw);
    b.append(head); if (isOn) { const body = el('div', { class: 'block-body' }); buildBody(body); b.append(body); }
    return b;
  }
  function secTitle(text, ...extra) { return el('div', { class: 'sec-title' }, text, ...extra); }
  function idEditor(type, id) {
    const input = el('input', { class: 'in', id: 'f_id', value: id, spellcheck: 'false', style: 'max-width: 260px' });
    input.addEventListener('change', () => { const nid = renameEntity(type, id, input.value); if (nid !== input.value) input.value = nid; });
    input.addEventListener('keydown', ev => { if (ev.key === 'Enter') input.blur(); });
    return el('div', { class: 'field' }, lbl('ID', { key: 'key in ' + PLURAL[type] }), input, el('span', { class: 'hint' }, 'lowercase_with_underscores. Renaming updates every reference in the world.'));
  }
  function problemList(type, id) {
    const ps = problemsFor(type, id); if (!ps.length) return document.createDocumentFragment();
    return el('div', { class: 'card', style: 'gap: 4px' }, ps.map(p => el('div', { style: 'display:flex; gap:8px; font-size:12px' }, el('span', { class: 'lvl ' + p.level, style: 'font-family: var(--font-display); font-size: 14px; text-transform: uppercase; color: ' + (p.level === 'error' ? 'var(--err)' : p.level === 'warn' ? 'var(--warn)' : 'var(--c-room)') }, p.level === 'warn' ? 'warn' : p.level), el('span', {}, p.msg))));
  }
  function dangerZone(type, id) {
    const zone = el('div', { class: 'danger-zone' });
    const del = el('button', { class: 'btn danger sm', onclick: () => { zone.innerHTML = ''; zone.append(el('span', { class: 'confirm' }, 'Delete "' + entityName(type, id) + '" and remove every reference to it?', el('button', { class: 'btn danger sm', onclick: () => deleteEntity(type, id) }, 'Yes, delete'), el('button', { class: 'btn ghost sm', onclick: () => renderInspector() }, 'Keep'))); } }, 'Delete');
    zone.append(el('button', { class: 'btn ghost sm', onclick: () => duplicateEntity(type, id) }, 'Duplicate'), del);
    return zone;
  }
  function titleRow(type, name) { return el('div', { class: 'insp-title' }, el('span', { class: 'kind t-' + type }, LABEL[type]), el('h2', {}, name || '(unnamed)')); }
  /* Where an entity is placed, with a remove control on each placement, plus a picker to place it
     somewhere new. Items can go into rooms or containers; NPCs and creatures only into rooms. */
  function appearsIn(kind, id) {
    const rs = refs.filter(r => r.kind === kind && r.id === id && r.mode === 'place');
    const box = el('div', { class: 'where' });
    if (!rs.length) box.append(el('span', { class: 'none' }, kind === 'item' ? 'Nowhere yet. Place it in a room, a container, a loot list, or have an NPC give it.' : 'Not in any room yet.'));
    for (const r of rs) box.append(el('span', {}, r.label + ' ', el('span', { class: 'chip link' },
      el('span', { class: 'dot bg-' + r.owner.type }),
      el('span', { onclick: () => select(r.owner.type, r.owner.id) }, entityName(r.owner.type, r.owner.id)),
      el('span', { class: 'x', title: 'Remove from here', onclick: () => { pushUndo(); r.remove(); commit({ inspector: true }); toast('Removed from ' + entityName(r.owner.type, r.owner.id)); } }, '\u00d7'))));
    const options = refOptions('room').map(x => Object.assign({}, x, { value: 'room:' + x.value }));
    if (kind === 'item') {
      const containers = Object.keys(W.items).filter(cid => cid !== id && isObj(W.items[cid]) && W.items[cid].is_container).sort((a, b) => entityName('item', a).localeCompare(entityName('item', b)));
      for (const cid of containers) options.push({ value: 'item:' + cid, label: entityName('item', cid), sub: cid, type: 'item', meta: 'container' });
    }
    const p = picker({ value: '', options, none: false, placeholder: kind === 'item' ? 'Place in room or container...' : 'Place in room...', onChange: v => {
      if (!v) return; const sep = v.indexOf(':'); const t = v.slice(0, sep), tid = v.slice(sep + 1);
      pushUndo();
      if (t === 'room') { const r = W.rooms[tid]; const k = PLURAL[kind]; r[k] = Array.isArray(r[k]) ? r[k] : []; if (!r[k].includes(id)) r[k].push(id); }
      else { const c = W.items[tid]; c.contents = Array.isArray(c.contents) ? c.contents : []; if (!c.contents.includes(id)) c.contents.push(id); }
      commit({ inspector: true }); toast('Placed in ' + entityName(t, tid));
    } });
    return el('div', { class: 'field' }, lbl('Appears in'), box, el('div', { class: 'addrow' }, p));
  }

  /* ---------- Room ---------- */
  function exitObj(room, dir) { const ex = room.exits[dir]; if (isObj(ex)) return ex; room.exits[dir] = { to: typeof ex === 'string' ? ex : '' }; return room.exits[dir]; }
  function normalizeExit(room, dir) { const ex = room.exits[dir]; if (isObj(ex) && Object.keys(ex).length === 1 && typeof ex.to === 'string') room.exits[dir] = ex.to; }
  function renameExitDir(room, oldDir, newDir) { newDir = String(newDir || '').trim().toLowerCase(); if (!newDir || newDir === oldDir) return; if (room.exits[newDir] !== undefined) { toast('This room already has a ' + newDir + ' exit.'); renderInspector(); return; } pushUndo(); const rebuilt = {}; for (const k in room.exits) rebuilt[k === oldDir ? newDir : k] = room.exits[k]; room.exits = rebuilt; commit({ inspector: true }); }
  function normalizeExits(w) { w = w || W; for (const rid in w.rooms) { const r = w.rooms[rid]; if (!isObj(r) || !isObj(r.exits)) continue; for (const d in r.exits) normalizeExit(r, d); } }
  function exitCard(rid, room, dir) {
    const ex = room.exits[dir]; const obj = isObj(ex) ? ex : { to: ex }; const complex = isObj(ex) && Object.keys(ex).some(k => k !== 'to');
    const card = el('div', { class: 'card' + (complex ? '' : ' compact') });
    const dirIn = picker({ value: dir, options: DIRS.map(d => ({ value: d, label: d, sub: DIR_ABBR[d] })), none: false, allowCustom: true, placeholder: 'direction', title: 'Direction', onChange: v => renameExitDir(room, dir, v) });
    dirIn.style.width = '128px'; dirIn.style.flex = 'none';
    const to = picker({ value: obj.to || '', options: refOptions('room'), none: false, type: 'room', placeholder: '(choose room)', title: 'Destination', onCreate: q => { pushUndo(); return quickCreate('room', q); }, onChange: v => { pushUndo(); if (isObj(room.exits[dir])) room.exits[dir].to = v; else room.exits[dir] = v; normalizeExit(room, dir); commit({ inspector: true }); } });
    to.style.flex = '1';
    let built = complex;
    const adv = el('button', { class: 'btn ghost sm', title: 'Locks, keywords, hidden', onclick: () => { if (!built) { exitObj(room, dir); buildAdv(); built = true; } card.classList.toggle('compact'); } }, complex ? 'Options \u25BE' : 'Options');
    const del = el('button', { class: 'btn ghost sm', title: 'Remove exit', onclick: () => { pushUndo(); delete room.exits[dir]; commit({ inspector: true }); } }, '\u00d7');
    card.append(el('div', { class: 'card-head' }, dirIn, el('span', { class: 'hint' }, '\u2192'), to, adv, del));
    const summary = []; if (obj.requires) summary.push('needs ' + entityName('item', obj.requires)); if (obj.requires_flag) summary.push('needs flag ' + obj.requires_flag); if (obj.use_item) summary.push('unlock with ' + entityName('item', obj.use_item)); if (obj.hidden) summary.push('hidden'); if (Array.isArray(obj.keywords) && obj.keywords.length) summary.push('"' + obj.keywords[0] + '"');
    if (summary.length) card.append(el('div', { class: 'hint' }, summary.join(' \u00b7 ')));
    const a = el('div', { class: 'adv', style: 'display:flex; flex-direction:column; gap:10px' }); card.append(a);
    const uid = rid + '_' + dir;
    function buildAdv() {
      const t = exitObj(room, dir); a.innerHTML = '';
      a.append(fTags(t, 'keywords', 'Keywords', { uid, hint: 'Names players can use instead of the direction: "use key on gate", "go drawbridge".', placeholder: 'door, iron door' }));
      const lockType = t.use_item !== undefined ? 'use_item' : t.requires !== undefined ? 'requires' : t.requires_flag !== undefined ? 'requires_flag' : '';
      const lockSel = picker({ value: lockType, none: false, options: [{ value: '', label: 'Open passage' }, { value: 'requires', label: 'Needs an item in inventory (passive)' }, { value: 'requires_flag', label: 'Needs a global flag (gate)' }, { value: 'use_item', label: 'Unlock by using an item on it' }],
        onChange: v => { pushUndo(); delete t.requires; delete t.requires_flag; delete t.use_item; delete t.on_unlock; delete t.permanently_unlock; delete t.consume_item; if (v === 'requires') t.requires = ''; if (v === 'requires_flag') t.requires_flag = ''; if (v === 'use_item') { t.use_item = ''; t.permanently_unlock = true; } commit({ inspector: true }); } });
      a.append(field('Lock', lockSel, { hint: lockType === 'requires_flag' ? 'When the flag becomes true the exit opens (and reveals itself if hidden).' : lockType === 'use_item' ? 'Player types "use <item> on <keyword or direction>".' : lockType === 'requires' ? 'The player just needs to be carrying the item.' : '' }));
      if (lockType === 'requires') a.append(fRef(t, 'requires', 'item', 'Required item', { uid, keepKey: true }));
      if (lockType === 'requires_flag') a.append(fFlag(t, 'requires_flag', 'Required flag', { uid, mode: 'check' }));
      if (lockType === 'use_item') a.append(fRef(t, 'use_item', 'item', 'Key item', { uid }), fText(t, 'on_unlock', 'Unlock message', { uid, placeholder: 'The key turns with a satisfying click.' }), el('div', { class: 'grid2' }, fBool(t, 'permanently_unlock', 'Stays unlocked', { uid, hint: 'Otherwise the player needs the item every time.' }), fBool(t, 'consume_item', 'Consumes the item', { uid })));
      if (lockType) a.append(fText(t, 'locked_msg', 'Locked message', { uid, placeholder: 'The door is locked tight.' }), fText(t, 'unlocked_msg', 'Unlocked message', { uid, placeholder: 'Shown when the exit is usable.' }));
      a.append(fBool(t, 'hidden', 'Hidden until revealed', { uid, rerender: true, hint: 'Reveal it with an item\u2019s on_examine / reveals_exit, or with requires_flag.' }));
      if (t.hidden) a.append(fText(t, 'reveal_msg', 'Reveal message', { uid, placeholder: 'A section of wall slides away!' }));
      a.append(fFlag(t, 'sets_flag', 'Sets flag when used', { uid, mode: 'set' }));
    }
    if (complex) buildAdv();
    return card;
  }
  function renderRoom(id) {
    const r = W.rooms[id]; const body = el('div', { class: 'insp-body' });
    body.append(titleRow('room', r.name), problemList('room', id), idEditor('room', id));
    const startCb = el('input', { type: 'checkbox', id: 'f_start' }); startCb.checked = W.meta.starting_room === id; startCb.disabled = startCb.checked;
    startCb.addEventListener('change', () => { pushUndo(); W.meta.starting_room = id; commit({ inspector: true }); toast('"' + (r.name || id) + '" is now the starting room'); });
    body.append(el('label', { class: 'check' }, startCb, el('span', {}, 'Player starts here'), el('span', { class: 'key hint' }, 'meta.starting_room')));
    body.append(fText(r, 'name', 'Name', { required: true, uid: id }), fText(r, 'description', 'Description', { required: true, textarea: true, rows: 5, uid: id, hint: 'Second person, present tense. Mention the things players can interact with.' }));
    body.append(block('First-visit message', isObj(r.on_enter), () => { r.on_enter = { type: 'message', text: '' }; }, () => { delete r.on_enter; }, b => { b.append(fText(r.on_enter, 'text', 'Text', { textarea: true, uid: id, hint: 'Fires once, the first time the player enters.' })); }, { key: 'on_enter' }));
    const exits = el('div', { style: 'display:flex; flex-direction:column; gap:8px' });
    for (const d in r.exits || {}) exits.append(exitCard(id, r, d));
    const addExitBtn = el('button', { class: 'btn sm', onclick: () => { pushUndo(); r.exits = isObj(r.exits) ? r.exits : {}; const free = DIRS.find(d => r.exits[d] === undefined) || 'exit_' + Object.keys(r.exits).length; r.exits[free] = ''; commit({ inspector: true }); } }, '+ Exit');
    body.append(secTitle('Exits', el('span', { class: 'badge' }, Object.keys(r.exits || {}).length), addExitBtn), exits.childElementCount ? exits : el('span', { class: 'hint' }, 'A dead end. Add an exit, or use Connect rooms on the map.'));
    body.append(secTitle('Contents'), idList(r, 'items', 'item', 'Items here', { create: true }), idList(r, 'npcs', 'npc', 'Characters here', { create: true }), idList(r, 'creatures', 'creature', 'Creatures here', { create: true }));
    const l = layout[id] || {}; const sz = nodeSize(id);
    body.append(secTitle('On the map'), el('div', { class: 'grid2' },
      field('Glyph', picker({ value: l.glyph || '', options: SYMBOL_LIST.map(k => ({ value: k, label: k[0].toUpperCase() + k.slice(1) })), none: '(none)', onChange: v => setLayout(id, { glyph: v || undefined }) }), { key: 'meta.editor' }),
      field('Outline', picker({ value: l.outline || 'box', options: OUTLINES.map(k => ({ value: k, label: k[0].toUpperCase() + k.slice(1) })), none: false, onChange: v => setLayout(id, { outline: v === 'box' ? undefined : v }) }), { key: 'meta.editor' })),
      el('div', { class: 'stat-preview' }, 'Box ', el('b', {}, sz.w + ' × ' + sz.h + ' px'), ' at grid ' + (l.x != null ? l.x : 0) + ', ' + (l.y != null ? l.y : 0) + '. Drag the corner handle on the map to resize. ', (l.w || l.h) ? el('button', { class: 'btn ghost sm', onclick: () => setLayout(id, { w: undefined, h: undefined }) }, 'Reset size') : null),
      el('span', { class: 'hint' }, 'Visual only. Saved under meta.editor, ignored by the engine, and rebuilt by Auto layout if missing.'));
    body.append(dangerZone('room', id));
    return body;
  }

  /* ---------- Meta ---------- */
  function renderMeta() {
    const m = W.meta; const body = el('div', { class: 'insp-body' });
    body.append(el('div', { class: 'insp-title' }, el('span', { class: 'kind t-meta' }, 'World'), el('h2', {}, m.name || 'Untitled')), problemList('meta', 'meta'));
    body.append(fText(m, 'name', 'Name', { required: true, uid: 'meta', onInput: v => { $('#worldName').value = v; } }), fText(m, 'description', 'Description', { required: true, textarea: true, uid: 'meta', hint: 'The premise, shown to players before they begin.' }));
    body.append(fRef(m, 'starting_room', 'room', 'Starting room', { required: true, uid: 'meta', allowNone: false }), el('div', { class: 'grid2' }, fText(m, 'version', 'Version', { uid: 'meta', placeholder: '1.0' }), fText(m, 'author', 'Author', { uid: 'meta' })));
    const counts = el('dl', { class: 'dl' });
    for (const t of TYPES) counts.append(el('dt', {}, PLURAL[t]), el('dd', {}, String(Object.keys(W[PLURAL[t]]).length)));
    counts.append(el('dt', {}, 'flags'), el('dd', {}, String(Object.keys(flagIndex).length)), el('dt', {}, 'reachable rooms'), el('dd', {}, reachable.size + ' of ' + Object.keys(W.rooms).length));
    body.append(secTitle('At a glance'), counts);
    return body;
  }

  /* ---------- Flag ---------- */
  function renderFlag(f) {
    const fi = flagIndex[f] || { set: [], check: [] }; const body = el('div', { class: 'insp-body' });
    body.append(el('div', { class: 'insp-title' }, el('span', { class: 'kind t-flag' }, 'Flag'), el('h2', {}, f)), problemList('flag', f));
    const input = el('input', { class: 'in', id: 'f_flagname', value: f, spellcheck: 'false' }); input.addEventListener('change', () => renameFlag(f, input.value)); input.addEventListener('keydown', ev => { if (ev.key === 'Enter') input.blur(); });
    body.append(el('div', { class: 'field' }, lbl('Name'), input, el('span', { class: 'hint' }, 'Renaming rewrites every place that sets or checks it.')));
    const list = (title, rs, empty) => { const w = el('div', { class: 'where' }); if (!rs.length) w.append(el('span', { class: 'none' }, empty)); for (const r of rs) w.append(el('span', {}, r.label + ' · ', el('span', { class: 'chip link', onclick: () => select(r.owner.type, r.owner.id) }, el('span', { class: 'dot bg-' + r.owner.type }), entityName(r.owner.type, r.owner.id)))); return el('div', { class: 'field' }, lbl(title), w); };
    body.append(list('Set to true by', fi.set, 'Nothing sets this flag. Every gate on it stays closed forever.'), list('Checked by', fi.check, 'Nothing checks this flag. Setting it has no effect yet.'));
    return body;
  }

  /* ---------- Item ---------- */
  function hiddenExitDirs() { const s = new Set(); for (const rid in W.rooms) { const r = W.rooms[rid]; if (!isObj(r) || !isObj(r.exits)) continue; for (const d in r.exits) if (isObj(r.exits[d]) && r.exits[d].hidden) s.add(d); } return Array.from(s); }
  function allTopics() { const out = []; for (const nid in W.npcs) { const n = W.npcs[nid]; if (isObj(n) && isObj(n.dialogue) && isObj(n.dialogue.topics)) for (const t in n.dialogue.topics) out.push([t, t + '  (' + entityName('npc', nid) + ')']); } return out; }
  function successRate(dice, dc) { const m = /^(\d+)d(\d+)$/i.exec(dice || '1d20'); if (!m || dc == null) return null; const n = +m[1], s = +m[2]; if (n * s > 4000 || n < 1 || s < 1) return null; let dist = [1]; for (let i = 0; i < n; i++) { const nd = new Array(dist.length + s).fill(0); dist.forEach((p, k) => { for (let f = 1; f <= s; f++) nd[k + f] += p / s; }); dist = nd; } let p = 0; dist.forEach((pr, total) => { if (total >= dc) p += pr; }); return Math.round(p * 100); }
  function outcomeEditor(out, title, uid) {
    const c = el('div', { class: 'card' }); c.append(el('div', { class: 'card-head' }, el('span', { class: 'ttl' }, title)));
    c.append(fText(out, 'message', 'Message', { uid, textarea: true, rows: 2 }), fFlag(out, 'sets_flag', 'Sets flag', { uid, mode: 'set' }));
    c.append(block('Unlocks an exit', isObj(out.unlocks_exit), () => { out.unlocks_exit = { direction: 'north' }; }, () => { delete out.unlocks_exit; }, b => { b.append(el('div', { class: 'grid2' }, fSelect(out.unlocks_exit, 'direction', 'Direction', DIRS, { uid, allowNone: false }), fRef(out.unlocks_exit, 'room', 'room', 'In room', { uid, noneLabel: '(current room)' }))); }, { key: 'unlocks_exit' }));
    c.append(block('Unlocks a dialogue topic', isObj(out.unlocks_dialogue), () => { out.unlocks_dialogue = { topic: '' }; }, () => { delete out.unlocks_dialogue; }, b => { b.append(fSelect(out.unlocks_dialogue, 'topic', 'Topic', allTopics(), { uid })); }, { key: 'unlocks_dialogue' }));
    return c;
  }
  function renderItem(id) {
    const it = W.items[id]; const body = el('div', { class: 'insp-body' }); const uid = id;
    body.append(titleRow('item', it.name), problemList('item', id), idEditor('item', id));
    body.append(fText(it, 'name', 'Name', { required: true, uid }), fText(it, 'description', 'Description', { required: true, textarea: true, rows: 4, uid, hint: 'Shown on examine.' }), fTags(it, 'keywords', 'Keywords', { uid, hint: 'Other names players might type. Matching is case-insensitive and partial.' }));
    body.append(el('div', { class: 'grid2' }, fBool(it, 'takeable', 'Can be picked up', { uid, def: true, rerender: true }), fBool(it, 'consumable', 'Consumed when used', { uid })));
    if (it.takeable === false) body.append(fText(it, 'cant_take_msg', 'Refusal message', { uid, placeholder: 'The fountain is far too heavy to move.' }));
    body.append(appearsIn('item', id));
    body.append(secTitle('Behaviours'));
    body.append(block('Weapon or armor', it.weapon_damage != null || it.defense_bonus != null, () => { it.weapon_damage = 5; }, () => { delete it.weapon_damage; delete it.defense_bonus; }, b => {
      b.append(el('div', { class: 'grid2' }, fNum(it, 'weapon_damage', 'Weapon damage', { uid, min: 0, hint: 'Only the best weapon counts.' }), fNum(it, 'defense_bonus', 'Defense bonus', { uid, min: 0, hint: 'All armor stacks.' })));
      const wd = it.weapon_damage || 0, db = it.defense_bonus || 0; b.append(el('div', { class: 'stat-preview' }, 'Carrying this: player hits for ', el('b', {}, '5 + ' + wd + ' ± 2'), ' minus creature defense' + (db ? '; takes ' + db + ' less damage per hit' : '') + '. No equip command needed.'));
    }, { hint: 'passive while carried' }));
    body.append(block('Heals in combat', isObj(it.combat_effect), () => { it.combat_effect = { type: 'heal', amount: 10 }; if (it.consumable == null) it.consumable = true; }, () => { delete it.combat_effect; }, b => { b.append(fNum(it.combat_effect, 'amount', 'HP restored', { uid, min: 1, def: 10, hint: 'Capped at max health (10 by default). Using it costs the turn.' })); }, { key: 'combat_effect' }));
    body.append(block('On use (outside combat)', isObj(it.on_use), () => { it.on_use = { type: 'message', text: '' }; }, () => { delete it.on_use; }, b => {
      const u = it.on_use; b.append(fSelect(u, 'type', 'Effect', [['message', 'Show a message'], ['unlock', 'Unlock: set a flag'], ['heal', 'Heal the player']], { uid, allowNone: false, rerender: true }));
      if (u.type === 'message') b.append(fText(u, 'text', 'Text', { uid, textarea: true, rows: 2 }));
      if (u.type === 'unlock') b.append(fFlag(u, 'sets_flag', 'Sets flag', { uid, mode: 'set' }), fText(u, 'success_msg', 'Success message', { uid }), fBool(u, 'requires_target', 'Needs a target ("use X on Y")', { uid }));
      if (u.type === 'heal') b.append(fNum(u, 'amount', 'HP restored', { uid, min: 1 }), fText(u, 'success_msg', 'Success message', { uid }));
    }, { key: 'on_use' }));
    body.append(block('Reveals a hidden exit when used', isObj(it.reveals_exit), () => { it.reveals_exit = { direction: hiddenExitDirs()[0] || 'north', message: '' }; }, () => { delete it.reveals_exit; }, b => { b.append(fSelect(it.reveals_exit, 'direction', 'Direction (in the room the player is in)', Array.from(new Set(DIRS.concat(hiddenExitDirs()))), { uid, allowNone: false, hint: hiddenExitDirs().length ? 'Hidden exits exist for: ' + hiddenExitDirs().join(', ') : 'No room has a hidden exit yet.' }), fText(it.reveals_exit, 'message', 'Message', { uid, textarea: true, rows: 2 })); }, { key: 'reveals_exit' }));
    body.append(block('On examine', isObj(it.on_examine), () => { it.on_examine = { text: '' }; }, () => { delete it.on_examine; }, b => { b.append(fText(it.on_examine, 'text', 'Text (replaces the description)', { uid, textarea: true, rows: 2 }), fSelect(it.on_examine, 'reveals_exit', 'Reveals hidden exit', Array.from(new Set(DIRS.concat(hiddenExitDirs()))), { uid, noneLabel: '(nothing)' })); }, { key: 'on_examine' }));
    body.append(block('Dice roll (skill check)', isObj(it.dice_roll), () => { it.dice_roll = { dc: 12, dice: '1d20', attempt_message: '', consume_on: 'failure', on_success: { message: '' }, on_failure: { message: '' } }; }, () => { delete it.dice_roll; }, b => {
      const d = it.dice_roll; if (!isObj(d.on_success)) d.on_success = { message: '' }; if (!isObj(d.on_failure)) d.on_failure = { message: '' };
      const rate = el('div', { class: 'stat-preview' }); const upd = () => { const p = successRate(d.dice, d.dc); rate.innerHTML = p == null ? 'Enter dice as NdS, e.g. 1d20.' : 'Roll ' + esc(d.dice || '1d20') + ' against DC ' + esc(d.dc) + ': <b>' + p + '% success</b>. ' + (p >= 65 ? 'Easy.' : p >= 45 ? 'Moderate.' : p >= 25 ? 'Hard.' : 'Nearly impossible.'); };
      b.append(el('div', { class: 'grid2' }, fNum(d, 'dc', 'DC', { uid, min: 1, max: 30, required: true, onInput: upd }), fText(d, 'dice', 'Dice', { uid, placeholder: '1d20', onInput: upd })), rate);
      upd();
      b.append(fText(d, 'attempt_message', 'Attempt message', { uid, hint: 'Shown before the player types ROLL.' }), fText(d, 'completed_message', 'Already done message', { uid, hint: 'Shown if used again after a success.' }), fSelect(d, 'consume_on', 'Consume the item on', [['failure', 'failure'], ['success', 'success'], ['any', 'any outcome']], { uid, noneLabel: '(never)' }));
      b.append(outcomeEditor(d.on_success, 'On success', uid + 's'), outcomeEditor(d.on_failure, 'On failure', uid + 'f'));
    }, { key: 'dice_roll' }));
    body.append(block('Container', !!it.is_container, () => { it.is_container = true; if (!Array.isArray(it.contents)) it.contents = []; if (it.takeable == null) it.takeable = false; }, () => { delete it.is_container; delete it.starts_closed; delete it.locked; delete it.unlock_item; delete it.unlock_flag; delete it.locked_message; delete it.on_open_message; delete it.on_close_message; delete it.open_description; delete it.closed_description; delete it.empty_message; delete it.contents; }, b => {
      b.append(idList(it, 'contents', 'item', 'Contents', { create: true, exclude: id, keepEmpty: true, hint: 'Containers can nest. Only open containers are searchable.' }));
      b.append(el('div', { class: 'grid2' }, fBool(it, 'starts_closed', 'Starts closed', { uid, def: true, hint: 'Uncheck for a container that begins open. A locked container must start closed.' }), fBool(it, 'locked', 'Starts locked', { uid, rerender: true })));
      if (it.locked) b.append(el('div', { class: 'grid2' }, fRef(it, 'unlock_item', 'item', 'Unlocks with item', { uid, exclude: id }), fFlag(it, 'unlock_flag', 'Or with flag', { uid, mode: 'check' })), fText(it, 'locked_message', 'Locked message', { uid }));
      b.append(el('div', { class: 'grid2' }, fText(it, 'on_open_message', 'On open', { uid }), fText(it, 'on_close_message', 'On close', { uid })), el('div', { class: 'grid2' }, fText(it, 'open_description', 'Open description', { uid }), fText(it, 'closed_description', 'Closed description', { uid })), fText(it, 'empty_message', 'Empty message', { uid }));
    }, { key: 'is_container' }));
    body.append(dangerZone('item', id));
    return body;
  }

  /* ---------- Movement (NPCs and creatures share it) ---------- */
  function movementBlock(ent, uid) {
    return block('Movement', isObj(ent.movement), () => { ent.movement = { type: 'patrol', schedule: [{ room: W.meta.starting_room, duration: 3 }], depart_msg: '', arrive_msg: '' }; }, () => { delete ent.movement; }, b => {
      const m = ent.movement;
      b.append(fSelect(m, 'type', 'Type', [['patrol', 'Patrol: loop through rooms'], ['triggered', 'Triggered: move once when a flag turns true']], { uid, allowNone: false, rerender: true, onChange: v => { if (v === 'patrol') { delete m.trigger_flag; delete m.destination; if (!Array.isArray(m.schedule)) m.schedule = [{ room: W.meta.starting_room, duration: 3 }]; } else { delete m.schedule; m.trigger_flag = m.trigger_flag || ''; m.destination = m.destination || ''; } } }));
      if (m.type === 'patrol') {
        if (!Array.isArray(m.schedule)) m.schedule = [];
        const list = el('div', { style: 'display:flex; flex-direction:column; gap:8px' });
        m.schedule.forEach((s, i) => { if (!isObj(s)) m.schedule[i] = s = { room: '', duration: 3 }; const c = el('div', { class: 'card' }); c.append(el('div', { class: 'card-head' }, el('span', { class: 'ttl' }, 'Stop ' + (i + 1)), i > 0 ? el('button', { class: 'btn ghost sm', title: 'Move up', onclick: () => { pushUndo(); m.schedule.splice(i - 1, 2, m.schedule[i], m.schedule[i - 1]); commit({ inspector: true }); } }, '↑') : null, el('button', { class: 'btn ghost sm', title: 'Remove stop', onclick: () => { pushUndo(); m.schedule.splice(i, 1); commit({ inspector: true }); } }, '×'))); c.append(el('div', { class: 'grid2' }, fRef(s, 'room', 'room', 'Room', { uid: uid + i, allowNone: false }), fNum(s, 'duration', 'Turns', { uid: uid + i, min: 1, required: true })), idList(s, 'blocked_while_player_in', 'room', 'Wait while player is in', { key: 'blocked_while_player_in', empty: 'Never waits.', hint: 'Defers this move while the player stands in any of these rooms.' })); list.append(c); });
        b.append(list, el('button', { class: 'btn sm', onclick: () => { pushUndo(); m.schedule.push({ room: '', duration: 3 }); commit({ inspector: true }); } }, '+ Stop'));
        const total = m.schedule.reduce((a, s) => a + (s.duration > 0 ? s.duration : 0), 0); b.append(el('div', { class: 'stat-preview' }, 'Loops forever. One full circuit takes ', el('b', {}, total + ' turn' + (total === 1 ? '' : 's')), '. Movement ticks once per player action; a creature in combat never moves.'));
      } else {
        b.append(el('div', { class: 'grid2' }, fFlag(m, 'trigger_flag', 'When flag becomes true', { uid, mode: 'check' }), fRef(m, 'destination', 'room', 'Move to', { uid, allowNone: false })), el('div', { class: 'hint' }, 'Fires once, then this entity never moves again.'));
      }
      b.append(el('div', { class: 'grid2' }, fText(m, 'depart_msg', 'Departure message', { uid, placeholder: 'The [name] leaves.' }), fText(m, 'arrive_msg', 'Arrival message', { uid, placeholder: 'The [name] arrives.' })));
    }, { key: 'movement' });
  }

  /* ---------- NPC ---------- */
  function topicCard(topics, key, npcId) {
    const t = topics[key]; const uid = npcId + '_' + key; const c = el('div', { class: 'card' });
    const keyIn = el('input', { class: 'in', value: key, spellcheck: 'false', style: 'font-weight:600', 'aria-label': 'Topic id' });
    keyIn.addEventListener('change', () => { const nk = keyIn.value.trim(); if (!nk || nk === key) { keyIn.value = key; return; } if (topics[nk]) { toast('Topic "' + nk + '" already exists.'); keyIn.value = key; return; } pushUndo(); const rebuilt = {}; for (const k in topics) rebuilt[k === key ? nk : k] = topics[k]; const n = W.npcs[npcId]; n.dialogue.topics = rebuilt; for (const k in rebuilt) { const lt = rebuilt[k].leads_to; if (Array.isArray(lt)) rebuilt[k].leads_to = lt.map(x => x === key ? nk : x); } commit({ inspector: true }); });
    c.append(el('div', { class: 'card-head' }, keyIn, el('button', { class: 'btn ghost sm', title: 'Remove topic', onclick: () => { pushUndo(); delete topics[key]; for (const k in topics) if (Array.isArray(topics[k].leads_to)) topics[k].leads_to = topics[k].leads_to.filter(x => x !== key); commit({ inspector: true }); } }, '×')));
    c.append(fTags(t, 'keywords', 'Keywords', { uid, required: true, hint: 'Players type "talk to X about <keyword>".' }), fText(t, 'text', 'Response', { uid, textarea: true, rows: 3, required: true }), fFlag(t, 'sets_flag', 'Sets flag', { uid, mode: 'set' }));
    const gated = t.requires_flag !== undefined || t.requires_item !== undefined || t.locked_text !== undefined;
    c.append(block('Gated', gated, () => { t.locked_text = ''; }, () => { delete t.requires_flag; delete t.requires_item; delete t.locked_text; }, b => { b.append(el('div', { class: 'grid2' }, fFlag(t, 'requires_flag', 'Requires flag', { uid, mode: 'check' }), fRef(t, 'requires_item', 'item', 'Requires item', { uid })), fText(t, 'locked_text', 'Locked response', { uid, hint: 'Also used when this topic is only reachable via another topic’s leads_to.' })); }, { hint: 'flag, item, or leads_to' }));
    const others = Object.keys(topics).filter(k => k !== key);
    if (others.length) { const lt = Array.isArray(t.leads_to) ? t.leads_to : []; const boxes = el('div', { class: 'chips' }); for (const o of others) { const cb = el('input', { type: 'checkbox' }); cb.checked = lt.includes(o); cb.addEventListener('change', () => { pushUndo(); let arr = Array.isArray(t.leads_to) ? t.leads_to : []; arr = cb.checked ? arr.concat(o) : arr.filter(x => x !== o); setVal(t, 'leads_to', arr); commit({}); }); boxes.append(el('label', { class: 'chip' }, cb, o)); } c.append(el('div', { class: 'field' }, lbl('Unlocks topics', { key: 'leads_to' }), boxes, el('span', { class: 'hint' }, 'Topics listed here only become available after this one is discussed.'))); }
    return c;
  }
  function renderNpc(id) {
    const n = W.npcs[id]; const body = el('div', { class: 'insp-body' }); const uid = id;
    body.append(titleRow('npc', n.name), problemList('npc', id), idEditor('npc', id));
    body.append(fText(n, 'name', 'Name', { required: true, uid }), fText(n, 'description', 'Description', { required: true, textarea: true, rows: 4, uid }), fTags(n, 'keywords', 'Keywords', { uid }));
    body.append(appearsIn('npc', id));
    body.append(secTitle('Behaviours'));
    body.append(block('Dialogue', isObj(n.dialogue), () => { n.dialogue = { greeting: '', topics: {} }; }, () => { delete n.dialogue; }, b => {
      const d = n.dialogue; if (!isObj(d.topics)) d.topics = {};
      b.append(fText(d, 'greeting', 'Greeting', { uid, textarea: true, rows: 3, hint: 'Reply to a plain "talk to".' }), fText(d, 'default', 'Fallback', { uid, textarea: true, rows: 2, hint: 'When the topic is not recognised. Also used as the greeting if none is set.' }), fFlag(d, 'sets_flag', 'Sets flag on first greeting', { uid, mode: 'set' }));
      const list = el('div', { style: 'display:flex; flex-direction:column; gap:8px' }); for (const k in d.topics) if (isObj(d.topics[k])) list.append(topicCard(d.topics, k, id));
      b.append(secTitle('Topics', el('span', { class: 'badge' }, Object.keys(d.topics).length), el('button', { class: 'btn sm', onclick: () => { pushUndo(); const k = slug('topic', d.topics); d.topics[k] = { keywords: [], text: '' }; commit({ inspector: true }); } }, '+ Topic')), list.childElementCount ? list : el('span', { class: 'hint' }, 'No topics. Players can only get the greeting.'));
    }, { key: 'dialogue' }));
    body.append(block('Trade / quest', n.accepts_item !== undefined || n.gives_item !== undefined, () => { n.accepts_item = ''; n.accept_message = ''; }, () => { delete n.accepts_item; delete n.gives_item; delete n.accept_message; delete n.sets_flag; }, b => { b.append(el('div', { class: 'grid2' }, fRef(n, 'accepts_item', 'item', 'Accepts item', { uid, keepKey: true }), fRef(n, 'gives_item', 'item', 'Gives back', { uid })), fText(n, 'accept_message', 'On accept', { uid, textarea: true, rows: 3 }), fFlag(n, 'sets_flag', 'Sets flag on accept', { uid, mode: 'set' }), el('div', { class: 'hint' }, 'Player types "give <item> to <npc>". The given item leaves their inventory.')); }, { hint: 'give X to NPC' }));
    body.append(movementBlock(n, uid));
    body.append(dangerZone('npc', id));
    return body;
  }

  /* ---------- Creature ---------- */
  function tierFor(c) { const score = (c.health || 0) + (c.attack || 0) * 3 + (c.defense || 0) * 4; return TIERS.find(t => score <= t.max); }
  function renderCreature(id) {
    const c = W.creatures[id]; const body = el('div', { class: 'insp-body' }); const uid = id;
    body.append(titleRow('creature', c.name), problemList('creature', id), idEditor('creature', id));
    body.append(fText(c, 'name', 'Name', { required: true, uid }), fText(c, 'description', 'Description', { required: true, textarea: true, rows: 4, uid }), fTags(c, 'keywords', 'Keywords', { uid }));
    body.append(appearsIn('creature', id));
    const tier = el('span', { class: 'tier' }); const preview = el('div', { class: 'stat-preview' });
    const upd = () => { const t = tierFor(c); tier.textContent = t.name; tier.style.color = t.color; const atk = c.attack == null ? 5 : c.attack, def = c.defense || 0, hp = c.health || 0; const perHitUnarmed = Math.max(5 - def, 1); const hits = hp > 0 ? Math.ceil(hp / perHitUnarmed) : 0; preview.innerHTML = 'Hits the player for <b>' + esc(atk) + ' ± 2</b> minus armor (min 1). Unarmed player needs about <b>' + hits + ' hit' + (hits === 1 ? '' : 's') + '</b> to kill it; player starts with 10 HP.'; };
    body.append(secTitle('Combat', tier), el('div', { class: 'grid3' }, fNum(c, 'health', 'Health', { uid, min: 1, required: true, onInput: upd }), fNum(c, 'attack', 'Attack', { uid, min: 0, def: 5, onInput: upd }), fNum(c, 'defense', 'Defense', { uid, min: 0, def: 0, onInput: upd })), preview);
    upd();
    body.append(fBool(c, 'hostile', 'Hostile (attacks on its own)', { uid, rerender: true }));
    if (c.hostile) {
      const ac = isObj(c.attack_condition) ? c.attack_condition : null; const kind = ac ? Object.keys(ac)[0] || '' : '';
      const condSel = picker({ value: ['moves', 'room_entries', 'on_talk'].includes(kind) ? kind : '', none: false, options: [{ value: '', label: 'Immediately, on the first action in the room' }, { value: 'moves', label: 'After N player actions in the room' }, { value: 'room_entries', label: 'On the Nth visit to the room' }, { value: 'on_talk', label: 'Only when the player talks to it' }],
        onChange: v => { pushUndo(); if (!v) delete c.attack_condition; else if (v === 'on_talk') c.attack_condition = { on_talk: true }; else c.attack_condition = { [v]: 3 }; commit({ inspector: true }); } });
      const row = el('div', { class: (kind === 'moves' || kind === 'room_entries') ? 'grid2' : '' }, field('Attacks when', condSel, { key: 'attack_condition' }));
      if (kind === 'moves' || kind === 'room_entries') row.append(fNum(c.attack_condition, kind, kind === 'moves' ? 'Actions' : 'Visits', { uid, min: 1 }));
      body.append(row, fText(c, 'aggro_text', 'Aggro message', { uid, placeholder: 'The ' + (c.name || 'creature') + ' attacks you!' }));
    }
    body.append(fText(c, 'talk_text', 'Reply to "talk to"', { uid, placeholder: 'It has no clue what you’re saying.' }));
    body.append(secTitle('Defeat'), fText(c, 'on_defeat_msg', 'On defeat', { uid, textarea: true, rows: 2 }), fText(c, 'on_flee_msg', 'On player flee', { uid, textarea: true, rows: 2 }), idList(c, 'loot', 'item', 'Drops loot', { create: true, empty: 'Drops nothing.', hint: 'Dropped into the room on defeat. These items need no other placement.' }), fFlag(c, 'sets_flag_on_defeat', 'Sets flag on defeat', { uid, mode: 'set' }));
    body.append(secTitle('Behaviours'), movementBlock(c, uid));
    body.append(dangerZone('creature', id));
    return body;
  }

  /* ---------- Decor (map-only) ---------- */
  function renderDecor(id) {
    const dd = decorById(id); const body = el('div', { class: 'insp-body' }); const uid = id;
    body.append(el('div', { class: 'insp-title' }, el('span', { class: 'kind', style: 'color: var(--fg-dim)' }, 'Decor'), el('h2', {}, entityName('decor', id))));
    body.append(el('span', { class: 'hint' }, 'A visual aid on the map. Saved under meta.editor and ignored by the engine.'));
    body.append(field('Shape', picker({ value: dd.shape || 'house', none: false, options: [{ value: 'label', label: 'Text label' }].concat(SYMBOL_LIST.map(k => ({ value: k, label: k[0].toUpperCase() + k.slice(1) }))), onChange: v => { pushUndo(); dd.shape = v; commit({ inspector: true }); } })));
    body.append(fText(dd, 'label', dd.shape === 'label' ? 'Text' : 'Caption', { uid, showKey: false, placeholder: dd.shape === 'label' ? 'New label' : 'Optional caption under the shape' }));
    body.append(el('div', { class: 'grid3' }, fNum(dd, 'w', 'Width', { uid, min: 16, showKey: false }), fNum(dd, 'h', 'Height', { uid, min: 14, showKey: false }), fNum(dd, 'r', 'Rotation', { uid, min: 0, max: 359, showKey: false, placeholder: '0' })));
    body.append(el('span', { class: 'hint' }, 'On the map: drag to move, the corner handle resizes, the top handle rotates.'));
    body.append(el('div', { class: 'danger-zone' }, el('button', { class: 'btn danger sm', onclick: () => deleteDecor(id) }, 'Delete')));
    return body;
  }

  /* ---------- Dispatcher ---------- */
  let lastSelKey = null;
  function renderInspector() {
    const key = sel ? sel.type + ':' + sel.id : null; const keep = key === lastSelKey ? insp.scrollTop : 0; lastSelKey = key;
    closePicker(); insp.innerHTML = ''; focusSnap = null;
    if (!sel) { insp.append(el('div', { class: 'insp-empty' }, el('b', {}, 'Nothing selected'), 'Pick a room on the map or an entry in the list.', el('ul', {}, el('li', {}, 'Double-click the map to add a room'), el('li', {}, 'Connect rooms draws exits between them'), el('li', {}, 'Every id field is a picker, so references cannot dangle'), el('li', {}, 'Renaming an id rewrites every reference')))); return; }
    const exists = sel.type === 'meta' || sel.type === 'flag' || (sel.type === 'decor' ? !!decorById(sel.id) : (W[PLURAL[sel.type]] && W[PLURAL[sel.type]][sel.id]));
    if (!exists) { sel = null; renderInspector(); return; }
    if (sel.type === 'meta') insp.append(renderMeta()); else if (sel.type === 'flag') insp.append(renderFlag(sel.id)); else if (sel.type === 'decor') insp.append(renderDecor(sel.id)); else if (sel.type === 'room') insp.append(renderRoom(sel.id)); else if (sel.type === 'item') insp.append(renderItem(sel.id)); else if (sel.type === 'npc') insp.append(renderNpc(sel.id)); else if (sel.type === 'creature') insp.append(renderCreature(sel.id));
    insp.scrollTop = keep;
  }

  /* ---------- Sidebar ---------- */
  const collapsed = new Set(); const filterTypes = new Set(); let problemsOnly = false;
  function renderSidebar() {
    const list = $('#sidebarList'); list.innerHTML = ''; const q = $('#search').value.trim().toLowerCase();
    const showType = t => !filterTypes.size || filterTypes.has(t); const keep = (type, id) => !problemsOnly || !!worstLevel(problemsFor(type, id));
    const match = (id, name) => !q || id.toLowerCase().includes(q) || String(name || '').toLowerCase().includes(q);
    const row = (type, id, name, sub) => { const ps = worstLevel(problemsFor(type, id)); const r = el('div', { class: 'row' + (sel && sel.type === type && sel.id === id ? ' selected' : ''), onclick: () => select(type, id) }, el('span', { class: 'dot bg-' + type }), el('span', { class: 'name' }, name || id), sub != null ? el('span', { class: 'id' }, sub) : null, ps ? el('span', { class: 'mark ' + (ps === 'error' ? 'err' : 'warn'), title: ps }) : null); return r; };
    const section = (key, title, type, rows, addFn) => {
      if (!showType(type)) return;
      const s = el('div', { class: 'section' + (collapsed.has(key) ? ' collapsed' : '') });
      const head = el('div', { class: 'section-head', onclick: () => { collapsed.has(key) ? collapsed.delete(key) : collapsed.add(key); s.classList.toggle('collapsed'); } }, el('span', { class: 'caret' }, '▼'), el('span', { class: 'section-name t-' + type }, title), el('span', { class: 'badge' }, String(rows.length)), addFn ? el('button', { class: 'btn ghost sm', title: 'Add ' + title.toLowerCase(), onclick: ev => { ev.stopPropagation(); addFn(); } }, '+') : null);
      s.append(head, el('div', { class: 'rows' }, rows.length ? rows : el('div', { class: 'empty' }, q ? 'No matches.' : 'None yet.')));
      list.append(s);
    };
    if (match('meta', W.meta.name) && !filterTypes.size && keep('meta', 'meta')) list.append(el('div', { class: 'section' }, el('div', { class: 'row' + (sel && sel.type === 'meta' ? ' selected' : ''), style: 'padding-left: 12px', onclick: () => select('meta', 'meta') }, el('span', { class: 'dot bg-meta' }), el('span', { class: 'name', style: 'font-family: var(--font-display); font-size: 18px' }, 'World settings'), worstLevel(problemsFor('meta', 'meta')) ? el('span', { class: 'mark err' }) : null)));
    const sorted = coll => Object.keys(coll).sort((a, b) => entityName2(coll, a).localeCompare(entityName2(coll, b)));
    const entityName2 = (coll, id) => (isObj(coll[id]) && coll[id].name) || id;
    section('rooms', 'Rooms', 'room', sorted(W.rooms).filter(id => match(id, entityName2(W.rooms, id)) && keep('room', id)).map(id => row('room', id, entityName2(W.rooms, id), id === W.meta.starting_room ? 'start' : null)), () => createEntity('room'));
    section('items', 'Items', 'item', sorted(W.items).filter(id => match(id, entityName2(W.items, id)) && keep('item', id)).map(id => { const it = W.items[id]; const tag = !isObj(it) ? '' : it.is_container ? 'container' : it.dice_roll ? 'dice' : it.weapon_damage != null ? 'weapon' : it.defense_bonus != null ? 'armor' : it.combat_effect ? 'heal' : null; return row('item', id, entityName2(W.items, id), tag); }), () => createEntity('item'));
    section('npcs', 'NPCs', 'npc', sorted(W.npcs).filter(id => match(id, entityName2(W.npcs, id)) && keep('npc', id)).map(id => { const n = W.npcs[id]; return row('npc', id, entityName2(W.npcs, id), isObj(n) && isObj(n.movement) ? n.movement.type : null); }), () => createEntity('npc'));
    section('creatures', 'Creatures', 'creature', sorted(W.creatures).filter(id => match(id, entityName2(W.creatures, id)) && keep('creature', id)).map(id => { const c = W.creatures[id]; return row('creature', id, entityName2(W.creatures, id), isObj(c) && c.hostile ? 'hostile' : null); }), () => createEntity('creature'));
    section('flags', 'Flags', 'flag', Object.keys(flagIndex).sort().filter(f => match(f, f) && keep('flag', f)).map(f => row('flag', f, f, flagIndex[f].set.length ? null : 'never set')), null);
  }
  $('#search').addEventListener('input', renderSidebar);
  $$('#typeFilters .fchip').forEach(ch => ch.addEventListener('click', () => {
    const t = ch.dataset.type;
    if (t === '') filterTypes.clear(); else if (t === 'problems') problemsOnly = !problemsOnly; else if (filterTypes.has(t)) filterTypes.delete(t); else filterTypes.add(t);
    $$('#typeFilters .fchip').forEach(c => { const ct = c.dataset.type; c.classList.toggle('active', ct === '' ? !filterTypes.size : ct === 'problems' ? problemsOnly : filterTypes.has(ct)); });
    renderSidebar();
  }));

  /* ---------- Tabs and views ---------- */
  function setTab(t) { tab = t; $$('.tab').forEach(b => b.classList.toggle('active', b.dataset.tab === t)); $$('.tabpane').forEach(p => p.classList.toggle('active', p.id === 'pane-' + t)); if (t === 'json') renderJson(); if (t === 'flags') renderFlags(); if (t === 'problems') renderProblems(); if (t === 'map') renderMap(); }
  $$('.tab').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));
  function setView(v) { $('#main').dataset.view = v; $$('#bottomnav button').forEach(b => b.classList.toggle('active', b.dataset.view === v)); if (v === 'canvas' && tab === 'map') renderMap(); }
  $$('#bottomnav button').forEach(b => b.addEventListener('click', () => setView(b.dataset.view)));

  /* ---------- Flags table ---------- */
  function renderFlags() {
    const wrap = $('#flagsTable'); wrap.innerHTML = ''; const flags = Object.keys(flagIndex).sort();
    if (!flags.length) { wrap.append(el('div', { class: 'allgood' }, el('b', {}, 'No flags yet'), 'Flags appear here as soon as an exit, item, topic or creature sets or checks one.')); return; }
    const chipsFor = rs => el('span', {}, rs.map(r => el('span', { class: 'chip link', title: r.label, onclick: ev => { ev.stopPropagation(); select(r.owner.type, r.owner.id); } }, el('span', { class: 'dot bg-' + r.owner.type }), entityName(r.owner.type, r.owner.id))));
    const t = el('table', { class: 'table' }, el('thead', {}, el('tr', {}, el('th', {}, 'Flag'), el('th', {}, 'Set by'), el('th', {}, 'Checked by'), el('th', {}, 'Status'))));
    const tb = el('tbody');
    for (const f of flags) { const fi = flagIndex[f]; const status = !fi.set.length ? el('span', { class: 'badge warn' }, 'never set') : !fi.check.length ? el('span', { class: 'badge' }, 'never checked') : el('span', { class: 'badge ok' }, 'wired'); tb.append(el('tr', { class: 'click', onclick: () => select('flag', f) }, el('td', { class: 't-flag' }, f), el('td', {}, fi.set.length ? chipsFor(fi.set) : el('span', { class: 'hint' }, 'nothing')), el('td', {}, fi.check.length ? chipsFor(fi.check) : el('span', { class: 'hint' }, 'nothing')), el('td', {}, status))); }
    t.append(tb); wrap.append(t);
  }

  /* ---------- Problems ---------- */
  function renderProblems() {
    const list = $('#problemsList'); list.innerHTML = '';
    if (!problems.length) { list.append(el('div', { class: 'allgood' }, el('b', {}, 'No problems'), 'Every reference resolves, every required field is filled, every room is reachable.')); return; }
    const order = { error: 0, warn: 1, info: 2 }; const sorted = problems.slice().sort((a, b) => order[a.level] - order[b.level]);
    for (const p of sorted) list.append(el('div', { class: 'problem', onclick: () => { select(p.target.type, p.target.id); } }, el('span', { class: 'lvl ' + p.level }, p.level === 'warn' ? 'warn' : p.level), el('div', { class: 'msg' }, p.msg, el('div', { class: 'who' }, LABEL[p.target.type] + ': ' + entityName(p.target.type, p.target.id)))));
  }
  function renderBadges() {
    const e = problems.filter(p => p.level === 'error').length, w = problems.filter(p => p.level === 'warn').length;
    const b = $('#problemsBadge'); b.textContent = String(e + w); b.className = 'badge ' + (e ? 'err' : w ? 'warn' : 'ok');
    const tb = $('#problemTabBadge'); tb.textContent = String(problems.length); tb.className = 'badge ' + (e ? 'err' : w ? 'warn' : '');
    $('#flagCount').textContent = String(Object.keys(flagIndex).length);
  }
  function renderStatus() {
    const s = $('#statusbar'); s.innerHTML = '';
    const n = t => Object.keys(W[PLURAL[t]]).length;
    s.append(el('span', {}, n('room') + ' rooms'), el('span', {}, n('item') + ' items'), el('span', {}, n('npc') + ' NPCs'), el('span', {}, n('creature') + ' creatures'), el('span', {}, Object.keys(flagIndex).length + ' flags'), el('span', {}, reachable.size + '/' + n('room') + ' rooms reachable'), el('span', { class: 'spacer' }), el('span', {}, canSave ? 'Drafts autosave in this browser; Save writes to the server' : fileMode ? 'Drafts autosave in this browser; Save file writes to disk' : 'Draft autosaves in this browser'), el('span', {}, el('kbd', {}, 'Ctrl'), '+', el('kbd', {}, 'Z'), ' undo'));
  }
  $('#btnProblems').addEventListener('click', () => { setTab('problems'); setView('canvas'); });

  /* ---------- JSON pane ---------- */
  const jsonText = $('#jsonText'); let jsonDirty = false;
  function exportJson() { const w = clone(W); normalizeExits(w); if (!$('#includeEditor').checked && isObj(w.meta)) delete w.meta.editor; return JSON.stringify(w, null, 2); }
  $('#includeEditor').addEventListener('change', () => renderJson(true));
  function renderJson(force) { if (jsonDirty && !force) return; jsonText.value = exportJson(); jsonDirty = false; const st = $('#jsonStatus'); st.textContent = 'In sync with the editor. Edit here and press Apply, or copy it out.'; st.classList.remove('err'); }
  jsonText.addEventListener('input', () => { jsonDirty = true; const st = $('#jsonStatus'); try { JSON.parse(jsonText.value); st.textContent = 'Edited. Press Apply to load these changes into the editor.'; st.classList.remove('err'); } catch (e) { st.textContent = 'Invalid JSON: ' + e.message; st.classList.add('err'); } });
  $('#btnApplyJson').addEventListener('click', () => { let parsed; try { parsed = JSON.parse(jsonText.value); } catch (e) { toast('Invalid JSON: ' + e.message, 4000); return; } if (!isObj(parsed)) { toast('The world must be a JSON object.'); return; } pushUndo(); W = ensureShape(parsed); jsonDirty = false; $('#worldName').value = W.meta.name || ''; afterReplace(); renderJson(true); toast('Applied JSON'); });
  $('#btnRevertJson').addEventListener('click', () => { renderJson(true); });
  $('#btnCopy').addEventListener('click', () => { const text = exportJson(); const done = () => toast('World JSON copied to the clipboard (' + Math.round(text.length / 1024) + ' KB)'); const fallback = () => { setTab('json'); setView('canvas'); renderJson(true); jsonText.focus(); jsonText.select(); toast('Clipboard unavailable. The JSON is selected; press Ctrl+C or Cmd+C.', 4000); }; if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback); else fallback(); });

  /* ---------- Load, import, drop ---------- */
  function loadSample(key) { const s = (host.samples || []).find(x => x.key === key); if (!s) return; loadWorld(clone(s.world)); select('room', W.meta.starting_room); dirty = canSave || fileMode; if (fileMode) fileHandle = null; renderSaveState(); toast('Loaded ' + (W.meta.name || s.name || key)); }
  const loadMenu = $('#loadMenu');
  $('#btnLoad').addEventListener('click', ev => { ev.stopPropagation(); loadMenu.classList.toggle('open'); });
  document.addEventListener('click', ev => { if (!ev.target.closest('#loadMenu')) loadMenu.classList.remove('open'); });
  (host.samples || []).slice().reverse().forEach(s => { const b = el('button', { onclick: () => { loadMenu.classList.remove('open'); loadSample(s.key); } }, s.name || s.key, s.description ? el('small', {}, s.description) : null); loadMenu.prepend(b); });
  $('#btnImport').addEventListener('click', () => { loadMenu.classList.remove('open'); $('#fileInput').click(); });
  function importFile(file, handle) { if (!file) return; const rd = new FileReader(); rd.onload = () => { try { const parsed = JSON.parse(rd.result); if (!isObj(parsed)) throw new Error('not an object'); loadWorld(parsed); select('room', W.meta.starting_room); fileHandle = handle || null; dirty = canSave; renderSaveState(); toast((handle ? 'Opened ' : 'Imported ') + file.name); } catch (e) { toast('Could not import ' + file.name + ': ' + e.message, 4000); } }; rd.readAsText(file); }
  $('#fileInput').addEventListener('change', ev => { importFile(ev.target.files[0]); ev.target.value = ''; });
  let dragDepth = 0; const dz = $('#dropzone');
  document.addEventListener('dragenter', ev => { if (ev.dataTransfer && Array.from(ev.dataTransfer.types).includes('Files')) { dragDepth++; dz.classList.add('show'); } });
  document.addEventListener('dragleave', () => { dragDepth = Math.max(0, dragDepth - 1); if (!dragDepth) dz.classList.remove('show'); });
  document.addEventListener('dragover', ev => ev.preventDefault());
  document.addEventListener('drop', ev => { ev.preventDefault(); dragDepth = 0; dz.classList.remove('show'); importFile(ev.dataTransfer.files[0]); });

  /* ---------- World name, undo, keys ---------- */
  const nameIn = $('#worldName');
  nameIn.addEventListener('input', () => { setVal(W.meta, 'name', nameIn.value); lightCommit(); if (sel && sel.type === 'meta') { const f = $('#f_name_meta'); if (f && f.value !== nameIn.value) f.value = nameIn.value; } });
  undoOnBlur(nameIn);
  $('#btnUndo').addEventListener('click', undo); $('#btnRedo').addEventListener('click', redo);
  document.addEventListener('keydown', ev => {
    const inField = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement && document.activeElement.tagName);
    if ((ev.ctrlKey || ev.metaKey) && !inField && ev.key.toLowerCase() === 'z') { ev.preventDefault(); ev.shiftKey ? redo() : undo(); }
    else if ((ev.ctrlKey || ev.metaKey) && !inField && ev.key.toLowerCase() === 'y') { ev.preventDefault(); redo(); }
    else if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 's' && (canSave || fileMode)) { ev.preventDefault(); doSave(); }
  });

  /* ---------- Boot ---------- */
  function start() {
    if (isObj(host.world)) { loadWorld(clone(host.world)); dirty = false; renderSaveState(); select('room', W.meta.starting_room); checkDraft(); return; }
    const d = readDraft();
    if (d) { loadWorld(d.world); dirty = fileMode; renderSaveState(); select('room', W.meta.starting_room); toast('Restored your draft from this browser'); }
    else if (host.samples && host.samples.length) { loadSample(host.samples[0].key); dirty = false; renderSaveState(); }
    else { loadWorld({ meta: { name: 'Untitled Adventure', description: 'A brand new world.', starting_room: 'start' }, rooms: { start: { name: 'Starting Room', description: 'You are standing in an empty room.', exits: {}, items: [], npcs: [], creatures: [] } } }); dirty = false; renderSaveState(); }
  }
  $('#btnSave').addEventListener('click', doSave); $('#btnSaveFile').addEventListener('click', doSave); $('#btnOpenFile').addEventListener('click', openFromFile);
  start();
  window.addEventListener('resize', () => { if (tab === 'map') renderMap(); });
  window.addEventListener('beforeunload', ev => { if (dirty && (canSave || fileMode)) { ev.preventDefault(); ev.returnValue = ''; } });
  return { getWorld: () => W, exportJson, isDirty: () => dirty, save: doSave, loadWorld: w => { loadWorld(w); select('room', W.meta.starting_room); } };
}

