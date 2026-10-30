# fr_armor_4 source01

Status: Selected source; actual engine composition pending.

Generated using built-in imagegen, one component per call, transparent_background=true. Native output copied byte-for-byte; no resizing, crop, alpha replacement or painted cleanup. Full source canvas 1254×1254; alpha≥128 bbox [209, 38, 855, 1169]; SHA-256 `cd4d98d38b59c34257ebc687cfd1b6833cb78f9cd1a9c4b8b3af974c5763f588`.

## Historical source and observation

- Object/image: Armour of the Dauphin, G118; 约1540；制作约1536–1547.
- Catalogue: https://www.musee-armee.fr/en/collections/museum-treasures/armour-of-the-dauphin.html
- Official image actually viewed: https://www.musee-armee.fr/fileadmin/_processed_/4/3/csm_Armure_du_dauphin_en_entier_9cdb7a0799.jpg
- Manufacture: 米兰；可能Filippo与Francesco Negroli.
- Use/context: 未来亨利二世的军用护甲；游戏不复制整套甲和所有宫廷徽记.
- Qualification: 米兰制造、法国王太子亨利关联；馆方认为用于军事，不把意大利工坊误称法国制造。

Dark steel with broad silver bands and simplified paired dolphin/crescent-like marks, long convex abdomen, narrow waist and short articulated fauld. More center rivets and idealized band geometry than source: decorative interpretation, not a Negroli facsimile. Milan manufacture distinguished from French owner.

Reference inputs: eng_armor_5 only for pixel material/style; structural reference was inspected separately and described in prompt.

## Exact generation prompt

```text
ONE isolated torso armor component for GALUMU, no person, TRUE transparent alpha. Style reference ONLY for consistent pixelcontour/lighting/frontthreequarterRIGHT; do NOT copy reference peascod sharp belly or gold petal skirt. Full torso front visible, sideplane narrow. No head, neck skin, arms, hands, pauldrons, shouldershells, legs, shield, sword, mannequin, stand or backdrop. Big open armholes and centered neck, shortunderlining allowed. Waist terminates with VERY SHORT articulated fauld only, no hangingthightassets. Designed94x104 logicalpixels enlarged into clear COARSE squareclusters withfewsteeltones, upperleftlighting. No glossy3D, smoothgradients, filigree noise, denseengraving, text, checkerboard, floor shadow, atlas or extraitems.
Historical form observed: Musée de l'Armée G118 Armour of the Dauphin, Milan circa1540 for futureHenryII. Front cuirass has a LONG ROUNDED GENTLYCONVEX ABDOMEN and narrow waist, NOT a sharply pointed Elizabethan peascod. Highplainrolledneckrim, smootharmopenings, horizontalarticulatedfauld3broadcurvedlames. Surface almost BLACKENEDSTEEL with 4broadSILVER VERTICALBANDS running shoulders towaist and curvingaroundbelly. Distinguishthecomposition as black-and-silver, NO gold, bluegold, giantcentersunmedallion, redcloth. Only a pair of very simple mirrored dolphin/crescent motifs formed by broad silverblocks in upperchest; reference's complex engraving deliberately simplified. Wideupperchest, lowerroundedbreast graduallytaperstowaist; curvesandboldbands define shape. This ismilitaryarmor, not fantasyparade. Standalonearmlessheadlesstorso.
```

## Verification boundary

The agent inspected the generated source image and measured decoded PNG alpha/dimensions. This does not verify in-engine readability, both-facings attachment, face registration, lean, guard/aim extremes, fall rendering or historical physical safety. Those require the parent's serial Godot QA. No claim of hand-authored exact pixel quantization or an exact archaeological reconstruction.

