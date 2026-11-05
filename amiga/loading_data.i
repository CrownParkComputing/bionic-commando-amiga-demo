        SECTION LoadingCopperData,DATA_C
LoadingCopper:
        dc.w DIWSTRT,$2C81,DIWSTOP,$1CC1
        dc.w DDFSTRT,$0038,DDFSTOP,$00D0
        dc.w $01FC,0,BPLCON0,$0200,BPLCON1,0,BPLCON2,0,BPLCON3,$0020
        dc.w BPL1MOD,0,BPL2MOD,0,COLOR00,$0113,COLOR00+2,$0DDD
LoadingBplPtr:
        dc.w $00E0,0,$00E2,0
        dc.w $8C07,$FFFE,BPLCON0,$1200 ;centre the sixteen loading rows
        dc.w $9C07,$FFFE,BPLCON0,$0200
        dc.w $FFDF,$FFFE,$1C07,$FFFE,INTREQ,$8010
        dc.w $FFFF,$FFFE
        SECTION LoadingPixels,BSS_C
LoadingBuffer: ds.b 640
