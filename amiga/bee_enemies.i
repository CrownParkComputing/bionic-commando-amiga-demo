; Native SMALL8 hive chain. Original vectors and PAL timings are generated from
; reference/level_objects/bee_motion_parameters.json. EnemyList/Aux stay16 bytes.
BE_TIMER EQU 0
BE_MODE  EQU 2                     ; 0 launch,1 cruise,+/-2 turn,3 contact,4 escape
BE_TX    EQU 4
BE_TY    EQU 6

; d0=type10,d1=node0..4,d2=parentObjectIndex,d3=side,d4=X,d5=map centerY.
; Return d0=slot or-1; preserve all other registers. Root preflights five slots.
SpawnNativeEnemy:
        movem.l d1-d7/a0-a4,-(sp)
        move.w  d0,d7
        cmpi.w  #12,d0
        beq.s   .find_slot
        cmpi.w  #10,d0
        bne.w   .full
        cmpi.w  #4,d1
        bhi.w   .full
.find_slot:
        lea     EnemyList,a0
        lea     EnemyAux,a2
        lea     EnemyBeeExtra,a4
        moveq   #0,d0
.find:
        tst.w   EN_STATE(a0)
        beq.s   .found
        lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a2),a2
        lea     8(a4),a4
        addq.w  #1,d0
        cmpi.w  #MAX_ENEMIES,d0
        blt.s   .find
        bra.w   .full
.found:
        cmpi.w  #12,d7
        beq.w   .spawn_child
        move.w  d0,d6                   ; default head index=self for kind0
        tst.w   d1
        beq.s   .head_found
        lea     EnemyList,a1
        lea     EnemyAux,a3
        moveq   #0,d6
.head_scan:
        cmpi.w  #1,EN_STATE(a1)
        bne.s   .next_head
        cmpi.w  #10,EN_TYPE(a1)
        bne.s   .next_head
        tst.w   EA_KIND(a3)
        bne.s   .next_head
        cmp.w   EA_HOME_Y(a3),d2
        beq.s   .head_found
.next_head:
        lea     EN_SIZE(a1),a1
        lea     EA_SIZE(a3),a3
        addq.w  #1,d6
        cmpi.w  #MAX_ENEMIES,d6
        blt.s   .head_scan
        bra.w   .full
.head_found:
        clr.l   (a0)
        clr.l   4(a0)
        clr.l   8(a0)
        clr.l   12(a0)
        clr.l   (a2)
        clr.l   4(a2)
        clr.l   8(a2)
        clr.l   12(a2)
        clr.l   (a4)
        clr.l   4(a4)
        move.w  d4,EN_X(a0)
        addq.w  #8,d5
        move.w  d5,EN_Y(a0)             ; shape0 footer=map anchor+8
        move.w  #1,EN_STATE(a0)
        move.w  #10,EN_TYPE(a0)
        move.w  #5,EN_HP(a0)            ; group HP is held by the head
        move.w  d1,EA_KIND(a2)
        move.w  d6,EA_HOME_X(a2)
        move.w  d2,EA_HOME_Y(a2)
        andi.w  #1,d3
        mulu.w  #5,d3
        add.w   d1,d3
        lea     NativeBeeFan(pc),a1
        moveq   #0,d7
        move.b  (a1,d3.w),d7
        move.w  d7,EA_VX(a2)            ; native32-way heading
        move.w  d7,EA_VY(a2)            ; delayed heading for next link
        move.w  #EN_MOVING,EN_TIMER(a0)
        cmpi.w  #16,d7
        bhi.s   .spawn_facing_ready
        move.w  #1,EN_DIR(a0)
.spawn_facing_ready:
        bra.s   .done
.spawn_child:
        clr.l   (a0)
        clr.l   4(a0)
        clr.l   8(a0)
        clr.l   12(a0)
        clr.l   (a2)
        clr.l   4(a2)
        clr.l   8(a2)
        clr.l   12(a2)
        move.w  d4,EN_X(a0)
        addi.w  #16,d5
        move.w  d5,EN_Y(a0)
        move.w  d4,EA_HOME_X(a2)
        move.w  d2,EA_HOME_Y(a2)        ; parent ObjectList index
        move.w  d1,EA_KIND(a2)
        move.w  #1,EN_STATE(a0)
        move.w  #12,EN_TYPE(a0)
        move.w  #1,EN_HP(a0)            ; native189A2 removes child on any damage
        clr.w   EN_SHOOT(a0)            ; native initial pose waits for parent signal
        move.w  #1,EN_DIR(a0)
        tst.w   d3
        beq.s   .child_ready
        clr.w   EN_DIR(a0)
.child_ready:
        bra.s   .done
.full:  moveq   #-1,d0
.done:  movem.l (sp)+,d1-d7/a0-a4
        rts
NativeBeeFan: dc.b 8,0,16,24,24,24,0,16,8,8
        EVEN
NativeBeeActivation: dc.w 50,53,53,57,60
NativeBeeEscapeHeadings: dc.w 0,6,12,20,26

; a1=actor,a2=aux. Preserve AI loop d6/d7 and actor a1.
NativeBeeThink:
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lsr.w   #1,d0
        lea     EnemyBeeExtra,a3
        adda.w  d0,a3
        ; Every follower belongs to the original head, including noncontiguous
        ; slots; a dead head invalidates the whole chain before contact/render.
        move.w  EA_HOME_X(a2),d0
        mulu.w  #EN_SIZE,d0
        lea     EnemyList,a0
        adda.w  d0,a0
        cmpi.w  #1,EN_STATE(a0)
        bne.w   .remove
        addq.w  #1,EA_STEP(a2)
        move.w  EA_KIND(a2),d0
        add.w   d0,d0
        lea     NativeBeeActivation(pc),a0
        move.w  (a0,d0.w),d0
        cmp.w   EA_STEP(a2),d0
        ble.w   .active
        ; Launchfan rotates at the native6/5tick ratio after8ticks (last16).
        move.w  EA_STEP(a2),d0
        mulu.w  #6,d0
        divu.w  #5,d0
        move.w  d0,d1
        sub.w   EN_SHOOT(a1),d1
        move.w  d0,EN_SHOOT(a1)
        moveq   #8,d2
        cmpi.w  #4,EA_KIND(a2)
        bne.s   .launch_delay
        moveq   #16,d2
.launch_delay:
        cmp.w   d2,d0
        ble.s   .launch_move
        add.w   d1,EA_VX(a2)
        andi.w  #31,EA_VX(a2)
.launch_move:
        lea     NativeBeeLaunchVectors(pc),a0
        bra.w   .move
.active:
        move.w  BE_MODE(a3),d0
        bne.s   .state_ready
        move.w  #1,BE_MODE(a3)
        tst.w   EA_KIND(a2)
        bne.s   .follower_start
        bsr.w   NativeBeeAimJoe
        move.w  d0,EA_VX(a2)
        move.w  PlayerX(pc),BE_TX(a3)
        move.w  PlayerY(pc),BE_TY(a3)
        bra.s   .state_ready
.follower_start:
        bsr.w   NativeBeeCopyPrevious
.state_ready:
        move.w  BE_MODE(a3),d0
        cmpi.w  #4,d0
        beq.w   .escape
        cmpi.w  #3,d0
        beq.w   .contact_mode
        tst.w   EA_KIND(a2)
        bne.w   .follower
        cmpi.w  #1,d0
        bne.s   .curve
        ; Native cruise holds an aimed route; reaching its target starts an
        ; arc of12headingsteps, rather than instantaneous per-tick pursuit.
        move.w  EN_X(a1),d0
        sub.w   BE_TX(a3),d0
        bpl.s   .abs_target_x
        neg.w   d0
.abs_target_x:
        cmpi.w  #32,d0
        bgt.w   .cruise
        move.w  #80,BE_TIMER(a3)       ; native12steps *8ticks ->80PAL
        move.w  #2,BE_MODE(a3)
        move.w  PlayerY(pc),d0
        cmp.w   EN_Y(a1),d0
        bge.s   .curve
        move.w  #-2,BE_MODE(a3)
.curve:
        subq.w  #1,BE_TIMER(a3)
        bgt.s   .curve_step
        bsr.w   NativeBeeAimJoe
        move.w  d0,EA_VX(a2)
        move.w  #1,BE_MODE(a3)
        move.w  PlayerX(pc),BE_TX(a3)
        move.w  PlayerY(pc),BE_TY(a3)
        bra.s   .cruise
.curve_step:
        moveq   #0,d0
        move.w  BE_TIMER(a3),d0
        divu.w  #7,d0                 ; native8ticks≈7PAL
        swap    d0
        tst.w   d0
        bne.s   .cruise
        moveq   #1,d0
        tst.w   BE_MODE(a3)
        bpl.s   .turn_heading
        moveq   #-1,d0
.turn_heading:
        add.w   d0,EA_VX(a2)
        andi.w  #31,EA_VX(a2)
        bra.s   .cruise
.follower:
        ; A link receives the previous link's delayed heading every4PAL ticks
        ; (native5). Saving the prior heading preserves the curved train.
        move.w  EA_STEP(a2),d0
        andi.w  #3,d0
        bne.s   .cruise
        bsr.w   NativeBeeCopyPrevious
.cruise:
        tst.w   EA_KIND(a2)
        bne.s   .cruise_vectors
        move.w  EA_STEP(a2),d0
        andi.w  #3,d0
        bne.s   .cruise_vectors
        move.w  EA_VX(a2),EA_VY(a2)
.cruise_vectors:
        lea     NativeBeeCruiseVectors(pc),a0
        ; Contact switches to native slow pursuit, then escape, as opposed to
        ; killing the whole group after its50tick warmup.
        bsr.w   EnemyPlayerDelta
        cmpi.w  #16,d5
        bge.s   .move
        move.w  d4,d0
        addq.w  #8,d0
        bpl.s   .abs_contact_y
        neg.w   d0
.abs_contact_y:
        cmpi.w  #16,d0
        bge.s   .move
        move.w  #3,BE_MODE(a3)
        move.w  #100,BE_TIMER(a3)       ; native120ticks
        bsr.w   KillPlayer
        lea     NativeBeeLaunchVectors(pc),a0
        bra.s   .move
.contact_mode:
        subq.w  #1,BE_TIMER(a3)
        ble.s   .start_escape
        move.w  EA_STEP(a2),d0
        andi.w  #1,d0
        bne.s   .contact_move
        bsr.w   NativeBeeAimJoe
        move.w  d0,EA_VX(a2)
.contact_move:
        lea     NativeBeeLaunchVectors(pc),a0
        bra.s   .move
.start_escape:
        move.w  #4,BE_MODE(a3)
        move.w  #150,BE_TIMER(a3)       ; native180ticks
        move.w  EA_KIND(a2),d0
        add.w   d0,d0
        lea     NativeBeeEscapeHeadings(pc),a0
        move.w  (a0,d0.w),EA_VX(a2)
.escape:
        subq.w  #1,BE_TIMER(a3)
        ble.s   .finish
        lea     NativeBeeEscapeVectors(pc),a0
.move:
        move.w  EA_VX(a2),d0
        andi.w  #31,d0
        lsl.w   #2,d0
        adda.w  d0,a0
        move.w  (a0),d0
        add.w   EA_XFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_XFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_X(a1)
        move.w  2(a0),d0
        add.w   EA_YFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_YFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_Y(a1)
        move.w  #EN_MOVING,EN_TIMER(a1)
        clr.w   EN_DIR(a1)
        cmpi.w  #16,EA_VX(a2)
        bhi.s   .done
        move.w  #1,EN_DIR(a1)
.done:  rts
.finish:
        tst.w   EA_KIND(a2)
        bne.s   .remove
        bsr.w   NativeBeeNotifyDeath
.remove:
        clr.w   EN_STATE(a1)
        rts

NativeBeeCopyPrevious:
        movem.l d0-d2/a0/a4,-(sp)
        move.w  EA_VX(a2),EA_VY(a2)     ; next link receives our prior route
        move.w  EA_KIND(a2),d2
        subq.w  #1,d2
        lea     EnemyList,a0
        lea     EnemyAux,a4
        moveq   #MAX_ENEMIES-1,d1
.scan:  cmpi.w  #1,EN_STATE(a0)
        bne.s   .next
        cmpi.w  #10,EN_TYPE(a0)
        bne.s   .next
        cmp.w   EA_KIND(a4),d2
        bne.s   .next
        move.w  EA_HOME_X(a4),d0
        cmp.w   EA_HOME_X(a2),d0
        bne.s   .next
        move.w  EA_VY(a4),EA_VX(a2)
        bra.s   .done
.next:  lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a4),a4
        dbf     d1,.scan
.done:  movem.l (sp)+,d0-d2/a0/a4
        rts

; Return closest native32-way cruise heading, using integer dot products.
NativeBeeAimJoe:
        movem.l d1-d7/a0,-(sp)
        move.w  PlayerX(pc),d3
        sub.w   EN_X(a1),d3
        move.w  PlayerY(pc),d4
        sub.w   EN_Y(a1),d4
        subq.w  #8,d4
        lea     NativeBeeCruiseVectors(pc),a0
        move.l  #$80000000,d2
        moveq   #0,d0
        moveq   #0,d1
        moveq   #31,d7
.loop:  move.w  (a0)+,d5
        muls.w  d3,d5
        move.w  (a0)+,d6
        muls.w  d4,d6
        add.l   d6,d5
        cmp.l   d2,d5
        ble.s   .next
        move.l  d5,d2
        move.w  d1,d0
.next:  addq.w  #1,d1
        dbf     d7,.loop
        movem.l (sp)+,d1-d7/a0
        rts

; Called before bullet damage. a1 becomes the group's head actor.
NativeBeeDamageHead:
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        move.w  EA_HOME_X(a2),d0
        mulu.w  #EN_SIZE,d0
        lea     EnemyList,a1
        adda.w  d0,a1
        rts

NativeBeeNotifyDeath:
        movem.l d0-d7/a0-a6,-(sp)
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        move.w  EA_HOME_Y(a2),d0
        bsr.w   RootNotifyHiveHeadDeath
        movem.l (sp)+,d0-d7/a0-a6
        rts

NativeSmall0NotifyDeath:
        movem.l d0-d7/a0-a6,-(sp)
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        move.w  EA_HOME_Y(a2),d0
        bsr.w   RootNotifyLarge2ChildDeath
        movem.l (sp)+,d0-d7/a0-a6
        rts

; d0=childslot,d1=0start/1panel-drop. Parent controls both indefinite poses.
AdvanceTrapdoorOperator:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w  #MAX_ENEMIES,d0
        bhs.s   .done
        tst.w   d0
        bmi.s   .done
        mulu.w  #EN_SIZE,d0
        lea     EnemyList,a1
        lea     EnemyAux,a2
        adda.w  d0,a1
        adda.w  d0,a2
        cmpi.w  #1,EN_STATE(a1)
        bne.s   .done
        cmpi.w  #12,EN_TYPE(a1)
        bne.s   .done
        tst.w   d1
        bne.s   .release
        tst.w   EA_VX(a2)
        bne.s   .done
        move.w  #1,EA_VX(a2)
        bra.s   .begin
.release:
        cmpi.w  #5,EA_VX(a2)
        bne.s   .done
        move.w  #6,EA_VX(a2)
        subq.w  #8,EN_Y(a1)
        eori.w  #1,EN_DIR(a1)
.begin:
        move.w  #8,EN_SHOOT(a1)
        clr.w   EA_STEP(a2)
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts
