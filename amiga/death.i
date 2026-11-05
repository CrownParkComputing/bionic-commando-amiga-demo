; Ordinary native fatal hit: knockback, ground tumble, static flat pose, restart.
; Source12BCE..12E80 and14990/14A40. PAL logic ticks, not rendered frames.
; Caller retains entry/attract/gameover eligibility guards in KillPlayer.
;
; BeginPlayerDeath: preserves all registers, idempotent while active.
; UpdatePlayerDeath: d0=1 requests the caller's life decrement/restart; otherwise0.
;                   Every other register is preserved. Call once per logic tick.
; CancelPlayerDeath: call at stage/title reset and before finishing a death.
; GetPlayerDeathSprite: a0=512B sprite, every other register preserved.
; Root supplies JoeDeathSpritesData(5120B) and PlayNativeSFX(d0=native ID).
JOE_DEATH_FRAME_BYTES EQU 512
JOE_DEATH_FRAME_COUNT EQU 10
JOE_DEATH_DATA_BYTES EQU 5120

BeginPlayerDeath:
        movem.l d0-d2,-(sp)
        tst.b   DeathActive
        bne.w   .done
        move.b  #1,DeathActive
        clr.b   DeathPhase
        clr.b   DeathPose
        clr.w   DeathTimer
        clr.w   DeathFractionX
        clr.w   DeathFractionY
        move.w  FacingDir,d0
        andi.w  #1,d0
        move.w  d0,DeathFacing
        move.w  #$01CD,DeathVelocityX    ; native1.5px/tick -> PAL1.8
        tst.w   d0
        beq.s   .direction_ready
        neg.w   DeathVelocityX          ; default push away from facing/attacker
.direction_ready:
        move.w  #-$0133,DeathVelocityY   ; native1px upward -> PAL1.2
        clr.b   GrappleState
        clr.b   VaultFlipTimer
        clr.b   ChuteMode
        clr.b   OnGround
        clr.w   PlayerVX
        clr.w   PlayerVY
        cmpi.w  #2080,PlayerY
        ble.s   .sprite
        ; Native127A8/127AE (or12BA4/12BAA) takes state6 without a new
        ; wait or sound call. MAME fall fixture451state6→452life decrement.
        ; Do NOT confuse12D0C: that is special substate0C, ID20+180tickhold.
        move.b  #3,DeathPhase           ; generic offscreen fall: no pose/cue
        move.w  #1,DeathTimer
.sprite:
        bsr.w   SetDeathSpriteIndex
.done:
        movem.l (sp)+,d0-d2
        rts

UpdatePlayerDeath:
        movem.l d1-d7/a0-a4,-(sp)
        moveq   #0,d0
        tst.b   DeathActive
        beq.w   .done
        cmpi.b  #2,DeathPhase
        bge.w   .hold_or_finish
        tst.b   DeathPhase
        bne.w   .ground
        addq.w  #1,DeathTimer
        move.w  PlayerY,d5
        move.w  DeathVelocityX,d1
        add.w   DeathFractionX,d1
        move.w  d1,d2
        andi.w  #$00FF,d2
        move.w  d2,DeathFractionX
        asr.w   #8,d1
        add.w   d1,PlayerX
        cmpi.w  #16,PlayerX
        bge.s   .min_x
        move.w  #16,PlayerX
.min_x:
        cmpi.w  #2016,PlayerX
        ble.s   .max_x
        move.w  #2016,PlayerX
.max_x:
        move.w  DeathVelocityY,d1
        add.w   DeathFractionY,d1
        move.w  d1,d2
        andi.w  #$00FF,d2
        move.w  d2,DeathFractionY
        asr.w   #8,d1
        add.w   d1,PlayerY
        addi.w  #$002E,DeathVelocityY   ; native.125 *1.2^2=.18px/tick²
        cmpi.w  #2080,PlayerY
        bgt.w   .offscreen
        cmpi.w  #125,DeathTimer         ; bounded if an isolated death has no floor
        bge.w   .offscreen
        cmpi.w  #$0133,DeathVelocityY
        blt.w   .active_done
        ; Sweep the downward arc through native tile/dynamic platform surfaces.
        move.w  d5,d6
        andi.w  #$FFF0,d6
.surface:
        move.w  PlayerX,d0
        move.w  d6,d1
        jsr     CheckPlatformAt
        tst.w   d0
        bmi.s   .next_surface
        move.w  d5,d2
        subq.w  #4,d2
        cmp.w   d2,d0
        blt.s   .next_surface
        move.w  PlayerY,d2
        addq.w  #4,d2
        cmp.w   d2,d0
        bgt.s   .next_surface
        move.w  d0,PlayerY
        move.b  #1,DeathPhase
        move.w  #13,DeathTimer          ; native15tick ground tumble
        move.b  #2,DeathAnimTimer
        clr.b   DeathPose
        bra.w   .active_done
.next_surface:
        addi.w  #16,d6
        cmp.w   PlayerY,d6
        ble.s   .surface
        bra.w   .active_done
.ground:
        subq.w  #1,DeathTimer
        beq.s   .flat
        ; Ground sliding retains the native knockback's horizontal speed.
        move.w  DeathVelocityX,d1
        add.w   DeathFractionX,d1
        move.w  d1,d2
        andi.w  #$00FF,d2
        move.w  d2,DeathFractionX
        asr.w   #8,d1
        add.w   d1,PlayerX
        subq.b  #1,DeathAnimTimer
        bgt.s   .active_done
        addq.b  #1,DeathPose
        andi.b  #3,DeathPose
        move.b  #3,DeathAnimTimer
        tst.b   DeathPose
        bne.s   .active_done
        move.b  #2,DeathAnimTimer
        bra.s   .active_done
.flat:
        move.b  #2,DeathPhase
        move.b  #4,DeathPose
        move.w  #50,DeathTimer          ; native60tick hold before life decrement
        moveq   #$20,d0
        jsr     PlayNativeSFX
        bra.s   .active_done
.offscreen:
        move.b  #3,DeathPhase
        move.w  #1,DeathTimer
        bra.s   .active_done
.hold_or_finish:
        subq.w  #1,DeathTimer
        bgt.s   .active_done
        moveq   #1,d0                  ; caller finishes once, then clearsactive
        bra.s   .done
.active_done:
        bsr.s   SetDeathSpriteIndex
        moveq   #0,d0
.done:
        movem.l (sp)+,d1-d7/a0-a4
        rts

CancelPlayerDeath:
        clr.b   DeathActive
        clr.b   DeathPhase
        clr.b   DeathPose
        clr.w   DeathTimer
        clr.w   DeathSpriteIndex
        rts

SetDeathSpriteIndex:
        movem.l d0-d1,-(sp)
        moveq   #0,d0
        move.w  DeathFacing,d0
        mulu.w  #5,d0
        moveq   #0,d1
        move.b  DeathPose,d1
        add.w   d1,d0
        move.w  d0,DeathSpriteIndex
        movem.l (sp)+,d0-d1
        rts

GetPlayerDeathSprite:
        move.l  d0,-(sp)
        moveq   #0,d0
        move.w  DeathSpriteIndex,d0
        lsl.l   #8,d0
        add.l   d0,d0
        lea     JoeDeathSpritesData,a0
        adda.l  d0,a0
        move.l  (sp)+,d0
        rts

DeathActive:      dc.b 0
DeathPhase:       dc.b 0                ; 0air,1groundtumble,2flat,3offscreen
DeathPose:        dc.b 0
DeathAnimTimer:   dc.b 0
        EVEN
DeathFacing:      dc.w 0
DeathTimer:       dc.w 0
DeathSpriteIndex: dc.w 0
DeathVelocityX:   dc.w 0
DeathVelocityY:   dc.w 0
DeathFractionX:   dc.w 0
DeathFractionY:   dc.w 0
