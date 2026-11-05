; Native command IDs and variable-length complete PCM cues. Two Paula voices
; reproduce a centered one-shot; priority prevents ambient buzz hiding actions.
UnpackExtendedAssets:
        movem.l d0-d7/a0-a4,-(sp)
        lea     JoeDeathSpritesLZ,a0
        lea     JoeDeathSpritesData,a1
        jsr     LZSS_Decompress
        lea     NativeSfxLZ,a0
        lea     NativeSfxData,a1
        jsr     LZSS_Decompress
        movem.l (sp)+,d0-d7/a0-a4
        rts

StopNativeEffects:
        move.w  #$000C,CUSTOM+DMACON
        clr.b   SfxState
        clr.b   NativeSfxPriority
        clr.w   NativeSfxBusyTicks
        clr.w   LastNativeSfx
        clr.w   NativeBuzzTimer
        move.b  #1,AmigaMusicForceRestore
        rts

; d0=native sound ID; preserve all registers at gameplay call sites.
PlayNativeSFX:
        movem.l d0-d7/a0-a2,-(sp)
        lea     NativeSfxDescriptors,a0
        moveq   #NATIVE_SFX_COUNT-1,d7
.find:
        cmp.w   (a0),d0
        beq.s   .found
        lea     NATIVE_SFX_DESCRIPTOR_BYTES(a0),a0
        dbf     d7,.find
        bra.w   .done
.found:
        moveq   #2,d6
        cmpi.w  #$22,d0
        bne.s   .foreground
        moveq   #1,d6
        bra.s   .priority
.foreground:
        cmpi.w  #$20,d0
        bne.s   .ordinary
        moveq   #4,d6
        bra.s   .priority
.ordinary:
        cmpi.w  #$19,d0
        beq.s   .priority
        moveq   #3,d6
.priority:
        tst.w   NativeSfxBusyTicks
        beq.s   .play
        cmp.b   NativeSfxPriority(pc),d6
        blo.s   .done
.play:
        move.w  d0,LastNativeSfx
        move.b  d6,NativeSfxPriority
        movea.l 2(a0),a1
        adda.l  #NativeSfxData,a1
        move.l  a1,PendingSfxPtr
        move.w  6(a0),PendingSfxWords
        move.w  8(a0),PendingSfxPeriod
        moveq   #0,d1
        move.w  6(a0),d1
        mulu.w  #100,d1
        addi.l  #7627,d1
        divu.w  #7628,d1
        move.w  d1,NativeSfxBusyTicks
        move.w  #$000C,CUSTOM+DMACON
        move.b  #1,SfxState
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; Called once per simulation tick, including catch-up ticks. A live hive head
; retriggers its buzz every100PAL ticks, only when higher-priority cues allow.
UpdateNativeAmbient:
        movem.l d0-d2/d7/a0-a1,-(sp)
        tst.b   LP_State
        bne.s   .done
        tst.w   NativeBuzzTimer
        beq.s   .scan
        subq.w  #1,NativeBuzzTimer
        bne.s   .done
.scan:
        lea     EnemyList,a0
        lea     EnemyAux,a1
        moveq   #MAX_ENEMIES-1,d7
.head:
        cmpi.w  #1,EN_STATE(a0)
        bne.s   .next
        cmpi.w  #10,EN_TYPE(a0)
        bne.s   .next
        tst.w   EA_KIND(a1)
        bne.s   .next
        move.w  #100,NativeBuzzTimer
        moveq   #$22,d0
        bsr.w   PlayNativeSFX
        bra.s   .done
.next:
        lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a1),a1
        dbf     d7,.head
        move.w  #10,NativeBuzzTimer
        cmpi.w  #$22,LastNativeSfx
        bne.s   .done
        bsr.w   StopNativeEffects
        move.w  #10,NativeBuzzTimer
.done:
        movem.l (sp)+,d0-d2/d7/a0-a1
        rts

; a1=defeated actor. Native death cues are distinct from landing/jumping.
PlayEnemyDeathSound:
        move.l  d0,-(sp)
        moveq   #$1E,d0
        cmpi.w  #1,EN_TYPE(a1)
        beq.s   .bird_or_acrobat
        cmpi.w  #11,EN_TYPE(a1)          ; native SMALL0 kind0 fatal18220 uses16
        bne.s   .heavy
.bird_or_acrobat:
        moveq   #$16,d0
        bra.s   .play
.heavy:
        cmpi.w  #2,EN_TYPE(a1)
        bne.s   .play
        moveq   #$1A,d0
.play:
        bsr.w   PlayNativeSFX
        move.l  (sp)+,d0
        rts

PendingSfxWords:     dc.w 1024
PendingSfxPeriod:    dc.w 465
NativeSfxBusyTicks:  dc.w 0
LastNativeSfx:       dc.w 0
NativeBuzzTimer:     dc.w 0
NativeSfxPriority:   dc.b 0
        EVEN
