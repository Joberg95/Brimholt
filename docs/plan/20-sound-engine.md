# 20 - Sound engine

**Effort:** L  **Needs from you:** approve CC0 sound sources before anything is downloaded

## Request
Sound for immersion: weather, attacks, monsters and more.

## Today
There is no audio. A first attempt (commit 4bc3025, reverted) built the engine below with CC0
packs from Kenney (RPG Audio, Impact Sounds, Interface Sounds), OpenGameArt (artisticdude's RPG
Sound Pack, rubberduck's 80 CC0 RPG and creature SFX), and Freesound previews. It was taken out
because most sounds did not match what they played for; the loot sounds were the worst. The town
murmur (Freesound 578072, "medieval_village_atmosphere" by ramonmineiro) was fine. Pick each
sound by listening, with you, before wiring it in; the engine code can come back from 4bc3025.

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
