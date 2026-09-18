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
const measureStart = widget.indexOf('    var key = HuddleState.keyOf(');
assert.ok(measureStart >= 0);
const tail = widget.slice(measureStart, widget.indexOf('\n  function injectPanel()')).replace(/\n  }\s*$/, '');
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

// Use the real cache and draw builder with fixed slots: surface changes alone
// must redraw, while identical inputs must retain the existing drawing.
const State = load('HuddleState.js');
const cacheRoot = {lastDrawKey: '', drawList: []};
const rail = {...builtins[3].settings, clusters: [], slots: []};
function measureGeometry(width, height, span, vertical) {
  measure(rail, State, cacheRoot, Draw, {contentItem: {width, height}}, span, vertical, {interval: 250}, {restart() {}});
  return cacheRoot.drawList;
}
let pieces = measureGeometry(32, 1080, 32, true);
assert.equal(pieces[0].height, 1080);
assert.equal(measureGeometry(32, 1080, 32, true), pieces);
pieces = measureGeometry(32, 1440, 32, true);
assert.equal(pieces[0].height, 1440);
pieces = measureGeometry(32, 1440, 40, true);
assert.equal(pieces[0].width, 36);
pieces = measureGeometry(32, 1440, 40, false);
assert.equal(pieces[0].width, 32);
assert.equal(pieces[0].height, 36);
pieces = measureGeometry(32.25, 1440, 40, false);
assert.equal(pieces[0].width, 32.25);
assert.equal(measureGeometry(32.25, 1440, 40, false), pieces);
// Changing to another surface of the same size must also discard old items.
const surfaceHandler = widget.match(/onBarLayerChanged:\s*\{([\s\S]*?)\n  \}/);
assert.ok(surfaceHandler);
let scheduled = false;
new Function('root', 'Qt', 'measureHuddle', surfaceHandler[1])(cacheRoot, {callLater(fn) {scheduled = true;}}, () => {});
assert.equal(scheduled, true);
assert.equal(cacheRoot.lastDrawKey, '');
assert.equal(cacheRoot.drawList.length, 0);
const replacement = measureGeometry(32.25, 1440, 40, false);
assert.notEqual(replacement, pieces);
assert.deepEqual(plain(replacement), plain(pieces));
console.log('PASS: cache handles height, thickness, orientation, fractional width, and surface replacement without rebuilding unchanged geometry.');

// Evaluate the actual QML path bindings so geometry tests cover the renderer,
// not a separate copy of its intended coordinates.
const chromeSource = fs.readFileSync(path.join(root, 'ChromeBox.qml'), 'utf8');
const shapeSource = chromeSource.slice(chromeSource.indexOf('    ShapePath {'));
const startX = shapeSource.match(/startX: (.+)/)[1];
const startY = shapeSource.match(/startY: (.+)/)[1];
const pathLines = [...shapeSource.matchAll(/PathLine\s*\{\s*x: ([^\n]+)\s*y: ([^\n]+)\s*\}/g)];
assert.equal(pathLines.length, 6);
function endsOutline(width, height, vertical) {
  const box = {width, height, vertical};
  const tipExpression = chromeSource.match(/readonly property real tip: (.+)/)[1];
  box.tip = new Function('box', 'width', 'height', 'vertical', `return ${tipExpression}`)(box, width, height, vertical);
  const evaluate = expression => new Function('box', `return ${expression}`)(box);
  return [[evaluate(startX), evaluate(startY)], ...pathLines.map(m => [evaluate(m[1]), evaluate(m[2])])];
}
function cross(a, b, c) {
  return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
}
for (const [width, height] of [[28,100], [32,1440], [100,28], [1440,32], [28,28], [8,28], [28,8], [27.5,103.25]]) {
  for (const vertical of [false,true]) {
    const points = endsOutline(width,height,vertical);
    assert.deepEqual(points[0],points[6], 'Outline must close');
    for (const [x,y] of points) assert.ok(x >= 0 && x <= width && y >= 0 && y <= height);
    for (let i=0; i<6; i++) for (let j=i+2; j<6; j++) {
      if (i===0 && j===5) continue;
      const a=points[i], b=points[i+1], c=points[j], d=points[j+1];
      const crossing = cross(a,b,c)*cross(a,b,d)<0 && cross(c,d,a)*cross(c,d,b)<0;
      assert.equal(crossing,false,`Crossing Ends edges ${i}/${j} at ${width}x${height}, vertical=${vertical}`);
    }
    // A pointed island is convex, with both ends centred on the strip.
    for (let i=0; i<6; i++) assert.ok(cross(points[i],points[(i+1)%6],points[(i+2)%6]) >= 0);
    const tips = vertical ? [[width/2,0],[width/2,height]] : [[0,height/2],[width,height/2]];
    for (const tip of tips) assert.ok(points.some(p => p[0]===tip[0] && p[1]===tip[1]));
  }
}
assert.deepEqual(endsOutline(100,28,false),[[14,0],[86,0],[100,14],[86,28],[14,28],[0,14],[14,0]]);
console.log('PASS: actual Ends paths are closed, convex, and non-crossing in both orientations; horizontal geometry is unchanged.');

// Malformed numbers must not silently turn into intentional zeroes.
for (const invalid of [null, '', '  ', false, true, [], {}, Infinity, NaN]) {
  const cfg = Settings.fromSettings({opacity: invalid, padding: invalid, radius: invalid});
  assert.equal(cfg.opacity, 66);
  assert.equal(cfg.padding, 1);
  assert.equal(cfg.radius, 100);
}
for (const zero of [0, '0']) assert.equal(Settings.fromSettings({opacity: zero}).opacity, 0);
assert.equal(Presets.saved([{name:'Array',settings:[]}]).length, 0);
assert.equal(Presets.saved([{name:'Empty',settings:{}}]).length, 0);
const future = {name:'Future',version:99,settings: {someFutureField:true}};
const broken = {name:'Broken',settings:[]};
const extended = {name:'Extended',extra:'preserve',settings:{...changed,unknown:'preserve'}};
const raw = [future,broken,extended];
result = Presets.save(raw,'New',changed);
assert.deepEqual(plain(result.presets.slice(0,3)),raw);
assert.ok(Presets.save(raw,'Future',changed).error);
assert.ok(Presets.save(raw,'Broken',changed).error);
assert.ok(Presets.save({version:99},'New',changed).error);
result = Presets.save(raw,'Extended',{...changed,opacity:0});
assert.equal(result.presets[2].settings.unknown,'preserve');
assert.equal(result.presets[2].extra,'preserve');
assert.equal(result.presets[2].settings.opacity,0);
assert.deepEqual(raw,[future,broken,extended]);

// Preserve raw shape bounds at each bar edge: clipping belongs to the viewport.
for (const vertical of [false,true]) {
  const payload={...builtins[1].settings,padding:8,clusters:[{x:2,y:2,width:20,height:20}],slots:[]};
  const piece=Draw.build(payload,100,100,32,vertical)[0];
  const start=vertical ? piece.y : piece.x;
  const length=vertical ? piece.height : piece.width;
  assert.equal(start,-6);
  assert.equal(start+length,30);
  const nearEnd={...payload,clusters:[{x:90,y:90,width:20,height:20}]};
  const last=Draw.build(nearEnd,100,100,32,vertical)[0];
  assert.equal(vertical?last.y:last.x,82);
  assert.equal((vertical?last.y+last.height:last.x+last.width),118);
}
assert.ok(widget.includes('clip: true'));

const Geometry=load('BarGeometry.js');
let childrenRead=0;
function slot(region='left') {
  return {region,moduleName:'test.widget',activeItem:{},mapToItem(){},width:20,height:32,visible:true,
    get children(){childrenRead++;return [];}};
}
const one=slot(),two=slot('right'),hidden=slot('center');hidden.visible=false;
const impostor={region:'left',moduleName:'not-a-slot',children:[two]};
const surface={width:800,height:32,parent:null,children:[one,hidden,impostor]};
const discovered=Geometry.slotsIn(surface);
assert.equal(discovered.length,2);
assert.equal(discovered[0],one);assert.equal(discovered[1],two);
assert.equal(childrenRead,0,'Discovery must not enter widget internals');
assert.equal(Geometry.findSurfaceRoot({width:20,height:32,parent:surface},surface,false),surface);
assert.equal(Geometry.findSurfaceRoot(null,surface,false),null);
assert.equal(Geometry.slotsIn({get children(){throw Error('destroyed')}}).length,0);

const Store=load('SettingsStore.js');
const original={...changed,savedPresets:[future],extension:{foo:'keep'}};
const transaction=Store.plan(original,{opacity:0,presetName:'Test'});
assert.deepEqual(plain(transaction.keys),['opacity','presetName']);
assert.deepEqual(plain(transaction.target.savedPresets),[future]);
assert.equal(Store.plan(original,{opacity:original.opacity}).keys.length,0);
assert.equal(Store.equal({a:1,b:2},{b:2,a:1}),true);
assert.ok(Store.matches(transaction.target,transaction.target,transaction.keys));
const restored=Store.restore({...transaction.target,externalChange:123},transaction);
assert.equal(restored.opacity,original.opacity);
assert.equal(restored.externalChange,123);
assert.equal('presetName' in restored,false);
assert.equal(Store.restore({...transaction.target,opacity:99},transaction),null);
const disk=JSON.stringify({bar:{layout:{left:[{id:'isles',...transaction.target}],center:[],right:[]}}});
assert.ok(Store.matches(Store.entryFromText(disk,'isles'),transaction.target,transaction.keys));
assert.equal(Store.entryFromText('broken','isles'),null);
assert.equal(Store.entryFromText(disk,'missing'),null);
console.log('PASS: strict input validation, lossless preset updates, edge clipping, bounded slot discovery, and atomic-update/recovery planning.');

const toDelete = {name:'Delete me',version:1,settings:plain(changed)};
const deletionInput = [future,broken,extended,toDelete];
const deletionResult = Presets.remove(deletionInput,'Delete me');
assert.deepEqual(plain(deletionResult.presets),[future,broken,extended]);
assert.equal(deletionInput.length,4,'Deletion must not mutate the original settings');
assert.deepEqual(plain(Presets.remove([toDelete],'DELETE ME').presets),[]);
for (const builtin of Presets.builtins()) {
  assert.ok(Presets.remove([{name:builtin.name,settings:plain(changed)}],builtin.name).error);
}
assert.equal(Presets.entries(deletionResult.presets).slice(0,6).length,6);
assert.ok(Presets.remove(deletionInput,'Missing').error);
assert.ok(Presets.remove(deletionInput,'Future').error);
assert.ok(Presets.remove([toDelete,toDelete],'Delete me').error);
assert.ok(Presets.remove({},'Delete me').error);
console.log('PASS: personal preset deletion preserves other records and protects all six built-ins.');
