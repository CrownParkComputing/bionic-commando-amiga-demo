; Title-only front end: options, original-music jukebox, persistent top10.
; UiPage0=normal game/title,1=options,2=jukebox,3=highscores.
TryOpenFrontPage:
        tst.b   AttractMode
        beq.w   .quick_return
        movem.l d0-d7/a0-a6,-(sp)
        lea     KeyState,a0
        moveq   #0,d0
        tst.b   $18(a0)                ;O opens options; F1-F3 have no shortcut
        beq.s   .pad
        moveq   #1,d0
.pad:   btst    #0,PadButtons
        beq.s   .keys_done
        moveq   #1,d0
.keys_done:
        tst.w   d0
        bne.s   .held
        clr.b   UiShortcutHeld
        bra.w   .done
.held:  tst.b   UiShortcutHeld
        bne.w   .done
        move.b  #1,UiShortcutHeld
        clr.b   UiParentPage
        moveq   #1,d0
        bsr.w   OpenFrontPage
.done:  movem.l (sp)+,d0-d7/a0-a6
.quick_return:
        rts

OpenFrontPage:
        move.b  d0,UiPage
        clr.w   UiCursor
        clr.b   UiNameEditing
        move.w  #18,UiRepeatTimer
        jsr     HideGameSprites
        jsr     StopNativeEffects
        bsr.w   ReadUiButtons
        move.w  d0,UiPreviousButtons
        bra.w   RenderFrontPage

CloseFrontPage:
        tst.b   UiParentPage
        beq.s   .title
        clr.b   UiParentPage
        moveq   #1,d0
        bra.w   OpenFrontPage
.title: clr.b   UiPage
        clr.b   KeyState+$45           ;menu Back must not become title Quit
        move.b  #1,UiConsumeStart       ;consume held Return/controller Start
        jsr     InitAttract
        rts

UpdateFrontPage:
        movem.l d0-d7/a0-a6,-(sp)
        bsr.w   ReadUiButtons
        move.w  d0,d6
        move.w  UiPreviousButtons,d1
        move.w  d0,UiPreviousButtons
        not.w   d1
        and.w   d1,d0
        move.w  d6,d2
        andi.w  #15,d2
        beq.s   .no_repeat
        tst.w   d0
        bne.s   .reset_repeat
        subq.w  #1,UiRepeatTimer
        bne.s   .buttons_ready
        or.w    d2,d0
        move.w  #5,UiRepeatTimer
        bra.s   .buttons_ready
.no_repeat:
.reset_repeat:
        move.w  #18,UiRepeatTimer
.buttons_ready:
        move.w  d0,d6
        tst.b   UiNameEditing
        bne.w   .edit_name
        btst    #5,d6
        beq.s   .not_back
        bsr.w   CloseFrontPage
        bra.w   .done
.not_back:
        cmpi.b  #3,UiPage
        beq.w   .scores
        move.w  UiCursor,d0
        btst    #3,d6
        beq.s   .down
        subq.w  #1,d0
.down:  btst    #2,d6
        beq.s   .wrap
        addq.w  #1,d0
.wrap:  moveq   #7,d1
        cmpi.b  #1,UiPage
        beq.s   .limit_ready
        move.w  #MUSIC_TRACK_COUNT-1,d1
        tst.b   C64MusicAvailable
        bne.s   .limit_ready
        move.w  #AMIGA_TRACK_COUNT,d1
.limit_ready:
        tst.w   d0
        bpl.s   .max
        move.w  d1,d0
.max:   cmp.w   d1,d0
        ble.s   .cursor
        moveq   #0,d0
.cursor:
        move.w  d0,UiCursor
        cmpi.b  #2,UiPage
        beq.w   .jukebox
        ; Options: music/background change with left/right or select.
        move.w  d6,d1
        andi.w  #$53,d1
        beq.w   .redraw_if_needed
        tst.w   d0
        beq.w   .music_source
        cmpi.w  #1,d0
        beq.w   .background
        cmpi.w  #5,d0
        beq.w   .graphics
        cmpi.w  #6,d0
        beq.w   .fps
        move.w  d6,d1
        andi.w  #$50,d1
        beq.w   .redraw_if_needed
        cmpi.w  #2,d0
        beq.w   .open_jukebox
        cmpi.w  #3,d0
        beq.w   .open_scores
        cmpi.w  #4,d0
        beq.w   .name_begin
        bsr.w   CloseFrontPage
        bra.w   .done
.music_source:
        move.w  MusicSource,d0
        btst    #1,d6
        bne.s   .music_previous
        addq.w  #1,d0
        bra.s   .music_wrap
.music_previous:
        subq.w  #1,d0
.music_wrap:
        moveq   #1,d1
        tst.b   C64MusicAvailable
        beq.s   .music_max
        moveq   #2,d1
.music_max:
        tst.w   d0
        bpl.s   .music_high
        move.w  d1,d0
.music_high:
        cmp.w   d1,d0
        ble.s   .music_store
        moveq   #0,d0
.music_store:
        move.w  d0,MusicSource
        move.b  #1,PreferencesDirty
        jsr     StartTitleMusic
        bra.w   .redraw
.background:
        eori.b  #1,BackgroundMove
        move.b  #1,PreferencesDirty
        bra.w   .redraw
.graphics:
        ; Graphics is the compiled edition; switching requires that edition.
        bra.w   .redraw
.fps:
        eori.b  #1,ShowFPS
        move.b  #1,PreferencesDirty
        bra.w   .redraw
.open_jukebox:
        moveq   #2,d0
        bra.s   .child
.open_scores:
        moveq   #3,d0
.child: move.b  #1,UiParentPage
        bsr.w   OpenFrontPage
        bra.w   .done
.name_begin:
        move.b  #1,UiNameEditing
        clr.w   UiNameLetter
        bra.w   .redraw
.jukebox:
        btst    #4,d6
        beq.s   .use_source
        jsr     PlayJukeboxTrack
.use_source:
        btst    #6,d6
        beq.w   .redraw_if_needed
        clr.w   MusicSource
        tst.w   UiCursor
        beq.s   .source_set
        move.w  #1,MusicSource
        cmpi.w  #C64_JUKEBOX_FIRST,UiCursor
        blo.s   .source_set
        move.w  #2,MusicSource
.source_set:
        move.b  #1,PreferencesDirty
        bra.w   .redraw
.scores:
        andi.w  #$50,d6
        beq.w   .done
        bsr.w   CloseFrontPage
        bra.w   .done
.edit_name:
        move.w  UiNameLetter,d0
        btst    #1,d6
        beq.s   .name_right
        subq.w  #1,d0
.name_right:
        btst    #0,d6
        beq.s   .name_wrap
        addq.w  #1,d0
.name_wrap:
        bpl.s   .name_max
        moveq   #2,d0
.name_max:
        cmpi.w  #2,d0
        ble.s   .name_letter
        moveq   #0,d0
.name_letter:
        move.w  d0,UiNameLetter
        lea     PlayerInitials,a0
        adda.w  d0,a0
        btst    #3,d6
        beq.s   .name_down
        addq.b  #1,(a0)
.name_down:
        btst    #2,d6
        beq.s   .name_check
        subq.b  #1,(a0)
.name_check:
        cmpi.b  #'A',(a0)
        bhs.s   .name_upper
        move.b  #'Z',(a0)
.name_upper:
        cmpi.b  #'Z',(a0)
        bls.s   .name_done
        move.b  #'A',(a0)
.name_done:
        move.b  #1,PreferencesDirty
        move.w  d6,d0
        andi.w  #$70,d0
        beq.s   .redraw_if_needed
        clr.b   UiNameEditing
        bra.s   .redraw
.redraw_if_needed:
        tst.w   d6
        bne.s   .redraw
        jsr     GetCurrentMusicEnded
        cmp.b   UiLastMusicEnded,d0
        beq.s   .done
.redraw:
        bsr.w   RenderFrontPage
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts

; Return current direction/action state; directions match gameplay bits.
ReadUiButtons:
        movem.l d1-d3/a0,-(sp)
        lea     KeyState,a0
        move.w  CUSTOM+JOY1DAT,d1
        moveq   #0,d0
        btst    #1,d1
        bne.s   .right
        tst.b   $4E(a0)
        beq.s   .left_check
.right: bset    #0,d0
.left_check:
        btst    #9,d1
        bne.s   .left
        tst.b   $4F(a0)
        beq.s   .vertical
.left:  bset    #1,d0
.vertical:
        move.w  d1,d2
        lsr.w   #1,d2
        eor.w   d1,d2
        btst    #0,d2
        bne.s   .down
        tst.b   $4D(a0)
        beq.s   .up_check
.down:  bset    #2,d0
.up_check:
        btst    #8,d2
        bne.s   .up
        tst.b   $4C(a0)
        beq.s   .confirm
.up:    bset    #3,d0
.confirm:
        btst    #1,PadButtons
        bne.s   .yes
        tst.b   $44(a0)
        bne.s   .yes
        tst.b   $63(a0)
        beq.s   .back
.yes:   bset    #4,d0
.back:  btst    #0,PadButtons
        bne.s   .cancel
        tst.b   $45(a0)
        beq.s   .use
.cancel:bset    #5,d0
.use:   btst    #6,PadButtons
        bne.s   .select
        tst.b   $40(a0)
        beq.s   .return
.select:bset    #6,d0
.return:
        movem.l (sp)+,d1-d3/a0
        rts

RenderTitleHints:
        lea     EditionTitleLabel,a0
        lea     HudBuffer+((40-(EditionTitleEnd-EditionTitleLabel-1))/2),a1
        jsr     DrawHudString
        lea     UiTitleHint(pc),a0
        lea     HudBuffer+8*40+1,a1
        jsr     DrawHudString
        rts

RenderFrontPage:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     WaitBlitter
        move.w  #$0100,CUSTOM+DMACON
        jsr     DisableParallax
        jsr     HideGameSprites
        lea     ScreenBuffer,a0
        move.w  #(224*40/4)-1,d7
.clear: clr.l   (a0)+
        dbf     d7,.clear
        lea     HudBuffer,a0
        move.w  #159,d7
.hud:   clr.l   (a0)+
        dbf     d7,.hud
        move.w  #$1201,CopDepth+2
        clr.w   CopScroll+2
        move.w  #$0038,CopFetchStart+2
        clr.w   CopModulo+2
        clr.w   CopModulo+6
        move.w  #$0113,CopColors+2
        move.w  #$0DDD,CopColors+6
        move.l  #ScreenBuffer,d0
        move.w  d0,CopBplPtrs+6
        swap    d0
        move.w  d0,CopBplPtrs+2
        move.l  #HudBuffer,d0
        move.w  d0,CopHudBpl+6
        swap    d0
        move.w  d0,CopHudBpl+2
        move.w  #$0113,CopHudBackground+2
        move.w  #$0FD2,CopHudForeground+2
        lea     UiNavHint(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        lea     UiBackHint(pc),a0
        lea     HudBuffer+8*40+5,a1
        jsr     DrawHudString
        jsr     GetCurrentMusicEnded
        move.b  d0,UiLastMusicEnded
        cmpi.b  #2,UiPage
        beq.w   .jukebox
        cmpi.b  #3,UiPage
        beq.w   .scores
        lea     UiOptionsTitle(pc),a0
        lea     ScreenBuffer+8*40+16,a1
        jsr     DrawHudString
        lea     UiOptionsDescription(pc),a0
        lea     ScreenBuffer+32*40+3,a1
        jsr     DrawHudString
        lea     UiOptionLabels(pc),a3
        moveq   #0,d5
.option:
        movea.l (a3)+,a0
        move.w  d5,d0
        mulu.w  #20*40,d0
        lea     ScreenBuffer+48*40+5,a1
        adda.l  d0,a1
        jsr     DrawHudString
        addq.w  #1,d5
        cmpi.w  #8,d5
        blo.s   .option
        lea     UiArcadeName(pc),a0
        tst.w   MusicSource
        beq.s   .music_value
        lea     UiAmigaName(pc),a0
        cmpi.w  #2,MusicSource
        bne.s   .music_value
        lea     UiC64Name(pc),a0
.music_value:
        lea     ScreenBuffer+48*40+23,a1
        jsr     DrawHudString
        lea     UiStaticName(pc),a0
        tst.b   BackgroundMove
        beq.w   .background_value
        lea     UiParallaxName(pc),a0
.background_value:
        lea     ScreenBuffer+68*40+23,a1
        jsr     DrawHudString
        move.b  PlayerInitials,UiNameDisplay
        move.b  PlayerInitials+1,UiNameDisplay+1
        move.b  PlayerInitials+2,UiNameDisplay+2
        lea     UiNameDisplay(pc),a0
        lea     ScreenBuffer+128*40+23,a1
        jsr     DrawHudString
        lea     UiReducedName(pc),a0
        tst.b   FullColourMode
        beq.w   .graphics_value
        lea     UiFullName(pc),a0
.graphics_value:
        lea     ScreenBuffer+148*40+23,a1
        jsr     DrawHudString
        lea     UiOffName(pc),a0
        tst.b   ShowFPS
        beq.w   .fps_value
        lea     UiOnName(pc),a0
.fps_value:
        lea     ScreenBuffer+168*40+23,a1
        jsr     DrawHudString
        tst.b   FullColourMode
        bne.s   .recommend
        tst.b   BackgroundMove
        beq.s   .options_cursor
.recommend:
        lea     UiRecommend(pc),a0
        lea     ScreenBuffer+208*40+11,a1
        jsr     DrawHudString
.options_cursor:
        move.w  UiCursor,d0
        mulu.w  #20*40,d0
        lea     ScreenBuffer+48*40+2,a1
        adda.l  d0,a1
        lea     UiMarker(pc),a0
        jsr     DrawHudString
        tst.b   UiNameEditing
        beq.w   .publish
        lea     UiNameHint(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        move.w  UiNameLetter,d0
        lea     ScreenBuffer+136*40+23,a1
        adda.w  d0,a1
        lea     UiMarker(pc),a0
        jsr     DrawHudString
        bra.w   .publish
.jukebox:
        lea     UiJukeboxTitle(pc),a0
        lea     ScreenBuffer+8*40+16,a1
        jsr     DrawHudString
        lea     UiPlayingLabel(pc),a0
        tst.w   CurrentMusicTrack
        beq.s   .playing_label
        jsr     GetCurrentMusicEnded
        tst.b   d0
        beq.s   .playing_label
        lea     UiEndedLabel(pc),a0
.playing_label:
        lea     ScreenBuffer+28*40+2,a1
        jsr     DrawHudString
        move.w  CurrentMusicTrack,d0
        jsr     GetMusicTrackName
        lea     ScreenBuffer+28*40+11,a1
        jsr     DrawHudString
        move.w  UiCursor,d4
        andi.w  #$FFF0,d4
        move.w  d4,d5
.track: move.w  d5,d0
        jsr     GetMusicTrackName
        move.w  d5,d0
        sub.w   d4,d0
        mulu.w  #8*40,d0
        lea     ScreenBuffer+48*40+4,a1
        adda.l  d0,a1
        jsr     DrawHudString
        addq.w  #1,d5
        move.w  #MUSIC_TRACK_COUNT,d1
        tst.b   C64MusicAvailable
        bne.s   .track_max
        move.w  #AMIGA_TRACK_COUNT+1,d1
.track_max:
        cmp.w   d1,d5
        bhs.s   .track_done
        move.w  d5,d0
        sub.w   d4,d0
        cmpi.w  #16,d0
        blo.s   .track
.track_done:
        move.w  UiCursor,d0
        andi.w  #15,d0
        mulu.w  #8*40,d0
        lea     ScreenBuffer+48*40+2,a1
        adda.l  d0,a1
        lea     UiMarker(pc),a0
        jsr     DrawHudString
        lea     UiSourceLabel(pc),a0
        lea     ScreenBuffer+192*40+3,a1
        jsr     DrawHudString
        lea     UiArcadeName(pc),a0
        tst.w   MusicSource
        beq.s   .source
        lea     UiAmigaName(pc),a0
        cmpi.w  #2,MusicSource
        bne.s   .source
        lea     UiC64Name(pc),a0
.source:lea     ScreenBuffer+192*40+22,a1
        jsr     DrawHudString
        lea     UiJukeboxHint(pc),a0
        lea     HudBuffer+1,a1
        jsr     DrawHudString
        bra.w   .publish
.scores:
        lea     UiScoresTitle(pc),a0
        lea     ScreenBuffer+8*40+14,a1
        jsr     DrawHudString
        lea     UiScoresColumns(pc),a0
        lea     ScreenBuffer+32*40+5,a1
        jsr     DrawHudString
        lea     HighScoreTable,a4
        moveq   #0,d5
.score: move.w  d5,d0
        mulu.w  #12*40,d0
        lea     ScreenBuffer+48*40+6,a1
        adda.l  d0,a1
        moveq   #'0',d0
        cmpi.w  #9,d5
        bne.s   .rank_first
        moveq   #'1',d0
.rank_first:
        jsr     DrawHudChar
        move.w  d5,d0
        addq.w  #1,d0
        cmpi.w  #10,d0
        bne.s   .rank_second
        moveq   #0,d0
.rank_second:
        addi.w  #'0',d0
        jsr     DrawHudChar
        addq.l  #4,a1
        lea     4(a4),a0
        jsr     DrawHudString
        addq.l  #5,a1
        move.l  (a4),d0
        jsr     DrawHudDec6
        addq.l  #8,a4
        addq.w  #1,d5
        cmpi.w  #10,d5
        blo.s   .score
        lea     UiLastScoreLabel(pc),a0
        lea     ScreenBuffer+184*40+5,a1
        jsr     DrawHudString
        move.l  LastFinalScore,d0
        jsr     DrawHudDec6
        lea     UiSavedScoresHint(pc),a0
        lea     ScreenBuffer+208*40+2,a1
        jsr     DrawHudString
.publish:
        move.w  #$8100,CUSTOM+DMACON
        movem.l (sp)+,d0-d7/a0-a6
        rts

UiPage: dc.b 0
UiParentPage: dc.b 0
UiNameEditing: dc.b 0
UiShortcutHeld: dc.b 0
UiLastMusicEnded: dc.b 0
UiConsumeStart: dc.b 0
        EVEN
UiCursor: dc.w 0
UiNameLetter: dc.w 0
UiPreviousButtons: dc.w 0
UiRepeatTimer: dc.w 18
UiNameDisplay: dc.b "AAA",0
UiMarker: dc.b ">",0
UiTitleHint: dc.b "B/O OPTIONS",0
UiNavHint: dc.b "UP/DOWN SELECT  LEFT/RIGHT CHANGE",0
UiBackHint: dc.b "A/RETURN SELECT  B/ESC BACK",0
UiNameHint: dc.b "UP/DOWN LETTER  LEFT/RIGHT MOVE",0
UiJukeboxHint: dc.b "A/RETURN PLAY SPACE/START USE SOURCE",0
UiOptionsTitle: dc.b "OPTIONS",0
UiOptionsDescription: dc.b "CHOOSE YOUR MUSIC AND BACKGROUND",0
UiJukeboxTitle: dc.b "JUKEBOX",0
UiScoresTitle: dc.b "HIGH SCORES",0
UiPlayingLabel: dc.b "PLAYING:",0
UiEndedLabel: dc.b "ENDED:",0
UiSourceLabel: dc.b "GAME MUSIC SOURCE:",0
UiScoresColumns: dc.b "RANK  NAME     SCORE",0
UiLastScoreLabel: dc.b "LAST RUN: ",0
UiSavedScoresHint: dc.b "SAVED WHEN YOU QUIT THE GAME",0
UiArcadeName: dc.b "ARCADE",0
UiAmigaName: dc.b "AMIGA",0
UiC64Name: dc.b "C64",0
UiStaticName: dc.b "STATIC",0
UiParallaxName: dc.b "PARALLAX",0
UiOptionMusic: dc.b "MUSIC",0
UiOptionBackground: dc.b "BACKGROUND",0
UiOptionJukebox: dc.b "JUKEBOX",0
UiOptionScores: dc.b "HIGH SCORES",0
UiOptionName: dc.b "PLAYER NAME",0
UiOptionGraphics: dc.b "GRAPHICS",0
UiOptionFPS: dc.b "FPS",0
UiOptionBack: dc.b "BACK",0
UiReducedName: dc.b "A1200 REDUCED",0
UiFullName: dc.b "A1200 FULL",0
UiOffName: dc.b "OFF",0
UiOnName: dc.b "ON",0
UiRecommend: dc.b "16X CPU RECOMMENDED",0
        EVEN
UiOptionLabels:
        dc.l UiOptionMusic,UiOptionBackground,UiOptionJukebox
        dc.l UiOptionScores,UiOptionName,UiOptionGraphics,UiOptionFPS,UiOptionBack
