BUILD_DEMO EQU 1
; Native WHDLoad17 slave for the Bionic Commando arcade conversion.
; Uses the documented WHDLoad ABI directly; no emulated Exec/DOS or KickEmu.
; https://www.whdload.de/docs/autodoc.html (Slave, LoadFile, Relocate, Abort)
        include "whd_generated.i"

CHIP_BASE       EQU $10000
CHIP_REQUEST    EQU $200000
FAST_REQUEST    EQU $400000
STACK_RESERVE   EQU $10000
WHD_FLAGS       EQU $1070              ;ClearMem, NoKbd, ReqAGA, Req68020
RES_ABORT       EQU $04
RES_LOADFILE    EQU $08
RES_SAVEFILE    EQU $0C
RES_FLUSHCACHE  EQU $20
RES_GETFILESIZE EQU $24
RES_CONTROL     EQU $34
RES_RELOCATE    EQU $50
TAG_ATTNFLAGS   EQU $88000000          ;WHDLTAG_ATTNFLAGS_GET, official SDK
TAG_CHIPPTR     EQU $88100000
TAG_ALIGN       EQU $88100002

        section Slave,code
Header:
        moveq   #-1,d0
        rts
        dc.b    "WHDLOADS"
        dc.w    17,WHD_FLAGS
        dc.l    CHIP_REQUEST,0
        dc.w    Loader-Header,DataDir-Header,0
        dc.b    0
QuitKey: dc.b  $59                     ;WHDLoad may replace with QUITKEY option
Expansion: dc.l FAST_REQUEST
        dc.w    GameName-Header,Copyright-Header,Info-Header
        dc.w    0                     ;no Kickstart file dependency
        dc.l    0
        dc.w    0,0
DataDir: dc.b   "data",0
GameName: dc.b  "Bionic Commando Arcade Demo"
        ifne BUILD_GFX_PROFILE
        dc.b " - Full Colour",0
        else
        dc.b " - Reduced Colour",0
        endif
Copyright: dc.b "1987 Capcom",0
Info:   dc.b    "Amiga conversion by WHittyApps",10
        dc.b    "Native AGA / 68020 / 2MB Chip / 8MB Fast",10
        ifne BUILD_GFX_PROFILE
        dc.b    "Full colour / 16x CPU recommended",10
        else
        dc.b    "Reduced colour",10
        endif
        dc.b    "Escape or F10: quit",0
        even
Version: dc.b   "$VER: Bionic Commando WHDLoad 1.0 (05.11.2026)",0
        even

Loader:
        lea     Resident(pc),a1
        move.l  a0,(a1)
        movea.l a0,a2
        lea     CpuTags(pc),a0
        jsr     RES_CONTROL(a2)
        movea.l Expansion(pc),a4
        movea.l a4,a7
        adda.l  #FAST_REQUEST,a7        ;own64KiB Fast stack above the game
        lea     GameFile(pc),a0
        jsr     RES_GETFILESIZE(a2)
        cmpi.l  #GAME_FILE_BYTES,d0
        bne.w   WrongVersion
        lea     GameFile(pc),a0
        movea.l a4,a1
        jsr     RES_LOADFILE(a2)
        cmpi.l  #GAME_FILE_BYTES,d0
        bne.w   WrongVersion
        ; Relocate ordinary hunks over the loaded file in Fast RAM. Route
        ; MEMF_CHIP hunks into the reserved chip window with8-byte alignment.
        clr.l   -(sp)
        move.l  #CHIP_BASE,-(sp)
        move.l  #TAG_CHIPPTR,-(sp)
        move.l  #8,-(sp)
        move.l  #TAG_ALIGN,-(sp)
        movea.l sp,a1
        movea.l a4,a0
        jsr     RES_RELOCATE(a2)
        cmpi.l  #(FAST_REQUEST-STACK_RESERVE),d0
        bhi.w   WrongVersion
        cmpi.l  #(CHIP_REQUEST-CHIP_BASE),12(sp)
        bhi.w   WrongVersion
        lea     20(sp),sp
        jsr     RES_FLUSHCACHE(a2)
        move.l  CpuAttnFlags(pc),d1    ;root distinguishes040/060 from020
        lea     Quit(pc),a0
        lea     Preferences(pc),a1
        moveq   #0,d0
        move.b  QuitKey(pc),d0
        jmp     (a4)

Quit:
        movea.l Resident(pc),a2
        pea     -1                     ;TDREASON_OK
        jmp     RES_ABORT(a2)
; d0=0load/1save, a0=100-byte buffer. Reads accept96legacy/100current and
; return the actual byte count; writes always save100bytes. Calls occur before
; takeover and on clean exit; no disk access occurs in gameplay updates.
Preferences:
        movem.l d1-d7/a0-a6,-(sp)
        movea.l a0,a3
        move.l  d0,d7
        movea.l Resident(pc),a2
        cmpi.l  #2,d7
        beq.w   .music
        tst.l   d7
        bne.s   .save
        lea     PreferencesFile(pc),a0
        jsr     RES_GETFILESIZE(a2)
        move.l  d0,d6
        cmpi.l  #96,d0
        beq.s   .load
        cmpi.l  #100,d0
        bne.s   .missing
.load:
        lea     PreferencesFile(pc),a0
        movea.l a3,a1
        jsr     RES_LOADFILE(a2)
        tst.l   d0
        beq.s   .done
        move.l  d6,d0
        bra.s   .done
.save:  moveq   #100,d0
        lea     PreferencesFile(pc),a0
        movea.l a3,a1
        jsr     RES_SAVEFILE(a2)
        tst.l   d0
        beq.s   .done
        moveq   #100,d0
        bra.s   .done
.missing:
        moveq   #0,d0
.done:  movem.l (sp)+,d1-d7/a0-a6
        rts
.music:
        move.l  d1,d5                  ;capacity passed by game, never overrun
        lea     C64MusicFile(pc),a0
        jsr     RES_GETFILESIZE(a2)
        tst.l   d0
        beq.s   .missing
        cmp.l   d5,d0
        bhi.s   .missing
        move.l  d0,d6
        lea     C64MusicFile(pc),a0
        movea.l a3,a1
        jsr     RES_LOADFILE(a2)
        tst.l   d0
        beq.s   .missing
        move.l  d6,d0
        bra.s   .done
WrongVersion:
        pea     9                      ;TDREASON_WRONGVER
        jmp     RES_ABORT(a2)
GameFile: dc.b  "bionic_game",0
C64MusicFile: dc.b "c64_music.bcm",0
PreferencesFile: dc.b "bionic_demo.scores",0
        even
Resident: dc.l  0
CpuTags:
        dc.l TAG_ATTNFLAGS
CpuAttnFlags: dc.l 0
        dc.l 0                         ;TAG_DONE
