; Lossless canonical Huffman PCM. Output remains identical signed8bit audio.
UnpackMusic:
        movem.l d0-d7/a0-a3,-(sp)
        lea     MusicHuffmanTableLZ,a0
        lea     MusicDecodeTable,a1
        jsr     LZSS_Decompress
        lea     MusicPart1Packed,a0
        lea     MusicPart1,a1
        bsr.s   DecodeMusicPCM
        lea     MusicPart2Packed,a0
        lea     MusicPart2,a1
        bsr.s   DecodeMusicPCM
        movem.l (sp)+,d0-d7/a0-a3
        rts

DecodeMusicPCM:
        move.l  (a0)+,d5
        moveq   #0,d0                 ; high-aligned input bits
        moveq   #0,d2                 ; valid bit count
        lea     MusicDecodeTable,a2
.sample:
        cmpi.w  #12,d2
        bge.s   .lookup
        moveq   #0,d3
        move.w  (a0)+,d3
        moveq   #16,d4
        sub.w   d2,d4
        lsl.l   d4,d3
        or.l    d3,d0
        addi.w  #16,d2
.lookup:
        move.l  d0,d3
        swap    d3
        lsr.w   #4,d3
        add.w   d3,d3
        move.w  (a2,d3.w),d1           ; length.b,sample.b
        move.b  d1,(a1)+
        lsr.w   #8,d1
        lsl.l   d1,d0
        sub.w   d1,d2
        subq.l  #1,d5
        bne.s   .sample
        rts
