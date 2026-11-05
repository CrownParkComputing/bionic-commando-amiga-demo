; Fixed ROM props share the BOB renderer with enemies. Sprite definitions
; retain native emitter origins; logical frames may contain many 32x32 parts.
MAX_OBJECTS     EQU 128
OB_SIZE         EQU 32
OB_X            EQU 0
OB_Y            EQU 2
OB_STATE        EQU 4                  ; 0 absent, 1 live, 2 destruction effect
OB_ROLE         EQU 6                  ; 1gate,2hive,3sign,4platform,5prop,6hazard,8hatch,9panel,10reactor
OB_KIND         EQU 8
OB_FIRST        EQU 10
OB_FRAME        EQU 12
OB_ANIMS        EQU 14
OB_PERIOD       EQU 16
OB_TICK         EQU 18
OB_HP           EQU 20
OB_TIMER        EQU 22
OB_FLAGS        EQU 24
OB_HOME_X       EQU 26
OB_HOME_Y       EQU 28
OB_AUX          EQU 30
BOB_OBJECT_BASE EQU BOB_ENEMY_FRAMES
OB_DIR_FLAG     EQU $1000
OB_OPEN_FLAG    EQU $2000
OB_FROZEN_FLAG  EQU $4000

; Asset decompression and banked BOB address lookup live in object_loader.i.

InitObjects:
        movem.l d0-d7/a0-a4,-(sp)
        lea     ObjectList,a0
        move.w  #(MAX_OBJECTS*OB_SIZE/4)-1,d0
.clear:
        clr.l   (a0)+
        dbf     d0,.clear
        move.w  #-1,PlayerPlatformIndex
        move.w  #-1,ClawPlatformIndex
        clr.w   ObjectPlatformCount
        move.w  CurrentStage(pc),d0
        lsl.w   #2,d0
        lea     ObjectStageDirectory,a0
        movea.l (a0,d0.w),a0
        move.w  (a0)+,d7
        move.w  d7,ObjectCount
        beq.s   .done
        lea     ObjectList,a1
        lea     ObjectPlatformPointers,a2
        subq.w  #1,d7
.record:
        movea.l a1,a3
        moveq   #7,d0
.copy:  move.l  (a0)+,(a1)+
        dbf     d0,.copy
        cmpi.w  #8,OB_ROLE(a3)
        beq.s   .register_surface
        cmpi.w  #4,OB_ROLE(a3)
        bne.s   .not_platform
.register_surface:
        move.l  a3,(a2)+
        addq.w  #1,ObjectPlatformCount
.not_platform:
        cmpi.w  #8,OB_ROLE(a3)
        bne.s   .record_done
        movea.l a3,a4
        bsr.w   SpawnHatchOperator
.record_done:
        dbf     d7,.record
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

UpdateObjects:
        movem.l d0-d7/a0-a4,-(sp)
        lea     ObjectList,a4
        move.w  #MAX_OBJECTS-1,d7
.loop:
        tst.w   OB_STATE(a4)
        beq.w   .next
        cmpi.w  #2,OB_STATE(a4)
        bne.s   .live
        subq.w  #1,OB_TIMER(a4)
        bgt.w   .animate
        clr.w   OB_STATE(a4)
        bra.w   .next
.live:
        cmpi.w  #8,OB_ROLE(a4)
        beq.s   .hatch
        cmpi.w  #9,OB_ROLE(a4)
        beq.s   .panel
        cmpi.w  #4,OB_ROLE(a4)
        bne.s   .damage
        bsr.w   MoveObjectPlatform
.damage:
        cmpi.w  #10,OB_ROLE(a4)
        bne.s   .bullet_hits
        ; Native activation occurs when the actor enters the visible view.
        movem.l d4-d7,-(sp)             ; d7 is the outer object-loop counter
        bsr.w   ObjectBounds
        move.w  CamX,d0
        cmp.w   d6,d0
        bge.s   .reactor_bounds_done
        addi.w  #320,d0
        cmp.w   d4,d0
        ble.s   .reactor_bounds_done
        move.w  CamY,d0
        cmp.w   d7,d0
        bge.s   .reactor_bounds_done
        addi.w  #240,d0
        cmp.w   d5,d0
        ble.s   .reactor_bounds_done
        jsr     NotifyLevelReactorVisible
.reactor_bounds_done:
        movem.l (sp)+,d4-d7
.bullet_hits:
        bsr.w   ObjectBulletHits
        tst.w   OB_STATE(a4)
        beq.w   .next
        cmpi.w  #1,OB_STATE(a4)
        bne.s   .animate
        cmpi.w  #2,OB_ROLE(a4)
        bne.s   .contact
        bsr.w   ObjectHiveArmContact
.contact:
        bsr.w   ObjectPlayerContact
.animate:
        bsr.w   AnimateObject
        bra.s   .next
.hatch:
        bsr.w   UpdateHatch
        bra.s   .next
.panel:
        bsr.w   UpdateFallingPanel
.next:
        lea     OB_SIZE(a4),a4
        dbf     d7,.loop
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Frame attributes contain native duration-1 in bits8..14. Each shape's actual
; frame keeps its own timing; low8 FLAGS stores native loop index+1, zero=hold.
AnimateObject:
        cmpi.w  #2,OB_ANIMS(a4)
        blt.s   .done
        moveq   #0,d0
        move.w  OB_FRAME(a4),d0
        lsl.w   #2,d0
        lea     ObjectFrameDirectory,a0
        movea.l (a0,d0.w),a0
        move.w  12(a0),d1
        lsr.w   #8,d1
        andi.w  #$007F,d1
        addq.w  #1,d1
        mulu.w  #5,d1
        addq.l  #3,d1
        divu.w  #6,d1
        bne.s   .duration_ready
        moveq   #1,d1
.duration_ready:
        addq.w  #1,OB_TICK(a4)
        cmp.w   OB_TICK(a4),d1
        bgt.s   .done
        clr.w   OB_TICK(a4)
        addq.w  #1,OB_FRAME(a4)
        move.w  OB_FRAME(a4),d0
        sub.w   OB_FIRST(a4),d0
        cmp.w   OB_ANIMS(a4),d0
        blt.s   .done
        move.w  OB_FLAGS(a4),d0
        andi.w  #$00FF,d0
        beq.s   .last
        subq.w  #1,d0
        add.w   OB_FIRST(a4),d0
        move.w  d0,OB_FRAME(a4)
        rts
.last:
        subq.w  #1,OB_FRAME(a4)
.done:  rts

; Native moving gantry ($20E68..$20FA4): 768..897, 1px/native tick,
; with a separate first-contact latch for Joe and for the attached claw.
MoveObjectPlatform:
        movem.l d0-d7/a0-a3,-(sp)
        move.w  OB_X(a4),d2
        moveq   #0,d3
        tst.w   OB_AUX(a4)
        bne.s   .left
        cmpi.w  #896,d2
        ble.s   .right_step
        move.w  #1,OB_AUX(a4)
        bra.s   .carry
.right_step:
        move.w  #$0133,d0
        bra.s   .step
.left:
        cmpi.w  #768,d2
        bgt.s   .left_step
        clr.w   OB_AUX(a4)
        bra.s   .carry
.left_step:
        move.w  #-$0133,d0
.step:
        add.w   OB_TIMER(a4),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,OB_TIMER(a4)
        asr.w   #8,d0
        add.w   d0,OB_X(a4)
        cmpi.w  #768,OB_X(a4)
        bge.s   .min_ok
        move.w  #768,OB_X(a4)
.min_ok:
        cmpi.w  #897,OB_X(a4)
        ble.s   .max_ok
        move.w  #897,OB_X(a4)
.max_ok:
        move.w  OB_X(a4),d3
        sub.w   d2,d3
.carry:
        move.l  a4,d6
        subi.l  #ObjectList,d6
        lsr.l   #5,d6
        cmpi.b  #3,GrappleState
        bge.s   .no_player
        tst.w   PlayerVY
        bmi.s   .no_player
        move.w  PlayerX(pc),d0
        sub.w   d2,d0
        bpl.s   .player_dx
        neg.w   d0
.player_dx:
        cmpi.w  #48,d0
        bgt.s   .no_player
        move.w  PlayerY(pc),d0
        sub.w   OB_Y(a4),d0
        cmpi.w  #16,d0
        bhi.s   .no_player
        cmp.w   PlayerPlatformIndex(pc),d6
        bne.s   .player_latch
        add.w   d3,PlayerX
.player_latch:
        move.w  d6,PlayerPlatformIndex
        move.w  OB_Y(a4),d0
        addq.w  #1,d0
        move.w  d0,PlayerY
        clr.w   PlayerVY
        move.b  #1,OnGround
        bra.s   .claw
.no_player:
        cmp.w   PlayerPlatformIndex(pc),d6
        bne.s   .claw
        move.w  #-1,PlayerPlatformIndex
.claw:
        tst.b   GrappleState
        beq.s   .no_claw
        move.w  ClawX(pc),d0
        sub.w   d2,d0
        bpl.s   .claw_dx
        neg.w   d0
.claw_dx:
        cmpi.w  #48,d0
        bgt.s   .no_claw
        move.w  ClawY(pc),d0
        sub.w   OB_Y(a4),d0
        bpl.s   .claw_dy
        neg.w   d0
.claw_dy:
        cmpi.w  #8,d0
        bgt.s   .no_claw
        cmp.w   ClawPlatformIndex(pc),d6
        bne.s   .claw_latch
        add.w   d3,ClawX
        cmpi.b  #3,GrappleState
        blt.s   .claw_latch
        add.w   d3,AnchorX
.claw_latch:
        move.w  d6,ClawPlatformIndex
        bra.s   .done
.no_claw:
        cmp.w   ClawPlatformIndex(pc),d6
        bne.s   .done
        move.w  #-1,ClawPlatformIndex
.done:
        movem.l (sp)+,d0-d7/a0-a3
        rts

; Dynamic support query, reached only when the extracted foreground tile
; has no surface. Keep the same d0=surface/-1 contract as CheckPlatformAt.
CheckObjectPlatformAt:
        tst.w   ObjectPlatformCount
        bne.s   .has_platform
        moveq   #-1,d0
        rts
.has_platform:
        movem.l d1-d7/a0-a1,-(sp)
        move.w  d0,d4
        move.w  d1,d5
        lea     ObjectPlatformPointers,a0
        move.w  ObjectPlatformCount(pc),d7
        subq.w  #1,d7
.loop:
        movea.l (a0)+,a1
        cmpi.w  #1,OB_STATE(a1)
        bne.s   .next
        cmpi.w  #8,OB_ROLE(a1)
        beq.s   .hatch_surface
        move.w  d4,d0
        sub.w   OB_X(a1),d0
        bpl.s   .dx
        neg.w   d0
.dx:    cmpi.w  #48,d0
        bgt.s   .next
        move.w  OB_Y(a1),d0
        addq.w  #1,d0
        move.w  d5,d1
        sub.w   d0,d1
        bpl.s   .dy
        neg.w   d1
.dy:    cmpi.w  #8,d1
        ble.s   .done
        bra.s   .next
.hatch_surface:
        move.w  OB_FLAGS(a1),d0
        andi.w  #OB_OPEN_FLAG,d0
        bne.s   .next
        move.w  d4,d0
        sub.w   OB_HOME_X(a1),d0
        btst    #4,OB_FLAGS(a1)        ; wordbit12, native direction
        bne.s   .hatch_left
        addq.w  #8,d0
        bra.s   .hatch_span
.hatch_left:
        addi.w  #56,d0
.hatch_span:
        cmpi.w  #64,d0
        bhs.s   .next
        move.w  OB_HOME_Y(a1),d0
        subq.w  #7,d0                 ; native JoeY=parentY+23,feet=center+16
        move.w  d5,d1
        sub.w   d0,d1
        bpl.s   .hatch_abs_y
        neg.w   d1
.hatch_abs_y:
        cmpi.w  #8,d1
        ble.s   .done
.next:
        dbf     d7,.loop
        moveq   #-1,d0
.done:
        movem.l (sp)+,d1-d7/a0-a1
        rts

; a4 = object. Bounds are d4=left,d5=top,d6=right,d7=bottom.
ObjectBounds:
        moveq   #0,d0
        move.w  OB_FRAME(a4),d0
        lsl.w   #2,d0
        lea     ObjectFrameDirectory,a0
        movea.l (a0,d0.w),a0
        move.w  4(a0),d4
        add.w   OB_X(a4),d4
        move.w  6(a0),d5
        add.w   OB_Y(a4),d5
        move.w  d4,d6
        add.w   (a0),d6
        move.w  d5,d7
        add.w   2(a0),d7
        rts

ObjectBulletHits:
        movem.l d0-d7/a0-a2,-(sp)
        cmpi.w  #2,OB_ROLE(a4)
        beq.s   .bounds
        tst.w   OB_HP(a4)
        ble.w   .done
.bounds:
        bsr.w   ObjectBounds
        lea     PBullets,a0
        moveq   #MAX_PBUL-1,d3
.bullet:
        tst.w   6(a0)
        beq.s   .next
        move.w  (a0),d0
        cmp.w   d4,d0
        blt.s   .next
        cmp.w   d6,d0
        bge.s   .next
        move.w  2(a0),d0
        cmp.w   d5,d0
        blt.s   .next
        cmp.w   d7,d0
        bge.s   .next
        clr.w   6(a0)
        cmpi.w  #2,OB_ROLE(a4)
        bne.s   .damage
        bsr.w   ReleaseHiveBees
        bra.s   .done
.damage:
        subq.w  #1,OB_HP(a4)
        bgt.s   .next
        bsr.w   DestroyObject
        bra.s   .done
.next:
        lea     BUL_SIZE(a0),a0
        dbf     d3,.bullet
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

DestroyObject:
        moveq   #$1E,d0
        jsr     PlayNativeSFX
        clr.w   OB_HP(a4)
        cmpi.w  #10,OB_ROLE(a4)
        bne.s   .gate
        jsr     NotifyLevelReactorDestroyed
        ; Reuse the extracted burst while the full reactor demolition is pending.
        bra.s   .burst
.gate:
        cmpi.w  #1,OB_ROLE(a4)
        bne.s   .remove
        ; Native275A0 moves upwardY+22 before switching to the64px burst.
        subi.w  #22,OB_Y(a4)
.burst:
        move.w  #2,OB_STATE(a4)
        move.w  #25,OB_TIMER(a4)
        move.w  #OBJ_GATE_BURST_FIRST,OB_FIRST(a4)
        move.w  #OBJ_GATE_BURST_FIRST,OB_FRAME(a4)
        move.w  #OBJ_GATE_BURST_COUNT,OB_ANIMS(a4)
        andi.w  #$FF00,OB_FLAGS(a4)
        ori.w   #7,OB_FLAGS(a4)        ; terminalnativeburstframe index6
        clr.w   OB_TICK(a4)
        rts
.remove:
        clr.w   OB_STATE(a4)
        rts

ObjectHiveArmContact:
        tst.b   GrappleState
        beq.s   .done
        movem.l d0-d7/a0-a1,-(sp)
        bsr.w   ObjectBounds
        move.w  ClawX(pc),d0
        cmp.w   d4,d0
        blt.s   .restore
        cmp.w   d6,d0
        bge.s   .restore
        move.w  ClawY(pc),d0
        cmp.w   d5,d0
        blt.s   .restore
        cmp.w   d7,d0
        bge.s   .restore
        bsr.w   ReleaseHiveBees
.restore:
        movem.l (sp)+,d0-d7/a0-a1
.done:  rts

ReleaseHiveBees:
        movem.l d0-d7/a0-a4,-(sp)
        tst.w   OB_AUX(a4)
        bne.w   .done
        lea     EnemyList,a0
        moveq   #0,d0
        moveq   #MAX_ENEMIES-1,d1
.count:
        tst.w   EN_STATE(a0)
        bne.s   .count_next
        addq.w  #1,d0
.count_next:
        lea     EN_SIZE(a0),a0
        dbf     d1,.count
        cmpi.w  #5,d0
        blt.w   .done
        move.l  a4,d2
        subi.l  #ObjectList,d2
        lsr.l   #5,d2
        moveq   #0,d3
        move.w  PlayerX(pc),d0
        cmp.w   OB_X(a4),d0
        bge.s   .side_ready
        moveq   #1,d3
.side_ready:
        move.w  OB_X(a4),d4
        move.w  OB_Y(a4),d5
        moveq   #0,d1
.spawn:
        moveq   #10,d0
        bsr.w   SpawnNativeEnemy
        tst.w   d0
        bmi.s   .rollback
        tst.w   d1
        bne.s   .next
        addq.w  #1,d0
        move.w  d0,OB_AUX(a4)
.next:
        addq.w  #1,d1
        cmpi.w  #5,d1
        blt.s   .spawn
        clr.w   NativeBuzzTimer
        bra.s   .done
.rollback:
        lea     EnemyList,a0
        lea     EnemyAux,a1
        moveq   #MAX_ENEMIES-1,d7
.rollback_loop:
        cmpi.w  #10,EN_TYPE(a0)
        bne.s   .rollback_next
        cmp.w   EA_HOME_Y(a1),d2
        bne.s   .rollback_next
        clr.w   EN_STATE(a0)
.rollback_next:
        lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a1),a1
        dbf     d7,.rollback_loop
        clr.w   OB_AUX(a4)
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; d0=parentObjectIndex. The native head clears the parent release latch.
RootNotifyHiveHeadDeath:
        movem.l d0/a0,-(sp)
        cmpi.w  #MAX_OBJECTS,d0
        bhs.s   .done
        lsl.w   #5,d0
        lea     ObjectList,a0
        adda.w  d0,a0
        cmpi.w  #2,OB_ROLE(a0)
        bne.s   .done
        clr.w   OB_AUX(a0)
        clr.w   NativeBuzzTimer
.done:  movem.l (sp)+,d0/a0
        rts

RootNotifyLarge2ChildDeath:
        movem.l d0/a0,-(sp)
        cmpi.w  #MAX_OBJECTS,d0
        bhs.s   .done
        lsl.w   #5,d0
        lea     ObjectList,a0
        adda.w  d0,a0
        cmpi.w  #8,OB_ROLE(a0)
        bne.s   .done
        ori.w   #OB_FROZEN_FLAG,OB_FLAGS(a0)
.done:  movem.l (sp)+,d0/a0
        rts

; Preview contact uses the live emitter rectangle and Joe's standing body.
; Native gate overlap is posture-dependent; the retained walking fixture first
; hits at13px center separation. Full native posture rectangle dispatch remains
; unported, so this conservative body rectangle is not claimed pixel-exact.
ObjectPlayerContact:
        movem.l d0-d7/a0-a1,-(sp)
        tst.b   EntryActive
        bne.s   .done
        tst.b   AttractMode
        bne.s   .done
        tst.b   GameOverMode
        bne.s   .done
        cmpi.w  #1,OB_ROLE(a4)
        beq.s   .dangerous
        cmpi.w  #6,OB_ROLE(a4)
        bne.s   .done
.dangerous:
        bsr.w   ObjectBounds
        move.w  PlayerX(pc),d0
        addq.w  #8,d0
        cmp.w   d4,d0
        blt.s   .done
        subi.w  #16,d0
        cmp.w   d6,d0
        bge.s   .done
        move.w  PlayerY(pc),d0
        cmp.w   d5,d0
        blt.s   .done
        subi.w  #30,d0
        cmp.w   d7,d0
        bge.s   .done
        bsr.w   KillPlayer
.done:
        movem.l (sp)+,d0-d7/a0-a1
        rts

BuildObjectBobs:
        movem.l d0-d7/a0-a4,-(sp)
        lea     ObjectList,a4
        move.w  #MAX_OBJECTS-1,d7
.loop:
        tst.w   OB_STATE(a4)
        beq.s   .next
        moveq   #0,d0
        move.w  OB_FRAME(a4),d0
        move.w  OB_X(a4),d4
        move.w  OB_Y(a4),d5
        bsr.s   AppendObjectFrame
.next:
        lea     OB_SIZE(a4),a4
        dbf     d7,.loop
        movem.l (sp)+,d0-d7/a0-a4
        rts

; d0=logical object frame, d4/d5=native anchor in top-down map coordinates.
; Preserve all caller registers: enemy families can use the same frame renderer.
RootAppendObjectFrame:
AppendObjectFrame:
        movem.l d0-d7/a0-a3,-(sp)
        cmpi.w  #OBJ_LOGICAL_FRAME_COUNT,d0
        bhs.s   .done
        lsl.w   #2,d0
        lea     ObjectFrameDirectory,a0
        movea.l (a0,d0.w),a0
        move.w  4(a0),d1
        add.w   d4,d1
        move.w  6(a0),d2
        add.w   d5,d2
        ; Reject the complete metasprite before expanding its quadrants.
        move.w  OldTileX(pc),d3
        lsl.w   #4,d3
        move.w  (a0),d4
        add.w   d1,d4
        cmp.w   d3,d4
        ble.s   .done
        addi.w  #352,d3
        cmp.w   d3,d1
        bge.s   .done
        move.w  OldTileY(pc),d3
        lsl.w   #4,d3
        move.w  2(a0),d4
        add.w   d2,d4
        cmp.w   d3,d4
        ble.s   .done
        addi.w  #240,d3
        cmp.w   d3,d2
        bge.s   .done
        move.w  8(a0),d6
        lea     OBJ_FRAME_HEADER_BYTES(a0),a0
        subq.w  #1,d6
.part:
        move.w  (a0)+,d4
        add.w   d1,d4
        move.w  (a0)+,d5
        add.w   d2,d5
        move.w  (a0)+,d3
        addi.w  #BOB_OBJECT_BASE,d3
        bsr.w   AddBob
        dbf     d6,.part
.done:
        movem.l (sp)+,d0-d7/a0-a3
        rts

; Kind1 hatches own one original SMALL0kind1 operator. Spawn once, before the
; parent activates; the six stage3 operators are dynamic, not extra fixed ROMs.
SpawnHatchOperator:
        movem.l d0-d7/a0-a4,-(sp)
        cmpi.w  #1,OB_KIND(a4)
        bne.s   .done
        tst.w   OB_AUX(a4)
        bne.s   .done
        move.w  OB_FLAGS(a4),d0
        andi.w  #OB_FROZEN_FLAG,d0
        bne.s   .done
        move.l  a4,d2
        subi.l  #ObjectList,d2
        lsr.l   #5,d2
        moveq   #0,d3
        move.w  OB_X(a4),d4
        subi.w  #32,d4
        btst    #4,OB_FLAGS(a4)
        beq.s   .side_ready
        moveq   #1,d3
        addi.w  #64,d4
.side_ready:
        move.w  OB_Y(a4),d5
        subi.w  #24,d5
        moveq   #12,d0
        moveq   #1,d1
        bsr.w   SpawnNativeEnemy
        tst.w   d0
        bmi.s   .done
        addq.w  #1,d0
        move.w  d0,OB_AUX(a4)
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Native1FF14..20170: closed->90tickwait->10+10open->falling panel,
; hold200ticks->four16tick right/left shifts->closed. PAL preserves time.
UpdateHatch:
        movem.l d0-d7/a0-a3,-(sp)
        move.w  OB_FLAGS(a4),d0
        andi.w  #OB_FROZEN_FLAG,d0
        bne.w   .done
        bsr.w   SpawnHatchOperator
        tst.w   OB_HP(a4)
        bne.w   .timed
        ; Only Joe contact starts the plain kind0 panel; kind1 uses its operator
        ; once the original actor is within the active camera neighborhood.
        tst.w   OB_KIND(a4)
        beq.s   .joe_contact
        tst.w   OB_AUX(a4)
        beq.w   .done
        bsr.w   ObjectIsVisible
        tst.w   d0
        beq.w   .done
        move.w  OB_AUX(a4),d0
        subq.w  #1,d0
        moveq   #0,d1
        bsr.w   AdvanceTrapdoorOperator
        bra.s   .activate
.joe_contact:
        move.w  PlayerX(pc),d0
        sub.w   OB_HOME_X(a4),d0
        btst    #4,OB_FLAGS(a4)
        bne.s   .joe_left
        addq.w  #8,d0
        bra.s   .joe_span
.joe_left:
        addi.w  #56,d0
.joe_span:
        cmpi.w  #64,d0
        bhs.w   .done
        move.w  PlayerY(pc),d0
        sub.w   OB_HOME_Y(a4),d0
        addq.w  #7,d0
        bpl.s   .joe_abs_y
        neg.w   d0
.joe_abs_y:
        cmpi.w  #8,d0
        bgt.w   .done
        tst.w   PlayerVY
        bmi.w   .done
.activate:
        move.w  #1,OB_HP(a4)
        move.w  #75,OB_TIMER(a4)
        bra.w   .done
.timed:
        ; Four native16tick move legs use converted1.2px speed and retain
        ; fractional progress across all four poses; final anchor is exact.
        cmpi.w  #5,OB_HP(a4)
        blt.s   .decrement
        bsr.w   MoveHatchAnchor
.decrement:
        subq.w  #1,OB_TIMER(a4)
        bgt.w   .done
        move.w  OB_HP(a4),d0
        cmpi.w  #1,d0
        beq.s   .open1
        cmpi.w  #2,d0
        beq.s   .open2
        cmpi.w  #3,d0
        beq.w   .drop_panel
        cmpi.w  #4,d0
        beq.w   .move0
        cmpi.w  #5,d0
        beq.w   .move1
        cmpi.w  #6,d0
        beq.w   .move2
        cmpi.w  #7,d0
        beq.w   .move3
        bra.w   .close
.open1:
        move.w  #2,OB_HP(a4)
        move.w  #8,OB_TIMER(a4)
        moveq   #0,d0
        bsr.w   SetHatchPose
        bra.w   .done
.open2:
        move.w  #3,OB_HP(a4)
        move.w  #8,OB_TIMER(a4)
        ori.w   #OB_OPEN_FLAG,OB_FLAGS(a4)
        moveq   #1,d0
        bsr.w   SetHatchPose
        bra.w   .done
.drop_panel:
        bsr.w   SpawnFallingPanel
        tst.w   d0
        bmi.w   .retry_drop
        move.w  #4,OB_HP(a4)
        move.w  #167,OB_TIMER(a4)
        moveq   #2,d0
        bsr.w   SetHatchPose
        tst.w   OB_KIND(a4)
        beq.w   .done
        move.w  OB_AUX(a4),d0
        beq.w   .done
        subq.w  #1,d0
        moveq   #1,d1
        bsr.w   AdvanceTrapdoorOperator
        bra.w   .done
.retry_drop:
        move.w  #1,OB_TIMER(a4)
        bra.w   .done
.move0:
        move.w  #5,OB_HP(a4)
        move.w  #13,OB_TIMER(a4)
        clr.w   OB_TICK(a4)            ; movement fraction, not animation timer
        subi.w  #16,OB_X(a4)
        btst    #4,OB_FLAGS(a4)
        beq.s   .move0_pose
        addi.w  #32,OB_X(a4)
.move0_pose:
        moveq   #3,d0
        bsr.w   SetHatchPose
        bra.s   .done
.move1:
        move.w  #6,OB_HP(a4)
        move.w  #13,OB_TIMER(a4)
        moveq   #4,d0
        bsr.w   SetHatchPose
        bra.s   .done
.move2:
        move.w  #7,OB_HP(a4)
        move.w  #14,OB_TIMER(a4)
        moveq   #5,d0
        bsr.w   SetHatchPose
        bra.s   .done
.move3:
        move.w  #8,OB_HP(a4)
        move.w  #13,OB_TIMER(a4)
        moveq   #6,d0
        bsr.w   SetHatchPose
        bra.s   .done
.close:
        clr.w   OB_HP(a4)
        clr.w   OB_TIMER(a4)
        clr.w   OB_TICK(a4)
        andi.w  #$DFFF,OB_FLAGS(a4)
        move.w  OB_HOME_X(a4),OB_X(a4)
        move.w  OB_HOME_Y(a4),OB_Y(a4)
        move.w  OB_FIRST(a4),OB_FRAME(a4)
.done:
        movem.l (sp)+,d0-d7/a0-a3
        rts

MoveHatchAnchor:
        move.w  #$0133,d0
        btst    #4,OB_FLAGS(a4)
        beq.s   .signed
        neg.w   d0
.signed:
        add.w   OB_TICK(a4),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,OB_TICK(a4)
        asr.w   #8,d0
        add.w   d0,OB_X(a4)
        rts

; d0 pose0..6. Explicit per-kind/per-direction scripts, never whole-table loops.
SetHatchPose:
        lsl.w   #3,d0
        move.w  OB_KIND(a4),d1
        andi.w  #1,d1
        lsl.w   #2,d1
        add.w   d1,d0
        btst    #4,OB_FLAGS(a4)
        beq.s   .index_ready
        addq.w  #2,d0
.index_ready:
        lea     HatchPoseFrames(pc),a0
        move.w  (a0,d0.w),OB_FRAME(a4)
        rts
HatchPoseFrames:
        dc.w OBJ_HATCH_KIND0_OPEN1_D0_FIRST,OBJ_HATCH_KIND0_OPEN1_D1_FIRST
        dc.w OBJ_HATCH_KIND1_OPEN1_D0_FIRST,OBJ_HATCH_KIND1_OPEN1_D1_FIRST
        dc.w OBJ_HATCH_KIND0_OPEN2_D0_FIRST,OBJ_HATCH_KIND0_OPEN2_D1_FIRST
        dc.w OBJ_HATCH_KIND1_OPEN2_D0_FIRST,OBJ_HATCH_KIND1_OPEN2_D1_FIRST
        dc.w OBJ_HATCH_KIND0_HOLD_D0_FIRST,OBJ_HATCH_KIND0_HOLD_D1_FIRST
        dc.w OBJ_HATCH_KIND1_HOLD_D0_FIRST,OBJ_HATCH_KIND1_HOLD_D1_FIRST
        dc.w OBJ_HATCH_KIND0_MOVE0_D0_FIRST,OBJ_HATCH_KIND0_MOVE0_D1_FIRST
        dc.w OBJ_HATCH_KIND1_MOVE0_D0_FIRST,OBJ_HATCH_KIND1_MOVE0_D1_FIRST
        dc.w OBJ_HATCH_KIND0_MOVE1_D0_FIRST,OBJ_HATCH_KIND0_MOVE1_D1_FIRST
        dc.w OBJ_HATCH_KIND1_MOVE1_D0_FIRST,OBJ_HATCH_KIND1_MOVE1_D1_FIRST
        dc.w OBJ_HATCH_KIND0_MOVE2_D0_FIRST,OBJ_HATCH_KIND0_MOVE2_D1_FIRST
        dc.w OBJ_HATCH_KIND1_MOVE2_D0_FIRST,OBJ_HATCH_KIND1_MOVE2_D1_FIRST
        dc.w OBJ_HATCH_KIND0_MOVE3_D0_FIRST,OBJ_HATCH_KIND0_MOVE3_D1_FIRST
        dc.w OBJ_HATCH_KIND1_MOVE3_D0_FIRST,OBJ_HATCH_KIND1_MOVE3_D1_FIRST

; Falling panel is native dynamic8: constant3px/native tick, no acceleration,
; terrain collision, damage flag or pickups in the decoded handler19BC6.
SpawnFallingPanel:
        movem.l d1-d7/a0-a3,-(sp)
        lea     ObjectList,a0
        moveq   #0,d0
.find:
        tst.w   OB_STATE(a0)
        beq.s   .found
        lea     OB_SIZE(a0),a0
        addq.w  #1,d0
        cmpi.w  #MAX_OBJECTS,d0
        blt.s   .find
        moveq   #-1,d0
        bra.s   .done
.found:
        movea.l a0,a1
        moveq   #7,d1
.clear: clr.l   (a1)+
        dbf     d1,.clear
        move.w  OB_X(a4),OB_X(a0)
        addq.w  #5,OB_X(a0)
        btst    #4,OB_FLAGS(a4)
        beq.s   .position_ready
        subi.w  #16,OB_X(a0)
.position_ready:
        move.w  OB_Y(a4),OB_Y(a0)
        addi.w  #48,OB_Y(a0)
        move.w  #1,OB_STATE(a0)
        move.w  #9,OB_ROLE(a0)
        move.w  OB_KIND(a4),OB_KIND(a0)
        move.w  OB_FLAGS(a4),d1
        andi.w  #OB_DIR_FLAG,d1
        move.w  d1,OB_FLAGS(a0)
        move.w  OB_KIND(a4),d1
        andi.w  #1,d1
        lsl.w   #2,d1
        btst    #4,OB_FLAGS(a4)
        beq.s   .art_ready
        addq.w  #2,d1
.art_ready:
        lea     HatchPanelFrames(pc),a1
        move.w  (a1,d1.w),OB_FIRST(a0)
        move.w  (a1,d1.w),OB_FRAME(a0)
        move.w  #1,OB_ANIMS(a0)
.done:
        movem.l (sp)+,d1-d7/a0-a3
        rts
HatchPanelFrames:
        dc.w OBJ_HATCH_PANEL_KIND0_D0_FIRST,OBJ_HATCH_PANEL_KIND0_D1_FIRST
        dc.w OBJ_HATCH_PANEL_KIND1_D0_FIRST,OBJ_HATCH_PANEL_KIND1_D1_FIRST

UpdateFallingPanel:
        movem.l d0-d2,-(sp)
        bsr.w   ObjectIsVisible
        tst.w   d0
        beq.s   .remove
        move.w  #$039A,d0              ; native3px *60/50=3.6px/PAL
        add.w   OB_AUX(a4),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,OB_AUX(a4)
        asr.w   #8,d0
        add.w   d0,OB_Y(a4)
        bra.s   .done
.remove:
        clr.w   OB_STATE(a4)
.done:  movem.l (sp)+,d0-d2
        rts

ObjectIsVisible:
        move.w  OB_X(a4),d0
        sub.w   CamX,d0
        addi.w  #64,d0
        cmpi.w  #448,d0
        bhi.s   .outside
        move.w  OB_Y(a4),d0
        sub.w   CamY,d0
        addi.w  #64,d0
        cmpi.w  #352,d0
        bhi.s   .outside
        moveq   #1,d0
        rts
.outside:
        moveq   #0,d0
        rts
