; Compile-time title edition. Full uses the capture's exact 24-bit colours;
; reduced retains its established RGB12 palette and bitmap bytes.
; Include in CODE. title_graphics_data.i owns the full edition's chip Copper.
InstallTitlePalette:
        ifne BUILD_GFX_PROFILE
        move.l  d0,-(sp)
        move.l  #CopParallaxJump,d0
        move.w  d0,FullTitlePaletteReturn+6
        swap    d0
        move.w  d0,FullTitlePaletteReturn+2
        move.l  #FullTitlePaletteCopper,d0
        jsr     SetPaletteCopperJump
        move.l  (sp)+,d0
        endif
        rts
