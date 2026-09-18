const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
function load(file, imports = {}) {
  const context = vm.createContext(imports);
  vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\.(pragma|import).*$/gm, ''), context);
  return context;
}
const Settings = load('IslesSettings.js');
const Presets = load('Presets.js', { Settings });
const Draw = load('HuddleDraw.js');
const plain = value => JSON.parse(JSON.stringify(value));
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json')));
const builtins = Presets.builtins();
assert.equal(builtins.length, 6);
assert.equal(builtins[0].name, 'Glowy');
assert.deepEqual(plain(Presets.snapshot({})), plain(builtins[0].settings));
assert.deepEqual(plain(Presets.snapshot(manifest.barWidget.defaults)), plain(builtins[0].settings));
for (const field of manifest.barWidget.schema) assert.equal(field.defaultValue, manifest.barWidget.defaults[field.key]);
for (const [index, preset] of builtins.entries()) {
  assert.equal(Presets.matching(preset.settings, builtins), String(index));
  assert.deepEqual(plain(Presets.snapshot(preset.settings)), plain(preset.settings));
  for (const vertical of [false, true]) {
    const payload = {...preset.settings, clusters:[{x:100,y:100,width:100,height:100,region:'left'}], slots:[{x:100,y:100,width:100,height:100,region:'left'}]};
    const pieces = Draw.build(payload,1920,1080,32,vertical);
    assert.ok(pieces.length);
    for (const piece of pieces) assert.ok(piece.width > 0 && piece.height > 0);
  }
}
const changed = {...builtins[0].settings, opacity: 67};
assert.equal(Presets.matching(changed, builtins), 'custom');
let result = Presets.save([], '  My glow  ', changed);
assert.equal(result.presets[0].name, 'My glow');
assert.deepEqual(plain(result.presets[0].settings), plain(changed));
const roundTrip = JSON.parse(JSON.stringify(result.presets));
assert.equal(Presets.matching(changed, Presets.entries(roundTrip)), '6');
assert.equal(Presets.saved(null).length, 0);
assert.equal(Presets.saved([null, {}, {name:'Bad'}, {name:'Glowy',settings:{}}]).length, 0);
assert.ok(Presets.save([], '', changed).error);
assert.ok(Presets.save([], 'glOWy', changed).error);
result = Presets.save(roundTrip, 'MY GLOW', {...changed, opacity: 0, strokeOpacity: 0});
assert.equal(result.presets.length, 1);
assert.equal(result.presets[0].settings.opacity, 0);
assert.equal(result.presets[0].settings.strokeOpacity, 0);
assert.equal(roundTrip[0].settings.opacity, 67); // Updating does not mutate input.
const clone = Presets.save([], 'My favourite', builtins[0].settings);
assert.equal(Presets.matching({...builtins[0].settings,presetName:'My favourite'}, Presets.entries(clone.presets)), '6');
const unusual = 'Quotes " and $(text) <b> ♥';
assert.equal(Presets.save([], unusual, changed).presets[0].name, unusual);
assert.equal(Presets.nameOf('x'.repeat(100)).length, 40);
// Previously fixed drawing regressions.
for (const look of ['cluster','glow','pills','rail']) {
  const payload = {...builtins[0].settings,look,border:'ends',strokeOpacity:0,clusters:[{x:100,y:100,width:100,height:100}],slots:[{x:100,y:100,width:100,height:100}]};
  for (const vertical of [false,true]) for (const piece of Draw.build(payload,1920,1080,32,vertical)) {
    assert.equal(piece.pointed,true);
    assert.equal(piece.strokeAlpha,0);
  }
}
console.log('PASS: preset defaults, six looks, matching, save/update, JSON round-trip, malformed data, and drawing regressions.');

// Exercise the real measurement tail with a deterministic timer clock.
const widget = fs.readFileSync(path.join(root, 'Widget.qml'), 'utf8');
const tail = widget.slice(widget.indexOf('    var key = HuddleState.keyOf(payload)'), widget.indexOf('\n  function injectPanel()')).replace(/\n  }\s*$/, '');
const measure = new Function('payload', 'HuddleState', 'root', 'HuddleDraw', 'window', 'span', 'edgeVertical', 'measureTimer', 'burstSettle', tail);
let now = 0, deadline = null, builds = 0;
const timer = {interval: 250};
const widgetState = {lastDrawKey: '', drawList: []};
function tick(key) {
  measure(key, {keyOf: value => value}, widgetState, {build: () => {builds++; return [];}}, {contentItem: {width: 1920, height: 32}}, 32, false, timer, {restart: () => {deadline = now + 400;}});
}
tick('initial');
assert.equal(timer.interval, 50);
for (now = 50; now < 400; now += 50) tick('initial');
assert.equal(deadline, 400);
assert.equal(builds, 1);
const settleHandler = widget.match(/onTriggered: measureTimer\.interval = (\d+)/);
assert.ok(settleHandler);
if (now >= deadline) timer.interval = Number(settleHandler[1]);
assert.equal(timer.interval, 250);
now = 450;
tick('changed');
assert.equal(timer.interval, 50);
assert.equal(deadline, 850);
assert.equal(builds, 2);
console.log('PASS: unchanged geometry settles polling; changed geometry resumes burst polling.');
