# fr_helmet_0 source01

Status: Selected source; actual engine composition pending.

Generated using built-in imagegen, one component per call, transparent_background=true. Native output copied byte-for-byte; no resizing, crop, alpha replacement or painted cleanup. Full source canvas 1536×1024; alpha≥128 bbox [60, 213, 1418, 614]; SHA-256 `71a46d934ce7199b1752a3e4df5a13bbe2e66efcdf2e163da90488e24567cc4f`.

## Historical source and observation

- Object/image: Morgan Picture Bible, war hat in upper battle scene, MS M.638 f.23v; 约1244–1254.
- Catalogue: https://ica.themorgan.org/manuscript/page/46/158530
- Official image actually viewed: https://ica.themorgan.org/icaimages/6/m638.023v.jpg
- Manufacture: 图像绘于巴黎；所示铁帽工坊未定.
- Use/context: 13世纪法国图像中的战斗装备；外檐尺寸作像素可读性调整.
- Qualification: 巴黎画本中的当代装备形制；非法国独有，移入骑枪玩法不等于严格比武安全复原。

Broad low iron hat with continuous brim, no person or opaque face plug. Native canvas 1536x1024 and wide silhouette retained. Face canvas deliberately extends below source_region; this is proposed registration and requires actual character composition. Plain iron and invented rivet simplification, not a manuscript tracing.

Reference inputs: eng_helmet_5 only for pixel material/style; structural reference was inspected separately and described in prompt.

## Exact generation prompt

```text
Use case: historical-scene
Asset type: ONE standalone helmet overlay sprite for GALUMU, item fr_helmet_0. Transparent PNG alpha, one component only, square canvas.
Input image 1 is the project's accepted helmet style reference ONLY. Keep its consistent blocky pixel groups, stepped dark contour, upper-left light and shallow three-quarter orientation toward the RIGHT. Do NOT copy its silhouette, gold, enclosed mask or neck collar.
Historical SHAPE observed from Morgan Library MS M.638 folio23v, Paris ca1244–1254: the plain broad-brimmed iron war hat in the upper battle scene. This is an independently drawn historical-game interpretation, not a photograph or tracing.
Subject: a simple low round iron skull bowl with a continuous WIDE CIRCULAR BRIM that slopes down at its sides and stretches clearly in front and behind. A flat, hat-like low silhouette, NOT a conical pointed helmet and not a sallet with an extended tail. Plain dark cool gray iron, three steel tones, a single shallow seam and 3 or4 restrained rivets. NO gold, paint symbols, crown, plume, nasal bar, visor, cheek plates, face guard, ornate engraving or attached mail.
Empty overlay: ONLY the skull bowl and ring-shaped brim are opaque. The large space beneath the brim and in front of the neck must be REAL TRANSPARENT ALPHA for a separate custom face. No black face-shaped plug, no opaque inner helmet hanging down across the face, no skin/eyes/nose/hair/person, no neck or torso. The open chin space connects to the surrounding transparent background.
Composition: shallow three-quarter view facing RIGHT, enough front-facing oval brim to align with a 3/4 face. Center the single component with generous transparent margins; no cropped brim. Its whole silhouette should be horizontally wider than it is high, approximately 1.5 width-to-height. Final helmet frame is at most84x80 game units, helmet and underlying face together; do not elongate the empty helmet into an 80-unit bowl.
Style: disciplined coarse PIXEL ART, as if a roughly70x55 logical sprite enlarged in clear square pixel steps, larger color clusters and fewer details than the ornate reference. Two to six logical pixel planes, restrained gray high lights, no shiny 3D metal, gradients, grain, noise or tiny etched lines. Crisp stepped opaque edges, true transparent background, no backdrop, no drop shadow, no text/label, no sheet, no additional items.
```

## Verification boundary

The agent inspected the generated source image and measured decoded PNG alpha/dimensions. This does not verify in-engine readability, both-facings attachment, face registration, lean, guard/aim extremes, fall rendering or historical physical safety. Those require the parent's serial Godot QA. No claim of hand-authored exact pixel quantization or an exact archaeological reconstruction.

