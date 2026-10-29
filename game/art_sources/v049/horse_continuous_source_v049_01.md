# v0.4.9 连续马体母片生成记录

- Task: DEV-049
- Date: 2026-10-29
- Tool: built-in `image_gen.imagegen`; no API/CLI fallback.
- Input role: `../../assets/art/pixel_v041/horse_atlas.png` is a style/tack reference, not an image to overwrite.
- Tool argument: `transparent_background: true`.
- Original tool output: `C:/Users/yifei/.codex/generated_images/01a1858f-9c1e-75c2-8e55-c624311db411/exec-60c42eca-64f3-41d7-b39f-24e1866b211e.png`.
- Immutable project copy: `horse_continuous_source_v049_01.png`.
- Runtime candidate: `../../assets/art/pixel_v049/horse_continuous_skin_v049.png` (byte-identical copy, not yet imported or bound by the asset author).
- SHA-256, both copies: `5894d64a8c22ea893171cb840bb6e5d3a1976b35680fc658d018b15d3e29f4d8`.
- No bitmap crop, repaint, recolor, resize, alpha rewrite, or Python image edit was performed.

## Exact prompt

```text
Use case: stylized-concept
Asset type: a production source plate for a 2D pixel-art jousting horse, to be skinned as ONE continuous mesh.
Input image 1 is a STYLE AND TACK REFERENCE only (the existing horse atlas). Create ONE new connected sprite, not an atlas and not a collection of detached parts. Keep its chestnut coat, red saddlecloth with gold border, brown leather medieval saddle and straps, warm upper-left lighting and dark brown pixel-art outlines.
Primary request: ONLY the horse's side-view trunk plus its TWO NEAR-SIDE UPPER LEGS, facing right. Hindquarters on the left, shoulders on the right. The trunk, near shoulder/upper foreleg, and near haunch/upper hindleg are ONE seamless connected skin silhouette with continuous muscle shading. There must NOT be a line, circular cap, or closed outline separating either upper leg from the trunk. At each leg root the belly silhouette flows naturally into the limb silhouette; the coat's connected warm brown planes cross the attachment without a black seam.
Anatomy/composition: long horizontal horse torso, strong but not round-ball hindquarters, broad shoulder blending into the chest. Back and saddle occupy the upper half. The front upper limb descends from the right shoulder, slight natural backward turn at the elbow, then forward-down to the carpus (the horse's front knee). The hind upper limb descends smoothly from the left haunch, forward to the stifle and back to the hock. Both limbs use a modest neutral standing bend, not a dramatic gallop. End the front limb at the carpus and the hind limb at the hock, with short plain coat-colored overlapping tabs for later lower-leg attachment, no black end caps. The lower outline is open between the two limbs. Entire connected silhouette fits within the canvas with transparent margin. Torso is roughly twice as wide as it is deep. Shoulder/haunch muscle is long and tapering, never a ball attached to a stick.
Style: crisp authored-looking PIXEL ART with deliberate stepped contours and organized medium-size pixel color clusters, a limited warm chestnut palette, readable anatomy at a game display width of about 250 pixels. Match the reference's red/gold saddle detail, but simplify noisy texture and avoid airbrush gradients or photorealism. Native sprite, no perspective floor and no poster.
STRICT EXCLUSIONS: NO head, NO neck, NO mane, NO tail, NO far-side legs, NO lower legs below the front carpus or rear hock, NO hooves, NO rider, NO person, NO arms, NO ground, NO cast shadow, NO text, NO labels, NO arrows, NO grid, NO UI. Only the connected trunk and two near upper limbs. This is an intentionally incomplete rigging component, NOT a complete horse illustration. True transparent alpha background; do not draw a checkerboard.
```

## Observed output and limitations

The generated plate is one visible connected chestnut torso, saddle and two near-side upper legs. No head/neck/tail/far legs/hooves/rider/text were observed. The two leg roots have continuous color planes and do not have the old atlas's closed black attachment contours. The image includes short tabs distal to the wrist/hock; the runtime mesh should end at or overlap around those joints instead of treating the tabs as new complete lower legs.

This is an AI-generated pixel-art-style source plate, not a claim of manually authored exact-grid sprite animation. The source uses visibly stepped clusters, but an actual game-scale nearest-filter render and full gait cycle are still required. Root/shoulder proportions, the broad carpus/hock, and how the old lower legs match must be reviewed in engine. No Godot run or gameplay verification was performed by the asset author.

## File/alpha inspection

Read-only `System.Drawing.Bitmap` inspection reported 1536 x 1024, Format32bppArgb. Whole-image counts: 861633 pixels alpha 0; 711231 pixels alpha 1..254; zero pixels alpha 255; maximum alpha 254. The high-alpha (>=128) bounding box is inclusive (120,50)..(1405,971). Samples outside the horse and between its legs have alpha 0. Interior coat/saddle samples have alpha 253..254, so the generated skin is slightly translucent (about 99.2-99.6% opacity) rather than exactly opaque. This alpha was preserved; no painted background or checkerboard was observed. Transparent pixels retain RGB color, which is not visible under normal alpha blending.

## Suggested binding

See the adjacent runtime JSON for visually estimated landmarks. These are source pixels with top-left origin and y down, not automatically detected or gameplay-verified anatomical coordinates. Preserve a rigid saddle/back/barrel region. Use connected shared mesh vertices and at least three transition rows across shoulder/haunch to the upper limb. Avoid stretching one quad from saddle to carpus/hock. Preserve original Gait joint targets, world hoof placement and collision points; map the new skin onto those targets. A selected source root can sit inside the body because that region blends with the rigid trunk; it need not be an exposed cut edge.
