# T aperture correction · built-in imagegen

Reference: production it_helmet_3.png, the prior generated source01 (second generation overall); no museum image supplied. Selected output: exec-7251117f-2fd8-4395-9212-0be1214e178c.png. Native copied bytes, no raster repaint by scripts.

Prompt: Edit this existing game helmet sprite precisely, preserving the same helmet silhouette, proportions, three-quarter facing-right orientation, metallic pixel cluster shading, all rivets and the T-shaped opening outline. REQUIRED FIX: the entire black T-shaped face opening must be completely transparent alpha=0, like a cut-out hole, so the separate player's face can show through behind it. Remove the black fill inside the horizontal eye opening and its vertical nose-mouth slit. This is an empty wearable helmet asset, no human face, no eyeballs, no head, no liner in the aperture. Keep the outer background completely transparent as it is. Keep all existing steel intact and the bottom neckline/opening transparent. No text, no shadow or floor, no crop of helmet. The only visual change is cutting the T hole out to transparency.

Read-only alpha samples: (850,800), (850,1000), (700,640) are zero; (820,750) alpha21 near rim. Previous candidate was alpha253 inside mouth. Runtime registration must be checked separately.
