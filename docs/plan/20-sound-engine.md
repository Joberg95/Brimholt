# 20 - Sound engine

**Effort:** L  **Needs from you:** approve CC0 sound sources before anything is downloaded

## Request
Sound for immersion: weather, attacks, monsters and more.

## Today
There is no audio.

## Steps
1. **Sources.** CC0 only (for example Kenney audio packs, freesound CC0), each with a license file
   and a `CREDITS.md` row, like `assets/third_party/`. Ask before downloading.
2. **Engine.** `game/audio/sound.gd`: buses (Master, Music, Ambience, Effects, UI) with volume
   settings saved in the client settings; a pool of `AudioStreamPlayer2D` for positional effects
   and a few `AudioStreamPlayer` for ambience and UI. Events from the host (`_handle_events`)
   map to sounds: hit, miss, spell kinds, death, level up, loot, coins, footsteps on terrain types.
3. **Ambience.** Driven by `weather.gd` and the region: rain loop, thunder with lightning, wind
   in the mountains, birds in woodland by day, crickets at night, town murmur.
4. **Monsters.** A sound set per monster `look` (wolf howl, rat squeak, golem grind), on
   aggro and death.
5. **Music** later, optional.
6. Settings: volume sliders in the Controls window; a mute key.

## Tests
Unit: every event kind maps to a sound or none; the audio pool never exceeds its size. Headless
tests run with the dummy audio driver.

## Done when
Combat, weather and towns have sound, with volume settings.
