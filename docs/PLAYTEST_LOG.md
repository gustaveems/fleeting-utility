# Playtest log

Alain's playthroughs, newest first. Each entry is the raw list of what went wrong or
needs work, sorted by severity. A line is ticked when a commit fixes it, and the fix is
noted next to it. The first fix pass (2026-10-30) is in `docs/tickets/TICKET-29.md`.

## 2026-11-03: second playthrough (after Ticket-29), up to day 5

Not reached: the park.

### Blockers
- [ ] **The metro while overloaded breaks the dream and traps him.**
  - **What happened** (day 3): he took the metro while overloading and collapsed. The
    dream showed the metro carriage, with the buildings flying past.
  - **On waking:** stuck in the apartment, body-blocked between the easel and the
    opposite wall. He can't reach the bed, the door or the kitchen.
  - **Suspected:** the collapse fires mid-ride and `MetroRide` never ends the ride.
    The carriage WorldRoot stays active under the valley, and his movement bounds stay
    the carriage's (`_saved_extents` isn't restored), so the room clamps him into a
    strip.
  - **To fix:** no collapse while riding, or end the ride first. A probe should ride
    overloaded and check the wake.

### Broken
- [ ] **Characters clip and duplicate.**
  - Several copies of the same NPC.
  - He phases through things and gets clipped.
  - Some player models collide with each other.
- [ ] **The film's opening shots:** the camera clips in and out of the train.
- [ ] **After the restaurant scene, the buildings and their window panes flash a lot**
  (flicker, likely z-fighting or LOD popping). It makes the walk slightly laggy.

### Look
- [ ] **The night train switches model.** The film's maglev is ours, but the night
  train after dinner is the Fab graffiti tram. Use one train family.
- [ ] **Not textured yet:**
  - the metro station;
  - the inside of the metro carriage;
  - the city (in game and the evening, beyond the film's towers).
- [ ] **Neon lettering** is still too much and too janky, even after `SignType`.
- [ ] **The apartment** could do with more work.

## 2026-10-30: first playthrough with sound, up to day 5
All fixed in `9b806c5` (Ticket-29):
- [x] the camera whipping in the film;
- [x] the train into a wall;
- [x] the train, the towers and the statues untextured;
- [x] the lettering;
- [x] the clothes;
- [x] constant shakes;
- [x] the camera too far;
- [x] the metro entrance;
- [x] the restaurant;
- [x] new players lost.
