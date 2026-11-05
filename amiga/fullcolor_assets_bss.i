; Own FastRAM buffers only. Display/cookie caches reuse root-owned chip banks.
        SECTION FullColourFGSource,BSS
FullColourFGAtlas:      ds.b FULLCOLOUR_FG_ATLAS_BYTES
        SECTION FullColourSpriteSource,BSS
FullColourSpriteAtlas:  ds.b FULLCOLOUR_SPRITE_ATLAS_BYTES
FullColourBobSpecs:     ds.b FULLCOLOUR_BOB_SPECS_BYTES
FullColourBGAtlas:      ds.b FULLCOLOUR_BG_ATLAS_BYTES
FullColourBGSpecs:      ds.b FULLCOLOUR_BG_SPECS_BYTES
FullColourTileSpecs:    ds.b (FULLCOLOUR_MAX_TILES*6)
FullColourTilePixels:   ds.b 256
FullColourRowWords:     ds.w 8
FullColourBobPixels:    ds.b 1024
FullColourBobRowLongs:  ds.l 8
