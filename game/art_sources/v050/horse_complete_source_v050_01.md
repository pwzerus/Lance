# DEV-050 完整骑乘马母版 01

- Date: 2026-10-30 UTC.
- Asset owner: Codex appearance/art subtask; runtime code remains owned by root.
- Tool: built-in `image_gen.imagegen`, transparent background requested; no CLI/API fallback.
- Native generated output: `C:/Users/yifei/.codex/generated_images/01a1858f-9c1e-75c2-8e55-c624311db411/exec-18b6b9ec-6613-46b7-8eae-c6571d6c78cc.png`.
- Preserved source: `horse_complete_source_v050_01.png`.
- Runtime candidate: `../../assets/art/pixel_v050/horse_complete_skin_v050_01.png`.
- SHA-256: `af974af28cc6d7aa56909009528e9e214626152c546aba7e0f345de88fb97512`.
- Both files are byte-identical copies of generated PNG. No crop/repaint/resize/alpha processing or Python image edit was performed. Older v041/v049 sources and all runtime scripts were preserved.

## Research and actual visual inspection

Read the project's jousting-pixel-art and imagegen skills, art-direction and current design decisions. Inspected v049 `skin05/frame_205.png` and `release-smoke01/04_arena.png`, the old component sources, and the selected v049 variant02. The visible problem was no longer only an open seam: a short, strongly folded front chain and separate neck texture made the body read as an assembly. This new plate therefore begins with a full natural standing silhouette rather than tracing the old poses.

Primary anatomical source: [University of Minnesota Extension — Conformation of the horse](https://extension.umn.edu/agriculture/animals-and-livestock/horse/conformation-of-the-horse), Dawn Melbye, reviewed2024. Both actual linked images were opened/downloaded to temporary inspection paths and viewed: [body thirds photograph](https://extension.umn.edu/sites/extension.umn.edu/files/styles/caption_large/public/Thirds-horse.png?itok=YxjDAFqJ) and [head/neck proportions photograph](https://extension.umn.edu/sites/extension.umn.edu/files/styles/caption_large/public/Head-neck-conformation.png?itok=dQQal9WQ). They informed a balanced body, neck tied high into chest, long lower limbs and ordinary weight-bearing joint alignment. The page describes a neck around1.5 head lengths and compares withers height to shoulder-to-buttock body length. These are drawing guides, not universal exact ratios or proof of a particular medieval breed. Reference photographs are not copied into the game repository or runtime asset directory.

Input1 to imagegen was the actual UMN body-thirds photograph for anatomy only, with its text/lines/background explicitly excluded. Input2 was `../../assets/art/pixel_v049/horse_continuous_skin_v049_02.png` for color and saddle/tack style only. The generated animal and pixels are an original stylization rather than a photograph used as game art. The source is not claimed to reconstruct a particular historical horse breed or saddle artifact.

## Exact prompt

```text
Use case: stylized-concept
Asset type: ONE complete unified pixel-art horse source sprite for a 2D jousting game, designed for continuous mesh animation. Landscape canvas 1536 x 1024, true transparent alpha background.
Input image 1 (real horse side-view photograph) is an ANATOMY/PROPORTION REFERENCE ONLY. Study the real horse's long straight lower limbs, compact forearm musculature, high shoulder attachment, correct hind stifle/hock geometry, and continuous neck/chest. Do not copy labels, lines, white background or photographic texture. Turn the horse to FACE RIGHT.
Input image 2 (the chestnut pixel-art component) is a COLOR AND MEDIEVAL TACK STYLE REFERENCE ONLY. Reuse the warm chestnut family, dark mane/tail, red saddlecloth with gold edging, and brown saddle character. Do NOT copy its old body proportions, swollen upper limbs, spherical haunch, or cut-off composition.
Primary request: redesign the ENTIRE horse as one coherent natural riding horse in strict side profile, facing right. Include head, ears, muzzle, neck, mane, withers, shoulder/chest, back and barrel, hindquarters, tail, and TWO COMPLETE NEAR-SIDE LEGS including hooves. This is a rigging plate: the FAR-SIDE TWO LEGS ARE OMITTED entirely, so exactly one foreleg and one hindleg are visible. Never blend an extra hidden leg into either visible leg. The horse is athletic and substantial enough to carry a knight, not a tiny pony, giant draft horse, greyhound, dog, chicken or frog.
Pose/anatomy: calm square neutral standing pose, not galloping, crouching, pawing or folding the legs. Front leg descends from the actual shoulder and chest, the elbow is high near the lower chest, and the long forearm, carpus/front knee, cannon, fetlock and hoof form a nearly straight weight-bearing column. Keep substantial muscle above the carpus, but no swollen human biceps and no elbow-like right angle halfway down. The hind leg grows from the haunch: hip inside the upper hindquarter, stifle comes modestly FORWARD near the flank, gaskin goes modestly BACK to the hock, then a long mostly vertical cannon to fetlock, short sloped pastern and hoof. No exaggerated zigzag or deep crouch. Slim but strong tendons below knees/hocks, realistic hoof size. Belly center has no leg roots. Neck blends through the withers and chest into the barrel as continuous anatomy, with no seam, black cutoff border or detachable head/neck piece. Long sloping muscular neck, modest correctly sized head, restrained horse eye. Continuous rear thigh, no circular rump spiral or ball-shaped joint cap. Broad subtle 3-4-tone muscle planes, not striped bodybuilding muscles.
Composition: whole animal comfortably inside the frame; body axis horizontal; hooves share a ground line approximately y930 with no ground drawn. Withers around y340, belly around y590, plenty of leg length and separate open transparent space beneath the belly. Shoulder-to-buttock body length should be approximately comparable to withers-to-ground height. Neck length about one and a half head lengths. Useful composition guide, not drawn labels: fore shoulder around (1090,475), elbow (1030,580), carpus (1050,740), fetlock (1050,870), forehoof (1080,930); hind hip (500,430), stifle (590,580), hock (460,735), fetlock (480,875), hindhoof (510,930). Head and neck occupy upper-right; tail hangs rear-left without covering the near hind leg. Keep the saddle small enough to leave shoulder and hip anatomy readable, one red/gold cloth and brown leather saddle. Bridle straps may be present, but NO loose reins joining head to saddle, no rider, no stirrup dangling across a leg.
Style: crisp readable detailed PIXEL ART, deliberate stepped silhouettes and large organized color clusters. Consistent pixel density across head, neck, body and limbs. Dark brown outline on true outer silhouette only, restrained warm upper-left light, no airbrushed gradients, no glossy pseudo-3D rendered muscles, no photographic fur. Must fit the existing medieval pixel-art game. No anatomy diagram aesthetics.
Hard exclusions: no separate body parts, no additional horses or panels, no far-side legs, no severed limbs, no mechanical joints, no cartoon round knee caps, no text or numbers or labels or bone marks, no grid, no ground or cast shadow, no checkerboard painted into the alpha. Original coherent horse design, not a collage of reference fragments.
```

## Observed result

The source is1536×1024 and includes one unified right-facing head/neck/chest/barrel/haunch, tail, and exactly two near-side complete legs including hooves. No far leg, rider, loose reins, anatomy label or ground was observed. The front chain is close to a normal standing column; the hind stifle and hock turn in opposite directions without the former extreme crouch. Head and neck coat/outline flow into the shoulder continuously. The existing red/gold/brown saddle character is retained. The generator added a white blaze and white stockings from the general riding-horse appearance; these are coherent but differ from the old asset's markings.

This is an AI-generated pixel-art-style mother plate, not a claim of strict manual pixel-grid authorship or a completed gait animation. Ear clearance is only about12 source pixels. Haunch shading remains stylized, and the moving result must be assessed independently from this neutral pose.

## Alpha / pixel evidence

Read-only System.Drawing inspection: Format32bppArgb,1536×1024; alpha0=1007994, alpha1..254=564870, alpha255=0, maximum254. Opaque-looking coat/white-sock samples alpha252–253, empty background samples0. Alpha>=128 inclusive bounding box: (67,12)..(1493,992). The fore hoof ROI ends at y992, rear at y986: six source pixels of sole difference must be resolved by each foot's own support target, not by distorting the torso. No opacity rewrite was performed.

Examples of alpha spans (inclusive source x) confirm separate hind limb/tail and only two visible limbs: y730 has tail118..250, hind281..379, fore978..1051; y800 has tail108..238, hind297..357, fore988..1039. A rectangular far-hind extraction that begins too far left would include tail pixels; the JSON instead supplies a contour-aware UV polygon.

## Binding handoff

The adjacent runtime JSON contains source-pixel saddle, withers, neck/head, fore shoulder/elbow/carpus/fetlock/coronet/sole and hind hip/stifle/hock/fetlock/coronet/sole anchors, suggested continuous source regions and far-leg UV polygon. Bone-center estimates are visually placed with about±10–15px tolerance, not skeletal imaging. Hoof-bottom y values are alpha measurements.

Suggested uniform conversion: source saddle(749,326) maps to game Model.HIP(-18,-168); scale180/666≈.270270 puts fore sole at GROUND12. Use uniform x/y scaling to keep the whole horse proportions coherent. Retarget each full chain to the observed lengths and its own foot contact: do not feed this standing source back into the old equal68+68 chain and re-create the folded frog-leg silhouette. Neck/shoulder and limb roots should share mesh topology and continuous skin weights; the far limbs may reuse the source's leg-only geometry behind the body. No v049 head or lower-leg patch is necessary for the new silhouette.

Source plate was viewed after copying. No Godot import/run, gait rendering, collision/hoof verification or player trial was performed by this art subtask; root owns integration and evidence.
