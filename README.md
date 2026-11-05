# Bionic Commando Amiga — Demo source

One playable level; free demo.
Amiga conversion by WHittyApps. This repository has an independent history.
Demo excludes later-level maps, actor placements and camera tables. Shared sprite/music banks retain the data linked by its jukebox and renderer.

Build from the included prepared assets:

```sh
python3 build.py --rom /path/to/your/kick31.rom
```

Requires Python 3 and `vasmm68k_mot`; `xdftool` additionally builds 880 KiB ADFs.
Outputs appear under `amiga/releases/`. Both reduced and full-colour executables
and native WHDLoad packages are built. WHDLoad17+ is installed separately.
AGA/68020, 2 MB Chip and 8 MB Fast are required. Amiberry reduced uses 4x;
full colour uses 64x plus immediate blits. PAL gameplay remains 50 Hz.
CPU memory timing remains enabled so those clock multipliers apply.

Music options: Arcade, original Amiga replay, and sampled stereo C64 recordings.
C64 banks are included with HD/WHDLoad builds; ADF uses Arcade/Amiga music.
The full edition reuses Round1 music in Round2 because no Round2 recording was supplied.

Start/Return begins. A fires, B grapples, X jumps. O/B on the title opens options,
jukebox and high scores. Arrows move; Ctrl fires; Space grapples; X jumps.
Escape quits; native WHDLoad also accepts F10. Preferences save on clean exit.

This is an active conversion. Some native enemy attack states and later-level
background machinery remain in development; a complete arcade reproduction is
not claimed. Report emulator settings and the chosen graphics edition with bugs.

Original game/artwork: Capcom. Arcade composition: Harumi Fujita. Original
Amiga replay/arrangements: Tim/Mike Follin. C64 recordings: Tim Follin,
with the high-score theme credited to Rhythm Method Band in the supplied metadata.
Third-party artwork and music retain their original rights. No blanket
open-source licence is granted for those assets by publishing this source.
System ROMs, original arcade ROM dumps and source MP3s are not included.
