# fr_helmet_2 source01

Status: Selected source; actual engine composition pending.

Generated using built-in imagegen, one component per call, transparent_background=true. Native output copied byte-for-byte; no resizing, crop, alpha replacement or painted cleanup. Full source canvas 1216×1293; alpha≥128 bbox [159, 40, 1020, 1236]; SHA-256 `bce90bbbf301c69d3d1e6254d24fcedb7779ece220455ff92227f075dddc5596`.

## Historical source and observation

- Object/image: Hounskull bascinet, H21; 约1350–1380（具体馆签）.
- Catalogue: https://www.musee-armee.fr/en/collections/museum-treasures/hounskull-bascinet.html
- Official image actually viewed: https://www.musee-armee.fr/fileadmin/_processed_/c/7/csm_Bacinet_a_bec_de_passereau_e80b0ac0d6.jpg
- Manufacture: 西欧；工坊未知；锻铁.
- Use/context: 晚14世纪头部防护结构；无已知具体法国佩戴者归属.
- Qualification: 馆签产地西欧，不写法国制造；尖吻别称是后世分类，页面概论年代不替代具体标签。

Tall rearward skull, projecting pointed visor, temple hinge and large breaths distinct from flat great helm. Neck attachment is shortened and simplified; it is not a complete historically reconstructed aventail. Western European object, not proven French manufacture.

Reference inputs: eng_helmet_5 only for pixel material/style; structural reference was inspected separately and described in prompt.

## Exact generation prompt

```text
Use case: historical-scene
Asset: ONE isolated helmet sprite, GALUMU fr_helmet_2. True transparent alpha.
Input image is accepted project STYLE ONLY: cool dark steel, deliberate stepped pixels, upper-left light, shallow three-quarter toward RIGHT. Do not copy its gold or Renaissance silhouette.
Historical form actually observed: Musée de l'Armée H21, Western Europe 1350–1380, hounskull bascinet. A tall slightly rearward-pointed skull, long angular projecting SNOUT visor with narrow horizontal eye slit near the brow, pointed muzzle drops below the face, dense but only 6–8 LARGE readable breathing holes on one side, a single distinct circular hinge at temple. Small aventail attachment rivets along lower bowl, but NO huge attached chainmail cape. The elongated visor must clearly differ from a flat great helm and rounded closed burgonet.
Plain functional gunmetal iron: 3 broad steel values, no gold edging, plume, crest, fantasy horns or engraved scrollwork. Whole helmet visible, no cropped muzzle. Closed visor contains no human eyes, skin, hair, face, neck or torso.
Composition: three-quarter front view facing RIGHT with projecting muzzle toward right; crown and lower neck edge centered to fit the same helmet overlay system, around 0.85 width-to-height. Independent component and generous transparent margins.
Style: coarse disciplined PIXEL ART, designed at roughly70x80 logical pixels enlarged in obvious square clusters. Big planar highlights and dark contour; simplify small rust pits and ornamental details into a few blocks. No gradients, photorealism, bevelled3D, grain, stippling, checkerboard, black backdrop, floor shadow, words, border, atlas or multiple items. No skin or body parts. One transparent equipment sprite only.
```

## Verification boundary

The agent inspected the generated source image and measured decoded PNG alpha/dimensions. This does not verify in-engine readability, both-facings attachment, face registration, lean, guard/aim extremes, fall rendering or historical physical safety. Those require the parent's serial Godot QA. No claim of hand-authored exact pixel quantization or an exact archaeological reconstruction.

