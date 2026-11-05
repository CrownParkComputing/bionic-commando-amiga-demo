; Generated lossless compactnative assets. Include among the game DATA sections.
        SECTION FullColourData,DATA
FullColourStageDirectory:
        dc.w 464,0
        dc.l FullColourStage0SpecsLZ,FullColourStage0ReducedLookup,FullColourStage0FullLookup,FullColourStage0Palette
FullColourFGAtlasLZ:
        incbin "data/fullcolor_demo_fg_atlas.lz"
        EVEN
FullColourStage0SpecsLZ:
        incbin "data/fullcolor_demo_stage0_specs.lz"
        EVEN
FullColourStage0ReducedLookup:
        incbin "data/fullcolor_stage0_reduced_lookup.bin"
FullColourStage0FullLookup:
        incbin "data/fullcolor_stage0_fg_lookup.bin"
FullColourStage0Palette:
        incbin "data/fullcolor_stage0_palette.bin"
        EVEN
FullColourSpriteAtlasLZ:
        incbin "data/fullcolor_sprite_atlas.lz"
        EVEN
FullColourBobSpecsLZ:
        incbin "data/fullcolor_bob_specs.lz"
        EVEN
FullColourBGAtlasLZ:
        incbin "data/fullcolor_background_atlas.lz"
        EVEN
FullColourBGSpecsLZ:
        incbin "data/fullcolor_background_specs.lz"
        EVEN
FullColourBGPaletteLookup:
        incbin "data/fullcolor_background_lookup.bin"
        EVEN
FullColourSpriteLookup:
        incbin "data/fullcolor_sprite_lookup.bin"
        EVEN
FullColourJoeSpritesLZ:
        incbin "data/fullcolor_joe_sprites.lz"
        EVEN
FullColourDeathSpritesLZ:
        incbin "data/fullcolor_death_sprites.lz"
        EVEN
FullColourDemoExtrasLZ:
        incbin "data/fullcolor_demo_extra.lz"
        EVEN
FullColourParachuteLZ:
        incbin "data/fullcolor_parachute_sprites.lz"
        EVEN
