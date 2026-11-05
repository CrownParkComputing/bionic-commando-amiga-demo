; Include after the game code/data, among its final BSS sections.
        SECTION OriginalAmigaMusic,BSS
AmigaMusicWork:             ds.b AMIGA_MUSIC_WORK_BYTES
AmigaMusicInstrumentHeader: ds.l 13
AmigaMusicShadows:          ds.b 64
        SECTION OriginalAmigaSamples,BSS_C
AmigaMusicSamplePool:       ds.b AMIGA_MUSIC_SAMPLE_BYTES
AmigaMusicSilence:          ds.l 1
