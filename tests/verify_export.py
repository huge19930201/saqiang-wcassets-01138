import json,hashlib,sys,struct
from pathlib import Path
root=Path(sys.argv[1]);folder=root/'test-folder'
assert (root/'exports-done.txt').exists(), 'native export callbacks did not complete'
m=json.loads((folder/'manifest.json').read_text());assert m['count']==12 and len(m['items'])==12
svg=png=bubbles=original_bubbles=0
expected={'ChatRoom_Bubble_HB_Sender_Dark@2x.png','ChatRoom_Bubble_AA_Receiver@3x.png','ChatRoom_Bubble_HB_Sender_Handled@2x.png'}
files=set()
for item in m['items']:
 p=item['file']; assert '/' not in p and '..' not in Path(p).parts and p.lower() not in files
 files.add(p.lower());data=(folder/p).read_bytes();assert hashlib.sha256(data).hexdigest()==item['sha256']
 if item['kind']=='SVG':
  assert data.startswith(b'<svg') and item['original'] and not item['snapshot'];svg+=1
 else:
  assert data.startswith(b'\x89PNG\r\n\x1a\n');png+=1
  if p in expected:
   assert item['original'] and not item['snapshot'] and item['originalNameAvailable'] and item['bubble'];original_bubbles+=1
  else: assert item['snapshot'] and not item['original'], 'unexpected png snapshot: %r (svg=%d png=%d bubbles=%d)' % (item, svg, png, bubbles)
  if item['bubble']:
   bubbles+=1;w,h=struct.unpack('>II',data[16:24]);assert 0<w<=160 and 0<h<=100
assert svg==7 and png==5 and bubbles==4 and original_bubbles==3,(svg,png,bubbles,original_bubbles)
assert expected.issubset({p.name for p in folder.iterdir()})
assert (folder/'icons_filled_camera.svg').exists() and (folder/'page_two_icon.svg').exists()
assert (folder/'recognition-diagnostic.json').exists()
assert (root/'single-bubble.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
print('Native named bubble export passed: 3 exact ChatRoom_Bubble HB/AA/Handled original PNG names; anonymous conflict stays snapshot; 7 SVG; A/B/A cumulative 12 unchanged')
