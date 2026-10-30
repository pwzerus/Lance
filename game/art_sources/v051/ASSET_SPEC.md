# DEV-051 equipment sprite production contract

Owner: Codex appearance/art subtask. Runtime code, catalogue, manifest assembly and Godot runs belong to the parent task. Existing assets remain intact. Scope is four collections (eng/fr/de/it), six helmet IDs and six armor IDs per collection: 48 independent new components, followed by the separately agreed lance presentation work. Country labels identify collection/use themes and do not establish an exclusive national manufacturing style.

## Native source and metadata

Each distinct component uses one separate built-in imagegen call. No CLI or generic multi-item sheet substitutes for the individual assets. A selected output is copied byte-for-byte to `game/assets/art/pixel_v051/<item_id>.png` and retained as `game/art_sources/v051/<item_id>_source01.png`; a revised image gets source02 before any accepted candidate change. Prompt, actual official reference links, collection number, date, manufacturing/use qualifications and observations are recorded with the source. Reference museum photographs are inspected from temporary files and are not shipped as runtime assets.

The prompt requests a square canvas, but the actual first outputs are 1254×1254; dimensions are measured, not inferred from the prompt. No automatic raster resize, crop, alpha replacement or painted cleanup is performed. Native alpha is retained. Runtime `source_region` is the measured alpha≥128 rectangle, using `[x,y,width,height]` with source origin at upper left. The original full canvas remains available for corrections.

Per-item JSON beside each candidate supplies:

- `id`, `slot`, `image_path` (`res://assets/art/pixel_v051/<item_id>.png`).
- `source_region`, `source_size`, SHA-256 and alpha evidence.
- `open_face`; an open helmet also needs `face_rect` in normalized 0–1 coordinates relative to `source_region`, for the real player face below the transparent opening. Closed examples use `[0,0,0,0]`.
- `draw_size`: helmet default `[70,80]` (wide examples at most 84×80); torso `[94,104]`.
- Historical/source fields, complete prompt path, and explicit source-versus-runtime validation status.

The parent assembles `game/data/equipment_art_v051.json`; this subtask does not edit it or the renderers. Legacy IDs and save compatibility remain parent-owned.

## Consistent appearance and attachment

Chest fronts use a very shallow three-quarter view toward the right while remaining visible to camera. Helmets face right at the corresponding shallow angle; both combat facings require actual runtime inspection. Upper-left light, dark stepped outer edges and a few organized steel/cloth/leather color groups match the current rider. The final game size determines detail: about 70×80 logical pixels for heads and 94×104 for torsos. Small rosettes or engraved borders are secondary to recognizable silhouette and plate construction. The output is AI-generated pixel-art-style source, not a claim of a perfectly quantized manual pixel grid.

Torso local draw frame is `(-47,-94)..(47,10)`, with the head/neck centered near `(0,-94)` and moving shoulder interfaces retained by the existing rig. Torso art contains no fixed head, arms, hands, legs or shield. Short mail/cloth underlap at neck/armholes and short waist defenses are allowed to prevent attachment gaps. Shoulder armor that needs to rotate with an arm must not be baked as a complete arm into this torso. The existing universal colored chest overlay must not obscure new structure.

Head frame is normally `(-35,-151)..(35,-71)`. Closed helmets contain no baked person. Open helmets must leave actual transparent face space; a dark painted face hole is insufficient for a selectable face drawn underneath. Face opening and neck alignment are measured from each accepted image, with Godot composition checked before bulk acceptance.

## Historical and visual acceptance

First sample pair: eng_helmet_5 and eng_armor_5, based on the inspected Greenwich Clifford garniture, 1586, Met 32.130.6a–y;36.98.1. Validate these two in actual size, both facings, forward/back lean and weapon/shield poses before expanding the same framing to the remaining collection. An early open helmet provides a separate face-layer gate.

For every later item, the researcher first supplies a specific observed object or manuscript image, not just a generic period label. A manufacturing region, owner/use region and present museum location are separate facts. Early shared mail/nasal-helmet structures remain shared historically; individual silhouettes, closure details, documented tailoring and game-adapted cloth organization can make variants readable without claiming invented national exclusivity. Cross-period collection slots are not a complete contemporary reconstructed outfit.

Batch acceptance compares all six helmets or six torsos together for more than color changes: silhouette, visor/face coverage, crown/neck shape, plate segmentation, torso volume, waist shape, closure and fabric/metal layering. Gold decoration alone cannot justify a distinct item. Close helmets must not erase character customization data; they merely cover the face.

Source-side checks: file exists, PNG decodes, actual alpha/background, measured visible bbox, no cropped crest/waist, no extra body parts or text, original historical structure retained, palette/cluster consistency and unique prompt/source metadata. Runtime gates: exact-size readability, shoulder/neck continuity, open-face registration, both directions, lean, shield movement, impact/fall and shop preview. These runtime checks are not marked passed by the art subtask; the parent runs Godot serially with QA saves.
