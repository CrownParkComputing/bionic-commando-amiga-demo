; Music source preference follows the level. Jukebox previews may play any
; retained Amiga level/clear/game-over combination without changing source.
InitAudio:
        movem.l d0-d7/a0-a6,-(sp)
        clr.b   MusicMuted
        move.b  #1,MusicInitialized
        move.w  #-1,CurrentMusicTrack
        bsr.w   StartTitleMusic
        movem.l (sp)+,d0-d7/a0-a6
        rts

StartTitleMusic:
        movem.l d0,-(sp)
        tst.b   MusicInitialized
        beq.s   .done
        moveq   #0,d0
        tst.w   MusicSource
        beq.s   .play
        moveq   #1,d0
        cmpi.w  #2,MusicSource
        bne.s   .play
        move.w  #C64_JUKEBOX_FIRST+C64_HIGH_SCORE_TRACK,d0
.play:  bsr.w   EnsureMusicTrack
.done:  movem.l (sp)+,d0
        rts

StartStageMusic:
        movem.l d0,-(sp)
        tst.b   MusicInitialized
        beq.s   .done
        moveq   #0,d0
        tst.w   MusicSource
        beq.s   .play
        move.w  CurrentStage,d0
        addq.w  #1,d0
        cmpi.w  #2,MusicSource
        bne.s   .play
        move.w  CurrentStage,d0
        beq.s   .c64_stage
        subq.w  #1,d0                 ; no Round2 file supplied: reuse Round1
.c64_stage:
        addi.w  #C64_JUKEBOX_FIRST,d0
.play:  bsr.w   EnsureMusicTrack
.done:  movem.l (sp)+,d0
        rts

StartClearMusic:
        movem.l d0,-(sp)
        tst.w   MusicSource
        beq.s   .done
        cmpi.w  #2,MusicSource
        bne.s   .amiga
        move.w  #C64_JUKEBOX_FIRST+C64_CLEAR_TRACK,d0
        bra.s   .play
.amiga: move.w  CurrentStage,d0
        addq.w  #6,d0                 ;jukebox1..5level,6..10clear
.play:  bsr.w   PlayJukeboxTrack
.done:  movem.l (sp)+,d0
        rts

StartGameOverMusic:
        movem.l d0,-(sp)
        tst.w   MusicSource
        beq.s   .done
        cmpi.w  #2,MusicSource
        bne.s   .amiga
        move.w  #C64_JUKEBOX_FIRST+C64_GAME_OVER_TRACK,d0
        bra.s   .play
.amiga: move.w  CurrentStage,d0
        addi.w  #11,d0                ;jukebox11..15game-over
.play:  bsr.w   PlayJukeboxTrack
.done:  movem.l (sp)+,d0
        rts

EnsureMusicTrack:
        cmp.w   CurrentMusicTrack,d0
        beq.s   .done
        bsr.s   PlayJukeboxTrack
.done:  rts

PlayJukeboxTrack:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w  #MUSIC_TRACK_COUNT-1,d0
        bls.s   .valid
        moveq   #0,d0
.valid:
        cmpi.w  #C64_JUKEBOX_FIRST,d0
        blo.s   .available
        tst.b   C64MusicAvailable
        bne.s   .available
        moveq   #0,d0
.available:
        move.w  d0,CurrentMusicTrack
        jsr     StopNativeEffects
        jsr     StopAmigaMusic
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        bhs.s   .c64
        tst.w   CurrentMusicTrack
        bne.s   .amiga
        jsr     InitArcadeAudio
        bra.s   .done
.c64:
        move.w  CurrentMusicTrack,d0
        subi.w  #C64_JUKEBOX_FIRST,d0
        jsr     InitC64MusicTrack
        bra.s   .done
.amiga:
        move.w  #$000F,CUSTOM+DMACON
        clr.b   MusicState
        move.w  CurrentMusicTrack,d0
        subq.w  #1,d0
        jsr     InitAmigaMusicTrack
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts

; d0=jukebox index0..15; returns a0=name, preserves other registers.
GetMusicTrackName:
        move.l  d0,-(sp)
        cmpi.w  #C64_JUKEBOX_FIRST,d0
        bhs.s   .c64
        tst.w   d0
        beq.s   .arcade
        subq.w  #1,d0
        lsl.w   #2,d0
        lea     AmigaTrackNameDirectory,a0
        movea.l (a0,d0.w),a0
        bra.s   .done
.c64:   subi.w  #C64_JUKEBOX_FIRST,d0
        lsl.w   #2,d0
        lea     C64TrackNameDirectory,a0
        movea.l (a0,d0.w),a0
        bra.s   .done
.arcade: lea    ArcadeMusicName(pc),a0
.done:  move.l  (sp)+,d0
        rts

GetCurrentMusicEnded:
        moveq   #0,d0
        tst.w   CurrentMusicTrack
        beq.s   .done
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        bhs.s   .c64
        move.b  AmigaMusicEnded,d0
        rts
.c64:   move.b  C64MusicEnded,d0
.done:  rts

MusicInitialized: dc.b 0
        EVEN
CurrentMusicTrack: dc.w -1
ArcadeMusicName: dc.b "ARCADE - STAGE 1",0
        EVEN
