# de_helmet_3 source02 — separate sallet and bevor correction

Selected revision, replacing source01 as runtime candidate. Source01 PNG/prompt remain intact as a failed historical-construction candidate.

## Specific correction and evidence

- Object: Met29.158.6a,b, sallet with independent bevor, Germany1480.
- Official catalogue: https://www.metmuseum.org/art/collection/search/34258
- Official image actually viewed: https://images.metmuseum.org/CRDImages/aa/web-large/29.158.6a_005june2015.jpg
- Existing source01 had a large temple pivot and connecting arm joining the lower face plate to the upper bowl, contradicting the separate-bevor brief. In this pass both the original PNG and locally downloaded temporary Met photo were opened with view_image before editing.
- Source02 removes that pivot/connector. The upper sallet and lower broad throat/chin protector have distinct bounded edges; the separate lower piece does not attach at an ear hinge. Combined into one overlay file for the existing rig, not a claim that the real two pieces were one object.
- Remaining game adaptation: slit width, tail length and lower-flare size enlarged/simplified for logical70×80 readability; historical rust omitted. No person, face or whole body is baked into the equipment.
- Native source 1254×1254, alpha≥128 bbox [158, 79, 999, 1132], SHA-256 `b05a9de2bc5fdbc700bcdf39496bf47d8a02e00843ca096712e0c14efa47e38d`.
- Alpha counts: zero 843532; 1–254 727733; 255 1251. No pixel edits, resize, crop or alpha replacement. Exact output copied to source02 and runtime PNG.
- Tool: built-in imagegen, transparent_background=true. Reference1 is existing game sprite for style/layout; reference2 is public-domain Met object photo for historical shape only. The museum photo is temporary and is not shipped as a game asset.

## Exact generation prompt

```text
Edit the FIRST image only, equipment sprite de_helmet_3. Preserve its coarse pixel-art material, cool plain steel, upper-left light, 3/4 toward RIGHT orientation, empty equipment-only appearance, transparency and centered full silhouette. SECOND image is the historically authoritative Met29.158.6a,b sallet-and-bevor photograph for construction.
Correct a specific historical mistake: the lower chin/throat protection is a SEPARATE BEVOR, NOT the hinged lower face of a close helmet. REMOVE COMPLETELY the large round pivot at the left temple and ALL arms/rods/plates connecting the lower face plate up to the temple. Do NOT replace this hinge elsewhere. No ear pivot, side hinge, visor hinge or strap bridge from helmet into bevor.
Reconstruct TWO overlapping but independently bounded shapes:
1. Upper SALLET: smooth rounded, slightly peaked plain bowl, subtle center ridge and short swept-back rear tail. Front brow lip almost straight and modest, not a long beaked visor.
2. Separate BEVOR below: a broad SINGLE rigid chin/throat plate with a straight high horizontal upper edge just under brow, a faint central vertical ridge, widening downward into a gently flared chest/neck edge. It rises from the throat/front, not from an ear hinge. Show its upper edge as an independent rolled line across front, disappearing behind the sallet on the side. The only gap between them is a THIN dark horizontal viewing slit. The separate plate's sides end BELOW the side rim of the sallet; no circle/hinge at their overlap.
Follow the SECOND photo's close overlapping construction and broad lower protector, simplified and slightly shortened to fit the modular sprite. Do not portray an open jaw, giant grin or long muzzle. Small plain rivets may remain on bowl/rear tail only; no decorative round hinge on the lower plate.
Retain a single combined overlay component (both actual equipment parts drawn together), no face, human head, skin, eyes, hair, torso or mannequin. Transparent background. Crisp enlarged low-resolution square pixel clusters, only3–4 steel shades and dark stepped outline, no photographic rust texture, gradients, gold, captions, checkerboard, floor shadow, sheet or additional items. This is a tightly scoped correction to the separate helmet/bevor construction.
```

## Verification scope

Source02 was actually displayed and inspected after generation; erroneous temple joint is absent. PNG decode/bbox/alpha/hash measured read-only. Parent must reimport and render actual game composition; no Godot, EXE, OS-input or player acceptance was run by this subtask. The game does not add an independently moving visor/bevor system.

