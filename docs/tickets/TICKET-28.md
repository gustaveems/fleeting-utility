# Ticket-28: Phase D, sound

Scoped with Alain on 2026-10-29:
- **sources:** Kenney CC0 audio plus code, with Cyberwave for the synthetic side;
- **scope:** an ambience per place, the in-head calls, music, and the prologue's mix.

The lines stay subtitles: no spoken words.

## Sources
- **Kenney CC0** (impact, interface, rpg, sci-fi, ui; 8.9 MB): fetched by the asset
  pipeline, group E (`download_assets.py --groups E`; it follows Kenney's current
  download-ID flow), and placed under `assets/third_party/kenney_audio/<pack>/` by the
  manifest. `place_and_import.py` now skips entries this machine hasn't downloaded but
  has placed.
- **Cyberwave** (Fab, NortonTre): its licence allows use in projects, but never
  redistribution, so the files stay in the Fab zip. **Re-pack it for Windows:**
  `python -I tools/assets/check_assets.py --pack-fab ../fleeting_utility_fab.zip`.
- **Code:**
  - `VoiceSynth`: a formant babbler for the voices and the party's walla, and the
    carriage's rails;
  - `ProceduralAudio`: the placeholders behind everything.

## The bank (`RealSounds.bank()`)
Recordings where they exist on disk, synthesis where it does better, the placeholders as
the fallback cue by cue. Families play as `AudioStreamRandomizer`, so steps and taps
vary.
- **Footsteps:** tiles, grass, the park's concrete, the carriage's floor, the roof's
  teak.
- **Short sounds:** a soft tap for soothing; UI errors for "denied"; the call opening and
  closing; the morning chime; glass on the roof; the door when he goes out; cloth for the
  brush; a heavy blow for the defib.
- **From Cyberwave:**
  - the decay drone (a sub bass) and the hesitation rumble;
  - the stings (statue: a high reverb; betrayal: a low one);
  - the party's music, from the bar's speaker;
  - the score: the dream's synth pad, *Omegon* for the realisation, a sub bass after
    the reset.

## The director (`AudioDirector`)
- **New beds in their worlds:** the carriage (rails over a rumble), the rooftop (the
  party's murmur and its music by the bar, a glass now and then).
- **Footsteps:** one per 0.42 m of real movement (none for teleports or while he's held),
  on the surface of the world he's in.
- **Voices:** under every line, a murmur in the speaker's voice for the line's length.
  - On a call it's phone-band, inside his head (UI bus, past the crash filter), opening
    and closing with a tone.
  - In the room it's on the SFX bus; the neighbour comes muffled through the wall.
  - His thoughts are silent.
  - The game's voices render behind the boot splash, the film's behind its black
    warm-up.
- **Music:** the dream's pad while he dreams; the realisation when the dual visions end;
  the end bed after the reset or waking alone; silence in the room, the clinic and the
  climax.

## The film (`PrologueSound`)
- **Beds by stage:** the town's dusty wind, the city's drone, the street's crowd and
  drone.
- **The train:** inside, its rumble and the rails; whooshes as it passes.
- **The colossus:** a sub swell under the reveal, a long tail through its legs.
- **Voices:** the radio, the PA and the street under every subtitle
  (`Prologue.line_spoken`), and the final call with its tones.
- **The street:** his footsteps on the walk, the car going by, the fight's blows.

## Checks
- `tools/probe_sound.gd` (14): the bank, footsteps and teleports, call tones and buses,
  silent thoughts, the carriage bed, the dream's music.
- `probe_prologue`: the film's sound, every line voiced.
- **Audition:** `godot --headless --path . -s tools/export_sounds.gd` writes every
  synthesised sound and voice to `tools/out/sounds/`.

## Not yet
- Mixing by ear. Every level is set by reasoning, not listening: **Alain, play it with
  sound on** and tell me what's too loud, too quiet or wrong.
- Real recorded ambiences (field recordings) would beat the synthesised room tone, wind
  and walla; Freesound CC0 would need your account.
