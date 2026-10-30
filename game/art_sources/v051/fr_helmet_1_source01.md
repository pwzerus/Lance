# fr_helmet_1 source01

Status: Selected source; actual engine composition pending.

Generated using built-in imagegen, one component per call, transparent_background=true. Native output copied byte-for-byte; no resizing, crop, alpha replacement or painted cleanup. Full source canvas 1122×1402; alpha≥128 bbox [93, 94, 967, 1239]; SHA-256 `b298290ef41ca907dd9eba3faf00aeb16aa1054a2e0a96ebd42a0af34c1b4d4e`.

## Historical source and observation

- Object/image: Morgan Picture Bible, flat-topped enclosed helm, MS M.638 f.23v; 约1244–1254.
- Catalogue: https://ica.themorgan.org/manuscript/page/46/158530
- Official image actually viewed: https://ica.themorgan.org/icaimages/6/m638.023v.jpg
- Manufacture: 图像绘于巴黎；所示钢盔工坊未定.
- Use/context: 法国13世纪图证；绘画为结构来源，不是存世整盔的测绘.
- Qualification: 同页不同人物并非同一种民族制服；颜色和呼吸孔排列按可读性改编，不编造专属制式。

Low flat-topped enclosed helm; prominent seams and breathing holes are enlarged for readability. No face inside eye slits. Rivet arrangement is game interpretation of manuscript structure, not a measured surviving helm.

Reference inputs: eng_helmet_5 only for pixel material/style; structural reference was inspected separately and described in prompt.

## Exact generation prompt

```text
Use case: historical-scene
Asset type: ONE isolated transparent helmet component, GALUMU item fr_helmet_1.
Style reference image: use ONLY the stepped pixel clusters, upper-left light and three-quarter-to-RIGHT framing. Do not reuse its gold, crest, deep neck collar or pointed visor.
Historical observed reference: Morgan MS M.638 fol.23v, Paris1244–1254. A thirteenth-century low FLAT-TOPPED enclosed great helm made from riveted plates. Its flat circular crown, vertical cylindrical sides, flat face panel and distinct right-angle brow distinguish it from both a nasal cap and the later pointed sugarloaf helm. Low barrel/cylinder with the face fully encased, two very narrow simple eye slits separated by a central flat nose bridge, one row of 5 broad breathing holes on one cheek and a single vertical plate seam/rivet row. Bottom ends at lower jaw, not a fantasy huge shoulder bucket. No pointed projecting muzzle, no later hinged visor, no comb or flared sallet tail.
Cool plain steel with broad medium-gray light planes and dark blue-gray shadow. At most two simple riveted seam bands, NO brass/gold edging or ornaments, no crown, cross painting or fleurs-de-lis. This low equipment is plain functional iron.
Empty equipment only: a closed helmet OVERLAY, no human eyes or face inside slits, no neck skin/hair, no torso, shoulders, chainmail cape, mannequin or pedestal. Eye slits may be dark recesses. Small dark rim interior is allowed but no face/person.
View: very shallow THREE-QUARTER facing RIGHT, front face plate clearly visible to camera with a smaller right side plane. Full component centered with transparent outer margin, approximately85% of canvas height, 0.80 width-to-height; no cropping.
Pixel art: BIG intentional low-res square blocks, roughly70x80 logical sprite enlarged; larger simpler color clusters than the ornate reference, 3 or4 steel colors, crisp stair-step edges and a handful of large readable rivets. No soft gradient, airbrush, photo/3D render, dense speckles or engraved noise.
Exactly ONE complete helmet on genuinely transparent alpha, no checkerboard pixels, text, labels, extra items, museum background, floor shadow, blood, atlas or border.
```

## Verification boundary

The agent inspected the generated source image and measured decoded PNG alpha/dimensions. This does not verify in-engine readability, both-facings attachment, face registration, lean, guard/aim extremes, fall rendering or historical physical safety. Those require the parent's serial Godot QA. No claim of hand-authored exact pixel quantization or an exact archaeological reconstruction.

