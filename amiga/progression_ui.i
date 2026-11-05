; Visible stage-clear cue and safe transition, outside actor iteration loops.
ResetProgressHud:
        clr.b   LevelClearHudShown
        clr.b   CampaignHudShown
        clr.w   ClearBonusTimer
        rts

HandleLevelFlow:
        movem.l d0-d7/a0-a6,-(sp)
        tst.b   AttractMode
        bne.w   .done
        tst.b   LP_AdvanceRequested
        bne.s   .advance
        tst.b   LP_CampaignComplete
        bne.s   .complete
        cmpi.b  #1,LP_State
        bne.w   .done
        tst.b   LevelClearHudShown
        beq.s   .show_clear
        bsr.w   UpdateClearBonus
        bra.w   .done
.show_clear:
        move.b  #1,LevelClearHudShown
        clr.b   InputDirs
        jsr     StopNativeEffects
        jsr     StartClearMusic
        bsr.w   ClearProgressHudLeft
        lea     LevelClearLabel(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        jsr     UpdateHudCoords
        clr.b   HudDirty
        bra.s   .done
.advance:
        move.w  LP_NextStage,d0
        jsr     LoadStage
        bra.s   .done
.complete:
        tst.b   CampaignHudShown
        bne.s   .done
        move.b  #1,CampaignHudShown
        jsr     StopNativeEffects
        jsr     ShowGameOver
        bsr.w   ClearProgressHudLeft
        lea     MissionCompleteLabel(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        lea     HudBuffer+8*40,a0
        moveq   #79,d7
.clear_demo_row:
        clr.l   (a0)+
        dbf     d7,.clear_demo_row
        lea     DemoReplayLabel(pc),a0
        lea     HudBuffer+8*40+((40-(DemoReplayEnd-DemoReplayLabel-1))/2),a1
        jsr     DrawHudString
        move.w  #400,GameOverTimer      ;eight seconds; Start can replay at once
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Counting uses the real transfer phase, then LoadStage stops the loop.
UpdateClearBonus:
        tst.w   LP_ClearTimer
        bne.s   .done
        tst.b   BonusActive
        beq.s   .done
        tst.w   ClearBonusTimer
        beq.s   .play
        subq.w  #1,ClearBonusTimer
        bne.s   .done
.play:
        moveq   #$24,d0
        jsr     PlayNativeSFX
        move.w  #NATIVE_BONUS_RETRIGGER,ClearBonusTimer
.done:
        rts

; Two clean seven-pixel font rows fit the existing sixteen-line HUD. Keep
; stage/score/lives above, and show the level timer/counting bonus below.
RenderLevelBonusHud:
        tst.b   AttractMode
        bne.w   .done
        movem.l d0-d7/a0-a2,-(sp)
        lea     HudBuffer+8*40,a0
        moveq   #79,d7
.clear: clr.l   (a0)+
        dbf     d7,.clear
        lea     LevelTimeLabel(pc),a0
        lea     HudBuffer+8*40+1,a1
        jsr     DrawHudString
        moveq   #0,d0
        move.w  BonusTimeRemaining,d0
        bsr.s   DrawHudDec3
        cmpi.b  #1,LP_State
        bne.s   .restore
        lea     LevelBonusLabel(pc),a0
        lea     HudBuffer+8*40+17,a1
        jsr     DrawHudString
        move.l  BonusRemaining,d0
        jsr     DrawHudDec6
.restore:
        movem.l (sp)+,d0-d7/a0-a2
.done:  rts

DrawHudDec3:
        moveq   #2,d3
.divide:
        divu.w  #10,d0
        swap    d0
        move.w  d0,-(sp)
        clr.w   d0
        swap    d0
        dbf     d3,.divide
        moveq   #2,d3
.print:
        move.w  (sp)+,d0
        addi.w  #'0',d0
        jsr     DrawHudChar
        dbf     d3,.print
        rts

ClearProgressHudLeft:
        lea     HudBuffer,a0
        moveq   #7,d7
.row:
        clr.l   (a0)
        clr.l   4(a0)
        clr.l   8(a0)
        clr.l   12(a0)
        clr.b   16(a0)
        lea     40(a0),a0
        dbf     d7,.row
        rts

RenderRoundStageHud:
        tst.w   LP_Round
        beq.s   .done
        movem.l d0-d7/a0-a1,-(sp)
        move.w  CurrentStage,d0
        addi.w  #'1',d0
        move.b  d0,RoundStageLabel+14
        bsr.s   ClearProgressHudLeft
        lea     RoundStageLabel(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        movem.l (sp)+,d0-d7/a0-a1
.done:  rts

; Native stages2/4/5 walk in from the left. Stage3's full vehicle sequence is
; not reproduced: use an explicit shortened chute into its gameplay checkpoint.
ConfigureStageEntry:
        jsr     GetLevelEntryInfo
        move.b  d0,EntryKind
        cmpi.w  #1,d0
        beq.s   .walk
        cmpi.w  #2,d0
        bne.s   .done
        clr.w   CamX
        move.w  #1764,CamY
        move.w  #128,PlayerX
        move.w  #1792,PlayerY
        move.w  #1921,EntryTargetY      ; converted collision surface(native1920)
        move.w  #1884,ChuteReleaseY
        move.b  #1,ChuteMode
        rts
.walk:
        move.w  d1,PlayerX
        move.w  d2,PlayerY
        move.w  d3,EntryWalkTargetX
        move.w  d4,EntryTargetY
        move.w  d5,CamX
        move.w  d6,CamY
        clr.b   ChuteMode
        move.b  #1,OnGround
.done:  rts

UpdateWalkEntry:
        moveq   #1,d0
        addq.w  #1,EntryStepPhase
        cmpi.w  #5,EntryStepPhase
        blt.s   .step
        clr.w   EntryStepPhase
        addq.w  #1,d0
.step:
        add.w   d0,PlayerX
        move.b  #1,InputDirs            ; original walking artwork during entry
        move.w  #1,FacingDir
        move.b  #1,OnGround
        move.w  EntryTargetY,PlayerY
        move.w  PlayerX,d0
        cmp.w   EntryWalkTargetX,d0
        blt.s   .done
        move.w  EntryWalkTargetX,PlayerX
        clr.b   EntryActive
        clr.b   InputDirs
.done:  rts

LevelClearLabel:       dc.b "STAGE CLEAR",0
MissionCompleteLabel: dc.b "DEMO COMPLETE",0
DemoReplayLabel:      dc.b "PRESS START TO PLAY AGAIN",0
DemoReplayEnd:
RoundStageLabel:       dc.b "ROUND 2 STAGE 1",0
LevelClearHudShown:    dc.b 0
CampaignHudShown:      dc.b 0
EntryKind:             dc.b 0
        EVEN
EntryWalkTargetX:      dc.w 72
ClearBonusTimer:       dc.w 0
LevelTimeLabel:        dc.b "TIME ",0
LevelBonusLabel:       dc.b "BONUS ",0
        EVEN
