; Each executable has one graphics edition, including its title palette.
InitPaletteCopperLinks:
        ifne BUILD_GFX_PROFILE
        move.l  #CopParallaxJump,d0
        move.w  d0,FullPaletteCopperEnd-6
        swap    d0
        move.w  d0,FullPaletteCopperEnd-10
        endif
        move.l  #CopParallaxJump,d0
        bra.w   SetPaletteCopperJump

SetPaletteCopperJump:
        move.w  d0,CopPaletteJump+6
        swap    d0
        move.w  d0,CopPaletteJump+2
        rts

        ifeq BUILD_GFX_PROFILE
PrepareColourProfile:
        movem.l d0-d7/a0-a6,-(sp)
        movea.l CurrentTilesLZ,a0
        lea     ActiveTileSheet,a1
        jsr     LZSS_Decompress
        movem.l (sp)+,d0-d7/a0-a6
        rts
ConfigureFullColour:
        rts
FullChipActive: dc.b 0
        EVEN
        endif

RenderGraphicsEditionHint:
        lea     GraphicsEditionHint(pc),a0
        lea     HudBuffer+8*40+24,a1
        jmp     DrawHudString
GraphicsEditionHint:
        ifne BUILD_GFX_PROFILE
        dc.b "FULL COLOUR",0
        else
        dc.b "REDUCED COLOUR",0
        endif
        EVEN
GraphicsBuildProfile: dc.w BUILD_GFX_PROFILE
