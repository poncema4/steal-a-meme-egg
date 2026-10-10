# Audio

All sound is licensed Creator Store audio (free for any experience), not generated: the two music loops are Distrokid tracks
(Playground Adventure for the Safe Zone, Obby Rush BGM for the Wilds, cross-faded by the player's `Zone` attribute) and the
effects are short community sounds picked from the trending lists (egg crack, whoosh, boing, fail, success, coin, level-up, UI click).
The asset ids and the title of each are in `Config.Sounds`. The server only ever sends a sound NAME over the `Sfx` remote; the
client looks the id up (`src/client/Audio.luau`).

To change a sound: find one in the Creator Store (create.roblox.com/store/audio, sort by trending, search by keyword), paste its
asset id into `Config.Sounds` (a test checks every id has the right shape). Prefer short effects (under 2 seconds) and music that
loops cleanly.
