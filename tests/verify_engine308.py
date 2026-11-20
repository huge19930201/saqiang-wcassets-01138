import base64,hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);report=json.loads((root/'engine308-checks.json').read_text())
assert report['status']=='passed' and len(report['cases'])==13
cases=root/'engine308-cases';assert cases.is_dir()
by={x['case']:x for x in report['cases']}
for name in ['newengine-data-map','newengine-path-map-stale-legacy','oldengine-stale-assets','newengine-different-theme']:
 r=by[name];assert r['summary']['complete'] and r['summary']['written']==r['summary']['itemsVerified']
 oracle=json.loads((cases/name/'expected.json').read_text());folder=cases/name/'output';expected={x['file']:x['base64'] for x in oracle['items']}
 actual={p.relative_to(folder).as_posix():p.read_bytes() for p in folder.rglob('*') if p.is_file() and '_export-info' not in p.parts}
 assert set(actual)==set(expected),(name,set(actual)^set(expected))
 for file,b64 in expected.items():
  raw=base64.b64decode(b64);assert actual[file]==raw and hashlib.sha256(actual[file]).hexdigest()==hashlib.sha256(raw).hexdigest(),(name,file)
r=by['newengine-opaque-pack-only'];assert r['summary']['available'] and not r['summary']['complete'] and r['summary']['opaqueContainer'];assert (cases/'newengine-opaque-pack-only'/'output'/'themebox.dat').is_file()
r=by['newengine-decoded-cache-only'];assert r['summary']['available'] and not r['summary']['complete'] and not r['summary']['expectedKnown'];assert (cases/'newengine-decoded-cache-only'/'output'/'EC308_pixel@2x.png').is_file()
print('ThemeBox 3.0.8: engine routing, exact assets/colors, decoded-cache-only capture, opaque-pack honest status passed')

for name in ['reference-2547','reference-wrong-missing','reference-other-id']:
 r=by[name]; oracle=json.loads((cases/name/'expected.json').read_text()); folder=cases/name/'output'
 actual={p.relative_to(folder).as_posix():p.read_bytes() for p in folder.rglob('*') if p.is_file() and '_export-info' not in p.parts}
 expected={x['file']:base64.b64decode(x['base64']) for x in oracle['items']}
 assert actual==expected, name
r=by['reference-2547']; assert r['summary']['referenceMatched']==2547 and r['summary']['referenceComplete'] and not r['summary']['complete']
r=by['reference-wrong-missing']; assert r['summary']['referenceMissing']==1 and r['summary']['referenceMismatch']==1 and not r['summary']['referenceComplete']
r=by['reference-theme-switch']; assert not r['directoryReturned']
print('Reference: 2547 exact independent bytes, stale cache bypass, wrong/missing rejection and theme switching passed')
