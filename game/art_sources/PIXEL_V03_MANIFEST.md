# v0.3 像素风重绘记录

2026-10-24，通过内置 image_gen 编辑原始分件并生成两张新背景。保留原始文件；当前游戏引用 `assets/art/pixel_v03/`。未复制商业游戏素材。

生成图具备更清晰的阶梯轮廓、大片色块与较少写实纹理，但不宣称已达到严格32色、固定逻辑网格或人工逐像素完稿。非整数关节旋转仍可能闪烁。实际双向组合见 `docs/development/screenshots/v03/04_equipment_gallery.png`。

| 当前资产 | 生成输出文件名 | 参照 |
| --- | --- | --- |
| rider_atlas.png | exec-b5b1a060-7dc5-49dd-948f-fc59131e491a.png | 原骑手图集，编辑 |
| equipment_eras.png | exec-12fb5f5f-ab46-4b3d-b37e-c4fc83cd8315.png | 原时期图集 + 新骑手风格参考 |
| nasal_head.png | exec-9276aef8-4a7f-435e-962a-f38a690a9877.png | 原护鼻盔头像 + 新骑手参考 |
| shield_fields.png | exec-d642eed5-fc96-44b4-b389-7a52e527d7b0.png | 原空白盾面 + 新骑手参考 |
| tournament_field.png | exec-aaebe48c-5910-4145-b4a2-c8e8b717e7e2.png | 新生成 |
| campaign_field.png | exec-e479706f-9679-4255-bb87-58bf5f21dfd9.png | 新生成 |

生成原图目录：`C:/Users/yifei/.codex/generated_images/01a16537-8b7f-7df0-9b98-d350cd639afb/`。项目副本已纳入源码快照。

## 基础骑手编辑说明

基础骑手的生成调用提示词未另存于本地；会话中保留调用记录。以下是制作要求摘要，不冒充逐字原文：保持原图画布、分件位置、透明间隔和朝向，改为粗像素色块、深色轮廓、少量材质明暗，减少噪点和渐变；保留蓝红骑士、近远手臂、马匹分件和装饰，使既有裁切仍可使用。

## 其余五次调用的完整提示词

### eras

```text
Production game sprite edit. Image 1 is the target atlas; Image 2 is ONLY the approved pixel-style reference. Redraw Image 1 into the SAME crisp chunky 1990s pixel-art style as Image 2. Preserve all target part positions, overall canvas and bounding rectangles, transparent spacing, orientations and equipment silhouettes so existing crop coordinates work. Flat deliberate square pixel clusters, limited coordinated palette (about 32 colors), 3 shades per material, dark outlines, simplified regular mail pattern, readable gold trim and silhouettes. No photorealistic texture, no painterly noise, no gradients, antialiasing, text, labels or background. Genuine transparent alpha. Looks like a 256-pixel logical atlas enlarged nearest-neighbor, NOT a high resolution digital painting. Keep exactly four isolated torso armor pieces across the top row and four helmet/coif pieces across the bottom row. The torso types are green coat of plates, smooth breastplate, fluted plate, and black/gold decorated plate. Keep all eight separate parts in their exact original grid. Use large clean material color clusters.
```

### nasal

```text
Production game sprite edit. Image 1 is the target atlas; Image 2 is ONLY the approved pixel-style reference. Redraw Image 1 into the SAME crisp chunky 1990s pixel-art style as Image 2. Preserve all target part positions, overall canvas and bounding rectangles, transparent spacing, orientations and equipment silhouettes so existing crop coordinates work. Flat deliberate square pixel clusters, limited coordinated palette (about 32 colors), 3 shades per material, dark outlines, simplified regular mail pattern, readable gold trim and silhouettes. No photorealistic texture, no painterly noise, no gradients, antialiasing, text, labels or background. Genuine transparent alpha. Looks like a 256-pixel logical atlas enlarged nearest-neighbor, NOT a high resolution digital painting. Keep the single three-quarter helmeted head facing right in exactly its original position. Make the face a simple readable pixel face and beard, helmet broad slate-gray clusters with gold nasal ridge, chainmail a sparse regular checker pattern. Render as if the cropped head were only 32x48 logical pixels. Do not render individual hairs or realistic skin.
```

### shields

```text
Image 1 is the target shield atlas and Image 2 is ONLY pixel-style reference. Redraw Image 1 in authentic chunky low-resolution pixel art, matching the simple palette, outlines and pixel clusters of Image 2. Preserve exactly the four shields' original positions, sizes, angles, overall square canvas and transparent spacing so the original crop rectangles work. Exactly four BLANK heater shield fields in a two by two grid: blue top left, red top right, ivory bottom left, ochre bottom right, all with gold rims. No crests or symbols or text; heraldry is drawn by the game. At most 4 shades per shield material, simple large square clusters with stepped silhouette, sparse rivets, no fine wood grain, no noise, no realistic shading, no gradients or antialiasing. Entire atlas like a 192x192 logical image enlarged nearest neighbor. True transparent alpha.
```

### arena

```text
Production background for a side-view medieval jousting pixel-art game, wide landscape 16:9. Authentic deliberately low resolution pixel art like a 480x270 logical image enlarged with nearest-neighbor square pixels. Restricted 32-color palette, flat clustered shading, clearly stepped silhouettes, no gradients, blur, photoreal noise, painterly or 3D detail. A 12th-13th century European tournament field: warm ochre sand lower half, a low wooden spectator stand and simple blue/ivory/red heraldic banners in the middle distance, restrained green hills and a few stone castle towers on upper left, pale warm sky. Calm atmospheric background with lower saturation than the riders. Bottom half an open continuous riding field, no foreground rail (game draws that), no foreground people, no horses or riders, no weapons, no text, symbols, UI or logos. Avoid dense decorative clutter. Visibly crisp modest pixel game scenery rather than an AI fantasy painting.
```

### war

```text
Production background for a side-view medieval jousting pixel-art game, wide landscape 16:9. Authentic low resolution pixel art like 480x270 enlarged nearest-neighbor square pixels. Restricted coordinated palette of muted slate, sage green, ochre and ivory. Flat stepped pixel clusters with hard edges, simple distant silhouettes, no photoreal noise, smooth gradients, blur, painterly or 3D detail. 12th-13th century European countryside encounter: lower half flat open grass-and-earth riding field, sparse grass tufts, distant low stone wall and ruined square tower on upper right, forest and subdued rolling hills in middle distance, overcast sky upper third with big simple clustered clouds. No foreground rail (game draws it), no foreground people, no horses or riders, no weapons, no bodies or blood, no text, UI or logos. Lower contrast than combat characters, readable uncluttered scene.
```

