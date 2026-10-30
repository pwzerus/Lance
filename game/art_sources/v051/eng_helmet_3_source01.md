# eng_helmet_3 — source 01

Built-in imagegen transparent output; source/runtime PNG copied unchanged. Native: `C:\Users\yifei\.codex\generated_images\01a1858f-9c1e-75c2-8e55-c624311db411\exec-8d9d519e-27e5-470c-9b57-a9b76b1a81ce.png`. No CLI or raster edits. Canvas1173×1341; alpha≥128source region `[94,72,1009,1206]`. A face sample at `[704,939]` is alpha0. Proposed complete32×40Face.draw_face canvas is source `[420,475,780,800]`, normalized in runtime JSON; this extends behind opaque metal and must be tested with all face shapes.

Historical source: [Met 29.150.13](https://www.metmuseum.org/art/collection/search/26451). 15世纪晚期；可能意大利；法勃艮第式样。可能意大利制造的法勃艮第风格；在英有同类，不证明此件为英制；原物修补甚多。 The official image https://collectionapi.metmuseum.org/api/collection/v1/iiif/26451/57003/main-image was downloaded temporarily and actually viewed. Existing repair/corrosion was not depicted as random noisy damage. Sidewall depth and component boundaries are stylized adaptations. Runtime face registration remains parent-owned validation.

## Exact prompt

```text
Use case: historical-scene
Asset: ONE open-faced SALLET helmet sprite for GALUMU, eng_helmet_3, true transparent PNG square canvas. Input1 is the inspected real Met29.150.13 late15th-century Franco-Burgundian-style sallet, possibly Italian; use its exact broad construction. Input2 is the game's open-bascinet PIXEL STYLE only; never copy its long vertical cheek walls.
Create a clean serviceable steel game adaptation, shallow3/4 front facing RIGHT, MIRROR the museum photo's direction. Distinctive pointed pear-like cranial bowl leaning toward the rear, SEPARATE forward brow plate, clearly separate SHORT outward-flared neck-tail plate at the rear. Rounded sides converge to the pointed skull peak. The front brow plate wraps low over the forehead and upper eye line, but the LOWER FRONT FACE stays OPEN, with no projecting hounskull visor, no solid chin plate, no long German-style rear tail, no cheek doors or neck gorget. Tail extends behind and is kept compact, visibly separate from the brow by small attachment rivets. Keep silhouette a sallet, not the tall open bascinet in reference2.
CRITICAL face compositing: empty helmet OVERLAY, no head/eyes/skin/hair/mannequin. The area beneath the forward brow where a face will be drawn MUST BE TRUE TRANSPARENT ALPHA extending down to open chin, not opaque black interior or back wall. Preserve broad enough front opening for a separate pixel face, with any back/side metal naturally masking only the rear side. No added face or beard.
Plain silver-gray steel, 3-4 broad organized highlight/shadow planes, few clear rivets; no gold, corrosion noise or decorative bands. Match the game's coarse PIXEL ART at final70x80units: stepped edges, large logical pixel clusters, upper-left light, no airbrush or photoreal texture. Whole helmet uncropped in transparent margins; no pedestal, stand, shoulders, chest, text, diagram, extra helmet or sheet. Historical repairs are not replicated as noisy cracks; reference provenance/repair caveat stays in metadata.
```

