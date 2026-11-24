"""Archive and relocate a verified DEV-113 candidate; never overwrite output."""
from pathlib import Path, PurePosixPath
import sys, zipfile, hashlib, json, re
root=Path('E:/GALUMU/builds').resolve()
version=sys.argv[1]
assert re.fullmatch(r'0\.4\.60-c[1-9][0-9]*',version)
bundle=root/('LanceAndLaurel-v'+version)
archive=root/(bundle.name+'-Windows.zip')
relocation=root/('DEV113 '+version+' 中文 空格验包')
assert bundle.is_dir() and not archive.exists() and not relocation.exists()
manifest=json.loads((bundle/'build-manifest.json').read_text(encoding='utf-8-sig'))
assert manifest['version']==version
expected={v['path'] for v in manifest['files']}|{'build-manifest.json'}
actual={p.relative_to(bundle).as_posix() for p in bundle.rglob('*') if p.is_file()}
assert actual==expected
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for relative in sorted(actual):z.write(bundle/relative,bundle.name+'/'+relative)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for name in z.namelist():
  parts=PurePosixPath(name).parts
  assert not PurePosixPath(name).is_absolute() and '..' not in parts and parts[0]==bundle.name
  assert (relocation/name).resolve().is_relative_to(root)
 relocation.mkdir()
 z.extractall(relocation)
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest().upper()
for entry in manifest['files']:
 path=relocation/bundle.name/entry['path']
 assert path.stat().st_size==entry['bytes'] and sha(path)==entry['sha256']
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'relocated_bundle':str(relocation/bundle.name),'manifest_files_verified':len(manifest['files']),'crc_passed':True},ensure_ascii=False,indent=2))
