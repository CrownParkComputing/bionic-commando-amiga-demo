; ============================================================================
; ORIGINAL ARCADE TITLE / ATTRACT DEMONSTRATION
; The title is captured from the supplied ROM running in MAME, reduced to the
; Amiga's 32 colours.  The demonstration uses the live map / physics / enemies.
; ============================================================================
ATTRACT_TITLE_TICKS EQU 350              ; 7 seconds at PAL 50Hz

InitAttract:
        clr.b   DemoPlaybackActive
        jsr     ResetLevelBonus
        jsr     ResetCampaignProgress
        jsr     ResetProgressHud
        jsr     CancelPlayerDeath
        jsr     StopNativeEffects
        clr.b   GameOverMode
        clr.w   GameOverTimer
        move.b  #1,AttractMode
        clr.b   AttractPhase
        clr.w   AttractTimer
        clr.w   BobCount
        clr.w   DrawnCount
        bsr.w   HideGameSprites
        bsr.w   ShowAttractTitle
        jsr     StartTitleMusic
        bsr.w   ResetGameClock
        rts

; Clear sprite headers, including unused SPR6/7 pointers via their null sprite.
HideGameSprites:
        clr.l   Spr0Buf
        clr.l   Spr1Buf
        clr.l   Spr2Buf
        clr.l   Spr3Buf
        clr.l   Spr4Buf
        clr.l   Spr5Buf
        clr.l   Spr6Buf
        clr.l   Spr7Buf
        rts

; Caller preserves registers. The original drop begins above the viewport.
; Crop source rows as it enters instead of clamping the header onto wrong art.
UpdateChuteSprites:
        move.w  PlayerY(pc),d5
        subi.w  #64,d5
        sub.w   CamY(pc),d5
        cmpi.w  #-64,d5
        ble.w   .hidden
        moveq   #0,d0
        tst.w   d5
        bpl.s   .clip_ready
        move.w  d5,d0
        neg.w   d0
.clip_ready:
        moveq   #64,d1
        sub.w   d0,d1
        cmp.w   ChuteClipRows(pc),d0
        bne.s   .upload
        cmpi.w  #-2,PrevPoseIdx
        beq.s   .position
.upload:
        move.w  d0,ChuteClipRows
        move.w  d1,ChuteVisibleRows
        lsl.w   #2,d0
        lea     ParachuteSpriteData,a0
        lea     ChuteSpriteBuffers(pc),a2
        moveq   #7,d6
.channel:
        movea.l a0,a4
        adda.w  #256,a4
        adda.w  d0,a0
        movea.l (a2)+,a1
        addq.l  #4,a1
        move.w  ChuteVisibleRows(pc),d7
        subq.w  #1,d7
.rows:  move.l  (a0)+,(a1)+
        dbf     d7,.rows
        clr.l   (a1)
        movea.l a4,a0
        dbf     d6,.channel
        move.w  #-2,PrevPoseIdx
.position:
        move.w  PlayerX(pc),d4
        subi.w  #40,d4
        sub.w   CamX(pc),d4
        tst.w   d5
        bpl.s   .top_visible
        moveq   #0,d5
.top_visible:
        lea     ChuteSpriteBuffers(pc),a2
        moveq   #3,d6
.pair:
        move.w  d4,d0
        move.w  d5,d1
        move.w  ChuteVisibleRows(pc),d2
        bsr.w   CalcSprCtrlWords
        movea.l (a2)+,a1
        move.l  d3,(a1)
        ori.w   #$0080,d3
        movea.l (a2)+,a1
        move.l  d3,(a1)
        addi.w  #16,d4
        dbf     d6,.pair
        rts
.hidden:
        bsr.w   HideGameSprites
        rts

ChuteSpriteBuffers:
        dc.l Spr0Buf,Spr1Buf,Spr2Buf,Spr3Buf,Spr4Buf,Spr5Buf,Spr6Buf,Spr7Buf

UpdateAttract:
        ; Start from every part of the attract loop.  A held trigger is consumed
        ; by LoadStage so the new parachute is not cut on the first game frame.
        bsr.w   ReadStartButton
        tst.b   d0
        bne.w   StartNewGame

        addq.w  #1,AttractTimer
        tst.b   AttractPhase
        bne.s   .demo
        cmpi.w  #ATTRACT_TITLE_TICKS,AttractTimer
        blt.s   .title_audio
        move.b  #2,AttractPhase
        clr.w   AttractTimer
        jsr     InitArcadeDemo
        moveq   #0,d0
        bsr.w   LoadStage
        bsr.w   BuildBobList
        rts
.title_audio:
        bsr.w   UpdateAudio
        rts
.demo:
        jsr     AdvanceArcadeDemo
        tst.b   DemoFinished
        beq.s   .done
        bsr.w   InitAttract
.done:  rts

StartNewGame:
        clr.b   HighScoreSubmitted
        clr.b   DemoPlaybackActive
        jsr     ResetLevelBonus
        jsr     ResetCampaignProgress
        clr.b   GameOverMode
        clr.w   GameOverTimer
        clr.b   AttractMode
        clr.b   AttractPhase
        clr.w   AttractTimer
        move.w  #3,Lives
        clr.l   Score
        moveq   #0,d0
        bsr.w   LoadStage
        bsr.w   BuildBobList
        rts

ReadStartButton:
        lea     KeyState(pc),a0
        moveq   #0,d0
        move.b  $44(a0),d0
        btst    #6,PadButtons
        beq.s   .consume
        moveq   #1,d0
.consume:
        tst.b   UiConsumeStart
        beq.s   .done
        tst.b   d0
        bne.s   .blocked
        clr.b   UiConsumeStart
.blocked:
        moveq   #0,d0
.done:  rts

ShowGameOver:
        jsr     SubmitHighScore
        jsr     StopNativeEffects
        jsr     StartGameOverMusic
        move.b  #1,GameOverMode
        move.w  #150,GameOverTimer
        clr.b   GrappleState
        clr.b   ChuteMode
        clr.b   EntryActive
        bsr.w   HideGameSprites
        bsr.w   ReadStartButton
        move.b  d0,GameOverStartHeld
        lea     HudBuffer,a0
        move.w  #159,d7
.clear:
        clr.l   (a0)+
        dbf     d7,.clear
        lea     GameOverLabel(pc),a0
        lea     HudBuffer+1,a1
        bsr.w   DrawHudString
        bsr.w   UpdateHudCoords         ; leave the final zero visibly displayed
        clr.b   HudDirty
        rts

UpdateGameOver:
        bsr.w   UpdateAudio
        bsr.w   ReadStartButton
        move.b  GameOverStartHeld(pc),d1
        move.b  d0,GameOverStartHeld
        tst.b   d0
        beq.s   .timer
        tst.b   d1
        beq.w   StartNewGame
.timer:
        subq.w  #1,GameOverTimer
        bgt.s   .done
        bsr.w   InitAttract
.done:  rts

; Original entry handlers ($7DFC / $7E4A) ignore input and branch collisions
; until the floor.  Native descent is 1px at 60Hz, then gravity 48/256 px/f².
UpdateEntry:
        clr.b   InputDirs
        clr.b   FireJustPressed
        clr.b   JumpJustPressed
        move.b  #1,PrevFireBtn
        move.b  #1,PrevShootBtn
        move.b  #1,PrevJumpBtn
        move.b  #1,WasUpHeld
        cmpi.b  #1,EntryKind
        bne.s   .air_entry
        jsr     UpdateWalkEntry
        rts
.air_entry:
        tst.b   ChuteMode
        beq.s   .free_fall
        moveq   #1,d0
        addq.w  #1,EntryStepPhase
        cmpi.w  #5,EntryStepPhase
        blt.s   .chute_step
        clr.w   EntryStepPhase
        addq.w  #1,d0                  ; 1.2px/PAL tick, preserving arcade speed
.chute_step:
        add.w   d0,PlayerY
        move.w  PlayerY(pc),d0
        cmp.w   ChuteReleaseY(pc),d0
        blt.s   .done
        move.w  ChuteReleaseY(pc),PlayerY
        clr.b   ChuteMode
        clr.w   PlayerVY               ; native free fall starts with zero velocity
        clr.w   EntryFraction
        rts
.free_fall:
        move.w  PlayerVY(pc),d0
        add.w   EntryFraction(pc),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EntryFraction
        lsr.w   #8,d0
        add.w   d0,PlayerY
        addi.w  #$0045,PlayerVY         ; 0.1875 * (60/50)^2 = 0.27px/PAL tick²
        move.w  PlayerY(pc),d0
        cmp.w   EntryTargetY(pc),d0
        blt.s   .done
        move.w  EntryTargetY(pc),PlayerY
        clr.w   PlayerVX
        clr.w   PlayerVY
        clr.b   EntryActive
        move.b  #1,OnGround
.done:  rts

; LoadStage calls this inside its register-preserving envelope, including
; unattended respawns, so a restarted demo retains its start prompt.
RenderDemoHud:
        lea     HudBuffer,a0
        move.w  #159,d7
.clear:
        clr.l   (a0)+
        dbf     d7,.clear
        lea     DemoPrompt(pc),a0
        lea     HudBuffer+4*40+7,a1
        bsr.w   DrawHudString
        clr.b   HudDirty
        rts

ShowAttractTitle:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     DisableParallax
        bsr.w   WaitBlitter

        ; Briefly blank the playfield while replacing its palette and pixels.
        move.w  #$0100,CUSTOM+DMACON
        lea     AttractTitleLZ,a0
        lea     ActiveTileSheet,a1
        bsr.w   LZSS_Decompress

        ; Source: 224 rows of five compact 40-byte planes.  Destination retains
        ; the game's 108-byte plane rows and 540-byte scanline stride.
        lea     ActiveTileSheet,a0
        lea     ScreenBuffer,a1
        move.w  #(224*5)-1,d7
.plane_row:
        moveq   #9,d6
.copy:  move.l  (a0)+,(a1)+
        dbf     d6,.copy
        moveq   #16,d6
.pad:   clr.l   (a1)+                   ; clear the 68-byte fetch padding
        dbf     d6,.pad
        dbf     d7,.plane_row

        lea     AttractTitlePalette,a0
        lea     CopColors+2,a1
        moveq   #31,d7
.palette:
        move.w  (a0)+,(a1)
        addq.l  #4,a1
        dbf     d7,.palette
        jsr     InstallTitlePalette

        clr.w   CopScroll+2
        move.w  #$0038,CopFetchStart+2
        move.w  #(ROW_STRIDE-40),CopModulo+2
        move.w  #(ROW_STRIDE-40),CopModulo+6
        move.l  #ScreenBuffer,d0
        lea     CopBplPtrs,a1
        moveq   #4,d7
.pointers:
        move.w  d0,6(a1)
        swap    d0
        move.w  d0,2(a1)
        swap    d0
        addi.l  #ROW_PLANE_BYTES,d0
        addq.l  #8,a1
        dbf     d7,.pointers

        lea     HudBuffer,a0
        move.w  #159,d7
.clear_hud:
        clr.l   (a0)+
        dbf     d7,.clear_hud
        move.l  #HudBuffer,d0
        lea     CopHudBpl,a1
        move.w  d0,6(a1)
        swap    d0
        move.w  d0,2(a1)
        ; The title bitmap owns its one Start prompt; leave no duplicate bar.
        clr.w   CopHudBackground+2
        move.w  #$0CCC,CopHudForeground+2
        jsr     RenderTitleHints
        jsr     RenderGraphicsEditionHint
        move.w  #$8100,CUSTOM+DMACON
        movem.l (sp)+,d0-d7/a0-a6
        rts

        include "attract_replay.i"

DemoPrompt:  dc.b "DEMO PRESS START OR RETURN",0
GameOverLabel: dc.b "GAME OVER",0
EditionTitleLabel: dc.b "ONE LEVEL DEMO",0
EditionTitleEnd:
        EVEN
