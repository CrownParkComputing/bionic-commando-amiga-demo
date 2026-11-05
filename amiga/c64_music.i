; Optional preloaded stereo C64 recordings. No filesystem calls during play.
LoadC64Music:
        movem.l d0-d7/a0-a6,-(sp)
        clr.b   C64MusicAvailable
        ifne BUILD_WHDLOAD
        lea     C64MusicBank,a0
        move.l  #C64_BANK_BYTES,d1
        moveq   #2,d0
        movea.l WHDPreferencesCallback,a1
        jsr     (a1)
        else
        movea.l 4.w,a6
        lea     DosName,a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)
        tst.l   d0
        beq.w   .unavailable
        movea.l d0,a4
        movea.l d0,a6
        lea     C64MusicFilename(pc),a0
        move.l  a0,d1
        move.l  #1005,d2
        jsr     -30(a6)
        move.l  d0,d4
        beq.s   .close_library
        move.l  d4,d1
        move.l  #C64MusicBank,d2
        move.l  #C64_BANK_BYTES+1,d3
        jsr     -42(a6)
        move.l  d0,d5
        move.l  d4,d1
        jsr     -36(a6)
        bra.s   .close
.close_library:
        moveq   #0,d5
.close:
        movea.l 4.w,a6
        movea.l a4,a1
        jsr     _LVOCloseLibrary(a6)
        move.l  d5,d0
        endif
        cmpi.l  #C64_BANK_BYTES,d0
        bne.s   .unavailable
        lea     C64MusicBank,a0
        cmpi.l  #$42433634,(a0)
        bne.s   .unavailable
        cmpi.w  #2,4(a0)
        bne.s   .unavailable
        cmpi.w  #C64_TRACK_COUNT,6(a0)
        bne.s   .unavailable
        cmp.l   8(a0),d0
        bne.s   .unavailable
        cmpi.w  #7628,12(a0)
        bne.s   .unavailable
        cmpi.w  #2,14(a0)
        bne.s   .unavailable
        lea     16(a0),a1
        moveq   #C64_TRACK_COUNT-1,d7
.track:
        move.l  (a1),d1
        cmpi.l  #(16+C64_TRACK_COUNT*16),d1
        blo.s   .unavailable
        move.l  4(a1),d2
        beq.s   .unavailable
        move.l  d2,d3
        addq.l  #1,d3
        lsr.l   #1,d3
        move.l  d3,d4
        add.l   d3,d3
        add.l   d4,d3
        add.l   d3,d1
        bcs.s   .unavailable
        cmp.l   d0,d1
        bhi.s   .unavailable
        cmpi.w  #1,8(a1)
        bhi.s   .unavailable
        lea     16(a1),a1
        dbf     d7,.track
        move.b  #1,C64MusicAvailable
.unavailable:
        tst.b   C64MusicAvailable
        bne.s   .done
        cmpi.w  #2,MusicSource
        bne.s   .done
        clr.w   MusicSource
        move.b  #1,PreferencesDirty
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts

; d0=C64 local track. All registers preserved. AUD0=left,AUD1=right.
InitC64MusicTrack:
        movem.l d0-d7/a0-a6,-(sp)
        move.w  d0,C64MusicTrack
        clr.b   C64MusicEnded
        clr.b   MusicMuted
        clr.l   C64BlocksDecoded
        clr.w   C64PendingFrames
        move.w  #$0003,CUSTOM+DMACON
        bsr.w   ResetC64Decoder
        lea     AudioBufA,a1
        lea     C64RightA,a2
        bsr.w   DecodeC64Block
        lea     AudioBufB,a1
        lea     C64RightB,a2
        bsr.w   DecodeC64Block
        lea     CUSTOM,a5
        move.l  #AudioBufA,AUD0LCH(a5)
        move.l  #C64RightA,AUD1LCH(a5)
        move.w  #1024,AUD0LEN(a5)
        move.w  #1024,AUD1LEN(a5)
        move.w  #465,AUD0PER(a5)
        move.w  #465,AUD1PER(a5)
        move.w  #56,AUD0VOL(a5)
        move.w  #56,AUD1VOL(a5)
        move.w  #$0180,INTREQ(a5)
        move.b  #1,MusicState
        move.w  #$8203,DMACON(a5)
        movem.l (sp)+,d0-d7/a0-a6
        rts

ResetC64Decoder:
        movem.l d0/a0,-(sp)
        move.w  C64MusicTrack,d0
        lsl.w   #4,d0
        lea     C64MusicBank+16,a0
        adda.w  d0,a0
        move.l  4(a0),C64FramesRemaining
        move.w  8(a0),C64TrackLoop
        move.l  (a0),d0
        addi.l  #C64MusicBank,d0
        move.l  d0,C64ReadPointer
        clr.b   C64PCMPhase
        movem.l (sp)+,d0/a0
        rts

; a1/a2=2048-byte left/right output; all registers preserved.
DecodeC64Block:
        move.l  d0,-(sp)
        move.w  #2047,d0
        bsr.w   DecodeC64Frames
        addq.l  #1,C64BlocksDecoded
        move.l  (sp)+,d0
        rts

; d0=count-1. The steady player spreads one2048-frame buffer over eight
; PAL ticks, keeping its Chip writes out of a single expensive display frame.
DecodeC64Frames:
        movem.l d0-d7/a0-a6,-(sp)
        movea.l C64ReadPointer,a3
        move.w  d0,d7
.frame:
        tst.l   C64FramesRemaining
        bne.s   .decode
        tst.w   C64TrackLoop
        beq.w   .silence
        bsr.s   ResetC64Decoder
        movea.l C64ReadPointer,a3
.decode:
        ; Ordinary blocks unpack two stereo frames with word-sized Chip
        ; writes. The byte path handles an odd cue end or loop seam.
        tst.b   C64PCMPhase
        bne.s   .single
        cmpi.l  #2,C64FramesRemaining
        blo.s   .single
        cmpi.w  #1,d7
        blo.s   .single
        move.w  (a3)+,d0
        moveq   #0,d1
        move.b  (a3)+,d1
        move.w  d0,d2
        andi.w  #$FC00,d2
        move.w  d0,d3
        lsl.w   #4,d3
        andi.w  #$00F0,d3
        or.w    d3,d2
        move.w  d1,d3
        lsr.w   #4,d3
        andi.w  #$000C,d3
        or.w    d3,d2
        move.w  d2,(a1)+
        lsl.w   #6,d0
        andi.w  #$FC00,d0
        lsl.w   #2,d1
        andi.w  #$00FC,d1
        or.w    d1,d0
        move.w  d0,(a2)+
        subq.l  #2,C64FramesRemaining
        subq.w  #2,d7
        bpl.w   .frame
        bra.s   .done
.single:
        tst.b   C64PCMPhase
        bne.s   .second
        move.b  (a3),d0
        andi.b  #$FC,d0
        move.b  d0,(a1)+
        move.w  (a3),d0
        lsr.w   #2,d0
        andi.b  #$FC,d0
        move.b  d0,(a2)+
        move.b  #1,C64PCMPhase
        bra.s   .decoded
.second:
        move.b  1(a3),d0
        lsl.b   #4,d0
        move.b  2(a3),d1
        lsr.b   #4,d1
        andi.b  #$0C,d1
        or.b    d1,d0
        move.b  d0,(a1)+
        move.b  2(a3),d0
        lsl.b   #2,d0
        move.b  d0,(a2)+
        addq.l  #3,a3
        clr.b   C64PCMPhase
.decoded:
        subq.l  #1,C64FramesRemaining
        subq.w  #1,d7
        bpl.w   .frame
        bra.s   .done
.silence:
        move.b  #1,C64MusicEnded
.zero:  clr.b   (a1)+
        clr.b   (a2)+
        dbf     d7,.zero
.done:  move.l  a3,C64ReadPointer
        movem.l (sp)+,d0-d7/a0-a6
        rts

TickC64Music:
        tst.w   C64PendingFrames
        beq.s   .quick_return
        movem.l d0-d7/a0-a6,-(sp)
        movea.l C64FillLeft,a1
        movea.l C64FillRight,a2
        move.w  #255,d0
        bsr.w   DecodeC64Frames
        addi.l  #256,C64FillLeft
        addi.l  #256,C64FillRight
        subi.w  #256,C64PendingFrames
        bne.s   .done
        addq.l  #1,C64BlocksDecoded
.done:  movem.l (sp)+,d0-d7/a0-a6
.quick_return:
        rts

TickSelectedMusic:
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        bhs.s   .c64
        jmp     TickAmigaMusic
.c64:   jmp     TickC64Music

ServiceC64MusicDMA:
        ; This is polled by every blitter wait. Avoid a full register save
        ; unless Paula actually needs a new buffer.
        btst    #7,CUSTOM+INTREQR+1
        beq.w   .quick_return
        movem.l d0-d7/a0-a6,-(sp)
        lea     CUSTOM,a5
        ; If a frame was unusually late, complete the old pending buffer
        ; before scheduling its replacement. Normal50Hz play uses256/tick.
        tst.w   C64PendingFrames
        beq.s   .ready
        movea.l C64FillLeft,a1
        movea.l C64FillRight,a2
        move.w  C64PendingFrames,d0
        subq.w  #1,d0
        bsr.w   DecodeC64Frames
        clr.w   C64PendingFrames
        addq.l  #1,C64BlocksDecoded
.ready:
        move.w  #$0180,INTREQ(a5)
        cmpi.b  #1,MusicState
        bne.s   .refill
        move.l  #AudioBufB,AUD0LCH(a5)
        move.l  #C64RightB,AUD1LCH(a5)
        move.b  #2,MusicState
        bra.s   .done
.refill:
        cmpi.b  #2,MusicState
        bne.s   .buffer_b
        move.l  #AudioBufA,C64FillLeft
        move.l  #C64RightA,C64FillRight
        move.l  #AudioBufA,AUD0LCH(a5)
        move.l  #C64RightA,AUD1LCH(a5)
        move.b  #3,MusicState
        move.w  #2048,C64PendingFrames
        bra.s   .done
.buffer_b:
        move.l  #AudioBufB,C64FillLeft
        move.l  #C64RightB,C64FillRight
        move.l  #AudioBufB,AUD0LCH(a5)
        move.l  #C64RightB,AUD1LCH(a5)
        move.b  #2,MusicState
        move.w  #2048,C64PendingFrames
.done:  movem.l (sp)+,d0-d7/a0-a6
.quick_return:
        rts

C64MusicFilename: dc.b "data/c64_music.bcm",0
        EVEN
C64MusicAvailable: dc.b 0
C64MusicEnded: dc.b 0
        EVEN
C64MusicTrack: dc.w 0
C64TrackLoop: dc.w 0
C64ReadPointer: dc.l 0
C64FramesRemaining: dc.l 0
C64BlocksDecoded: dc.l 0
C64FillLeft: dc.l 0
C64FillRight: dc.l 0
C64PendingFrames: dc.w 0
C64PCMPhase: dc.b 0
        EVEN
C64TrackNameDirectory:
        dc.l C64TrackName0
        dc.l C64TrackName4,C64TrackName5,C64TrackName6
C64TrackName0: dc.b "C64 - THE FRONT LINE",0
C64TrackName4: dc.b "C64 - HIGH SCORES",0
C64TrackName5: dc.b "C64 - ROUND CLEAR",0
C64TrackName6: dc.b "C64 - GAME OVER",0
        EVEN
