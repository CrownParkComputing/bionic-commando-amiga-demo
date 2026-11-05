; BCS2/version2,100-byte preferences. Bytes0..91 retain the version1 fields;
; 92FPS,93fullcolour,94lastmachine,95zero,96checksum(first48BE words),98zero.
; Valid BCS1/version1,96-byte files migrate without losing scores/options.
; Load before hardware takeover; save only on clean exit via DOS/native slave.
LoadPreferences:
        movem.l d0-d7/a0-a6,-(sp)
        lea     PreferencesBuffer,a0
        moveq   #0,d0
        bsr.w   PreferencesIO
        cmpi.l  #96,d0
        beq.w   .legacy
        cmpi.l  #100,d0
        bne.w   .done
        lea     PreferencesBuffer,a0
        cmpi.l  #$42435332,(a0)
        bne.w   .done
        cmpi.w  #2,4(a0)
        bne.w   .done
        cmpi.b  #1,92(a0)
        bhi.w   .done
        cmpi.b  #1,93(a0)
        bhi.w   .done
        cmpi.b  #$FF,94(a0)
        beq.s   .machine_ok
        cmpi.b  #1,94(a0)
        bhi.w   .done
.machine_ok:
        tst.b   95(a0)
        bne.w   .done
        tst.w   98(a0)
        bne.w   .done
        moveq   #0,d5                  ;current schema
        moveq   #47,d6                 ;checksum covers96bytes
        bra.s   .validate_common
.legacy:
        lea     PreferencesBuffer,a0
        cmpi.l  #$42435331,(a0)
        bne.w   .done
        cmpi.w  #1,4(a0)
        bne.w   .done
        moveq   #1,d5
        moveq   #45,d6                 ;legacy checksum covers92bytes
.validate_common:
        cmpi.w  #2,6(a0)
        bhi.w   .done
        cmpi.b  #1,8(a0)
        bhi.w   .done
        moveq   #0,d0
        move.w  d6,d7
.checksum:
        add.w   (a0)+,d0
        dbf     d7,.checksum
        cmp.w   (a0),d0
        bne.w   .done
        lea     PreferencesBuffer+9,a0
        moveq   #2,d7
.initials:
        cmpi.b  #'A',(a0)
        blo.w   .done
        cmpi.b  #'Z',(a0)+
        bhi.w   .done
        dbf     d7,.initials
        move.l  #599999,d1
        moveq   #9,d7
.record:
        move.l  (a0)+,d0
        cmp.l   d1,d0
        bhi.w   .done
        move.l  d0,d1
        moveq   #2,d6
.name:
        move.b  (a0)+,d0
        cmpi.b  #'-',d0
        beq.s   .name_ok
        cmpi.b  #'A',d0
        blo.w   .done
        cmpi.b  #'Z',d0
        bhi.w   .done
.name_ok:
        dbf     d6,.name
        tst.b   (a0)+
        bne.w   .done
        dbf     d7,.record
        lea     PreferencesBuffer,a0
        lea     PreferencesData,a1
        tst.b   d5
        bne.s   .migrate
        moveq   #24,d7
.copy:  move.l  (a0)+,(a1)+
        dbf     d7,.copy
        bra.s   .done
.migrate:
        moveq   #22,d7
.copy_legacy:
        move.l  (a0)+,(a1)+
        dbf     d7,.copy_legacy
        move.l  #$42435332,PreferencesData
        move.w  #2,PreferencesData+4
        clr.b   ShowFPS
        clr.b   FullColourMode
        ; A known launch profile preserves a legacy user's background choice.
        move.b  MachineProfile,LastMachineProfile
        clr.b   PreferencesReserved
        clr.w   PreferencesChecksum
        clr.w   PreferencesPadding
        move.b  #1,PreferencesDirty
.done:  bsr.w   EnforceGraphicsEdition
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Called after LoadPreferences. Background defaults follow a new edition;
; the same edition retains the user's background and FPS choices.
ApplyMachineDefaults:
        move.l  d0,-(sp)
        bsr.w   EnforceGraphicsEdition
        moveq   #0,d0
        move.b  MachineProfile,d0
        cmpi.b  #1,d0
        bls.s   .valid
        moveq   #0,d0
.valid: cmp.b   LastMachineProfile,d0
        beq.s   .done
        move.b  d0,FullColourMode
        move.b  d0,BackgroundMove
        move.b  d0,LastMachineProfile
        move.b  #1,PreferencesDirty
.done:  move.l  (sp)+,d0
        rts

; Old settings cannot turn a reduced executable into a full one, or vice versa.
EnforceGraphicsEdition:
        move.b  #BUILD_GFX_PROFILE,MachineProfile
        cmpi.b  #BUILD_GFX_PROFILE,FullColourMode
        beq.s   .done
        move.b  #BUILD_GFX_PROFILE,FullColourMode
        move.b  #1,PreferencesDirty
.done:  rts

SavePreferences:
        movem.l d0-d7/a0-a6,-(sp)
        tst.b   PreferencesDirty
        beq.s   .done
        lea     PreferencesData,a0
        moveq   #0,d0
        moveq   #47,d7
.checksum:
        add.w   (a0)+,d0
        dbf     d7,.checksum
        move.w  d0,(a0)
        lea     PreferencesData,a0
        moveq   #1,d0
        bsr.w   PreferencesIO
        tst.l   d0
        beq.s   .done
        clr.b   PreferencesDirty
.done:  movem.l (sp)+,d0-d7/a0-a6
        rts

PreferencesIO:
        ifne BUILD_WHDLOAD
        movea.l WHDPreferencesCallback,a1
        jmp     (a1)
        else
        movem.l d1-d7/a0-a6,-(sp)
        move.l  d0,d6
        movea.l a0,a3
        moveq   #0,d5
        movea.l 4.w,a6
        lea     DosName,a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)
        tst.l   d0
        beq.s   .result
        movea.l d0,a4
        movea.l d0,a6
        lea     PreferencesFilename(pc),a0
        move.l  a0,d1
        move.l  #1005,d2
        tst.l   d6
        beq.s   .open
        move.l  #1006,d2
.open:  jsr     -30(a6)
        move.l  d0,d4
        beq.s   .close_library
        move.l  d4,d1
        move.l  a3,d2
        moveq   #100,d3
        tst.l   d6
        bne.s   .write
        jsr     -42(a6)
        bra.s   .close
.write: jsr     -48(a6)
.close: move.l  d0,d5
        move.l  d4,d1
        jsr     -36(a6)
.close_library:
        movea.l 4.w,a6
        movea.l a4,a1
        jsr     _LVOCloseLibrary(a6)
.result:
        moveq   #0,d0
        cmpi.l  #100,d5
        beq.s   .valid_count
        tst.l   d6                     ;writes must complete all100bytes
        bne.s   .return
        cmpi.l  #96,d5                  ;reads also accept the legacy record
        bne.s   .return
.valid_count:
        move.l  d5,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        rts
        endif

SubmitHighScore:
        movem.l d0-d7/a0-a3,-(sp)
        tst.b   HighScoreSubmitted
        bne.w   .done
        move.b  #1,HighScoreSubmitted
        move.l  Score,d0
        move.l  d0,LastFinalScore
        move.w  #-1,HighScoreLastRank
        tst.l   d0
        beq.w   .done
        lea     HighScoreTable,a0
        moveq   #0,d1
.find:  cmp.l   (a0),d0
        bhi.s   .insert
        addq.l  #8,a0
        addq.w  #1,d1
        cmpi.w  #10,d1
        blo.s   .find
        bra.s   .done
.insert:
        move.w  d1,HighScoreLastRank
        lea     HighScoreTable+9*8,a1
        moveq   #9,d7
.shift:
        cmp.w   d1,d7
        beq.s   .store
        move.l  -8(a1),(a1)
        move.l  -4(a1),4(a1)
        subq.l  #8,a1
        subq.w  #1,d7
        bra.s   .shift
.store: move.l  d0,(a0)
        move.b  PlayerInitials,4(a0)
        move.b  PlayerInitials+1,5(a0)
        move.b  PlayerInitials+2,6(a0)
        clr.b   7(a0)
        move.b  #1,PreferencesDirty
.done:  movem.l (sp)+,d0-d7/a0-a3
        rts

        EVEN
PreferencesData:
        dc.b "BCS2"
        dc.w 2
MusicSource:    dc.w 0                 ;0arcade,1original Amiga,2C64 recordings
BackgroundMove: dc.b 0                 ;0fixed scenery,1parallax
PlayerInitials: dc.b "AAA"
HighScoreTable:
        REPT 10
        dc.l 0
        dc.b "---",0
        ENDR
ShowFPS:            dc.b 0
FullColourMode:     dc.b 0
LastMachineProfile: dc.b $FF
PreferencesReserved:dc.b 0
PreferencesChecksum:dc.w 0
PreferencesPadding: dc.w 0
PreferencesDataEnd:
PreferencesBuffer: ds.b 100
PreferencesDirty: dc.b 0
HighScoreSubmitted: dc.b 0
        EVEN
HighScoreLastRank: dc.w -1
LastFinalScore: dc.l 0
PreferencesFilename: dc.b "bionic_demo.scores",0
        EVEN
