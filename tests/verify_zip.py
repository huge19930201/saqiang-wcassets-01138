import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
 assert z.testzip() is None
 assert z.namelist()==['icons/voice_regular.svg','bubbles/气泡@3x.png','manifest.json','empty.txt']
 assert z.read('bubbles/气泡@3x.png')==bytes([0,1,2,0,255,4,5])
 assert z.read('icons/voice_regular.svg')==b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>'
 assert z.read('empty.txt')==b''
 assert z.read('manifest.json')==b'{"items":[1,2]}'
 assert all(i.flag_bits & 0x800 for i in z.infolist())
print('ZIP independent-reader CRC, UTF-8 names, empty file and binary payload: passed')
