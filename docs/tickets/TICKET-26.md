# Ticket-26: characters (dressed, faceless)

Scoped with Alain on 2026-10-28:
- **base characters + tint**, chosen over downloading Quaternius's modular outfit packs or
  building garments in code;
- **faceless stays**, so everyone remains without a face, as the story's calls are
  voices only.

## What changed
`StreetFigure` still plays the Universal Animation Library's clips on the UAL skeleton,
but it no longer shows the mannequin:
- **The body:** a Universal Base Character (Quaternius, CC0, already in the asset
  pipeline: `assets/third_party/quaternius_chars/`) on the same skeleton (both have the
  same 65 joints, so the skin binds by bone name). Men and women: `body` 0 or 1, or −1 to
  mix a crowd by where each figure stands, seeded so it's the same every run. He and the
  friend are always men.
- **Hair** by class (`HAIR`): parted for the suits, buns and long hair, buzzed for him and
  the guards, beards among the poor. The veiled rich have none (the veil covers it).
- **Clothes** by class (`OUTFIT`), from one shader (`CLOTH_SHADER`): a top, trousers below
  the hips and a skin-toned head, split by height on the posed body. The cloth is matte,
  and the bodysuit's musculature is softened.
- **Faceless:** the eyes and brows are left out, and the head's shading is flattened, so
  features melt into one matte form under the hair. Five skin tones vary the crowd.
- **The fallback:** without the base pack it's the tinted UAL mannequin; without UAL it's
  the primitive figure. Same as before.

## Notes
- **The friend** is dressed in a camel top and dark trousers, pulled away from skin tones
  (the first pass read as bare skin). The friend is always a man, the same body in every
  scene: the game's own line is "He sold me out." Flip it in `_dress_body` if the friend's
  story changes.
- **Limits:** these are fitted base layers, not full outfits (no coats, collars or shoes).
  Real outfits need a pack on this rig. Quaternius's only outfit pack is fantasy; his
  modern Ultimate Modular packs are on an older rig and would need retargeting.
- **Street frame rates** are in the same range as before (`tools/fps_prologue.gd`).
