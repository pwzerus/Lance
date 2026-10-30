# fr_helmet_4 source01

Status: REJECTED candidate; not runtime.

Generated using built-in imagegen, one component per call, transparent_background=true. Native output copied byte-for-byte; no resizing, crop, alpha replacement or painted cleanup. Full source canvas 1374×1145; alpha≥128 bbox [172, 78, 1138, 1050]; SHA-256 `b459c9d284c6b0254148719f2395216b0aebf7420f1511c0b59fd697d748d379`.

## Historical source and observation

- Object/image: Sallet, 04.3.227; 约1475.
- Catalogue: https://www.metmuseum.org/art/collection/search/21982
- Official image actually viewed: https://images.metmuseum.org/CRDImages/aa/web-large/DP101947.jpg
- Manufacture: 可能法国或佛兰德；工坊未定.
- Use/context: 15世纪头盔；不混成德式超长尾或后世莫里昂盔.
- Qualification: 可能法国或佛兰德；短尾形制并非法国专利，游戏重新整理铆孔，不复制腐蚀斑。

Rejected after source-side visual inspection: visor projects into pointed muzzle, bowl/comb and deep mask do not match the low rounded Met sallet. Preserved for failure history; source02 replaces it.

Reference inputs: eng_helmet_5 only for pixel material/style; structural reference was inspected separately and described in prompt.

## Exact generation prompt

```text
ONE standalone transparent helmet sprite for GALUMU fr_helmet_4. Historical shape observed: Met04.3.227, possibly French/Flemish circa1475 sallet. LOW smooth rounded steel bowl, SHORT rear neck tail only, long LOW narrow horizontal eye slit in an integrated front visor, small forward rolled brow edge, modest cheek coverage. Whole silhouette broad and low, clearly distinct from pointed bascinet or a long German lobster-tail sallet. Front visor is CLOSED, no face/hair/eyes/person. Plain polished-gray steel with 3 or4 broad tonal planes, single side rivet and rolled edges; no gold, crown, plume, pointed muzzle, fantasy horns, heavy neck collar or chainmail cape. Historical object's rust and damage are not reproduced. Shallow3/4 toward RIGHT; visor/front to the right, short tail to left. Intended logical sprite about78x65 pixels enlarged in crisp coarse square steps, large color clusters, upper-left light, dark clean contour. Style input ONLY for pixel material and lighting, do not copy its gold. Single component centered on real transparent alpha with margin, no torso/neck, black backdrop, checkerboard, gradient, photorealism, tiny engraving, floor shadow, text or atlas.
```

## Verification boundary

The agent inspected the generated source image and measured decoded PNG alpha/dimensions. This does not verify in-engine readability, both-facings attachment, face registration, lean, guard/aim extremes, fall rendering or historical physical safety. Those require the parent's serial Godot QA. No claim of hand-authored exact pixel quantization or an exact archaeological reconstruction.

