; Additional native fixed soldier families. Geometry and state art come from
; the original shape/script tables; original movement magnitudes are converted
; from 60Hz to 50Hz in 8.8 units. Complex melee/projectile branches are tracked
; in reference/ENEMY_LOGIC.md rather than silently mapped to rifle AI.
NP_FOOT         EQU 0
NP_HEIGHT       EQU 2
NP_HALF_WIDTH   EQU 4
NP_SPEED        EQU 6
NP_IDLE         EQU 8
NP_WALK         EQU 12
NP_ATTACK       EQU 16
NP_DEATH        EQU 20
NP_SIZE         EQU 24

; a1 actor, a2 auxiliary record; keep a1/d6/d7 for UpdateEnemyAI.
NativeGroundThink:
        addq.w  #1,EA_STEP(a2)
        bsr.w   NativeGetParams
        bsr.w   EnemyPlayerDelta
        ; The original 48px soldiers have a wider body than the 32px rifleman.
        move.w  NP_HALF_WIDTH(a3),d0
        subq.w  #4,d0
        cmp.w   d0,d5
        bge.s   .contact_done
        move.w  d4,d0
        bpl.s   .contact_abs_y
        neg.w   d0
.contact_abs_y:
        cmpi.w  #24,d0
        bge.s   .contact_done
        bsr.w   KillPlayer
.contact_done:
        move.w  EN_TYPE(a1),d0
        cmpi.w  #3,d0
        bne.s   .persistent_patrol
        ; Small4 kind0 chooses retreat when Joe is closer than 52px ($266C6).
        move.w  d4,d1
        bpl.s   .small_abs_y
        neg.w   d1
.small_abs_y:
        cmpi.w  #32,d1
        bgt.s   .persistent_patrol
        cmpi.w  #52,d5
        bge.s   .persistent_patrol
        tst.w   d3
        bmi.s   .retreat_right
        clr.w   EN_DIR(a1)
        bra.s   .persistent_patrol
.retreat_right:
        move.w  #1,EN_DIR(a1)
.persistent_patrol:
        move.w  NP_SPEED(a3),d0
.speed_ready:
        tst.w   EN_DIR(a1)
        bne.s   .signed_speed
        neg.w   d0
.signed_speed:
        add.w   EA_XFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_XFRAC(a2)
        asr.w   #8,d0
        move.w  d0,d3
        beq.w   .moving
        move.w  EN_X(a1),d2
        add.w   d0,d2
        cmpi.w  #16,d2
        blt.w   .turn
        cmpi.w  #2032,d2
        bgt.w   .turn

        ; Combat4,6,9 and Combat10 kind0 preserve their native patrol bounds.
        move.w  EN_TYPE(a1),d0
        cmpi.w  #10,d0
        bge.s   .walls
        cmpi.w  #6,d0
        blt.s   .walls
        cmpi.w  #9,d0
        bne.s   .kind_bounds
        tst.w   EA_KIND(a2)
        bne.s   .walls
        lea     NativeCombat10Bounds(pc),a0
        bra.s   .bounds_ready
.kind_bounds:
        subi.w  #6,d0
        lsl.w   #2,d0
        lea     NativeBoundsDirectory(pc),a0
        movea.l (a0,d0.w),a0
        move.w  EA_KIND(a2),d0
        lsl.w   #2,d0
        adda.w  d0,a0
.bounds_ready:
        cmp.w   (a0),d2
        blt.w   .turn
        cmp.w   2(a0),d2
        bgt.w   .turn
.walls:
        move.w  d2,d0
        move.w  NP_HALF_WIDTH(a3),d1
        subq.w  #4,d1
        tst.w   EN_DIR(a1)
        beq.s   .lead_left
        add.w   d1,d0
        bra.s   .wall_test
.lead_left:
        sub.w   d1,d0
.wall_test:
        move.w  EN_Y(a1),d1
        subi.w  #14,d1
        bsr.w   GetTileCol
        tst.w   d0
        bmi.s   .turn
        cmpi.w  #11,EN_TYPE(a1)
        beq.s   .edge_support
        cmpi.w  #5,EN_TYPE(a1)
        bne.s   .move
.edge_support:
        ; Small5 $1E1CE reverses at the end of its supporting platform.
        move.w  d2,d0
        move.w  EN_Y(a1),d1
        addq.w  #2,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.s   .turn
        sub.w   EN_Y(a1),d0
        cmpi.w  #6,d0
        bgt.s   .turn
        cmpi.w  #-12,d0
        blt.s   .turn
.move:
        move.w  d2,EN_X(a1)
        tst.w   d3
        bpl.s   .gait
        neg.w   d3
.gait:
        add.w   d3,EN_TIMER(a1)
        andi.w  #$000F,EN_TIMER(a1)
.moving:
        ori.w   #EN_MOVING,EN_TIMER(a1)
        rts
.turn:
        eori.w  #1,EN_DIR(a1)
        clr.w   EA_XFRAC(a2)
        rts

; Combat10 kind1 is a scripted three-leg actor, not a ground patroller.
; Native $1C4D4/$1C51E/$1C584: right82, up226, right250 then remove.
NativeMarchThink:
        andi.w  #$000F,EN_TIMER(a1)
        addq.w  #1,EA_STEP(a2)
        cmpi.w  #464,EA_STEP(a2)
        bge.s   .remove
        move.w  #1,EN_DIR(a1)
        cmpi.w  #68,EA_STEP(a2)
        blt.s   .horizontal
        cmpi.w  #256,EA_STEP(a2)
        bge.s   .horizontal
        move.w  #-$0170,d0
        add.w   EA_YFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_YFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_Y(a1)
        bra.s   .contact
.horizontal:
        move.w  #$0170,d0
        add.w   EA_XFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_XFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_X(a1)
        add.w   d0,EN_TIMER(a1)
        ori.w   #EN_MOVING,EN_TIMER(a1)
.contact:
        bsr.w   EnemyPlayerDelta
        bra.w   EnemyContact
.remove:
        clr.w   EN_STATE(a1)
        rts

; Dynamic SMALL0 kind1 is the LARGE2 child, table189E0. Native18864..18996
; stop/pose/move/crouch/turn cycle; unlike kind0 it does not use floor gravity.
NativeSmall0ChildThink:
        andi.w  #$000F,EN_TIMER(a1)
        addq.w  #1,EA_STEP(a2)
        tst.w   EA_VX(a2)
        beq.w   .contact               ; parent starts operator from indefiniteidle
        cmpi.w  #5,EA_VX(a2)
        beq.w   .contact               ; parent panel-drop releases lowposeloop
        subq.w  #1,EN_SHOOT(a1)
        bgt.s   .phase_ready
        addq.w  #1,EA_VX(a2)
        cmpi.w  #11,EA_VX(a2)
        blt.s   .new_phase
        clr.w   EA_VX(a2)
.new_phase:
        clr.w   EA_STEP(a2)
        move.w  EA_VX(a2),d0
        add.w   d0,d0
        lea     NativeSmall0ChildDurations(pc),a0
        move.w  (a0,d0.w),EN_SHOOT(a1)
        cmpi.w  #5,EA_VX(a2)
        bne.s   .uncrouch
        addq.w  #8,EN_Y(a1)            ; native188E0 decrements upwardY by8
        bra.s   .phase_ready
.uncrouch:
        cmpi.w  #6,EA_VX(a2)
        bne.s   .last_turn
        subq.w  #8,EN_Y(a1)
        eori.w  #1,EN_DIR(a1)
        bra.s   .phase_ready
.last_turn:
        cmpi.w  #9,EA_VX(a2)
        bne.s   .phase_ready
        eori.w  #1,EN_DIR(a1)
.phase_ready:
        cmpi.w  #3,EA_VX(a2)
        beq.s   .move
        cmpi.w  #8,EA_VX(a2)
        bne.s   .contact
.move:
        move.w  #$0133,d0
        tst.w   EN_DIR(a1)
        bne.s   .signed
        neg.w   d0
.signed:
        add.w   EA_XFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_XFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_X(a1)
        ori.w   #EN_MOVING,EN_TIMER(a1)
.contact:
        bsr.w   EnemyPlayerDelta
        bra.w   EnemyContact
NativeSmall0ChildDurations:
        dc.w 0,8,8,17,8,0,8,8,17,8,8

NativeGetParams:
        move.w  EN_TYPE(a1),d0
        subi.w  #3,d0
        mulu.w  #NP_SIZE,d0
        lea     NativeEnemyParams(pc),a3
        adda.w  d0,a3
        rts

; Sequence format count.w,totalTicks.w,loopIndex.w; then leftID,rightID,ticks.
; No live sequence includes hit or death frames from another native state.
BuildNativeEnemyBob:
        movem.l d0-d5/a0-a3,-(sp)
        bsr.w   NativeGetParams
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        move.w  EN_X(a1),d4
        move.w  EN_Y(a1),d5
        sub.w   NP_FOOT(a3),d5          ; emitter's world center, not feet
        cmpi.w  #2,EN_STATE(a1)
        beq.w   .death
        cmpi.w  #12,EN_TYPE(a1)
        bne.s   .ordinary_art
        move.w  EA_VX(a2),d0
        lsl.w   #2,d0
        lea     NativeSmall0ChildArt(pc),a0
        movea.l (a0,d0.w),a0
        move.w  EA_STEP(a2),d0
        bra.w   .sequence
.ordinary_art:
        movea.l NP_IDLE(a3),a0
        tst.w   EN_TIMER(a1)
        bpl.s   .idle
        movea.l NP_WALK(a3),a0
        cmpi.w  #9,EN_TYPE(a1)
        bne.s   .walk_sequence
        cmpi.w  #1,EA_KIND(a2)
        bne.s   .walk_sequence
        lea     NativeEnemy9March(pc),a0
.walk_sequence:
        move.w  EA_STEP(a2),d0
        bra.s   .sequence
.idle:  moveq   #0,d0                  ; never walk in place while stopped
        bra.s   .sequence
.death:
        movea.l NP_DEATH(a3),a0
        move.l  a0,d0
        beq.w   .done
        move.w  2(a0),d0
        sub.w   EN_TIMER(a1),d0
.sequence:
        move.l  a0,d1
        beq.s   .done                  ; unresolved state never borrows unrelated art
        moveq   #0,d1
        move.w  2(a0),d1
        beq.s   .done
        cmp.w   d1,d0
        blo.s   .select
        ; Repeating live scripts wrap only at their native loop target.
        move.w  4(a0),d2
        bmi.s   .last
        mulu.w  #6,d2
        lea     6(a0,d2.w),a3
        move.w  (a0),d3
        move.w  4(a0),d2
        sub.w   d2,d3
        moveq   #0,d2
.loop_sum:
        add.w   4(a3),d2
        lea     6(a3),a3
        subq.w  #1,d3
        bgt.s   .loop_sum
        sub.w   d1,d0
        andi.l  #$0000FFFF,d0
        divu.w  d2,d0
        swap    d0
        move.w  d1,d3
        sub.w   d2,d3
        add.w   d3,d0
        bra.s   .select
.last:
        move.w  d1,d0
        subq.w  #1,d0
.select:
        move.w  (a0)+,d1
        addq.l  #4,a0
        subq.w  #1,d1
.find:
        cmp.w   4(a0),d0
        blo.s   .found
        sub.w   4(a0),d0
        lea     6(a0),a0
        dbf     d1,.find
        bra.s   .done
.found:
        tst.w   EN_DIR(a1)
        beq.s   .left
        addq.l  #2,a0
.left:  move.w  (a0),d0
        bsr.w   RootAppendObjectFrame
.done:  movem.l (sp)+,d0-d5/a0-a3
        rts

NativeSmall0ChildArt:
        dc.l NativeEnemy12_idle,NativeEnemy12_phase1,NativeEnemy12_walk
        dc.l NativeEnemy12_walk,NativeEnemy12_phase3,NativeEnemy12_crouch
        dc.l NativeEnemy12_phase3,NativeEnemy12_walk,NativeEnemy12_walk
        dc.l NativeEnemy12_walk,NativeEnemy12_phase1

NativeBoundsDirectory:
        dc.l NativeCombat4Bounds,NativeCombat6Bounds,NativeCombat9Bounds
NativeCombat4Bounds:
        dc.w 1072,1136,1312,1344       ; native $1C9DE, kinds0/1
NativeCombat6Bounds:
        dc.w 1931,2032,1936,1984,1776,1872,936,1200
        dc.w 1936,2016,1824,1920,1856,2016,1792,1856 ; native $1D6DE
NativeCombat9Bounds:
        dc.w 1936,2032,1936,2016       ; native $1B666
NativeCombat10Bounds:
        dc.w 1936,2016                 ; native $1BF7A; kind0 only
        include "native_enemy_art.i"
        include "bee_enemies.i"
