; Lossless four-plane banks. Repeated quadrants share one chip-RAM image;
; the fifth mask plane is the OR of the four colour planes.
UnpackSpriteAssets:
        lea     SpriteAssetsLZ,a0
        lea     ArcadeFont,a1
        jsr     LZSS_Decompress
        rts

; External enemy art can differ from the embedded sheet. Recompute its mask
; bounds from the actually loaded72 frames; generated object bounds stay valid.
BuildLegacyBobBounds:
        lea     RawBobs+512,a0
        lea     BobBoundsData,a1
        moveq   #BOB_ENEMY_FRAMES-1,d7
.frame:
        moveq   #0,d1
        moveq   #32,d2
        moveq   #-1,d3
        moveq   #0,d4
        moveq   #31,d5
.row:
        move.l  (a0)+,d0
        beq.s   .next_row
        or.l    d0,d1
        cmp.w   d2,d4
        bge.s   .last_row
        move.w  d4,d2
.last_row:
        move.w  d4,d3
.next_row:
        addq.w  #1,d4
        dbf     d5,.row
        tst.l   d1
        beq.s   .empty
        move.b  d2,(a1)+
        sub.w   d2,d3
        addq.w  #1,d3
        move.b  d3,(a1)+
        moveq   #0,d0
        moveq   #1,d6
        move.l  d1,d5
        swap    d5
        tst.w   d5
        bne.s   .high_word
        moveq   #2,d0
        bra.s   .store_words
.high_word:
        tst.w   d1
        beq.s   .store_words
        moveq   #2,d6
.store_words:
        move.b  d0,(a1)+
        move.b  d6,(a1)+
        bra.s   .next_frame
.empty:
        clr.l   (a1)+
.next_frame:
        lea     512(a0),a0
        dbf     d7,.frame
        rts

LoadObjectBobs:
        ifne BUILD_GFX_PROFILE
        rts                              ;native full caches replace reduced banks
        else
        movem.l d0-d7/a0-a4,-(sp)
        lea     ObjectBankDirectory,a4
        moveq   #OBJ_BANK_COUNT-1,d7
.bank:
        movea.l (a4)+,a0
        lea     RawObjectScratch,a1
        move.w  d7,-(sp)              ; decoder uses d7 for unpacked byte length
        jsr     LZSS_Decompress
        move.w  (sp)+,d7
        movea.l (a4)+,a1
        move.l  (a4)+,d6
        subq.w  #1,d6
        lea     RawObjectScratch,a0
.frame:
        movea.l a1,a2
        move.w  #127,d0
.colours:
        move.l  (a0)+,(a1)+
        clr.w   (a1)+
        dbf     d0,.colours
        moveq   #31,d0
.mask:
        move.l  (a2),d1
        or.l    192(a2),d1
        or.l    384(a2),d1
        or.l    576(a2),d1
        move.l  d1,(a1)+
        clr.w   (a1)+
        addq.l  #6,a2
        dbf     d0,.mask
        dbf     d6,.frame
        dbf     d7,.bank
        movem.l (sp)+,d0-d7/a0-a4
        rts

        endif

; d3=original extracted quadrant index; a1=expanded chip image.
; Keep every other register intact for DrawBobs.
RootObjectBobAddress:
        movem.l d0-d2/a0,-(sp)
        moveq   #0,d0
        move.w  d3,d0
        add.w   d0,d0
        lea     ObjectRawIndexMap,a0
        moveq   #0,d1
        move.w  (a0,d0.w),d1
        move.w  d1,d2
        lsr.w   #8,d2
        mulu.w  #12,d2
        lea     ObjectBankDirectory,a0
        movea.l 4(a0,d2.w),a1
        andi.w  #255,d1
        mulu.w  #BOB_FRAME_BYTES,d1
        adda.l  d1,a1
        movem.l (sp)+,d0-d2/a0
        rts
