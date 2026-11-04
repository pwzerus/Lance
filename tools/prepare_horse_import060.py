"""Write import settings only; never edits generated image pixels."""
from pathlib import Path
import hashlib
import json
import re
root = Path(__file__).resolve().parents[1]
base = root / 'game/assets/art/pixel_v050/horse_complete_skin_v050_01.png.import'
params = base.read_text(encoding='utf-8').split('[params]', 1)[1]
params = params.replace('process/size_limit=0', 'process/size_limit=768')
for name in ('grey', 'flaxen', 'black'):
    source = f'res://assets/art/horse_coats060/{name}.png'
    target = f'res://.godot/imported/{name}.png-{hashlib.md5(source.encode()).hexdigest()}.ctex'
    text = f'[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="{target}"\nmetadata={{"vram_texture": false}}\n\n[deps]\nsource_file="{source}"\ndest_files=["{target}"]\n\n[params]{params}'
    (root / f'game/assets/art/horse_coats060/{name}.png.import').write_text(text, encoding='utf-8')
catalogue = (root / 'game/scripts/core/catalogue.gd').read_text(encoding='utf-8')
mapping = catalogue.split('const HORSE_COATS = ', 1)[1].split('}', 1)[0]
keys = re.findall(r'"(horse_[^"]+)"', mapping)
horses = [i for i in json.loads((root / 'game/data/equipment_expansion.json').read_text(encoding='utf-8')) if i['slot']=='horse']
assert set(keys)=={i['id'] for i in horses}
print('All 10 horse IDs mapped; import settings prepared, no engine launched.')
