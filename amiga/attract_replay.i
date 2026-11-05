; Recorded original arcade actor/camera playback at the PAL simulation rate.
; Six native samples elapse over five PAL ticks. Preserve action edges from
; both samples when crossing two native frames, so a one-frame shot survives.
DEMO_NATIVE_FRAMES EQU DEMO_MOTION_FRAMES
DEMO_MOTION_BYTES EQU DEMO_MOTION_DATA_BYTES

UnpackArcadeDemo:
        movem.l d0-d7/a0-a6,-(sp)
        lea     DemoMotionLZ,a0
        lea     RawObjectScratch,a1
        jsr     LZSS_Decompress
        lea     RawObjectScratch,a0
        lea     DemoMotionData,a1
        jsr     ExpandAttractMotion
        lea     DemoExtraPosesLZ,a0
        lea     RawObjectScratch,a1
        jsr     LZSS_Decompress
        lea     RawObjectScratch,a0
        lea     DemoExtraPoseData,a1
        jsr     DeinterleaveAttractPoses
        movem.l (sp)+,d0-d7/a0-a6
        rts

InitArcadeDemo:
        clr.w   DemoClockFraction
        clr.w   DemoNativeTick
        clr.w   DemoPreviousNativeTick
        clr.w   DemoInputTransitionCount
        clr.b   DemoInputMask
        clr.b   DemoActionPress
        clr.b   DemoFinished
        clr.b   DemoActorVisible
        clr.b   DemoPreviousArmState
        move.b  #1,DemoPlaybackActive
        rts

AdvanceArcadeDemo:
        movem.l d0-d3/a0,-(sp)
        clr.b   DemoActionPress
        addq.w  #6,DemoClockFraction
.native_tick:
        cmpi.w  #5,DemoClockFraction
        blo.s   .done
        subq.w  #5,DemoClockFraction
        cmpi.w  #DEMO_NATIVE_FRAMES,DemoNativeTick
        bhs.s   .finished
        move.w  DemoNativeTick,d0
        mulu.w  #20,d0
        lea     DemoMotionData,a0
        adda.l  d0,a0
        move.w  14(a0),d1
        lsr.w   #8,d1
        andi.w  #$3F,d1                ; native current input mask
        cmp.b   DemoInputMask,d1
        beq.s   .same_input
        addq.w  #1,DemoInputTransitionCount
.same_input:
        moveq   #0,d2
        move.b  DemoInputMask,d2
        not.b   d2
        and.b   d1,d2
        andi.b  #3,d2                  ; native grapple01 / rifle02
        or.b    d2,DemoActionPress
        move.b  d1,DemoInputMask
        addq.w  #1,DemoNativeTick
        bra.s   .native_tick
.finished:
        move.b  #1,DemoFinished
        clr.b   DemoInputMask
        clr.b   DemoActionPress
.done:
        movem.l (sp)+,d0-d3/a0
        rts

; Playback replaces only the attract actor, retaining live level props/NPCs.
; Normal gameplay continues to use UpdatePlayer and its requested jump controls.
UpdateArcadeDemoActor:
        movem.l d0-d7/a0-a2,-(sp)
        addq.w  #1,AnimTick
        move.w  DemoNativeTick,d0
        subq.w  #1,d0
        bpl.s   .sample_ready
        moveq   #0,d0
.sample_ready:
        mulu.w  #20,d0
        lea     DemoMotionData,a0
        adda.l  d0,a0
        move.w  (a0)+,PlayerX
        move.w  (a0)+,PlayerY
        move.w  (a0)+,CamX
        move.w  (a0)+,CamY
        move.w  (a0)+,ClawX
        move.w  (a0)+,ClawY
        move.w  (a0)+,DemoPoseIndex
        move.w  (a0)+,d7
        move.w  d7,d0
        andi.w  #1,d0
        move.b  d0,DemoActorVisible
        lsr.w   #1,d7
        move.w  d7,d0
        andi.w  #1,d0
        move.b  d0,ChuteMode
        lsr.w   #1,d7
        move.w  d7,d0
        andi.w  #1,d0
        move.b  d0,EntryActive
        lsr.w   #1,d7
        move.w  d7,d0
        andi.w  #1,d0
        move.b  d0,OnGround
        lsr.w   #1,d7
        move.w  d7,d0
        andi.w  #1,d0
        move.w  d0,FacingDir
        lsr.w   #1,d7
        andi.w  #7,d7
        move.b  d7,GrappleState
        moveq   #0,d0
        move.b  (a0)+,d0
        move.w  d0,CurrentSwingAng
        move.b  (a0)+,d0
        ext.w   d0
        move.w  d0,GrappleDir
        move.w  (a0)+,SwingRadius
        move.w  ClawX,AnchorX
        move.w  ClawY,AnchorY
        clr.w   PlayerVX
        clr.w   PlayerVY
        clr.b   VaultFlipTimer
        moveq   #0,d6
        jsr     DemoDirections
        move.b  d6,InputDirs
        move.w  DemoNativeTick,d0
        sub.w   DemoPreviousNativeTick,d0
        add.w   d0,ArmAnimTick
        move.w  DemoNativeTick,DemoPreviousNativeTick
        tst.b   LatchAnimTimer
        beq.s   .latch_ready
        subq.b  #1,LatchAnimTimer
.latch_ready:
        cmp.b   DemoPreviousArmState,d7
        beq.s   .arm_ready
        clr.w   ArmAnimTick
        cmpi.b  #3,d7
        blo.s   .launch
        cmpi.b  #3,DemoPreviousArmState
        bhs.s   .arm_ready
        move.b  #6,LatchAnimTimer
        moveq   #$12,d0
        jsr     PlayNativeSFX
        bra.s   .arm_ready
.launch:
        cmpi.b  #1,d7
        bne.s   .arm_ready
        moveq   #$13,d0
        jsr     PlayNativeSFX
.arm_ready:
        move.b  d7,DemoPreviousArmState
        move.w  PlayerY,d0
        subi.w  #20,d0
        sub.w   ClawY,d0
        tst.w   GrappleDir
        beq.s   .arm_distance
        move.w  ClawX,d0
        sub.w   PlayerX,d0
        bpl.s   .arm_distance
        neg.w   d0
.arm_distance:
        tst.w   d0
        bpl.s   .distance_ready
        moveq   #0,d0
.distance_ready:
        move.w  d0,GrappleDist
        movem.l (sp)+,d0-d7/a0-a2
        rts

; a0=exact pose pixels, d0=unique cache key, d1=height, d2=feet-to-top.
GetArcadeDemoPose:
        move.w  DemoPoseIndex,d0
        move.w  d0,d1
        lsl.w   #3,d1
        lea     DemoPoseDirectory,a0
        adda.w  d1,a0
        move.w  4(a0),d1
        move.w  6(a0),d2
        movea.l (a0),a0
        ori.w   #$6000,d0
        rts

DemoDirections:
        moveq   #0,d6
        tst.b   EntryActive
        bne.s   .done
        move.b  DemoInputMask,d6
        lsr.w   #2,d6
        andi.w  #15,d6
.done:  rts

DemoFire:
        moveq   #0,d5
        tst.b   EntryActive
        bne.s   .done
        move.b  DemoInputMask,d5
        or.b    DemoActionPress,d5
        andi.w  #1,d5
.done:  rts

DemoClockFraction:       dc.w 0
DemoNativeTick:          dc.w 0
DemoPreviousNativeTick:  dc.w 0
DemoInputTransitionCount: dc.w 0
DemoPoseIndex:           dc.w 0
DemoInputMask:           dc.b 0
DemoActionPress:         dc.b 0
DemoFinished:            dc.b 0
DemoPlaybackActive:      dc.b 0
DemoActorVisible:        dc.b 0
DemoPreviousArmState:    dc.b 0
        EVEN
        include "attract_motion_unpack.i"
