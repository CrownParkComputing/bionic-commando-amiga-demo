; Eight-plane AGA renderer. Reuse the reduced-mode chip banks, so both
; profiles fit a 2 MB chip machine. Source atlases and lookup tables use Fast.
FC_ROW EQU (8*FRAME_PLANE_BYTES)
FC_BYTES EQU (FRAME_LINES*FC_ROW)
FC_ORIGIN EQU (32*FC_ROW+4)
FC_ALPHA EQU (ScreenBuffer+FC_BYTES)
FC_BOB_SLOTS EQU 49

PrepareColourProfile:
        movem.l d0-d7/a0-a6,-(sp)
        move.b  #1,FullChipActive
        move.l  #ServiceBackgroundTasks,FullColourLoadPoll
        move.b  #1,LoadingProgressPhase
        jsr     BuildProfileTiles
        clr.b   LoadingProgressPhase
        tst.b   FullBackgroundReady
        bne.s   .background_ready
        jsr     BuildFullColourBackground
        move.b  #1,FullBackgroundReady
.background_ready:
        jsr     LoadFullHardwareSprites
        bsr.w   BuildFullBackgroundSeam
        lea     FullBobSlots,a0
        move.w  #FULLCOLOUR_BOB_COUNT-1,d7
.indices:
        move.w  #-1,(a0)+
        dbf     d7,.indices
        lea     FullBobOwners,a0
        moveq   #FC_BOB_SLOTS-1,d7
.owners:
        move.w  #-1,(a0)+
        dbf     d7,.owners
        clr.w   FullBobNextSlot
        clr.b   FullSceneValid
        move.w  #-1,FullFrameGeneration0
        move.w  #-1,FullFrameGeneration1
        lea     GameFrame0,a0
        move.w  #(FC_BYTES/512)-1,d6
.clear_scene_chunk:
        moveq   #127,d7
.clear_scene:
        clr.l   (a0)+
        dbf     d7,.clear_scene
        jsr     ServiceBackgroundTasks
        dbf     d6,.clear_scene_chunk
        move.w  #-1,FullCacheTileX
        move.w  #-1,FullCacheTileY
        lea     ScreenBuffer,a0
        move.w  #(FC_BYTES*2/512)-1,d6
.clear_chunk:
        moveq   #127,d7
.clear:
        clr.l   (a0)+
        dbf     d7,.clear
        jsr     ServiceBackgroundTasks
        dbf     d6,.clear_chunk
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; A seam supplies consecutive native words31/0 without crossing a plane row.
; ActiveTileSheet is otherwise unused in full mode. 512*8*4 =16 KiB.
BuildFullBackgroundSeam:
        lea     ActiveTileSheet,a1
        lea     ParallaxBank4,a0
        moveq   #1,d6
.bank:
        move.w  #2047,d7
.row:
        move.w  62(a0),(a1)+
        move.w  (a0),(a1)+
        lea     64(a0),a0
        dbf     d7,.row
        lea     ParallaxBank5,a0
        dbf     d6,.bank
        rts

ConfigureFullColour:
        tst.b   FullChipActive
        beq.w   .done
        move.w  #$0211,CopDepth+2        ;AGA BPU3: eight planes, colour/ECSENA
        move.w  #$0224,CopPriority+2
        move.l  #CopPlainHudWait,d0
        jsr     SetParallaxCopperJump
        lea     FullPaletteCopper,a1
        movea.l FullColourPalettePtr,a0
        moveq   #7,d6
.bank:
        addq.l  #4,a1                  ;BPLCON3 bank selector
        moveq   #31,d7
.colour:
        move.w  (a0)+,2(a1)
        addq.l  #4,a1
        dbf     d7,.colour
        dbf     d6,.bank
        move.l  #FullPaletteCopper,d0
        bsr.w   SetPaletteCopperJump
        move.l  #ParallaxBank0,FrameDrawPtr
        move.l  #ParallaxBank1,FrameShowPtr
.done:  rts

BuildFullForegroundCache:
        move.w  CamX,d0
        lsr.w   #4,d0
        move.w  CamY,d1
        lsr.w   #4,d1
        move.w  d0,OldTileX
        move.w  d1,OldTileY
        cmp.w   FullCacheTileX,d0
        bne.s   .rebuild
        cmp.w   FullCacheTileY,d1
        beq.w   .done
.rebuild:
        clr.b   FullSceneValid
        move.w  d0,FullCacheTileX
        move.w  d1,FullCacheTileY
        move.w  #0,FullCacheRow
.row:
        clr.w   FullCacheCol
.tile:
        move.w  FullCacheTileX,d0
        add.w   FullCacheCol,d0
        lsl.w   #4,d0
        move.w  FullCacheTileY,d1
        add.w   FullCacheRow,d1
        lsl.w   #4,d1
        jsr     GetTileCol
        andi.l  #$3FF,d0
        move.l  d0,d2
        lsl.l   #8,d2
        add.l   d2,d2
        lea     ObjectBobBank0,a2
        adda.l  d2,a2
        lea     ParallaxBank2,a0
        cmpi.w  #256,d0
        blo.s   .bank
        subi.l  #131072,d2
        lea     ParallaxBank3,a0
.bank:
        adda.l  d2,a0
        bsr.w   ClassifyFullTileTransparency
        move.w  FullCacheRow,d0
        mulu.w  #(16*FC_ROW),d0
        move.w  FullCacheCol,d1
        andi.l  #$FFFF,d1
        add.w   d1,d1
        add.l   d1,d0
        lea     ScreenBuffer+FC_ORIGIN,a1
        adda.l  d0,a1
        jsr     WaitBlitter
        move.w  #$09F0,CUSTOM+BLTCON0
        clr.w   CUSTOM+BLTCON1
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
        move.w  #2,CUSTOM+BLTAMOD
        move.w  #50,CUSTOM+BLTDMOD
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTDPTH
        move.w  #((128<<6)|1),CUSTOM+BLTSIZE
        jsr     WaitBlitter
        adda.l  #FC_BYTES,a1
        move.l  a2,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTDPTH
        move.w  #((128<<6)|1),CUSTOM+BLTSIZE
        addq.w  #1,FullCacheCol
        cmpi.w  #22,FullCacheCol
        blo.w   .tile
        addq.w  #1,FullCacheRow
        cmpi.w  #16,FullCacheRow
        blo.w   .row
.done:
        jsr     WaitBlitter
        rts

; Same independent native BG state as reduced mode, without its palette writes.
UpdateFullBackgroundState:
        jsr     GetParallaxCamera
        tst.b   BackgroundMove
        bne.s   .moving
        move.w  d0,ParallaxPreviousX
        move.w  d1,ParallaxPreviousY
        clr.l   ParallaxXFP
        clr.l   ParallaxYFP
        rts
.moving:
        tst.b   AttractMode
        beq.s   .integrate
        tst.b   DemoPlaybackActive
        beq.s   .integrate
        move.w  d0,ParallaxPreviousX
        move.w  d1,ParallaxPreviousY
        move.w  DemoNativeTick,d0
        subq.w  #1,d0
        bpl.s   .demo
        moveq   #0,d0
.demo:
        lsl.w   #2,d0
        lea     ParallaxDemoCoords,a0
        adda.w  d0,a0
        move.w  (a0)+,d0
        ext.l   d0
        lsl.l   #8,d0
        move.l  d0,ParallaxXFP
        move.w  (a0),d0
        ext.l   d0
        lsl.l   #8,d0
        move.l  d0,ParallaxYFP
        rts
.integrate:
        jmp     AdvanceParallaxCamera

CopyFullFlatBackground:
        jsr     WaitBlitter
        move.w  #$09F0,CUSTOM+BLTCON0
        clr.w   CUSTOM+BLTCON1
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
        move.w  #8,CUSTOM+BLTAMOD
        move.w  #8,CUSTOM+BLTDMOD
        lea     ScreenBuffer+FC_ORIGIN,a0
        movea.l FrameDrawPtr,a1
        adda.l  #FC_ORIGIN,a1
        moveq   #1,d7
.half:
        jsr     WaitBlitter
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTDPTH
        move.w  #22,CUSTOM+BLTSIZE     ;1024 rows (128pixels*8planes)
        adda.l  #(128*FC_ROW),a0
        adda.l  #(128*FC_ROW),a1
        dbf     d7,.half
        jmp     WaitBlitter

; d0 rawBOBid ->a1 cached RGB; FIFO eviction after previous blit completes.
GetFullBob:
        movem.l d0-d4/a0/a2,-(sp)
        andi.l  #$FFFF,d0
        move.w  d0,d4
        add.w   d0,d0
        lea     FullBobSlots,a2
        move.w  (a2,d0.w),d1
        bpl.s   .cached
        jsr     WaitBlitter
        move.w  FullBobNextSlot,d1
        move.w  d1,d2
        add.w   d2,d2
        lea     FullBobOwners,a0
        move.w  (a0,d2.w),d3
        bmi.s   .empty
        add.w   d3,d3
        move.w  #-1,(a2,d3.w)
.empty:
        move.w  d4,(a0,d2.w)
        move.w  d1,(a2,d0.w)
        addq.w  #1,FullBobNextSlot
        cmpi.w  #FC_BOB_SLOTS,FullBobNextSlot
        blo.s   .slot_ready
        clr.w   FullBobNextSlot
.slot_ready:
        moveq   #0,d0
        move.w  d1,d0
        mulu.w  #3072,d0
        lea     ObjectBobBank1,a0
        adda.l  d0,a0
        lea     1536(a0),a1
        move.w  d4,d0
        jsr     BuildFullBobCache
.cached:
        moveq   #0,d0
        move.w  d1,d0
        mulu.w  #3072,d0
        lea     ObjectBobBank1,a1
        adda.l  d0,a1
        movem.l (sp)+,d0-d4/a0/a2
        rts

DrawFullBobs:
        move.w  BobCount,d6
        beq.w   .done
        subq.w  #1,d6
        lea     BobList,a6
        lea     BobDrawFlags,a3
.bob:
        move.w  (a6)+,d4
        move.w  (a6)+,d5
        move.w  (a6)+,d0
        tst.b   (a3)+
        beq.w   .next
        move.w  OldTileX,d1
        lsl.w   #4,d1
        move.w  d4,d2
        sub.w   d1,d2
        cmpi.w  #-31,d2
        blt.w   .next
        cmpi.w  #351,d2
        bgt.w   .next
        addi.w  #32,d2
        asr.w   #4,d2
        add.w   d2,d2
        move.w  OldTileY,d1
        lsl.w   #4,d1
        move.w  d5,d3
        sub.w   d1,d3
        cmpi.w  #-31,d3
        blt.w   .next
        cmpi.w  #239,d3
        bgt.w   .next
        addi.w  #32,d3
        mulu.w  #FC_ROW,d3
        movea.l FrameDrawPtr,a4
        adda.l  d3,a4
        adda.w  d2,a4
        bsr.w   GetFullBob
        lea     1536(a1),a0
        move.w  d4,d0
        andi.w  #15,d0
        ror.w   #4,d0
        move.w  d0,d1
        ori.w   #$0FCA,d1
        jsr     WaitBlitter
        move.w  d1,CUSTOM+BLTCON0
        move.w  d0,CUSTOM+BLTCON1
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
        clr.w   CUSTOM+BLTAMOD
        clr.w   CUSTOM+BLTBMOD
        move.w  #46,CUSTOM+BLTCMOD
        move.w  #46,CUSTOM+BLTDMOD
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTBPTH
        move.l  a4,CUSTOM+BLTCPTH
        move.l  a4,CUSTOM+BLTDPTH
        move.w  #((256<<6)|3),CUSTOM+BLTSIZE
.next:
        dbf     d6,.bob
.done:
        jmp     WaitBlitter

ComposeFullColourFrame:
        move.w  #$8400,CUSTOM+DMACON
        bsr.w   BuildFullForegroundCache
        jsr     BuildBobList
        jsr     BuildObjectBobs
        bsr.w   RefreshFullCleanScene
        lea     FrameHistory0,a0
        lea     FullFrameGeneration0,a1
        cmpi.l  #ParallaxBank0,FrameDrawPtr
        beq.s   .history
        lea     FrameHistory1,a0
        lea     FullFrameGeneration1,a1
.history:
        move.l  a0,FrameHistoryPtr
        move.l  a1,FullHiddenGenerationPtr
        move.w  FullSceneGeneration,d0
        cmp.w   (a1),d0
        bne.s   .background
        jsr     FindChangedBobs
        tst.w   ChangedBobCount
        beq.s   .draw
        bsr.w   RestoreFullFrameBobs
        bra.s   .draw
.background:
        bsr.w   CopyFullCleanScene
        jsr     MarkAllBobsDirty
.draw:
        bsr.w   DrawFullBobs
        movea.l FullHiddenGenerationPtr,a0
        move.w  FullSceneGeneration,(a0)
        movea.l FrameHistoryPtr,a0
        move.w  OldTileX,(a0)+
        move.w  OldTileY,(a0)+
        move.w  BobCount,d0
        move.w  d0,(a0)+
        beq.s   .present
        subq.w  #1,d0
        lea     BobList,a1
.save:
        move.l  (a1)+,(a0)+
        move.w  (a1)+,(a0)+
        dbf     d0,.save
.present:
        jsr     EndBlitterHog
        move.w  #$0010,CUSTOM+INTREQ
        jsr     WaitVBL
        move.l  FrameShowPtr,d0
        move.l  FrameDrawPtr,FrameShowPtr
        move.l  d0,FrameDrawPtr
        bsr.w   UpdateFullCopperPointers
        tst.b   GameOverMode
        beq.s   .sprites
        jsr     HideGameSprites
        rts
.sprites:
        jsr     UpdateSprites
        rts

; The two reduced display buffers are contiguous and unused in full mode.
; They supply a third 126464-byte clean scene, without extra chip allocation.
RefreshFullCleanScene:
        tst.w   CurrentStage
        bne.s   .flat
        jsr     ComputeFullBackgroundCoords
        bra.s   .key
.flat:
        clr.w   FullBGFine
        clr.w   FullBGLeftWord
        clr.w   FullBGTop
.key:
        tst.b   FullSceneValid
        beq.s   .refresh
        move.l  FullBGFine,d0
        cmp.l   FullSceneBGKey,d0
        bne.s   .refresh
        move.w  FullBGTop,d0
        cmp.w   FullSceneBGY,d0
        beq.s   .done
.refresh:
        move.l  FrameDrawPtr,-(sp)
        move.l  #GameFrame0,FrameDrawPtr
        tst.b   FullSceneValid
        bne.s   .foreground_ready
        jsr     CopyFullFlatBackground
.foreground_ready:
        jsr     ComposeFullBackgroundFastPrepared
        move.l  (sp)+,FrameDrawPtr
        move.l  FullBGFine,FullSceneBGKey
        move.w  FullBGTop,FullSceneBGY
        addq.w  #1,FullSceneGeneration
        move.b  #1,FullSceneValid
.done:  rts

CopyFullCleanScene:
        jsr     WaitBlitter
        move.w  #$09F0,CUSTOM+BLTCON0
        clr.w   CUSTOM+BLTCON1
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
        move.w  #8,CUSTOM+BLTAMOD
        move.w  #8,CUSTOM+BLTDMOD
        lea     GameFrame0+FC_ORIGIN,a0
        movea.l FrameDrawPtr,a1
        adda.l  #FC_ORIGIN,a1
        moveq   #1,d7
.half:
        jsr     WaitBlitter
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTDPTH
        move.w  #22,CUSTOM+BLTSIZE
        adda.l  #(128*FC_ROW),a0
        adda.l  #(128*FC_ROW),a1
        dbf     d7,.half
        jmp     WaitBlitter

RestoreFullFrameBobs:
        movea.l FrameHistoryPtr,a3
        move.w  4(a3),d6
        beq.w   .done
        subq.w  #1,d6
        addq.l  #6,a3
        lea     BobDrawFlags,a4
        jsr     WaitBlitter
        move.w  #$09F0,CUSTOM+BLTCON0
        clr.w   CUSTOM+BLTCON1
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
.bob:
        move.w  (a3)+,d4
        move.w  (a3)+,d5
        moveq   #0,d3
        move.w  (a3)+,d3
        tst.b   (a4)+
        beq.w   .next
        move.w  OldTileX,d0
        lsl.w   #4,d0
        move.w  d4,d1
        sub.w   d0,d1
        cmpi.w  #-31,d1
        blt.w   .next
        cmpi.w  #351,d1
        bgt.w   .next
        addi.w  #32,d1
        asr.w   #4,d1
        add.w   d1,d1
        move.w  OldTileY,d0
        lsl.w   #4,d0
        move.w  d5,d2
        sub.w   d0,d2
        cmpi.w  #-31,d2
        blt.w   .next
        cmpi.w  #239,d2
        bgt.w   .next
        addi.w  #32,d2
        lsl.w   #2,d3
        lea     BobBoundsData,a2
        adda.w  d3,a2
        moveq   #0,d0
        move.b  (a2),d0
        add.w   d0,d2
        mulu.w  #FC_ROW,d2
        moveq   #0,d0
        move.b  2(a2),d0
        add.w   d0,d1
        lea     GameFrame0,a0
        adda.l  d2,a0
        adda.w  d1,a0
        movea.l FrameDrawPtr,a1
        adda.l  d2,a1
        adda.w  d1,a1
        moveq   #0,d7
        move.b  3(a2),d7
        move.w  d4,d0
        andi.w  #15,d0
        beq.s   .width
        addq.w  #1,d7
.width:
        moveq   #0,d3
        move.b  1(a2),d3
        beq.s   .next
        lsl.w   #8,d3
        add.w   d3,d3                 ;height*8 planes*64
        or.w    d7,d3
        add.w   d7,d7
        neg.w   d7
        addi.w  #52,d7
        jsr     WaitBlitter
        move.w  d7,CUSTOM+BLTAMOD
        move.w  d7,CUSTOM+BLTDMOD
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTDPTH
        move.w  d3,CUSTOM+BLTSIZE
.next:
        dbf     d6,.bob
.done:  jmp     WaitBlitter

UpdateFullCopperPointers:
        move.w  #1,CopFetchMode+2
        move.w  #FULLCOLOUR_BPLCON4_JOE,CopSpriteBank+2
        tst.b   ChuteMode
        beq.s   .scroll
        clr.w   CopFetchMode+2
        move.w  #FULLCOLOUR_BPLCON4_CHUTE,CopSpriteBank+2
        move.w  #$0038,CopFetchStart+2
        move.w  #(FC_ROW-40),CopModulo+2
        move.w  #(FC_ROW-40),CopModulo+6
        clr.w   CopScroll+2
        bra.s   .pointers
.scroll:
        move.w  #$0030,CopFetchStart+2
        move.w  #(FC_ROW-44),CopModulo+2
        move.w  #(FC_ROW-44),CopModulo+6
        move.w  CamX,d0
        not.w   d0
        andi.w  #15,d0
        move.w  d0,d1
        lsl.w   #4,d1
        or.w    d1,d0
        ori.w   #$4400,d0              ;AGA32-bit fetch extends both delays16px
        move.w  d0,CopScroll+2
.pointers:
        move.w  CamY,d0
        andi.w  #15,d0
        mulu.w  #FC_ROW,d0
        movea.l FrameShowPtr,a0
        adda.l  #FC_ORIGIN,a0
        adda.l  d0,a0
        move.l  a0,d0
        lea     CopBplPtrs,a1
        moveq   #7,d7
.plane:
        move.w  d0,6(a1)
        swap    d0
        move.w  d0,2(a1)
        swap    d0
        addi.l  #FRAME_PLANE_BYTES,d0
        addq.l  #8,a1
        dbf     d7,.plane
        rts

FullChipActive: dc.b 0
FullSceneValid: dc.b 0
FullBackgroundReady: dc.b 0
        EVEN
FullCacheTileX: dc.w -1
FullCacheTileY: dc.w -1
FullCacheRow: dc.w 0
FullCacheCol: dc.w 0
FullBGFine: dc.w 0
FullBGLeftWord: dc.w 0
FullBGTop: dc.w 0
FullComposeCol: dc.w 0
FullComposeY: dc.w 0
FullComposeHeight: dc.w 0
FullBobNextSlot: dc.w 0
FullBobOwners: ds.w FC_BOB_SLOTS
FullBobSlots: ds.w FULLCOLOUR_BOB_COUNT

        EVEN
FullSceneGeneration: dc.w 0
FullFrameGeneration0: dc.w -1
FullFrameGeneration1: dc.w -1
FullHiddenGenerationPtr: dc.l 0
FullSceneBGKey: dc.l 0
FullSceneBGY: dc.w 0

; 0=fully opaque,1=empty,2=mixed. Opacity repeats for each colour plane.
ClassifyFullTileTransparency:
        movem.l d0-d3/a0-a1,-(sp)
        movea.l a2,a1
        moveq   #0,d0
        moveq   #-1,d1
        moveq   #15,d3
.row:
        move.w  (a1),d2
        or.w    d2,d0
        and.w   d2,d1
        lea     32(a1),a1
        dbf     d3,.row
        moveq   #0,d2
        cmpi.w  #$FFFF,d1
        beq.s   .store
        moveq   #1,d2
        tst.w   d0
        beq.s   .store
        moveq   #2,d2
.store:
        move.w  FullCacheRow,d0
        mulu.w  #22,d0
        add.w   FullCacheCol,d0
        lea     FullTileCoverage,a1
        move.b  d2,(a1,d0.w)
        movem.l (sp)+,d0-d3/a0-a1
        rts
FullTileCoverage: ds.b (22*16)
        EVEN
