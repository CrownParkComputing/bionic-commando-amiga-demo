; Asset-only lossless startup decoders. Main owns all runtime playback.
; Include attract_motion_defs.i before this file.
;
; ExpandAttractMotion: a0=LZSS-decoded sparse stream,a1=31200B destination.
; Each frame has an unaligned BE11-bit field-change mask. Changed coordinate
; fields0..5 are signed8 deltas ($80 escapes to signed16); pose/angle/dir/radius
; are absolute bytes, flags an unaligned BE word. Missing fields retain state.
; All registers are preserved. No game state, waits or hardware accesses.
ExpandAttractMotion:
        movem.l d0-d7/a0-a4,-(sp)
        lea     AttractMotionWorkingState(pc),a2
        movea.l a2,a3
        moveq   #4,d5
.clear: clr.l   (a3)+
        dbf     d5,.clear
        move.w  #DEMO_MOTION_FRAMES-1,d7
.frame:
        bsr.w   AttractReadPackedWord
        move.w  d0,d6
        movea.l a2,a3
        moveq   #5,d5
.coordinate:
        btst    #0,d6
        beq.s   .coordinate_next
        moveq   #0,d0
        move.b  (a0)+,d0
        cmpi.b  #$80,d0
        bne.s   .small_delta
        bsr.w   AttractReadPackedWord
        bra.s   .add_delta
.small_delta:
        ext.w   d0
.add_delta:
        add.w   d0,(a3)
.coordinate_next:
        addq.l  #2,a3
        lsr.w   #1,d6
        dbf     d5,.coordinate
        btst    #0,d6                  ; dense pose index at12
        beq.s   .pose_next
        moveq   #0,d0
        move.b  (a0)+,d0
        move.w  d0,(a3)
.pose_next:
        addq.l  #2,a3
        lsr.w   #1,d6
        btst    #0,d6                  ; flags at14
        beq.s   .flags_next
        bsr.w   AttractReadPackedWord
        move.w  d0,(a3)
.flags_next:
        addq.l  #2,a3
        lsr.w   #1,d6
        btst    #0,d6                  ; angle byte at16
        beq.s   .angle_next
        move.b  (a0)+,(a3)
.angle_next:
        addq.l  #1,a3
        lsr.w   #1,d6
        btst    #0,d6                  ; signed direction byte at17
        beq.s   .direction_next
        move.b  (a0)+,(a3)
.direction_next:
        addq.l  #1,a3
        lsr.w   #1,d6
        btst    #0,d6                  ; byte-expanded radius word at18
        beq.s   .copy_state
        moveq   #0,d0
        move.b  (a0)+,d0
        move.w  d0,(a3)
.copy_state:
        movea.l a2,a3
        moveq   #4,d5
.copy:  move.l  (a3)+,(a1)+
        dbf     d5,.copy
        dbf     d7,.frame
        movem.l (sp)+,d0-d7/a0-a4
        rts

AttractReadPackedWord:
        moveq   #0,d0
        move.b  (a0)+,d0
        lsl.w   #8,d0
        move.b  (a0)+,d0
        rts

; a0=LZSS-decoded8704B in4byte lanes,a1=8704B native channel destination.
; This is a byte permutation only: no image approximation or palette changes.
DeinterleaveAttractPoses:
        movem.l d0-d2/a0-a3,-(sp)
        movea.l a1,a2
        moveq   #3,d2
.lane:
        movea.l a2,a3
        move.w  #DEMO_EXTRA_LANE_BYTES-1,d1
.byte:
        move.b  (a0)+,(a3)
        addq.l  #4,a3
        dbf     d1,.byte
        addq.l  #1,a2
        dbf     d2,.lane
        movem.l (sp)+,d0-d2/a0-a3
        rts

AttractMotionWorkingState:
        ds.b    20
        EVEN
