; Original 1988 Amiga Tim/Mike Follin replay. Native notes, effects, PCM,
; periods, volumes and 50Hz score clock are retained. The three native DMA
; instructions call hooks; the register-pointer table writes music shadows.
; This permits the existing arcade SFX to borrow Paula2/3 without resetting
; music's score state. Voices0/1 remain audible during that interval.
;
; ABI (all registers preserved):
;   InitAmigaMusicTrack: d0.w = index < AMIGA_TRACK_COUNT
;   TickAmigaMusic: exactly once per PAL logic tick, also in menus
;   StopAmigaMusic: stop available music voices, preserve an active SFX
; Externals: LZSS_Decompress, MusicMuted, NativeSfxBusyTicks, SfxState.
; Include amiga_music_bss.i once among the final BSS sections.
        include "amiga_music_defs.i"

UnpackAmigaMusicAssets:
        movem.l d0-d7/a0-a4,-(sp)
        tst.b   AmigaMusicReady
        bne.w   .done
        lea     AmigaMusicCoreLZ,a0
        lea     AmigaMusicWork,a1
        jsr     LZSS_Decompress
        lea     AmigaMusicWork,a1
        move.l  a1,d1
        lea     AmigaMusicRelocations,a2
.relocate:
        moveq   #0,d0
        move.w  (a2)+,d0
        bmi.s   .dma_patches
        add.l   d1,(a1,d0.w)
        bra.s   .relocate
.dma_patches:
        lea     AmigaMusicDmaPatchTable,a2
.patch:
        moveq   #0,d0
        move.w  (a2)+,d0
        bmi.s   .registers
        move.w  (a2)+,d2
        move.l  #AmigaMusicDisableDMA,d3
        tst.w   d2
        beq.s   .patch_write
        move.l  #AmigaMusicEnableDMA,d3
.patch_write:
        move.l  d3,(a1,d0.w)
        bra.s   .patch
.registers:
        lea     AmigaMusicWork+AMIGA_CORE_REGISTERS,a0
        lea     AmigaMusicShadows,a2
        moveq   #3,d7
.voice:
        lea     6(a2),a3
        move.l  a3,(a0)
        lea     4(a2),a3
        move.l  a3,16(a0)
        move.l  a2,32(a0)
        lea     8(a2),a3
        move.l  a3,48(a0)
        addq.l  #4,a0
        lea     16(a2),a2
        dbf     d7,.voice
        move.l  #AmigaMusicInstrumentHeader-32,AmigaMusicWork+AMIGA_CORE_BANK_SLOT
        move.l  #AmigaMusicSilence,AmigaMusicWork+AMIGA_CORE_SILENCE_SLOT
        lea     AmigaMusicSampleSource,a0
        lea     AmigaMusicSamplePool,a1
        move.w  #(AMIGA_MUSIC_SAMPLE_BYTES/2)-1,d7
.samples:
        move.w  (a0)+,(a1)+
        dbf     d7,.samples
        move.b  #1,AmigaMusicReady
.done:
        movem.l (sp)+,d0-d7/a0-a4
        rts

InitAmigaMusicTrack:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w  #AMIGA_TRACK_COUNT,d0
        blo.s   .index
        moveq   #0,d0
.index:
        move.w  d0,AmigaMusicTrack
        bsr.w   StopAmigaMusic
        bsr.w   UnpackAmigaMusicAssets
        move.w  AmigaMusicTrack,d0
        lea     AmigaMusicTrackBanks,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        move.w  d1,AmigaMusicBank
        mulu.w  #26,d1
        lea     AmigaMusicBankOffsets,a0
        adda.w  d1,a0
        lea     AmigaMusicInstrumentHeader,a1
        move.l  #AmigaMusicSamplePool,d3
        sub.l   a1,d3
        moveq   #12,d7
.instrument:
        moveq   #0,d2
        move.w  (a0)+,d2
        add.l   d3,d2
        move.l  d2,(a1)+
        dbf     d7,.instrument
        ; Native synths0..3 have independent mutable duty-cycle buffers.
        lea     AmigaMusicSampleSource,a0
        lea     AmigaMusicSamplePool,a1
        moveq   #67,d7
.reset_synth:
        move.w  (a0)+,(a1)+
        dbf     d7,.reset_synth
        lea     AmigaMusicShadows,a0
        moveq   #15,d7
.clear_shadow:
        clr.l   (a0)+
        dbf     d7,.clear_shadow
        move.w  AmigaMusicTrack,d0
        lea     AmigaMusicTrackScores,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        move.w  d1,AmigaMusicWork+AMIGA_CORE_SONG
        clr.b   AmigaMusicWork+AMIGA_CORE_ENDED
        jsr     AmigaMusicWork+AMIGA_CORE_INIT
        clr.b   AmigaMusicEnded
        clr.l   AmigaMusicTicks
        bsr.w   AmigaMusicSetBlocked
        move.b  AmigaMusicBlocked,AmigaMusicPreviousBlocked
        move.b  #1,AmigaMusicActive
        movem.l (sp)+,d0-d7/a0-a6
        rts

TickAmigaMusic:
        movem.l d0-d7/a0-a6,-(sp)
        tst.b   AmigaMusicActive
        beq.w   .done
        bsr.w   AmigaMusicSetBlocked
        moveq   #0,d2
        move.b  AmigaMusicPreviousBlocked,d2
        tst.b   AmigaMusicForceRestore
        beq.s   .no_force
        ori.b   #$0C,d2
        tst.b   AmigaMusicBlocked
        bne.s   .no_force
        clr.b   AmigaMusicForceRestore
.no_force:
        moveq   #0,d1
        move.b  AmigaMusicBlocked,d1
        not.b   d1
        and.b   d1,d2
        and.b   AmigaMusicDmaWanted,d2
        beq.s   .native_tick
        ; An SFX has finished: restart only music voices still enabled by
        ; the native score, using their current shadow loop/sample state.
        move.w  d2,CUSTOM+DMACON
        moveq   #0,d7
.restore_voice:
        btst    d7,d2
        beq.s   .restore_next
        move.w  d7,d0
        bsr.w   AmigaMusicWriteVoice
.restore_next:
        addq.w  #1,d7
        cmpi.w  #4,d7
        blo.s   .restore_voice
        ori.w   #$8200,d2
        move.w  d2,CUSTOM+DMACON
.native_tick:
        move.b  AmigaMusicBlocked,AmigaMusicPreviousBlocked
        jsr     AmigaMusicWork+AMIGA_CORE_TICK
        jsr     AmigaMusicWork+AMIGA_CORE_STATUS_TICK
        addq.l  #1,AmigaMusicTicks
        moveq   #0,d7
.flush:
        btst    d7,AmigaMusicBlocked
        bne.s   .next
        move.w  d7,d0
        bsr.w   AmigaMusicWriteVoice
.next:
        addq.w  #1,d7
        cmpi.w  #4,d7
        blo.s   .flush
        tst.b   AmigaMusicWork+AMIGA_CORE_ENDED
        beq.s   .done
        move.b  #1,AmigaMusicEnded
        clr.b   AmigaMusicActive
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

StopAmigaMusic:
        movem.l d0-d2/a0,-(sp)
        clr.b   AmigaMusicActive
        clr.b   AmigaMusicDmaWanted
        clr.b   AmigaMusicForceRestore
        bsr.w   AmigaMusicSetBlocked
        moveq   #15,d0
        moveq   #0,d1
        move.b  AmigaMusicBlocked,d1
        not.w   d1
        and.w   d1,d0
        move.w  d0,CUSTOM+DMACON
        lea     CUSTOM+$A8,a0
        moveq   #0,d2
.voice:
        btst    d2,AmigaMusicBlocked
        bne.s   .next
        clr.w   (a0)
.next:
        lea     16(a0),a0
        addq.w  #1,d2
        cmpi.w  #4,d2
        blo.s   .voice
        movem.l (sp)+,d0-d2/a0
        rts

AmigaMusicSetBlocked:
        clr.b   AmigaMusicBlocked
        tst.w   NativeSfxBusyTicks
        bne.s   .sfx
        tst.b   SfxState
        beq.s   .done
.sfx:  move.b  #$0C,AmigaMusicBlocked
.done: rts

; d0.w=voice. Preserve d2 (a caller's restore mask), d6/d7 and a2..a6.
; Publish the same native register values, with only the existing mute applied.
AmigaMusicWriteVoice:
        lsl.w   #4,d0
        lea     AmigaMusicShadows,a0
        adda.w  d0,a0
        lea     CUSTOM+$A0,a1
        adda.w  d0,a1
        move.l  (a0),(a1)
        move.w  4(a0),4(a1)
        move.w  6(a0),6(a1)
        tst.b   MusicMuted
        beq.s   .audible
        clr.w   8(a1)
        rts
.audible:
        move.w  8(a0),8(a1)
        rts

; Entered from native core with d6=voice,d5=voice*2,a4=native DMA table.
; Preserve every native working register and condition flags are irrelevant
; at all three original write sites (the following native instruction tests).
AmigaMusicEnableDMA:
        movem.l d0-d2/a0-a1,-(sp)
        bset    d6,AmigaMusicDmaWanted
        btst    d6,AmigaMusicBlocked
        bne.s   .done
        move.w  d6,d0
        bsr.w   AmigaMusicWriteVoice
        move.w  8(a4,d5.w),CUSTOM+DMACON
.done:
        movem.l (sp)+,d0-d2/a0-a1
        rts

AmigaMusicDisableDMA:
        bclr    d6,AmigaMusicDmaWanted
        btst    d6,AmigaMusicBlocked
        bne.s   .done
        move.w  (a4,d5.w),CUSTOM+DMACON
.done: rts

AmigaMusicReady:           dc.b 0
AmigaMusicActive:          dc.b 0
AmigaMusicEnded:           dc.b 0
AmigaMusicDmaWanted:       dc.b 0
AmigaMusicBlocked:         dc.b 0
AmigaMusicPreviousBlocked: dc.b 0
; Root may set1 after StopNativeEffects disables Paula2/3. The next available
; music tick republishes their native shadows and restores wanted DMA bits.
AmigaMusicForceRestore:    dc.b 0
        EVEN
AmigaMusicTrack:           dc.w 0
AmigaMusicBank:            dc.w 0
AmigaMusicTicks:           dc.l 0

        include "amiga_music_data.i"
