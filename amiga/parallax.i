; AGA landscape: five unchanged foreground planes plus one background plane.
; Palette32..63 mirrors1..31; only0/32 differ. A small Copper gradient chooses
; two original-background shades per row. Six phase banks cancel the fine
; scroll shared by planes2/4/6, so movement needs no background blits.
PARA_BANK_BYTES EQU (512*FRAME_ROW_STRIDE)
PARA_COPPER_BYTES EQU (224*24+4+12)

UnpackParallaxAssets:
        movem.l d0-d7/a0-a4,-(sp)
        lea     ParallaxAssetsLZ,a0
        lea     RawObjectScratch,a1
        jsr     LZSS_Decompress
        lea     RawObjectScratch+32768,a0
        lea     ParallaxRowPalette,a1
        move.w  #511,d7
.palette: move.l (a0)+,(a1)+
        dbf     d7,.palette
        lea     ParallaxDemoCoords,a1
        move.w  #(1560*4/4)-1,d7
.demo:  move.l  (a0)+,(a1)+
        dbf     d7,.demo
        moveq   #0,d6
.phase:
        moveq   #0,d0
        move.w  d6,d0
        divu.w  #3,d0
        move.l  d0,d1
        swap    d1
        mulu.w  #80,d1
        lsl.w   #2,d0
        lea     ParallaxBankDirectory,a2
        movea.l (a2,d0.w),a1
        adda.l  d1,a1
        lea     RawObjectScratch,a0
        move.w  #511,d5
.row:
        moveq   #62,d2                  ; sixteen-pixel guard before the map
        moveq   #39,d4
.word:
        move.w  (a0,d2.w),d0
        swap    d0
        addq.w  #2,d2
        andi.w  #63,d2
        move.w  (a0,d2.w),d0
        lsl.l   d6,d0
        swap    d0
        move.w  d0,(a1)+
        dbf     d4,.word
        adda.w  #64,a0
        adda.w  #(FRAME_ROW_STRIDE-80),a1
        dbf     d5,.row
        addq.w  #1,d6
        cmpi.w  #16,d6
        blo.s   .phase
        bsr.w   BuildParallaxCopper
        movem.l (sp)+,d0-d7/a0-a4
        rts

BuildParallaxCopper:
        lea     ParallaxCopperRows,a0
        lea     ParallaxColorSlots,a2
        moveq   #44,d5
        move.w  #223,d7
.row:
        cmpi.w  #256,d5
        bne.s   .wait
        move.l  #$FFDFFFFE,(a0)+
.wait:
        lea     10(a0),a1
        move.l  a1,(a2)+
        move.w  d5,d0
        lsl.w   #8,d0
        ori.w   #7,d0
        move.w  d0,(a0)+
        move.w  #$FFFE,(a0)+
        move.l  #((BPLCON3<<16)|$0020),(a0)+
        move.l  #((COLOR00<<16)|0),(a0)+
        move.l  #((BPLCON3<<16)|$2020),(a0)+
        move.l  #((COLOR00<<16)|0),(a0)+
        move.l  #((BPLCON3<<16)|$0020),(a0)+
        addq.w  #1,d5
        dbf     d7,.row
        move.l  #CopHudCommon,d0
        move.w  #COP2LCH,(a0)+
        swap    d0
        move.w  d0,(a0)+
        move.w  #COP2LCL,(a0)+
        swap    d0
        move.w  d0,(a0)+
        move.l  #((COPJMP2<<16)|0),(a0)+
        rts

DisableParallax:
        clr.w   CopFetchMode+2
        move.l  #CopParallaxJump,d0
        jsr     SetPaletteCopperJump
        move.w  #$0011,CopSpriteBank+2
        clr.b   ParallaxEnabled
        move.w  #$5200,CopDepth+2
        move.w  #$0024,CopPriority+2
        move.l  #CopPlainHudWait,d0
SetParallaxCopperJump:
        move.w  d0,CopParallaxJump+6
        swap    d0
        move.w  d0,CopParallaxJump+2
        rts

ConfigureParallax:
        movem.l d0-d7/a0-a2,-(sp)
        bsr.s   DisableParallax
        clr.l   ParallaxXFP
        clr.l   ParallaxYFP
        move.w  #-1,ParallaxPaletteY
        bsr.w   GetParallaxCamera
        move.w  d0,ParallaxPreviousX
        move.w  d1,ParallaxPreviousY
        tst.w   CurrentStage
        bne.s   .done
        tst.b   ParallaxAllowed
        beq.s   .done
        move.b  #1,ParallaxEnabled
        move.w  #$6201,CopDepth+2         ;64 colours + ECS border blank enable
        move.w  #$0224,CopPriority+2      ;AGA KILLEHB; ordinary sprite priority
        move.l  #ParallaxCopperRows,d0
        bsr.s   SetParallaxCopperJump
        movea.l CurrentPal,a0
        lea     CopParallaxMirror+2,a1
        moveq   #31,d7
.mirror:
        move.w  (a0)+,(a1)
        addq.l  #4,a1
        dbf     d7,.mirror
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; Virtual256px view centred within the wider320px Amiga view.
GetParallaxCamera:
        move.w  CamX,d0
        bne.s   .interior
        move.w  PlayerX,d0
        subi.w  #132,d0
        bpl.s   .left_positive
        moveq   #0,d0
.left_positive:
        cmpi.w  #32,d0
        ble.s   .y
        moveq   #32,d0
        bra.s   .y
.interior:
        addi.w  #32,d0
.y:     move.w  #1808,d1
        sub.w   CamY,d1
        rts

UpdateParallaxDisplay:
        tst.b   ParallaxEnabled
        beq.w   .return
        movem.l d0-d7/a0-a4,-(sp)
        bsr.s   GetParallaxCamera
        tst.b   BackgroundMove
        bne.s   .moving_background
        move.w  d0,ParallaxPreviousX
        move.w  d1,ParallaxPreviousY
        clr.l   ParallaxXFP
        clr.l   ParallaxYFP
        bra.w   .pointer
.moving_background:
        tst.b   AttractMode
        beq.s   .integrate
        tst.b   DemoPlaybackActive
        beq.s   .integrate
        move.w  d0,ParallaxPreviousX
        move.w  d1,ParallaxPreviousY
        move.w  DemoNativeTick,d0
        subq.w  #1,d0
        bpl.s   .demo_index
        moveq   #0,d0
.demo_index:
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
        bra.s   .pointer
.integrate:
        bsr.w   AdvanceParallaxCamera
.pointer:
        move.l  ParallaxXFP,d2
        asr.l   #8,d2
        moveq   #0,d3
        tst.b   ChuteMode
        bne.s   .fine_ready
        move.w  CamX,d3
        andi.w  #15,d3
        addq.w  #1,d3                  ;DDF$30 / delay15-fine exposes bit fine+1
.fine_ready:
        sub.w   d3,d2
        moveq   #0,d0
        move.w  d2,d0
        andi.w  #15,d0
        divu.w  #3,d0
        move.l  d0,d1
        swap    d1
        mulu.w  #80,d1
        lsl.w   #2,d0
        lea     ParallaxBankDirectory,a0
        movea.l (a0,d0.w),a1
        adda.l  d1,a1
        asr.w   #4,d2
        add.w   d2,d2
        addq.w  #2,d2                  ;skip the sixteen-pixel guard
        adda.w  d2,a1
        move.l  ParallaxYFP,d0
        asr.l   #8,d0
        move.w  #272,d4
        sub.w   d0,d4
        bpl.s   .top_positive
        moveq   #0,d4
.top_positive:
        cmpi.w  #288,d4
        ble.s   .top_ready
        move.w  #288,d4
.top_ready:
        move.w  d4,d0
        mulu.w  #FRAME_ROW_STRIDE,d0
        adda.l  d0,a1
        move.l  a1,d0
        move.w  d0,CopParallaxBplPtr+6
        swap    d0
        move.w  d0,CopParallaxBplPtr+2
        cmp.w   ParallaxPaletteY,d4
        beq.s   .done
        move.w  d4,ParallaxPaletteY
        lsl.w   #2,d4
        lea     ParallaxRowPalette,a0
        adda.w  d4,a0
        lea     ParallaxColorSlots,a2
        move.w  #223,d7
.colors:
        movea.l (a2)+,a1
        move.w  (a0)+,(a1)
        move.w  (a0)+,8(a1)
        dbf     d7,.colors
.done:
        movem.l (sp)+,d0-d7/a0-a4
.return:
        rts

; Native-style independent background state and direction guards. The port's
; integer camera velocities interpolate missing +4/down odd table entries.
; Explicit debug teleports reconstruct a bounded starting offset instead.
AdvanceParallaxCamera:
        move.w  d0,d2
        sub.w   ParallaxPreviousX,d2
        move.w  d0,ParallaxPreviousX
        move.w  d1,d3
        sub.w   ParallaxPreviousY,d3
        move.w  d1,ParallaxPreviousY
        tst.w   d2
        beq.s   .vertical
        move.w  d2,d4
        bpl.s   .x_abs
        neg.w   d4
.x_abs: cmpi.w  #64,d4
        bhi.s   .x_teleport
        move.l  ParallaxXFP,d4
        tst.w   d2
        bmi.s   .left
        cmpi.l  #65536,d4
        bge.s   .vertical
        bra.s   .x_step
.left:  tst.l   d4
        ble.s   .vertical
.x_step:
        ext.l   d2
        lsl.l   #6,d2
        add.l   d2,d4
        bra.s   .x_clamp
.x_teleport:
        moveq   #0,d4
        move.w  d0,d4
        lsl.l   #6,d4
.x_clamp:
        tst.l   d4
        bpl.s   .x_max
        moveq   #0,d4
.x_max: cmpi.l  #65536,d4
        ble.s   .x_store
        move.l  #65536,d4
.x_store:
        move.l  d4,ParallaxXFP
.vertical:
        tst.w   d3
        beq.w   .done
        move.w  d3,d4
        bpl.s   .y_abs
        neg.w   d4
.y_abs: cmpi.w  #64,d4
        bls.s   .y_steps
        move.w  d1,d4
        subi.w  #256,d4
        bpl.s   .y_teleport_positive
        moveq   #0,d4
.y_teleport_positive:
        mulu.w  #96,d4
        cmpi.l  #65536,d4
        ble.s   .y_teleport_store
        move.l  #65536,d4
.y_teleport_store:
        move.l  d4,ParallaxYFP
        rts
.y_steps:
        tst.w   d3
        bmi.s   .down
        cmpi.w  #256,d1
        blo.s   .done
.up:    cmpi.l  #(257*256),ParallaxYFP
        bge.s   .done
        moveq   #5,d4
        cmp.w   d4,d3
        bge.s   .up_lookup
        move.w  d3,d4
.up_lookup:
        sub.w   d4,d3
        add.w   d4,d4
        lea     ParallaxUpSteps(pc),a0
        moveq   #0,d5
        move.w  (a0,d4.w),d5
        add.l   d5,ParallaxYFP
        tst.w   d3
        bne.s   .up
        rts
.down:  neg.w   d3
.down_loop:
        tst.l   ParallaxYFP
        ble.s   .done
        moveq   #10,d4
        cmp.w   d4,d3
        bge.s   .down_lookup
        move.w  d3,d4
.down_lookup:
        sub.w   d4,d3
        add.w   d4,d4
        lea     ParallaxDownSteps(pc),a0
        moveq   #0,d5
        move.w  (a0,d4.w),d5
        sub.l   d5,ParallaxYFP
        tst.w   d3
        bne.s   .down_loop
.done:  rts

ParallaxUpSteps: dc.w 0,96,192,320,392,464
ParallaxDownSteps: dc.w 0,96,192,288,384,512,640,712,784,856,928
        EVEN
ParallaxBankDirectory:
        dc.l ParallaxBank0,ParallaxBank1,ParallaxBank2
        dc.l ParallaxBank3,ParallaxBank4,ParallaxBank5
ParallaxAllowed:     dc.b 1
ParallaxEnabled:     dc.b 0
        EVEN
ParallaxPreviousX:   dc.w 0
ParallaxPreviousY:   dc.w 0
ParallaxPaletteY:    dc.w -1
ParallaxXFP:         dc.l 0
ParallaxYFP:         dc.l 0
