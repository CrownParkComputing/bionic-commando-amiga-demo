; Five shipped stages only. Native evidence: reference/progression/native_progression.json.
; Integration: ResetCampaignProgress on NEW GAME; InitLevelProgress after LoadStage.
; ClampLevelCamera AFTER UpdateCamera (each logic tick). UpdateLevelProgress on
; logic ticks, gated by the caller while the player is dying. It internally
; ignores attract, entry, game-over and free-fly. Freeze play during LP_State=1.
; LP_AdvanceRequested asks caller to LoadStage(LP_NextStage); never requests5.
; LP_State3 / LP_CampaignComplete means the second native five-stage pass ended.
; LP_ClearTimer125 is an explicit 2.5s PAL presentation adaptation; native bonus
; presentation waits vary with remaining time. No blocking waits occur here.
LP_PLAYER_FOOT_TARGET EQU 158          ; native deltaY96..100 => feet156..160
LP_CLEAR_TICKS       EQU 125
LP_NATIVE_VIEW_X     EQU 256
LP_PORT_VIEW_X       EQU 320
LP_NATIVE_TO_PORT_Y  EQU 1808

ResetCampaignProgress:
        clr.w   LP_Round
        clr.b   LP_ReactorDestroyed
        clr.b   LP_CampaignComplete
        rts

InitLevelProgress:
        movem.l d0/a0,-(sp)
        clr.b   LP_State
        clr.b   LP_CanProceed
        clr.b   LP_AdvanceRequested
        clr.b   LP_ReactorActive
        clr.b   LP_ReactorDestroyed    ;port LoadStage recreates the fixed reactor
        clr.w   LP_ClearTimer
        clr.w   LP_Kills
        clr.l   LP_SeenDeaths
        clr.l   LP_SeenDeaths+4
        move.w  CurrentStage,LP_Stage
        move.w  CamX,LP_PreviousCamX
        move.w  CamY,LP_PreviousCamY
        move.b  #1,LP_PreviousValid
        movem.l (sp)+,d0/a0
        rts

; Fresh-stage presentation. Outputs d0=kind(0chute,1walk,2specialvehicle),
; d1=initial visible JoeX,d2=initial feetY,d3=walk target(-1=complex),
; d4=first gameplay support feet,d5=initial cameraX,d6=initial cameraY.
; Stage3 special vehicle/drop script is not silently called a parachute:
; its native fresh scene starts at(-48,208),camera(32,80), then reaches a
; separate gameplay checkpoint camera nativeY43/44 near supportY1920.
GetLevelEntryInfo:
        move.l  a0,-(sp)
        move.w  CurrentStage,d0
        cmpi.w  #5,d0
        bhs.s   .unused
        mulu.w  #14,d0
        lea     LP_EntryInfo(pc),a0
        adda.w  d0,a0
        movem.w (a0),d0-d6
        movea.l (sp)+,a0
        rts
.unused:
        moveq   #-1,d0
        movea.l (sp)+,a0
        rts

NotifyLevelReactorVisible:
        tst.b   LP_ReactorDestroyed
        bne.s   .done
        move.b  #1,LP_ReactorActive
.done:  rts
NotifyLevelReactorDestroyed:
        move.b  #1,LP_ReactorDestroyed
        clr.b   LP_ReactorActive
        rts

GetLevelCanProceed:
        moveq   #0,d0
        move.b  LP_CanProceed,d0
        rts

; Call at the lethal-hit decision, BEFORE a no-art death is immediately
; removed by UpdateEnemyAI. a1=EnemyList actor; preserves every register.
; The STATE2 poll below is only a fallback for longer death sequences.
NotifyLevelEnemyDefeated:
        movem.l d0-d4/a0-a2,-(sp)
        move.w  CurrentStage,d0
        cmpi.w  #2,d0
        blo.s   .done
        cmpi.w  #5,d0
        bhs.s   .done
        move.l  a1,d0
        subi.l  #EnemyList,d0
        cmpi.l  #(MAX_ENEMIES*EN_SIZE),d0
        bhs.s   .done
        move.w  EN_TYPE(a1),d1
        cmpi.w  #7,d1
        bne.s   .other
        lea     EnemyAux,a0
        adda.w  d0,a0
        cmpi.w  #3,EA_KIND(a0)
        beq.s   .done
        bra.s   .eligible
.other: cmpi.w  #8,d1
        beq.s   .eligible
        cmpi.w  #9,d1
        bne.s   .done
.eligible:
        lsr.w   #4,d0
        move.w  d0,d1
        lsr.w   #3,d1
        lea     LP_SeenDeaths(pc),a0
        adda.w  d1,a0
        andi.w  #7,d0
        bset    d0,(a0)
        bne.s   .done
        addq.w  #1,LP_Kills
.done:  movem.l (sp)+,d0-d4/a0-a2
        rts

UpdateLevelProgress:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  CurrentStage,d0
        cmpi.w  #5,d0
        bhs.w   .done                  ; unused prototype is never normal progression
        tst.b   AttractMode
        bne.w   .done
        tst.b   EntryActive
        bne.w   .done
        tst.b   GameOverMode
        bne.w   .done
        tst.b   FlyMode
        bne.w   .done
        cmpi.b  #1,LP_State
        beq.w   .clear_tick
        tst.b   LP_State
        bne.w   .done
        cmpi.w  #2,d0
        bhs.s   .bosses
        tst.b   OnGround
        beq.w   .done
        move.w  d0,d1
        add.w   d1,d1
        lea     LP_WalkGoalX(pc),a0
        move.w  PlayerX,d2
        cmp.w   (a0,d1.w),d2
        blo.w   .done
        lea     LP_CameraGoalX(pc),a0
        move.w  CamX,d2
        addi.w  #32,d2                 ;320px centered view -> native256px view
        cmp.w   (a0,d1.w),d2
        blo.w   .done
        lea     LP_CameraGoalY(pc),a0
        move.w  #LP_NATIVE_TO_PORT_Y,d2
        sub.w   CamY,d2
        sub.w   (a0,d1.w),d2
        cmpi.w  #5,d2
        bhi.w   .done
        bra.s   .begin_clear
.bosses:
        lea     EnemyList,a0
        lea     EnemyAux,a1
        moveq   #0,d7
.scan:  cmpi.w  #2,EN_STATE(a0)
        bne.s   .next
        move.w  EN_TYPE(a0),d1
        cmpi.w  #7,d1                  ;native COMBAT6, except kind3
        bne.s   .other_boss
        cmpi.w  #3,EA_KIND(a1)
        beq.s   .next
        bra.s   .eligible
.other_boss:
        cmpi.w  #8,d1                  ;native COMBAT9
        beq.s   .eligible
        cmpi.w  #9,d1                  ;native COMBAT10
        bne.s   .next
.eligible:
        move.w  d7,d1
        lsr.w   #3,d1
        lea     LP_SeenDeaths(pc),a2
        adda.w  d1,a2
        move.w  d7,d1
        andi.w  #7,d1
        bset    d1,(a2)
        bne.s   .next
        addq.w  #1,LP_Kills
.next:  lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a1),a1
        addq.w  #1,d7
        cmpi.w  #MAX_ENEMIES,d7
        blo.s   .scan
        move.w  CurrentStage,d0
        add.w   d0,d0
        lea     LP_BossKillsRequired(pc),a0
        move.w  LP_Kills,d1
        cmp.w   (a0,d0.w),d1
        blo.w   .done
.begin_clear:
        move.b  #1,LP_CanProceed
        move.b  #1,LP_State
        move.w  #LP_CLEAR_TICKS,LP_ClearTimer
        jsr     BeginLevelBonus
        bra.w   .done
.clear_tick:
        tst.w   LP_ClearTimer
        beq.s   .count_bonus
        subq.w  #1,LP_ClearTimer
        bra.s   .done
.count_bonus:
        jsr     UpdateLevelBonusCount
        tst.w   d0
        beq.s   .done
        bra.s   .campaign_end          ;demo ends only after the whole bonus
.campaign_end:
        move.b  #1,LP_CampaignComplete
        move.b  #3,LP_State
.done:  movem.l (sp)+,d0-d7/a0-a2
        rts

; Directional stop semantics are crucial: crossing a new sector never snaps
; the camera into its limits. A newly higher minimum only blocks RETURN travel.
; Native bbox lookup: Xmin/max indexed by nativeCamY>>8; Ymax/min byCamX>>8.
; Wide right edge is nativeXmax+256-320. A locked256px room is centered in320px.
; This helper retargets ordinary vertical follow to feet158 before limiting it.
; Entry and free-fly retain their existing camera behavior.
ClampLevelCamera:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  CurrentStage,d7
        cmpi.w  #5,d7
        bhs.w   .done
        tst.b   FlyMode
        bne.w   .store
        tst.b   EntryActive
        bne.w   .store
        tst.b   LP_PreviousValid
        bne.s   .previous_ready
        move.w  CamX,LP_PreviousCamX
        move.w  CamY,LP_PreviousCamY
.previous_ready:
        move.w  LP_PreviousCamX,d0
        addi.w  #32,d0
        cmpi.w  #1728,LP_PreviousCamX
        blt.s   .native_x_ready
        move.w  #1792,d0               ;same2048px right edge at the wider-view cap
.native_x_ready:
        move.w  #LP_NATIVE_TO_PORT_Y,d1
        sub.w   LP_PreviousCamY,d1
        move.w  d7,d6
        lsl.w   #5,d6
        lea     LP_XStops,a0
        adda.w  d6,a0
        move.w  d1,d2
        lsr.w   #8,d2
        andi.w  #7,d2
        lsl.w   #2,d2
        adda.w  d2,a0
        move.w  (a0),d2                ;native Xmin
        move.w  2(a0),d3               ;native Xmax
        lea     LP_YStops,a0
        adda.w  d6,a0
        move.w  d0,d4
        lsr.w   #8,d4
        andi.w  #7,d4
        lsl.w   #2,d4
        adda.w  d4,a0
        move.w  (a0),d5                ;native Ymax
        move.w  2(a0),d4               ;native Ymin
        clr.b   LP_NoScroll
        move.w  #2064,d6
        sub.w   PlayerY,d6             ;native Joe body anchorY
        bsr.w   LP_ApplyNativeOverrides
        tst.b   LP_NoScroll
        beq.s   .limit_x
        move.w  LP_PreviousCamX,CamX
        move.w  LP_PreviousCamY,CamY
        bra.w   .store
.limit_x:
        subi.w  #64,d3                 ;preserve native world RIGHT edge
        cmp.w   d2,d3
        bge.s   .x_limits_ready
        add.w   d2,d3
        asr.w   #1,d3                  ;256px locked room ->centered320px view
        move.w  d3,d2
.x_limits_ready:
        tst.w   d2
        bpl.s   .xmin_ready
        moveq   #0,d2
.xmin_ready:
        tst.w   d3
        bpl.s   .xmax_ready
        moveq   #0,d3
.xmax_ready:
        cmpi.w  #1728,d2               ;never show beyond the full2048px canvas
        ble.s   .xmin_canvas
        move.w  #1728,d2
.xmin_canvas:
        cmpi.w  #1728,d3
        ble.s   .xmax_canvas
        move.w  #1728,d3
.xmax_canvas:
        move.w  d2,LP_CameraMinX
        move.w  d3,LP_CameraMaxX
        move.w  CamX,d0
        cmp.w   LP_PreviousCamX,d0
        blt.s   .left
        beq.s   .limit_y
        cmp.w   d3,d0
        ble.s   .limit_y
        move.w  d3,d0
        cmp.w   LP_PreviousCamX,d0
        bge.s   .set_x
        move.w  LP_PreviousCamX,d0
        bra.s   .set_x
.left:  cmp.w   d2,d0
        bge.s   .limit_y
        move.w  d2,d0
        cmp.w   LP_PreviousCamX,d0
        ble.s   .set_x
        move.w  LP_PreviousCamX,d0
.set_x: move.w  d0,CamX
.limit_y:
        move.w  PlayerY,d0
        subi.w  #LP_PLAYER_FOOT_TARGET,d0
        bpl.s   .target_positive
        moveq   #0,d0
.target_positive:
        cmpi.w  #1808,d0
        ble.s   .target_ready
        move.w  #1808,d0
.target_ready:
        move.w  #LP_NATIVE_TO_PORT_Y,d1
        sub.w   d5,d1                  ;port camera minimum(top)
        move.w  d1,LP_CameraMinY
        move.w  #LP_NATIVE_TO_PORT_Y,d1
        sub.w   d4,d1                  ;port camera maximum(bottom)
        move.w  d1,LP_CameraMaxY
        cmp.w   LP_PreviousCamY,d0
        blt.s   .up
        beq.s   .set_y
        cmp.w   LP_CameraMaxY,d0
        ble.s   .set_y
        move.w  LP_CameraMaxY,d0
        cmp.w   LP_PreviousCamY,d0
        bge.s   .set_y
        move.w  LP_PreviousCamY,d0
        bra.s   .set_y
.up:    cmp.w   LP_CameraMinY,d0
        bge.s   .set_y
        move.w  LP_CameraMinY,d0
        cmp.w   LP_PreviousCamY,d0
        ble.s   .set_y
        move.w  LP_PreviousCamY,d0
.set_y: move.w  d0,CamY
.store:
        move.w  CamX,LP_PreviousCamX
        move.w  CamY,LP_PreviousCamY
        move.b  #1,LP_PreviousValid
        ; Native ordinary walk stops16px from screen edge; report widened
        ; view limits without blindly forcing Joe into a sector's X minimum.
        move.w  CamX,d0
        addi.w  #16,d0
        move.w  d0,LP_PlayerMinX
        addi.w  #288,d0
        move.w  d0,LP_PlayerMaxX
        move.b  #1,LP_PlayerWithinView
        move.w  PlayerY,d0
        sub.w   CamY,d0
        cmpi.w  #8,d0
        blt.s   .outside
        cmpi.w  #232,d0
        ble.s   .done
.outside:
        clr.b   LP_PlayerWithinView
.done:  movem.l (sp)+,d0-d7/a0-a2
        rts

; In/out d2=Xmin,d3=Xmax. d0/d1=current native-equivalent cameraXY,
; d6=native JoeY,d7=stage. Ystop fields d4/d5 stay untouched.
LP_ApplyNativeOverrides:
        tst.w   d7
        bne.w   .done
        cmpi.w  #1264,d6
        ble.s   .s1_lower
        move.w  #1280,d3
        rts
.s1_lower:
        cmpi.w  #1136,PlayerX
        bhi.w   .freeze
        rts
.done:  rts
.freeze:
        move.b  #1,LP_NoScroll
        rts

LP_WalkGoalX:          dc.w 1293 ;ordinary right-walk adaptation; nativecamtestbelow
LP_CameraGoalX:        dc.w 1160 
LP_CameraGoalY:        dc.w 1194 
LP_BossKillsRequired:  dc.w 0
LP_EntryInfo:
        dc.w 0,128,1792,128,2002,0,1808
        include "reference/progression/native_bounds_data.i"
LP_Stage:              dc.w -1
LP_Round:              dc.w 0
LP_Kills:              dc.w 0
LP_ClearTimer:         dc.w 0
LP_NextStage:          dc.w 0
LP_PreviousCamX:       dc.w 0
LP_PreviousCamY:       dc.w 1808
LP_CameraMinX:         dc.w 0
LP_CameraMaxX:         dc.w 1728
LP_CameraMinY:         dc.w 0
LP_CameraMaxY:         dc.w 1808
LP_PlayerMinX:         dc.w 16
LP_PlayerMaxX:         dc.w 2032
LP_SeenDeaths:         ds.b 8
LP_State:              dc.b 0
LP_CanProceed:         dc.b 0
LP_AdvanceRequested:   dc.b 0
LP_CampaignComplete:   dc.b 0
LP_ReactorDestroyed:   dc.b 0
LP_ReactorActive:      dc.b 0
LP_PreviousValid:      dc.b 0
LP_NoScroll:           dc.b 0
LP_PlayerWithinView:   dc.b 1
        EVEN
