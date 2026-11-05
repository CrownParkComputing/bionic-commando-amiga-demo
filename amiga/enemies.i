; ============================================================================
; ENEMIES, RIFLE BULLETS, BOB RENDERING & HUD
;   - Native enemy bodies use 16/32/48/64px shapes split into 32px quadrants,
;     blitted with cookie-cut into the hidden frame; plane 4 = mask so every BOB renders in the
;     15-colour sprite palette (COLOR17..31).
;   - BOB art is decoded from the arcade ROM, with three 24-frame enemy banks
;     (12 frames facing left, then 12 facing right per bank). Replace that file
;     (same layout) to swap the artwork without re-assembling.
;   - Erase = redraw the covered map tiles from ActiveTileSheet (no save-under buffers).
; ============================================================================
MAX_ENEMIES     EQU 64
EN_SIZE         EQU 16
EN_X            EQU 0
EN_Y            EQU 2                   ; feet
EN_STATE        EQU 4                   ; 0 = inactive, 1 = alive, 2 = exploding
EN_DIR          EQU 6                   ; 0 = left, 1 = right
EN_TIMER        EQU 8
EN_SHOOT        EQU 10                  ; reload counter
EN_TYPE         EQU 12                  ; 0..2 legacy banks; 3..12 native additional NPC families
EN_HP           EQU 14
MAX_PBUL        EQU 4
MAX_EBUL        EQU 8
BUL_SIZE        EQU 8                   ; x.w, y.w, vx.w, life.w
MAX_BOBS        EQU 128                 ; visible enemy quadrants, props and bullets
BOB_FRAME_BYTES EQU 960                 ; 5 planes x 32 rows x 6 bytes (3 words, last word blank)
BOB_ENEMY_FRAMES EQU 72
BOB_TOTAL_FRAMES EQU BOB_ENEMY_FRAMES
BOB_RAW_BYTES   EQU (BOB_ENEMY_FRAMES*640)
NUM_S1_ENEMIES  EQU 23
ENEMY_RELOAD    EQU 110
EA_SIZE         EQU 16
EA_HOME_X       EQU 0
EA_HOME_Y       EQU 2
EA_VX           EQU 4
EA_VY           EQU 6
EA_XFRAC        EQU 8
EA_YFRAC        EQU 10
EA_KIND         EQU 12                  ; native variant: heavy 0=patrol,3=guard; bird 1=perched
EA_STEP         EQU 14                  ; guard: 0=dormant, positive=alert delay, -1=active
EN_MOVING       EQU $8000               ; EN_TIMER flags; low 4 bits = distance gait phase
EN_FALLING      EQU $4000
BLTCPTH         EQU $048
BLTBPTH         EQU $04C
BLTCMOD         EQU $060
BLTBMOD         EQU $062
POTGOR          EQU $016

; ----------------------------------------------------------------------------
; LoadEnemyBobs: load data/enemy_bobs.bin (dos.library) or fall back to the built-in art,
; then expand rows from 2 to 3 words into chip RAM (BobSheet).
; ----------------------------------------------------------------------------
LoadEnemyBobs:
        movem.l d0-d7/a0-a6,-(sp)
        ifeq BUILD_WHDLOAD
        clr.l   d5
        movea.l 4.w,a6
        lea     DosName(pc),a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)
        move.l  d0,DosBase
        beq.s   .no_dos
        movea.l d0,a6
        lea     EnemyFileName(pc),a0
        move.l  a0,d1
        move.l  #1005,d2                ; MODE_OLDFILE
        jsr     -30(a6)                 ; Open
        move.l  d0,d4
        beq.s   .close_dos
        move.l  d4,d1
        move.l  #RawBobs,d2
        move.l  #BOB_RAW_BYTES,d3
        jsr     -42(a6)                 ; Read
        move.l  d0,d5
        move.l  d4,d1
        jsr     -36(a6)                 ; Close
.close_dos:
        movea.l 4.w,a6
        movea.l DosBase,a1
        jsr     _LVOCloseLibrary(a6)
.no_dos:
        cmpi.l  #BOB_RAW_BYTES,d5
        beq.s   .expand
        endif
        ; Fall back to built-in art
        lea     EnemyBobsDefault,a0
        lea     RawBobs,a1
        move.w  #(BOB_RAW_BYTES/4)-1,d0
.cp:    move.l  (a0)+,(a1)+
        dbf     d0,.cp
.expand:
        jsr     BuildLegacyBobBounds    ; respect an optional external enemy sheet
        lea     RawBobs,a0
        lea     BobSheet,a1
        move.w  #(BOB_ENEMY_FRAMES*5*32)-1,d0
.ex:    move.l  (a0)+,(a1)+
        clr.w   (a1)+
        dbf     d0,.ex
        movem.l (sp)+,d0-d7/a0-a6
        rts

; ----------------------------------------------------------------------------
; InitEnemies: reset enemy / bullet / bob lists (called from LoadStage)
; ----------------------------------------------------------------------------
InitEnemies:
        movem.l d0-d3/a0-a3,-(sp)
        lea     EnemyList,a0
        move.w  #(MAX_ENEMIES*EN_SIZE/4)-1,d0
.c1:    clr.l   (a0)+
        dbf     d0,.c1
        lea     EnemyAux,a0
        move.w  #(MAX_ENEMIES*EA_SIZE/4)-1,d0
.caux:  clr.l   (a0)+
        dbf     d0,.caux
        lea     EnemyBeeExtra,a0
        move.w  #(MAX_ENEMIES*8/4)-1,d0
.cbee:  clr.l   (a0)+
        dbf     d0,.cbee
        lea     PBullets,a0
        moveq   #((MAX_PBUL+MAX_EBUL)*BUL_SIZE/4)-1,d0
.c2:    clr.l   (a0)+
        dbf     d0,.c2
        clr.w   BobCount
        clr.w   DrawnCount
        move.b  #1,HudDirty
        move.w  CurrentStage(pc),d0
        cmpi.w  #5,d0
        bhi.w   .done
        mulu.w  #6,d0
        lea     EnemyStageDirectory(pc),a1
        adda.w  d0,a1
        move.w  (a1)+,d0
        beq.w   .done
        movea.l (a1),a1
        lea     EnemyList,a0
        lea     EnemyAux,a2
        subq.w  #1,d0
.lp:    move.w  (a1)+,EN_X(a0)
        move.w  (a1)+,EN_Y(a0)
        move.w  (a1)+,d1
        move.w  d1,EN_TYPE(a0)
        move.w  EN_X(a0),EA_HOME_X(a2)
        move.w  EN_Y(a0),EA_HOME_Y(a2)
        move.w  (a1)+,EA_KIND(a2)
        move.w  #1,EN_STATE(a0)
        clr.w   EN_DIR(a0)
        cmpi.w  #11,EN_TYPE(a0)
        bne.s   .native_direction_ready
        move.w  #1,EN_DIR(a0)           ; native SMALL0kind0 initialization forcesright
.native_direction_ready:
        tst.w   CurrentStage
        bne.s   .direction_ready
        cmpi.w  #NUM_S1_ENEMIES-1,d0
        bne.s   .direction_ready
        move.w  #1,EN_DIR(a0)           ; adapted first arrival enters from the left
.direction_ready:
        add.w   d1,d1
        lea     EnemyHitPoints(pc),a3
        move.w  (a3,d1.w),EN_HP(a0)
        move.w  d0,d3
        mulu.w  #7,d3
        addi.w  #50,d3
        move.w  d3,EN_SHOOT(a0)
        move.w  d0,EN_TIMER(a0)
        lea     EN_SIZE(a0),a0
        lea     EA_SIZE(a2),a2
        dbf     d0,.lp
.done:
        movem.l (sp)+,d0-d3/a0-a3
        rts

; ----------------------------------------------------------------------------
; KillPlayer: lose a life, reload the stage (parachute drop-in)
; ----------------------------------------------------------------------------
KillPlayer:
        movem.l d0-d7/a0-a6,-(sp)
        tst.b   GameOverMode
        bne.s   .safe
        tst.b   EntryActive
        bne.s   .safe
        tst.b   DeathActive
        bne.s   .safe
        tst.b   AttractMode
        beq.s   .fatal
        cmpi.w  #2080,PlayerY
        ble.s   .safe
        move.w  CurrentStage(pc),d0
        bsr.w   LoadStage
        bra.s   .safe
.fatal:
        jsr     BeginPlayerDeath
.safe:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Called once when the native fatal pose/hold has finished.
FinishPlayerDeath:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     CancelPlayerDeath
        subq.w  #1,Lives
        bsr.w   UpdateHudCoords
        tst.w   Lives
        bgt.s   .respawn
        clr.w   Lives
        bsr.w   ShowGameOver
        bra.s   .done
.respawn:
        move.w  CurrentStage(pc),d0
        bsr.w   LoadStage
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; ----------------------------------------------------------------------------
; UpdateEnemies: per-frame game logic (called after UpdatePlayer)
; ----------------------------------------------------------------------------
UpdateEnemies:
        bsr.w   UpdateEnemyLogic
        bra.w   BuildBobList

UpdateEnemyLogic:
        bsr.w   PollShoot
        bsr.w   UpdatePlayerBullets
        bsr.w   UpdateEnemyAI
        bsr.w   UpdateEnemyBullets
        rts

; --- Rifle button: V, Ctrl, Amiga keys, or joystick button 2 ---
PollShoot:
        tst.b   LP_State
        bne.w   .done
        tst.b   DeathActive
        bne.w   .done
        tst.b   EntryActive
        bne.w   .done
        tst.b   AttractMode
        beq.s   .real_input
        btst    #1,DemoActionPress
        beq.w   .done
        bra.s   .shoot
.real_input:
        lea     KeyState(pc),a0
        moveq   #0,d0
        tst.b   $34(a0)
        beq.s   .k1
        moveq   #1,d0
.k1:    tst.b   $63(a0)
        beq.s   .k2
        moveq   #1,d0
.k2:    tst.b   $66(a0)
        beq.s   .k3
        moveq   #1,d0
.k3:    tst.b   $67(a0)
        beq.s   .k4
        moveq   #1,d0
.k4:    btst    #1,PadButtons            ; A / red is the native rifle button
        beq.s   .k5
        moveq   #1,d0
.k5:    move.b  PrevShootBtn(pc),d1
        move.b  d0,PrevShootBtn
        not.b   d1
        and.b   d0,d1
        beq.s   .done                   ; not a fresh press
.shoot:
        tst.b   FlyMode
        bne.s   .done
        tst.b   GrappleState
        bne.s   .done
        tst.b   ChuteMode
        bne.s   .done
        lea     PBullets,a0
        moveq   #MAX_PBUL-1,d1
.find:  tst.w   6(a0)
        beq.s   .got
        lea     BUL_SIZE(a0),a0
        dbf     d1,.find
        bra.s   .done
.got:   move.w  PlayerX(pc),d0
        tst.w   FacingDir
        beq.s   .left
        addi.w  #14,d0
        moveq   #5,d2                   ; 60Hz arcade 4 px/frame -> 5 px/frame at 50Hz
        bra.s   .set
.left:  subi.w  #14,d0
        moveq   #-5,d2
.set:   move.w  d0,(a0)
        move.w  PlayerY(pc),d0
        subi.w  #18,d0
        ; Native129C4..129CC lowers a crouched muzzle by8px. Keep airborne
        ; Down steering at ordinary rifle height; crouching requires support.
        tst.b   OnGround
        beq.s   .muzzle_ready
        btst    #2,InputDirs
        beq.s   .muzzle_ready
        addq.w  #8,d0
.muzzle_ready:
        move.w  d0,2(a0)
        move.w  d2,4(a0)
        move.w  #24,6(a0)               ; 120 px range
        moveq   #$14,d0
        jsr     PlayNativeSFX
.done:  rts

; --- Player bullets: move, wall test, enemy hit test ---
UpdatePlayerBullets:
        lea     PBullets,a0
        moveq   #MAX_PBUL-1,d7
.lp:    tst.w   6(a0)
        beq.s   .next
        subq.w  #1,6(a0)
        move.w  4(a0),d0
        add.w   d0,(a0)
        move.w  (a0),d0
        move.w  2(a0),d1
        bsr.w   GetTileCol
        tst.w   d0
        bpl.s   .free
        clr.w   6(a0)
        bra.s   .next
.free:  bsr.w   BulletVsEnemies
.next:  lea     BUL_SIZE(a0),a0
        dbf     d7,.lp
        rts

; a0 = player bullet
BulletVsEnemies:
        tst.w   6(a0)
        beq.w   .out
        lea     EnemyList,a1
        moveq   #MAX_ENEMIES-1,d6
.e:     cmpi.w  #1,EN_STATE(a1)
        bne.w   .n
        move.w  (a0),d0
        sub.w   EN_X(a1),d0
        bpl.w   .a1
        neg.w   d0
.a1:    moveq   #14,d2
        cmpi.w  #3,EN_TYPE(a1)
        blt.w   .width_ready
        move.w  EN_TYPE(a1),d2
        subi.w  #3,d2
        mulu.w  #NP_SIZE,d2
        lea     NativeEnemyParams(pc),a2
        move.w  NP_HALF_WIDTH(a2,d2.w),d2
        subq.w  #2,d2
.width_ready:
        cmp.w   d2,d0
        bge.w   .n
        move.w  EN_Y(a1),d1
        sub.w   2(a0),d1
        bmi.w   .n
        moveq   #32,d2
        cmpi.w  #3,EN_TYPE(a1)
        blt.w   .height_ready
        move.w  EN_TYPE(a1),d2
        subi.w  #3,d2
        mulu.w  #NP_SIZE,d2
        lea     NativeEnemyParams(pc),a2
        move.w  NP_HEIGHT(a2,d2.w),d2
.height_ready:
        cmp.w   d2,d1
        bge.w   .n
        clr.w   6(a0)                   ; bullet is spent
        cmpi.w  #10,EN_TYPE(a1)
        bne.w   .damage_target_ready
        bsr.w   NativeBeeDamageHead     ; every follower forwards damage to its head
        cmpi.w  #1,EN_STATE(a1)
        bne.w   .out
.damage_target_ready:
        subq.w  #1,EN_HP(a1)
        bgt.w   .out
        jsr     NotifyLevelEnemyDefeated
        cmpi.w  #10,EN_TYPE(a1)
        bne.w   .child_death
        bsr.w   NativeBeeNotifyDeath
        bra.w   .ordinary_death
.child_death:
        cmpi.w  #12,EN_TYPE(a1)
        bne.w   .ordinary_death
        bsr.w   NativeSmall0NotifyDeath
.ordinary_death:
        move.w  #2,EN_STATE(a1)         ; explode
        move.w  #18,EN_TIMER(a1)
        cmpi.w  #3,EN_TYPE(a1)
        blt.w   .death_timer_ready
        move.l  a3,-(sp)
        bsr.w   NativeGetParams
        movea.l NP_DEATH(a3),a2
        move.l  a2,d0
        beq.w   .death_no_art
        move.w  2(a2),EN_TIMER(a1)
        bra.w   .death_restore
.death_no_art:
        move.w  #1,EN_TIMER(a1)         ; no invented death pose from a different family
.death_restore:
        movem.l (sp)+,a3
.death_timer_ready:
        move.w  EN_TYPE(a1),d0
        add.w   d0,d0
        lea     ScoreTab(pc),a2
        moveq   #0,d1
        move.w  (a2,d0.w),d1
        add.l   d1,Score
        cmpi.l  #599999,Score
        ble.w   .sc_ok
        move.l  #599999,Score
.sc_ok: move.b  #1,HudDirty
        jsr     PlayEnemyDeathSound
        bra.w   .out
.n:     lea     EN_SIZE(a1),a1
        dbf     d6,.e
.out:   rts

; --- Enemy AI ---
UpdateEnemyAI:
        lea     EnemyList,a1
        moveq   #MAX_ENEMIES-1,d7
        move.w  CamX(pc),d6
        addi.w  #160,d6
.lp:    move.w  EN_STATE(a1),d0
        beq.s   .nx
        cmpi.w  #2,d0
        beq.s   .dying
        cmpi.w  #10,EN_TYPE(a1)
        beq.s   .think
        move.w  EN_X(a1),d0
        sub.w   d6,d0
        bpl.s   .r1
        neg.w   d0
.r1:    cmpi.w  #260,d0
        bge.s   .nx
        move.w  CamY(pc),d2
        addi.w  #120,d2
        move.w  EN_Y(a1),d0
        sub.w   d2,d0
        bpl.s   .r2
        neg.w   d0
.r2:    cmpi.w  #190,d0
        bge.s   .nx
.think: bsr.w   EnemyThink
        bra.s   .nx
.dying: subq.w  #1,EN_TIMER(a1)
        bgt.s   .nx
        clr.w   EN_STATE(a1)
.nx:    lea     EN_SIZE(a1),a1
        dbf     d7,.lp
        rts

; a1 = enemy.  Preserves d6/d7/a1.  Auxiliary records have the same stride.
EnemyThink:
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        cmpi.w  #1,EN_TYPE(a1)
        beq.w   PerchedBirdThink
        cmpi.w  #12,EN_TYPE(a1)
        beq.w   NativeSmall0ChildThink
        cmpi.w  #10,EN_TYPE(a1)
        beq.w   NativeBeeThink
        cmpi.w  #9,EN_TYPE(a1)
        bne.s   .ordinary_ground
        cmpi.w  #1,EA_KIND(a2)
        beq.w   NativeMarchThink
.ordinary_ground:
        andi.w  #$000F,EN_TIMER(a1)     ; clear last tick's motion flags

        ; A branch only supports a body close to its actual feet.  Unsupported
        ; infantry enters free fall; it does not march in place at every ledge.
        move.w  EN_X(a1),d0
        move.w  EN_Y(a1),d1
        addq.w  #2,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.s   .fall
        move.w  d0,d2
        sub.w   EN_Y(a1),d2
        cmpi.w  #-12,d2
        blt.s   .fall
        cmpi.w  #6,d2
        bgt.s   .fall
        move.w  d0,EN_Y(a1)
        clr.w   EA_VY(a2)
        clr.w   EA_YFRAC(a2)
        bra.s   .grounded
.fall:
        ori.w   #EN_FALLING,EN_TIMER(a1)
        move.w  EN_Y(a1),d3
        move.w  EA_VY(a2),d0
        add.w   EA_YFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_YFRAC(a2)
        asr.w   #8,d0
        add.w   d0,EN_Y(a1)
        addi.w  #$0045,EA_VY(a2)        ; PAL conversion of native 0.1875px/frame²
        cmpi.w  #$0700,EA_VY(a2)
        ble.s   .fall_speed_ok
        move.w  #$0700,EA_VY(a2)
.fall_speed_ok:
        move.w  EN_X(a1),d0
        move.w  EN_Y(a1),d1
        addq.w  #2,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.s   .fall_bounds
        move.w  d3,d1
        subi.w  #12,d1
        cmp.w   d1,d0
        blt.s   .fall_bounds
        move.w  EN_Y(a1),d1
        addq.w  #2,d1
        cmp.w   d1,d0
        bgt.s   .fall_bounds
        move.w  d0,EN_Y(a1)
        clr.w   EA_VY(a2)
        clr.w   EA_YFRAC(a2)
        andi.w  #$000F,EN_TIMER(a1)
        bra.s   .grounded
.fall_bounds:
        cmpi.w  #2040,EN_Y(a1)
        blt.w   .done
        clr.w   EN_STATE(a1)
        rts

.grounded:
        cmpi.w  #3,EN_TYPE(a1)
        bge.w   NativeGroundThink
        bsr.w   EnemyPlayerDelta
        bsr.w   EnemyContact
        cmpi.w  #2,EN_TYPE(a1)
        bne.s   .guard_ready
        cmpi.w  #3,EA_KIND(a2)
        bne.s   .guard_ready
        tst.w   EA_STEP(a2)
        bmi.s   .guard_ready
        bgt.s   .guard_wait
        ; Native kind03 ($16C5A) waits for an active claw within +/-48px.
        ; It does not continuously shoot diagonally at a player on another floor.
        tst.b   GrappleState
        beq.w   .done
        move.w  ClawX(pc),d0
        sub.w   EN_X(a1),d0
        bpl.s   .guard_abs_x
        neg.w   d0
.guard_abs_x:
        cmpi.w  #48,d0
        bgt.w   .done
        move.w  EN_Y(a1),d1
        subi.w  #16,d1
        move.w  ClawY(pc),d0
        sub.w   d1,d0
        bpl.s   .guard_abs_y
        neg.w   d0
.guard_abs_y:
        cmpi.w  #48,d0
        bgt.w   .done
        move.w  AnimTick(pc),d0
        andi.w  #3,d0
        add.w   d0,d0
        lea     HeavyGuardWaits(pc),a0
        move.w  (a0,d0.w),EA_STEP(a2)
        tst.w   d3
        bmi.s   .guard_face_left
        move.w  #1,EN_DIR(a1)
        bra.w   .done
.guard_face_left:
        clr.w   EN_DIR(a1)
        bra.w   .done
.guard_wait:
        subq.w  #1,EA_STEP(a2)
        bgt.w   .done
        move.w  #-1,EA_STEP(a2)
.guard_ready:
        ; Only a player at the same height changes a patrol's facing/spacing.
        ; The previous X-only proximity check stopped the first infantryman
        ; because Joe was directly below him on the stone floor.
        move.w  d4,d0
        bpl.s   .height_abs
        neg.w   d0
.height_abs:
        cmpi.w  #28,d0
        bgt.s   .patrol
        cmpi.w  #150,d5
        bge.s   .patrol
        tst.w   d3
        bmi.s   .face_left
        move.w  #1,EN_DIR(a1)
        bra.s   .engage
.face_left:
        clr.w   EN_DIR(a1)
.engage:
        cmpi.w  #40,d5
        blt.w   EnemyShoot
        cmpi.w  #18,EN_SHOOT(a1)
        ble.w   EnemyShoot             ; aim only during a real attack window

.patrol:
        cmpi.w  #2,EN_TYPE(a1)
        bne.s   .rifle_speed
        move.w  #$0114,d0              ; native heavy $E6 * 60/50 = 276/256
        bra.s   .speed_ready
.rifle_speed:
        move.w  #$0133,d0              ; native infantry 1px/frame -> ~1.2px/PAL tick
.speed_ready:
        tst.w   EN_DIR(a1)
        bne.s   .signed_speed
        neg.w   d0
.signed_speed:
        add.w   EA_XFRAC(a2),d0
        move.w  d0,d1
        andi.w  #$00FF,d1
        move.w  d1,EA_XFRAC(a2)
        asr.w   #8,d0
        move.w  d0,d3                  ; actual integer step, for gait distance
        beq.s   .walk_intent
        move.w  EN_X(a1),d2
        add.w   d0,d2
        cmpi.w  #16,d2
        blt.s   .turn
        cmpi.w  #2032,d2
        bgt.s   .turn
        move.w  d2,d0
        tst.w   EN_DIR(a1)
        beq.s   .lead_left
        addq.w  #8,d0
        bra.s   .wall_test
.lead_left:
        subq.w  #8,d0
.wall_test:
        move.w  EN_Y(a1),d1
        subi.w  #14,d1
        bsr.w   GetTileCol
        tst.w   d0
        bmi.s   .turn
        move.w  d2,EN_X(a1)
        tst.w   d3
        bpl.s   .gait_distance
        neg.w   d3
.gait_distance:
        add.w   d3,EN_TIMER(a1)
        andi.w  #$000F,EN_TIMER(a1)
.walk_intent:
        ori.w   #EN_MOVING,EN_TIMER(a1)
        bra.w   EnemyShoot
.turn:
        eori.w  #1,EN_DIR(a1)
        clr.w   EA_XFRAC(a2)
        bra.w   EnemyShoot
.done:  rts

; Native $1646A uses 60/120/180/60 frames; these retain elapsed time at PAL.
HeavyGuardWaits:
        dc.w 50,100,150,50

; dx/dy and absolute dx, with no change to the enemy pointer or auxiliary record.
EnemyPlayerDelta:
        move.w  PlayerX(pc),d3
        sub.w   EN_X(a1),d3
        move.w  PlayerY(pc),d4
        sub.w   EN_Y(a1),d4
        move.w  d3,d5
        bpl.s   .done
        neg.w   d5
.done:  rts

EnemyContact:
        tst.b   EntryActive
        bne.s   .done
        tst.b   AttractMode
        bne.s   .done
        cmpi.w  #12,d5
        bge.s   .done
        move.w  d4,d0
        bpl.s   .abs_y
        neg.w   d0
.abs_y: cmpi.w  #20,d0
        bge.s   .done
        bsr.w   KillPlayer
.done:  rts

; The four original kind01 birds are fixed perches, not ground walkers.
; Their one idle shape is $256. Takeoff/flight/death belong to other states.
PerchedBirdThink:
        bsr.w   EnemyPlayerDelta
        bsr.w   EnemyContact
        rts

EnemyShoot:
        subq.w  #1,EN_SHOOT(a1)
        bgt.w   .done
        move.w  #ENEMY_RELOAD,EN_SHOOT(a1)
        bsr.w   EnemyPlayerDelta
        cmpi.w  #150,d5
        bge.w   .done
        move.w  d4,d0
        bpl.s   .abs_y
        neg.w   d0
.abs_y: cmpi.w  #28,d0
        bge.s   .done
        ; Face the actual target before emitting a rifle shot.
        tst.w   d3
        bmi.s   .face_left
        move.w  #1,EN_DIR(a1)
        bra.s   .find_bullet
.face_left:
        clr.w   EN_DIR(a1)
.find_bullet:
        lea     EBullets,a0
        moveq   #MAX_EBUL-1,d1
.fnd:   tst.w   6(a0)
        beq.s   .spawn
        lea     BUL_SIZE(a0),a0
        dbf     d1,.fnd
        bra.s   .done
.spawn: move.w  EN_X(a1),d0
        moveq   #2,d2
        tst.w   EN_DIR(a1)
        bne.s   .sp_r
        subi.w  #14,d0
        moveq   #-2,d2
        bra.s   .sp_set
.sp_r:  addi.w  #14,d0
.sp_set:
        move.w  d0,(a0)
        move.w  EN_Y(a1),d0
        subi.w  #18,d0
        move.w  d0,2(a0)
        move.w  d2,4(a0)
        move.w  #110,6(a0)
        cmpi.w  #2,EN_TYPE(a1)
        bne.s   .done
        moveq   #$19,d0
        jsr     PlayNativeSFX
.done:  rts

; --- Enemy bullets: move, wall test, hit Joe ---
UpdateEnemyBullets:
        lea     EBullets,a0
        moveq   #MAX_EBUL-1,d7
.lp:    tst.w   6(a0)
        beq.s   .next
        subq.w  #1,6(a0)
        move.w  4(a0),d0
        add.w   d0,(a0)
        move.w  (a0),d0
        move.w  2(a0),d1
        bsr.w   GetTileCol
        tst.w   d0
        bpl.s   .free
        clr.w   6(a0)
        bra.s   .next
.free:  tst.b   ChuteMode
        bne.s   .next
        move.w  (a0),d0
        sub.w   PlayerX(pc),d0
        bpl.s   .a1
        neg.w   d0
.a1:    cmpi.w  #10,d0
        bge.s   .next
        move.w  PlayerY(pc),d1
        sub.w   2(a0),d1
        bmi.s   .next
        cmpi.w  #32,d1
        bge.s   .next
        clr.w   6(a0)
        bsr.w   KillPlayer
        rts
.next:  lea     BUL_SIZE(a0),a0
        dbf     d7,.lp
        rts

; --- Build the list of BOBs to draw next frame (x, y top-left, frame) ---
BuildBobList:
        clr.w   BobCount
        lea     EnemyList,a1
        moveq   #MAX_ENEMIES-1,d7
.en:    move.w  EN_STATE(a1),d0
        beq.w   .nx
        cmpi.w  #3,EN_TYPE(a1)
        blt.s   .legacy_art
        bsr.w   BuildNativeEnemyBob
        bra.w   .nx
.legacy_art:
        move.w  EN_X(a1),d4
        subi.w  #16,d4                  ; BOB left
        move.w  EN_Y(a1),d5
        subi.w  #32,d5                  ; retain all 32 rows of the original ROM art
        cmpi.w  #2,d0
        beq.s   .expl
        ; Motion and native kind select animation; a stationary actor must
        ; not cycle through walking, takeoff and flight art just because time passes.
        move.l  a1,d0
        subi.l  #EnemyList,d0
        lea     EnemyAux,a2
        adda.w  d0,a2
        moveq   #4,d3                  ; rifle aim or the bird's one perched pose
        cmpi.w  #1,EN_TYPE(a1)
        beq.s   .frame_ok
        cmpi.w  #2,EN_TYPE(a1)
        bne.s   .ground_pose
        cmpi.w  #3,EA_KIND(a2)
        bne.s   .ordinary_heavy_pose
        tst.w   EA_STEP(a2)
        beq.s   .frame_ok              ; dormant native guard $362
.ordinary_heavy_pose:
        moveq   #6,d3                  ; ordinary heavy rifle-forward $344
.ground_pose:
        btst    #6,EN_TIMER(a1)        ; word bit14: unsupported / falling
        bne.s   .fall_pose
        tst.w   EN_TIMER(a1)           ; word bit15: actually walking
        bpl.s   .frame_ok
        moveq   #0,d3
        move.w  EN_TIMER(a1),d3
        lsr.w   #2,d3                  ; native gait holds one pose for 4 travelled pixels
        andi.w  #3,d3
        bra.s   .frame_ok
.fall_pose:
        moveq   #5,d3
        bra.s   .frame_ok
.expl:  moveq   #18,d3
        sub.w   EN_TIMER(a1),d3
        ext.l   d3
        divu    #6,d3
        cmpi.w  #2,d3
        ble.s   .e_ok
        moveq   #2,d3
.e_ok:  addq.w  #7,d3
.frame_ok:
        tst.w   EN_DIR(a1)
        beq.s   .type_bank
        addi.w  #12,d3
.type_bank:
        move.w  EN_TYPE(a1),d0
        mulu.w  #24,d0
        add.w   d0,d3
.add:   bsr.w   AddBob
.nx:    lea     EN_SIZE(a1),a1
        dbf     d7,.en

        ; player bullets (frame 10) and enemy bullets (frame 11)
        lea     PBullets,a0
        moveq   #MAX_PBUL-1,d7
.pb:    tst.w   6(a0)
        beq.s   .pn
        move.w  (a0),d4
        subi.w  #16,d4
        move.w  2(a0),d5
        subi.w  #16,d5
        moveq   #10,d3
        bsr.w   AddBob
.pn:    lea     BUL_SIZE(a0),a0
        dbf     d7,.pb
        lea     EBullets,a0
        moveq   #MAX_EBUL-1,d7
.eb:    tst.w   6(a0)
        beq.s   .en2
        move.w  (a0),d4
        subi.w  #16,d4
        move.w  2(a0),d5
        subi.w  #16,d5
        moveq   #11,d3
        bsr.w   AddBob
.en2:   lea     BUL_SIZE(a0),a0
        dbf     d7,.eb
        rts

 ; d4 = world x, d5 = world y, d3 = frame. Trashes d0,a2.
; Include partial BOBs in the 32px frame guards at the left/top edges.
AddBob:
        move.w  d3,d0
        lsl.w   #2,d0
        lea     BobBoundsData,a2
        tst.b   1(a2,d0.w)
        beq.s   .full
        move.w  OldTileX(pc),d0
        lsl.w   #4,d0
        neg.w   d0
        add.w   d4,d0
        cmpi.w  #-31,d0
        blt.s   .full
        cmpi.w  #351,d0
        bgt.s   .full
        move.w  OldTileY(pc),d0
        lsl.w   #4,d0
        neg.w   d0
        add.w   d5,d0
        cmpi.w  #-31,d0
        blt.s   .full
        cmpi.w  #239,d0
        bgt.s   .full
        move.w  BobCount,d0
        cmpi.w  #MAX_BOBS,d0
        bge.s   .full
        mulu.w  #6,d0
        lea     BobList,a2
        adda.w  d0,a2
        move.w  d4,(a2)+
        move.w  d5,(a2)+
        move.w  d3,(a2)+
        addq.w  #1,BobCount
.full:  rts

; Compatibility entry for renderer fixtures. The map cache contains no BOBs;
; a hidden frame is repainted before any BOB is drawn.
EraseBobs:
        rts

; ----------------------------------------------------------------------------
; DrawBobs: cookie-cut every BOB into the hidden, flat display frame
; ----------------------------------------------------------------------------
DrawBobs:
        bsr.w   MarkAllBobsDirty        ; compatibility entry for direct renderer callers
DrawDirtyBobs:
        move.l  a6,-(sp)
        clr.w   DrawnCount
        move.w  BobCount,d6
        beq.w   .done
        lea     CUSTOM,a5
        bsr.w   WaitBlitter
        move.w  #$8400,DMACON(a5)       ; blitter priority during masked sprite draws
        lea     BobList,a2
        lea     DrawnList,a3
        lea     BobDrawFlags,a6
        subq.w  #1,d6
.lp:    move.w  (a2)+,d4                ; x
        move.w  (a2)+,d5                ; y
        move.w  (a2)+,d3                ; frame
        move.w  d3,d2
        tst.b   (a6)+
        beq.w   .record                ; unchanged cached BOB remains in this frame

        move.w  OldTileX(pc),d0
        lsl.w   #4,d0
        move.w  d4,d1
        sub.w   d0,d1
        cmpi.w  #-31,d1
        blt.w   .skip
        cmpi.w  #351,d1
        bgt.w   .skip
        addi.w  #32,d1                 ; left guard in the flat hidden frame
        lsr.w   #4,d1
        add.w   d1,d1                  ; destination word offset

        move.w  OldTileY(pc),d0
        lsl.w   #4,d0
        move.w  d5,d2
        sub.w   d0,d2
        cmpi.w  #-31,d2
        blt.w   .skip
        cmpi.w  #239,d2
        bgt.w   .skip
        addi.w  #32,d2                 ; top guard
        mulu.w  #FRAME_ROW_STRIDE,d2
        movea.l FrameDrawPtr(pc),a0
        adda.l  d2,a0
        adda.w  d1,a0

        ; shift bits
        move.w  d4,d0
        andi.w  #15,d0
        ror.w   #4,d0
        move.w  d0,d1
        ori.w   #$0FCA,d1               ; A,B,C,D enabled, D = A*B + ~A*C
        move.w  d3,d2                  ; retain the original frame ID in the history

        ; Object frames follow the 72 enemy frames in the public BOB index.
        cmpi.w  #BOB_ENEMY_FRAMES,d3
        blt.s   .enemy_sheet
        subi.w  #BOB_ENEMY_FRAMES,d3
        bsr.w   RootObjectBobAddress   ; banked chip hunks, preserves all but a1
        bra.s   .mask_ready
.enemy_sheet:
        mulu.w  #BOB_FRAME_BYTES,d3
        lea     BobSheet,a1
        adda.l  d3,a1
.mask_ready:
        move.w  d2,d3
        lsl.w   #2,d3
        lea     BobBoundsData,a4
        adda.w  d3,a4
        moveq   #0,d3
        move.b  (a4),d3                ; first nonempty row
        mulu.w  #6,d3
        adda.w  d3,a1
        moveq   #0,d3
        move.b  2(a4),d3               ; first nonempty source word (bytes)
        adda.w  d3,a1
        adda.w  d3,a0
        moveq   #0,d3
        move.b  (a4),d3
        mulu.w  #FRAME_ROW_STRIDE,d3
        adda.l  d3,a0
        moveq   #0,d3
        move.b  1(a4),d3
        lsl.w   #6,d3                  ; BLTSIZE height
        moveq   #0,d7
        move.b  3(a4),d7               ; one/two nonempty source words
        tst.w   d0
        beq.s   .width_ready
        addq.w  #1,d7                  ; zero word flushes shifted rows
.width_ready:
        or.w    d7,d3
        lea     4*192(a1),a4            ; mask plane

.w0:    btst    #6,DMACONR(a5)
        bne.s   .w0
        move.w  d1,BLTCON0(a5)
        move.w  d0,BLTCON1(a5)
        move.l  #$FFFFFFFF,BLTAFWM(a5)
        add.w   d7,d7
        neg.w   d7
        addq.w  #6,d7
        move.w  d7,BLTAMOD(a5)
        move.w  d7,BLTBMOD(a5)
        addi.w  #(FRAME_ROW_STRIDE-6),d7
        move.w  d7,BLTCMOD(a5)
        move.w  d7,BLTDMOD(a5)
        moveq   #4,d7
.pl:    btst    #6,DMACONR(a5)
        bne.s   .pl
        move.l  a4,BLTAPTH(a5)
        move.l  a1,BLTBPTH(a5)
        move.l  a0,BLTCPTH(a5)
        move.l  a0,BLTDPTH(a5)
        move.w  d3,BLTSIZE(a5)
        lea     FRAME_PLANE_BYTES(a0),a0
        lea     192(a1),a1
        dbf     d7,.pl

.record:
        move.w  d4,(a3)+
        move.w  d5,(a3)+
        move.w  d2,(a3)+
        addq.w  #1,DrawnCount
.skip:  dbf     d6,.lp
        bsr.w   WaitBlitter
.done:  bsr.w   EndBlitterHog
        movea.l (sp)+,a6
        rts

; ----------------------------------------------------------------------------
; HUD: SCORE nnnnnn   LIVES n   (stage title is on the left)
; ----------------------------------------------------------------------------
UpdateHudCoords:
        lea     HudBuffer+17,a1
        lea     ScoreLbl(pc),a0
        bsr.w   DrawHudString
        move.l  Score,d0
        bsr.s   DrawHudDec6
        lea     HudBuffer+31,a1
        lea     LivesLbl(pc),a0
        bsr.w   DrawHudString
        move.w  Lives,d0
        addi.w  #'0',d0
        bsr.w   DrawHudChar
        jsr     RenderLevelBonusHud
        jsr     RenderFPS
        rts

DrawHudDec6:
        moveq   #5,d3
.dv:    divu    #10,d0
        swap    d0
        move.w  d0,-(sp)
        clr.w   d0
        swap    d0
        dbf     d3,.dv
        moveq   #5,d3
.pr:    move.w  (sp)+,d0
        addi.w  #'0',d0
        bsr.w   DrawHudChar
        dbf     d3,.pr
        rts

ScoreLbl:       dc.b "SCORE ",0
LivesLbl:       dc.b "LIVES ",0
DosName:        dc.b "dos.library",0
EnemyFileName:  dc.b "data/enemy_bobs.bin",0
                EVEN
ScoreTab:       dc.w 100,200,300,100,300,300,300,200,400,400,100,200,200
EnemyHitPoints: dc.w 1,2,3,1,3,3,3,2,4,4,5,2,1

        include "native_enemies.i"

        include "enemy_spawns.i"

; --- Variables ---
Score:          dc.l 0
DosBase:        dc.l 0
BobCount:       dc.w 0
DrawnCount:     dc.w 0
HudDirty:       dc.b 1
PrevShootBtn:   dc.b 0
                EVEN
EnemyList:      ds.b (MAX_ENEMIES*EN_SIZE)
EnemyAux:       ds.b (MAX_ENEMIES*EA_SIZE)
EnemyBeeExtra:  ds.b (MAX_ENEMIES*8) ; timer,mode,targetX,targetY for original bee steering
PBullets:       ds.b (MAX_PBUL*BUL_SIZE)
EBullets:       ds.b (MAX_EBUL*BUL_SIZE)
BobList:        ds.b (MAX_BOBS*6)
DrawnList:      ds.b (MAX_BOBS*6)
