# Audio

All sounds are synthesised from scratch by `scripts/audio/make_game_sfx.py` (no samples, nothing to license), converted to .ogg with ffmpeg and uploaded to the Nexus Hollow Studios audio library. The asset ids are in `Config.Sounds`. The server only ever sends a sound NAME over the `Sfx` remote; the client looks the id up (`src/client/Audio.luau`).

| name | when | what |
|---|---|---|
| hatch | an egg hatches in your base | pop plus a rising sparkle |
| steal | you grab an egg from a nest | quick whoosh and a two-note blip |
| roar | the guardian wakes | low growl |
| caught | a guardian catches you | bonk and a falling sad trombone |
| deliver | an egg arrives in your base | four-note fanfare |
| horn | an event starts or an admin announces | three-note horn for every player |
| limited | a new limited egg goes on sale | bell glissando |
| coin, click | reserved for UI | ping, tick |
| music | always | a 35-second looping marimba tune, kept quiet |

To change a sound: edit the generator, run `python3 scripts/audio/make_game_sfx.py out/`, convert, upload to Creator Hub > Audio, paste the new id into `Config.Sounds` (a test checks every id has the right shape). Roblox moderates audio uploads, so a new id may be silent for other players until it clears.
