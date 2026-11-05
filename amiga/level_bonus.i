; Native clear bonus:5000 + remaining displayed time*100 ($8FA0,$5CA8).
; Native counts50points/frame at60Hz ($5D16,$5D40,$58C6). Rational6/5
; scheduling retains that pace on the port's50Hz simulation clock.
; The port stores ordinary integers and retains its existing599999 score cap;
; native score/bonus/time are packed BCD. Source:reference/bonus/README.md.
;
; ResetLevelBonus:new game/attract. InitLevelBonus:after each LoadStage.
; UpdateLevelBonusClock:once per active PAL tick; d0=1 ONCE on timeout.
; BeginLevelBonus:idempotent clear entry. UpdateLevelBonusCount:clear tick,
; d0=1 iff fully awarded. Other registers are preserved by all entry points.

ResetLevelBonus:
        move.w  #200,BonusTimeRemaining
        move.w  #-1,BonusLastStage
        clr.w   BonusClockPhase
        clr.w   BonusCountPhase
        clr.l   BonusTotal
        clr.l   BonusRemaining
        clr.l   BonusAwarded
        clr.b   BonusActive
        clr.b   BonusDone
        clr.b   BonusTimedOut
        rts

InitLevelBonus:
        move.l  d0,-(sp)
        move.w  CurrentStage,d0
        cmp.w   BonusLastStage,d0
        bne.s   .fresh
        tst.b   BonusTimedOut
        beq.s   .preserve_time
.fresh:
        move.w  #200,BonusTimeRemaining
        clr.w   BonusClockPhase
        clr.b   BonusTimedOut
.preserve_time:
        move.w  d0,BonusLastStage
        clr.w   BonusCountPhase
        clr.l   BonusTotal
        clr.l   BonusRemaining
        clr.l   BonusAwarded
        clr.b   BonusActive
        clr.b   BonusDone
        move.l  (sp)+,d0
        rts

UpdateLevelBonusClock:
        move.l  d1,-(sp)
        moveq   #0,d0
        tst.b   AttractMode
        bne.w   .done
        tst.b   EntryActive
        bne.w   .done
        tst.b   DeathActive
        bne.w   .done
        tst.b   GameOverMode
        bne.w   .done
        tst.b   FlyMode
        bne.w   .done
        tst.b   LP_State
        bne.w   .done
        cmpi.w  #5,CurrentStage
        bhs.s   .done
        tst.b   BonusTimedOut
        bne.s   .done
        tst.w   BonusTimeRemaining
        beq.s   .timeout
        ; 64native ticks =320 sixths of a PAL tick; add6 perPAL tick.
        move.w  BonusClockPhase,d1
        addq.w  #6,d1
        cmpi.w  #320,d1
        blo.s   .store_phase
        subi.w  #320,d1
        subq.w  #1,BonusTimeRemaining
        move.b  #1,HudDirty
        ; Native zero test precedes decrement: timeout is the NEXT tick.
.store_phase:
        move.w  d1,BonusClockPhase
        bra.s   .done
.timeout:
        move.b  #1,BonusTimedOut
        move.b  #1,HudDirty
        moveq   #1,d0
.done:
        move.l  (sp)+,d1
        rts

BeginLevelBonus:
        tst.b   BonusActive
        bne.s   .done
        tst.b   BonusDone
        bne.s   .done
        move.l  d0,-(sp)
        moveq   #0,d0
        move.w  BonusTimeRemaining,d0
        mulu.w  #100,d0
        addi.l  #5000,d0
        move.l  d0,BonusTotal
        move.l  d0,BonusRemaining
        clr.l   BonusAwarded
        clr.w   BonusCountPhase
        clr.b   BonusDone
        move.b  #1,BonusActive
        move.l  (sp)+,d0
.done:
        rts

UpdateLevelBonusCount:
        movem.l d1-d3,-(sp)
        moveq   #0,d0
        tst.b   BonusDone
        bne.s   .already_done
        tst.b   BonusActive
        beq.w   .done
        move.w  BonusCountPhase,d1
        addq.w  #6,d1
.next_unit:
        cmpi.w  #5,d1
        blo.s   .store_phase
        subq.w  #5,d1
        moveq   #50,d2
        move.l  BonusRemaining,d3
        cmp.l   d2,d3
        bhs.s   .transfer
        move.l  d3,d2                  ; bounded even for a partial test fixture
.transfer:
        sub.l   d2,BonusRemaining
        add.l   d2,BonusAwarded
        add.l   d2,Score
        cmpi.l  #599999,Score
        bls.s   .score_ready
        move.l  #599999,Score
.score_ready:
        move.b  #1,HudDirty
        tst.l   BonusRemaining
        bne.s   .next_unit
        clr.b   BonusActive
        move.b  #1,BonusDone
        clr.w   BonusCountPhase
.already_done:
        moveq   #1,d0
        bra.s   .done
.store_phase:
        move.w  d1,BonusCountPhase
.done:
        movem.l (sp)+,d1-d3
        rts

        EVEN
BonusTimeRemaining: dc.w 200
BonusLastStage:     dc.w -1
BonusClockPhase:    dc.w 0
BonusCountPhase:    dc.w 0
BonusTotal:         dc.l 0
BonusRemaining:     dc.l 0
BonusAwarded:       dc.l 0
BonusActive:        dc.b 0
BonusDone:          dc.b 0
BonusTimedOut:      dc.b 0
        EVEN
