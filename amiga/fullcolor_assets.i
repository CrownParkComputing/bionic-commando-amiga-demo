; Lossless source-pen atlas decoders. All public routines preserve every
; d0-d7/a0-a6 register. No waits, blitter commands or RawObjectScratch use.
; InitFullColourAssets: unpack compact native atlases/specs into own FastBSS.
; BuildProfileTiles: CurrentStage; FullColourMode0=>exact old160B tiles,
;   mode1=>512B padded8plane tiles in ParallaxBank2/3 and repeated8plane
;   native opacity masks in ObjectBobBank0. FullColourPalettePtr is public.
; BuildFullColourBackground: native512x512 BG into ParallaxBank4/5.
; BuildFullBobCache: d0.w=global rawID0..744,a0=1536B RGB,a1=1536B mask.
;   Both outputs:32rows x8planes x6B (32visiblebits plus16zero guardbits).
; LoadFullHardwareSprites: exact nativeJoe/arm/death/demo/chute to old buffers.
        include "fullcolor_defs.i"

InitFullColourAssets:
        movem.l d0-d7/a0-a6,-(sp)
        tst.b   FullColourAssetsReady
        bne.s   .done
        lea     FullColourFGAtlasLZ,a0
        lea     FullColourFGAtlas,a1
        jsr     LZSS_Decompress
        lea     FullColourSpriteAtlasLZ,a0
        lea     FullColourSpriteAtlas,a1
        jsr     LZSS_Decompress
        lea     FullColourBobSpecsLZ,a0
        lea     FullColourBobSpecs,a1
        jsr     LZSS_Decompress
        lea     FullColourBGAtlasLZ,a0
        lea     FullColourBGAtlas,a1
        jsr     LZSS_Decompress
        lea     FullColourBGSpecsLZ,a0
        lea     FullColourBGSpecs,a1
        jsr     LZSS_Decompress
        move.b  #1,FullColourAssetsReady
.done: movem.l (sp)+,d0-d7/a0-a6
        rts

BuildProfileTiles:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.w   InitFullColourAssets
        moveq   #0,d0
        move.w  CurrentStage,d0
        cmpi.w  #GAME_STAGE_COUNT,d0
        blo.s   .stage
        moveq   #0,d0
.stage:
        mulu.w  #FULLCOLOUR_STAGE_BYTES,d0
        lea     FullColourStageDirectory,a6
        adda.l  d0,a6
        move.w  (a6),FullColourTileCount
        move.l  16(a6),FullColourPalettePtr
        movea.l 4(a6),a0
        lea     FullColourTileSpecs,a1
        jsr     LZSS_Decompress
        movea.l 8(a6),a6
        tst.b   FullColourMode
        beq.s   .lookup_ready
        ; The fulllookup follows the reduced64-byte lookup in generateddata.
        adda.w  #64,a6
.lookup_ready:
        lea     FullColourTileSpecs,a5
        moveq   #0,d6
        move.w  FullColourTileCount,d7
        subq.w  #1,d7
.tile:
        moveq   #0,d0
        move.w  (a5)+,d0
        mulu.w  #128,d0
        lea     FullColourFGAtlas,a0
        adda.l  d0,a0
        moveq   #0,d0
        move.w  (a5)+,d0
        lsl.w   #4,d0
        movea.l a6,a2
        adda.w  d0,a2
        move.w  (a5)+,d4
        lea     FullColourTilePixels,a1
        moveq   #16,d3
        moveq   #16,d5
        bsr.w   FullColourDecodeTile
        moveq   #0,d0
        move.w  d6,d0
        tst.b   FullColourMode
        bne.s   .full_target
        mulu.w  #160,d0
        lea     ActiveTileSheet,a1
        adda.l  d0,a1
        bsr.w   FullColourPackFGTile
        bra.s   .next_tile
.full_target:
        lea     ParallaxBank2,a1
        cmpi.w  #256,d0
        blo.s   .bank_ready
        subi.w  #256,d0
        lea     ParallaxBank3,a1
.bank_ready:
        lsl.l   #8,d0
        add.l   d0,d0
        adda.l  d0,a1
        moveq   #0,d0
        move.w  d6,d0
        lsl.l   #8,d0
        add.l   d0,d0
        lea     ObjectBobBank0,a4
        adda.l  d0,a4
        bsr.w   FullColourPackFGTile
.next_tile:
        bsr.w   PollFullColourAssetInput
        addq.w  #1,d6
        dbf     d7,.tile
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Native packed-pen tile ->8bit AGA indices. a0source,a1dest,a2lookup16B,
; d3size(8/16),d4flags(bit0Xflip,bit1Yflip),d5destinationstride. Preserveall.
FullColourDecodeTile:
        movem.l d0-d7/a0-a6,-(sp)
        moveq   #0,d6
.row:
        move.w  d6,d0
        btst    #1,d4
        beq.s   .source_y
        move.w  d3,d0
        subq.w  #1,d0
        sub.w   d6,d0
.source_y:
        move.w  d3,d1
        lsr.w   #1,d1
        mulu.w  d1,d0
        movea.l a0,a3
        adda.l  d0,a3
        move.w  d6,d0
        mulu.w  d5,d0
        movea.l a1,a4
        adda.l  d0,a4
        moveq   #0,d7
.pixel:
        move.w  d7,d0
        btst    #0,d4
        beq.s   .source_x
        move.w  d3,d0
        subq.w  #1,d0
        sub.w   d7,d0
.source_x:
        move.w  d0,d1
        lsr.w   #1,d1
        moveq   #0,d2
        move.b  (a3,d1.w),d2
        btst    #0,d0
        bne.s   .low_pen
        lsr.w   #4,d2
.low_pen:
        andi.w  #15,d2
        move.b  (a2,d2.w),(a4)+
        addq.w  #1,d7
        cmp.w   d3,d7
        blo.s   .pixel
        addq.w  #1,d6
        cmp.w   d3,d6
        blo.s   .row
        movem.l (sp)+,d0-d7/a0-a6
        rts

; a0=sequential8bit pixelrow,d3=pixelcount8/16. Output8word bitplanes.
; a0 advances. Other registers are preserved, including the outer tileindex.
FullColourMakeRowWords:
        movem.l d0-d2/d4-d5/a3,-(sp)
        lea     FullColourRowWords,a3
        clr.l   (a3)+
        clr.l   (a3)+
        clr.l   (a3)+
        clr.l   (a3)+
        move.w  d3,d5
        subq.w  #1,d5
.pixel:
        move.b  (a0)+,d2
        lea     FullColourRowWords,a3
        moveq   #7,d4
.plane:
        lsr.b   #1,d2
        roxl.w  (a3)+
        dbf     d4,.plane
        dbf     d5,.pixel
        movem.l (sp)+,d0-d2/d4-d5/a3
        rts

; FullColourTilePixels16x16 ->a1RGB; mode1 also writes a4native mask.
FullColourPackFGTile:
        movem.l d0-d7/a0-a6,-(sp)
        lea     FullColourTilePixels,a0
        moveq   #16,d3
        moveq   #15,d6
.row:
        bsr.s   FullColourMakeRowWords
        lea     FullColourRowWords,a3
        tst.b   FullColourMode
        bne.s   .full
        moveq   #4,d7
.reduced:
        move.w  (a3)+,(a1)+
        dbf     d7,.reduced
        bra.s   .next
.full:
        moveq   #0,d0
        moveq   #7,d7
.colour:
        move.w  (a3)+,d1
        or.w    d1,d0
        move.w  d1,(a1)+
        clr.w   (a1)+
        dbf     d7,.colour
        moveq   #7,d7
.mask:
        move.w  d0,(a4)+
        clr.w   (a4)+
        dbf     d7,.mask
.next:
        dbf     d6,.row
        movem.l (sp)+,d0-d7/a0-a6
        rts

BuildFullBobCache:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.w   InitFullColourAssets
        move.l  a0,FullColourBobRGBDestination
        move.l  a1,FullColourBobMaskDestination
        cmpi.w  #FULLCOLOUR_BOB_COUNT,d0
        blo.s   .valid
        moveq   #0,d0
.valid:
        andi.l  #$FFFF,d0
        lsl.l   #4,d0
        lea     FullColourBobSpecs,a5
        adda.l  d0,a5
        moveq   #0,d6
.quad:
        moveq   #0,d0
        move.w  (a5)+,d0
        mulu.w  #128,d0
        lea     FullColourSpriteAtlas,a0
        adda.l  d0,a0
        move.w  (a5)+,d0
        move.w  d0,d4
        andi.w  #$3C,d0
        lsl.w   #2,d0
        lea     FullColourSpriteLookup,a2
        adda.w  d0,a2
        ; Native spriteattrs: bit0Y,bit1X. Decoder: bit0X,bit1Y.
        andi.w  #3,d4
        move.w  d4,d0
        lsr.w   #1,d4
        andi.w  #1,d0
        add.w   d0,d0
        or.w    d0,d4
        move.w  d6,d0
        andi.w  #1,d0
        lsl.w   #4,d0
        move.w  d6,d1
        lsr.w   #1,d1
        lsl.w   #8,d1
        add.w   d1,d1
        add.w   d1,d0
        lea     FullColourBobPixels,a1
        adda.w  d0,a1
        moveq   #16,d3
        moveq   #32,d5
        bsr.w   FullColourDecodeTile
        addq.w  #1,d6
        cmpi.w  #4,d6
        blo.s   .quad
        lea     FullColourBobPixels,a0
        movea.l FullColourBobRGBDestination,a1
        movea.l FullColourBobMaskDestination,a2
        moveq   #31,d6
.row:
        lea     FullColourBobRowLongs,a3
        moveq   #7,d7
.clear:
        clr.l   (a3)+
        dbf     d7,.clear
        moveq   #31,d7
.pixel:
        move.b  (a0)+,d2
        lea     FullColourBobRowLongs,a3
        moveq   #7,d4
.plane:
        lsr.b   #1,d2
        move.l  (a3),d1
        roxl.l  #1,d1
        move.l  d1,(a3)+
        dbf     d4,.plane
        dbf     d7,.pixel
        lea     FullColourBobRowLongs,a3
        moveq   #0,d0
        moveq   #7,d7
.colour:
        move.l  (a3)+,d1
        or.l    d1,d0
        move.l  d1,(a1)+
        clr.w   (a1)+
        dbf     d7,.colour
        moveq   #7,d7
.mask:
        move.l  d0,(a2)+
        clr.w   (a2)+
        dbf     d7,.mask
        dbf     d6,.row
        movem.l (sp)+,d0-d7/a0-a6
        rts

BuildFullColourBackground:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.w   InitFullColourAssets
        lea     FullColourBGSpecs,a5
        moveq   #0,d7
.tile:
        moveq   #0,d0
        move.w  (a5)+,d0
        lsl.l   #5,d0
        lea     FullColourBGAtlas,a0
        adda.l  d0,a0
        moveq   #0,d0
        move.b  (a5)+,d0
        lsl.w   #4,d0
        lea     FullColourBGPaletteLookup,a2
        adda.w  d0,a2
        moveq   #0,d4
        move.b  (a5)+,d4
        lea     FullColourTilePixels,a1
        moveq   #8,d3
        moveq   #8,d5
        bsr.w   FullColourDecodeTile
        moveq   #0,d0
        moveq   #0,d1
        move.w  d7,d0
        andi.w  #63,d0
        move.w  d7,d1
        lsr.w   #6,d1
        lea     ParallaxBank4,a4
        cmpi.w  #32,d1
        blo.s   .bank
        subi.w  #32,d1
        lea     ParallaxBank5,a4
.bank:
        lsl.l   #8,d1
        lsl.l   #4,d1
        add.l   d0,d1
        adda.l  d1,a4
        lea     FullColourTilePixels,a0
        moveq   #7,d6
.row:
        bsr.w   FullColourMakeRowWords
        lea     FullColourRowWords+1,a3
        movea.l a4,a1
        moveq   #7,d5
.plane:
        move.b  (a3),(a1)
        addq.l  #2,a3
        lea     64(a1),a1
        dbf     d5,.plane
        lea     512(a4),a4
        dbf     d6,.row
        move.w  d7,d0
        andi.w  #7,d0
        bne.s   .no_input_poll
        bsr.w   PollFullColourAssetInput
.no_input_poll:
        addq.w  #1,d7
        cmpi.w  #4096,d7
        blo.w   .tile
        movem.l (sp)+,d0-d7/a0-a6
        rts

LoadFullHardwareSprites:
        movem.l d0-d7/a0-a6,-(sp)
        lea     FullColourJoeSpritesLZ,a0
        lea     JoeSpritesData,a1
        jsr     LZSS_Decompress
        lea     FullColourDeathSpritesLZ,a0
        lea     JoeDeathSpritesData,a1
        jsr     LZSS_Decompress
        lea     FullColourDemoExtrasLZ,a0
        lea     DemoExtraPoseData,a1
        jsr     LZSS_Decompress
        lea     FullColourParachuteLZ,a0
        lea     ParachuteSpriteData,a1
        jsr     LZSS_Decompress
        movem.l (sp)+,d0-d7/a0-a6
        rts

LoadReducedHardwareSprites:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     UnpackSpriteAssets
        jsr     UnpackExtendedAssets
        jsr     UnpackArcadeDemo
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Optional host callback keeps serial input acknowledged during a long
; conversion. Zero leaves the deterministic asset APIs free of hardware IO.
PollFullColourAssetInput:
        tst.l   FullColourLoadPoll
        beq.s   .done
        movem.l d0-d1/a0,-(sp)
        movea.l FullColourLoadPoll,a0
        jsr     (a0)
        movem.l (sp)+,d0-d1/a0
.done:  rts
FullColourLoadPoll:           dc.l 0
FullColourAssetsReady:        dc.b 0
        EVEN
FullColourTileCount:          dc.w 0
FullColourPalettePtr:         dc.l 0
FullColourBobRGBDestination:  dc.l 0
FullColourBobMaskDestination: dc.l 0
