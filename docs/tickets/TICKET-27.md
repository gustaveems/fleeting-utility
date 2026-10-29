# Ticket-27: look pass on the in-game spaces (2026-10-29)

The palettes and references in `docs/references/notes.md`, applied to the spaces you
play in. Captures: `godot --path . -s tools/capture_states.gd` (one PNG per lighting
state) and `tools/capture_layout.gd`.

## The apartment (all its states)
- **The floor** is the reference room's hex patterned tiles: `RoomTiles` paints a
  seamless texture once, in code. It has rosettes of cream, oxblood and slate (the
  palette's tiles #8C3B3B and #3E4F66, worn down a step: at the camera's distance the full
  colours read as a checkerboard), dark grout, every tile a shade off, a few cracked or
  gone to bare concrete. It stays a StandardMaterial: `AtmosphereController` still
  polishes it for the clinic. The kit's concrete normal adds wear.
- **The walls:** damp comes through the plaster (the palette's damp #5A5240). The
  material's detail layer blends it in through a blotchy noise mask, triplanar like the
  rest.

## The atmosphere's modes (`AtmosphereController`)
- **Clinical:** the palette's teal #8FB3B5 in the shadows, the bare bulb's hard white
  #FFF6E0 as the key, a teal background. The floor is the palette's worn pale #B9C4C2 at
  roughness 0.2, still glossy enough to reflect; at 0.22 albedo it read black.
- **Broken** (the ransacked room): ambient lifted 0.24 → 0.34. It's still a dark crime
  scene, but readable.
- **Subdued** (after the reset): ambient 0.1 → 0.3, key 0.5 → 0.9. It was near black; it's
  now dim and drained.
- `ticket07_verify` and `probe_vfx` check against the constants, not literals.

## Already in the palette (checked, unchanged)
The valley (Ticket-25 thinned its fog), the rooftop, the carriage and the park.

## Not yet
- The clinic's corridor reference (a long corridor vanishing to a point) isn't built:
  the clinic is his room, re-lit.
- The damp doesn't grow with the decay yet. It could follow entropy through the mask's
  ramp.
