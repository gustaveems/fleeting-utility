# Ticket-22: the campaign advert (beat 2)

Story: `docs/STORY.md`, *"The valley is nowhere"*: its imagery reaches him through
luxury advertising, a fashion campaign selling misty birch forests, fallen leaves and old
blood-marked stones as heritage. Beat 2 has the image among the billboards over the
maglev (*"Players will see that image again in his dreams."*). Scoped with Alain on
2026-10-26: **beat 2 only (the prologue billboard)**, with the image **drawn in code**.

## The image
`CampaignArt` is a shader painting that any board can wear at any aspect
(`CampaignArt.material(aspect)`):
- **The scene:** a gold haze over a misty horizon, birch trunks in depth (nearer ones
  sharper, far ones lost in the mist), leaf litter, and the path running to the
  vanishing point.
- **The stones:** three rough-hewn standing stones beside the path, blood pooled on their
  tops and dripping down in thin runs of different lengths.
- **The model:** a slim dark figure walking away up the path. Leaves fall in the air.
- **The finish:** a warm grade and a vignette. It's authored in display colours and
  converted to linear, so the renderer doesn't wash it out.

It's the valley he'll dream of, sold first.

## Where
**The prologue's HERITAGE COLLECTION billboard** (`PrologueScript.CAMPAIGN_BILLBOARD`, the
"through the train" gaze shot) wears it, with the brand small and low
(`CAMPAIGN_BRAND`: *"HERITAGE COLLECTION / Authentic origin."*) while the radio sells it.
`probe_prologue` checks that the board wears the shader.

## Not yet (proposed, not picked)
- **6:** the wall screen's rotation includes the advert; the first canvas: *"I know this
  place."*
- **15:** the HERITAGE tag on the friend's shoes.
- **18:** the first vision flash is the advert itself, then the real colossi: *"It was an
  advert."*
- The campaign billboards of Ticket-21 still show his canvas, not this image (by design:
  it's his copy).
