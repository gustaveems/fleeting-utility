# Reference notes

Mood references only; never ship them (they are copyrighted stills). This is Claude's
reading (2026-10-19). Alain: correct anything that is wrong and add one line per image
on why you picked it.

| File | Use | Take from it |
|---|---|---|
| `1674120956740.jpeg` (2077 Night City, night) | Billboards | Animated faces and logos are the brightest thing in the sky: the promises |
| `BladeRunner2049_JohnNelson_ITW_07B.jpg` | City massing | Teal-grey brutalist monoliths with no neon; oppressive, endless |
| `Cyberpunk2077-Heywood_exteriors_overview…avif` | Flyover framing | High aerial view, low sun through haze, megatowers over crammed low blocks |
| `IMG_6383…jpg` (Tyrell facade miniature) | The corporation | Rust-brown monumental wall, endless lit windows; brand of billboards and ambulance |
| `Wu-Lei…Zegna…webp` | The dream, and the campaign | Misty birch path, leaf litter. A luxury fashion ad, so the valley is sold imagery (STORY.md) |
| `cyberpunk-2077-night-city-1.avif` (daytime) | Billboards | The ads never switch off, even in daylight |
| `dc282cb1…jpg` (voxel building diorama) | **Art style** | Isometric cutaway building on black, neon accents, cracked street: our camera |
| `in-page_image_002.jpg` (2049 Vegas outlets) | The dying town | Dead commerce in orange dust, rust and faded murals |
| `one-thing…br2049…webp` (BR 1982 street) | Street-level arrival | Layered, filthy, hazy, neon in the dirt |

### Batch 2 (2026-10-19)
| File | Use | Take from it |
|---|---|---|
| `Colosse_de_Rhodes_(Barclay).jpg` (engraving) | Statues | Human colossus, arm raised, on a stone plinth above water; old-print rendering for how the dream "remembers" |
| `images (3).jpeg` (gold Colossus render, skyline behind) | Statues / city | Gleaming giant straddling water before a modern skyline: proposed corporate golden colossus |
| `images.jpeg` (Soviet beige tower) | His building / the town | Beige concrete, every balcony enclosed differently by tenants (irony vs. "No alterations"); overcast light |
| `istockphoto-1135106441…jpg` (abandoned room) | **Apartment interior** | Two-tone walls split at a dado line (nicotine yellow over grey-green), hex patterned tiles, damp peeling ceiling, net curtain, cast-iron radiator, lone sink |
| `images (1).jpeg` (hospital corridor) | Clinical ending | Cold teal, single bare bulb, a long corridor vanishing to a point, worn floor |
| `images (2).jpeg` (blinding white) | Resuscitation | Full overexposure at the jolt, then the teal clinical room resolves |

### Batch 3 (2026-10-20)
| File | Use | Take from it |
|---|---|---|
| `images (4).jpeg` (Shanghai Transrapid) | Maglev exterior | Sleek white, rounded nose, blue + orange stripes, T-beam guideway: the future as advertised |
| `sonat-samir-cp-sub2.jpg` (grimy subway car) | Maglev interior | Ads over the windows, steel poles, graffiti and litter, fluorescent strip, neon "DO NOT CROSS THE LINE": the future as lived |

## Batch 4: the walk layout (Alain's sketch, 2026-10-20)
| File | For | Take |
|---|---|---|
| `sketch_walk_layout.png` | Prologue walk, top-down | Left: the metro line and its path, in front of massive buildings (nothing visible behind them). He descends from the station to the road, walks up it past the rundown buildings on his right, turns right at the corner, and arrives at his apartment complex. Built as `PrologueAvenue.PATH`. |

## Third-party assets (CC0)
| Pack | Source | Where | Used for |
|---|---|---|---|
| Downtown City MegaKit (Standard) by Quaternius, CC0 1.0 | quaternius.itch.io/downtown-city-megakit (downloaded 2026-10-21) | `assets/third_party/quaternius_downtown/` (git-ignored: 190 MB; re-download to rebuild) | `CityKit` facades on the avenue, his street and his complex |
| 13 Poly Haven models (1k), CC0: chainlink fence, roller shutters 01/03, utility box 02, exterior AC unit, concrete road barrier, industrial pipes 01, rusted wheel rim 02, tool cart, painted wooden cabinet, marble bust 01, fancy picture frame 01, cigarette pack | polyhaven.com (2026-10-21) | `assets/third_party/polyhaven/<id>/` | Street dressing (`PrologueAvenue._build_props`), the town's fence; cabinet/tool cart reserved for the apartment |
| Poly Haven *old_bed_frame* (CC0) and Poly Pizza *Easel Large Leaning* by reyshapes (CC0) | polyhaven.com, poly.pizza (2026-10-21) | `assets/third_party/polyhaven/old_bed_frame/`, `assets/third_party/polypizza/easel/` | The apartment's bed (the cot) and the easel; the door is the Downtown kit's `DoorFrame_Wooden` + `Door_1` |
| Universal Animation Library 1 + 2 (Standard) by Quaternius, CC0 | quaternius.itch.io (2026-10-21) | `assets/third_party/quaternius_anim/` | `StreetFigure`: the rigged mannequin and its clips |
| Universal Base Characters (Standard) by Quaternius, CC0 | quaternius.itch.io (2026-10-21) | `assets/third_party/quaternius_chars/` | Base bodies + hair (reserved: Standard has no clothes) |
| LowPoly Cars ("Realistic Car Pack") by Quaternius, CC0 | quaternius.itch.io (2026-10-21) | `assets/third_party/quaternius_cars/` | The taxi that passes, parked cars |
| 13 Fab items (CC-BY / Fab Personal): graffiti tram, rooftops 1/3, mega tower, neon signs, noodle kiosk, high-rise 06, sci-fi skyline backdrop, flying/cyber/police cars, Cyberwave audio | fab.com via Alain's account (2026-10-21) | `assets/third_party/fab/<name>/` | City landmarks, horizon and `FlyingTraffic`; the avenue's kiosk, neon, police car; the town's tram; the prologue sound bed. See `CREDITS.md` |

## Palettes (starting values, to tune)
| World | Base | Accent |
|---|---|---|
| City | teal-grey `#2E3B3F` → `#5F7478` | ad magenta `#E0329B`, cyan `#36D6E7` |
| Decay (town, corporation, rotting room) | rust `#7A4A2E`, dust `#B9875A` | sodium `#E8A040` |
| Dream | mist `#C9C4BA`, birch `#D9D4C8` | leaf gold `#C9822F` glowing through fog, not saturating the frame |
| Apartment interior | walls `#C8B46A` over `#6F7B6E` (dado split) | tiles `#8C3B3B`, `#3E4F66`; damp `#5A5240` |
| Clinical | teal `#8FB3B5`, worn floor `#B9C4C2` | bare bulb `#FFF6E0`; the jolt: pure white overexposure |

## Still wanted
Sound and music · the friend's look · the fashion campaign itself (luxury ads using nature/heritage) · Alain's one-line notes per image.
