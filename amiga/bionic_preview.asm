BUILD_DEMO EQU 1
; ============================================================================
; BIONIC COMMANDO (1987 CAPCOM ARCADE) - AMIGA 68000 PLAYABLE SWING & MAP ENGINE
; ============================================================================
; Features:
;   - Playable Super Joe (32x32, 15-color attached Hardware Sprites SPR0..SPR3)
;   - Bionic Arm Grappling & Pendulum Swinging (Hardware Sprites SPR4..SPR5):
;       * Grapple (Space / Z / Shift / Pad B): Shoot Bionic Arm 45 deg up-forward
;       * Up + Fire: Shoot Bionic Arm 90 deg straight up & climb onto branch
;       * Left / Right while swinging: Pump pendulum swing arc (-60..+60 deg)
;       * Up / Down while swinging: Reel in (climb onto branch) / lengthen cable
;       * Jump (X / C / Alt) or Fire while swinging: Vault & launch into mid-air
;       * Jump on ground (X / C / Alt / Up): Jump across gaps & grapple in mid-air
;       * Down + Jump on branch: Drop down through one-way tree branch
;   - 'F' Key Toggle: Switch between Playable Physics & 8-Way Free-Fly Mode
;   - Pad A: rifle; Pad B: grapple; Pad X: jump; Start / Return: begin game
;   - Stage-switch debug shortcuts are disabled during gameplay
;   - Clean torus map cache and double-buffered, complete display frames
; ============================================================================

        ifnd BUILD_WHDLOAD
BUILD_WHDLOAD   EQU 0
        endif
        ifnd BUILD_GFX_PROFILE
BUILD_GFX_PROFILE EQU 0             ;0 reduced,1 full; separate graphics builds
        endif
GAME_STAGE_COUNT EQU 1
        include "c64_music_defs.i"

        SECTION Code,CODE

; --- Amiga Custom Chip Registers ($DFF000) ---
CUSTOM          EQU $DFF000
DMACONR         EQU $002
VPOSR           EQU $004
VHPOSR          EQU $006
POTGO           EQU $034
JOY0DAT         EQU $00A
JOY1DAT         EQU $00C
INTREQR         EQU $01E
INTENAR         EQU $01C
COP1LCH         EQU $080
COP2LCH         EQU $084
COP2LCL         EQU $086
COPJMP2         EQU $08A
COPJMP1         EQU $088
DIWSTRT         EQU $08E
DIWSTOP         EQU $090
DDFSTRT         EQU $092
DDFSTOP         EQU $094
DMACON          EQU $096
INTENA          EQU $09A
INTREQ          EQU $09C
BPLCON0         EQU $100
BPLCON1         EQU $102
BPLCON2         EQU $104
BPLCON3         EQU $106
BPL1MOD         EQU $108
BPL2MOD         EQU $10A
COLOR00         EQU $180

; --- Paula 4-Channel Audio Registers ---
AUD0LCH         EQU $0A0
AUD0LEN         EQU $0A4
AUD0PER         EQU $0A6
AUD0VOL         EQU $0A8
AUD1LCH         EQU $0B0
AUD1LEN         EQU $0B4
AUD1PER         EQU $0B6
AUD1VOL         EQU $0B8
AUD2LCH         EQU $0C0
AUD2LEN         EQU $0C4
AUD2PER         EQU $0C6
AUD2VOL         EQU $0C8
AUD3LCH         EQU $0D0
AUD3LEN         EQU $0D4
AUD3PER         EQU $0D6
AUD3VOL         EQU $0D8

; --- Blitter Registers ---
BLTCON0         EQU $040
BLTCON1         EQU $042
BLTAFWM         EQU $044
BLTALWM         EQU $046
BLTAPTH         EQU $050
BLTDPTH         EQU $054
BLTSIZE         EQU $058
BLTAMOD         EQU $064
BLTDMOD         EQU $066

; --- CIA Registers ---
CIAAPRA         EQU $BFE001
CIAADDRA        EQU $BFE201
CIAASDR         EQU $BFEC01
CIAACRA         EQU $BFEE01
CIAAICR         EQU $BFED01

; --- Exec / Graphics LVO Offsets ---
_LVOOpenLibrary         EQU -552
_LVOCloseLibrary        EQU -414
_LVOOwnBlitter          EQU -456
_LVODisownBlitter       EQU -462
_LVOWaitBlit            EQU -228
_LVOLoadView            EQU -222
_LVOWaitTOF             EQU -270
gb_ActiView             EQU 34
gb_copinit              EQU 38

; --- Torus Scroll Buffer Constants ---
; 64 words (128 bytes = 1024px) per plane row -> 32+22=54 words (108 bytes) used
ROW_PLANE_BYTES EQU 108
NUM_PLANES      EQU 5
ROW_STRIDE      EQU (ROW_PLANE_BYTES*NUM_PLANES) ; 540 bytes per interleaved scanline
TILE_ROW_BYTES  EQU (16*ROW_STRIDE)              ; 8640 bytes per 16-pixel tile row
TOTAL_BUF_LINES EQU 480                          ; 16 + 14 tile rows = 480 scanlines (259,200 bytes)
MAP_MAX_X       EQU (2048-320)                   ; 1728
MAP_MAX_Y       EQU (2048-240)                   ; 1808
CHUTE_DROP      EQU 210                          ; native entry: feet 1792 -> floor 2002

; Complete display images, with 32px guards for partially visible BOBs.
; The map cache stays clean; its visible area is copied into the hidden frame.
FRAME_PLANE_BYTES EQU 52                         ; 416px including both guards
FRAME_ROW_STRIDE EQU (FRAME_PLANE_BYTES*NUM_PLANES)
FRAME_LINES     EQU 304
FRAME_BYTES     EQU (FRAME_LINES*FRAME_ROW_STRIDE)
FRAME_ORIGIN    EQU (32*FRAME_ROW_STRIDE+4)        ; map tile origin inside guards

; ============================================================================
; ENTRY POINT & SYSTEM TAKEOVER
; ============================================================================
Start:
        ifne BUILD_WHDLOAD
        move.l  a0,WHDQuitCallback      ;native slave supplies quit entry/key
        move.l  a1,WHDPreferencesCallback
        move.b  d0,WHDQuitKey
        endif
        movem.l d0-d7/a0-a6,-(sp)

        jsr     DetectMachineProfile
        jsr     LoadPreferences
        jsr     LoadC64Music
        jsr     ApplyMachineDefaults
        jsr     InitPaletteCopperLinks
        jsr     UnpackSpriteAssets
        bsr.w   LoadEnemyBobs           ; enemy art from data/enemy_bobs.bin (or built-in)
        ifeq BUILD_GFX_PROFILE
        jsr     LoadObjectBobs
        endif
        jsr     UnpackMusic
        jsr     UnpackExtendedAssets
        jsr     UnpackArcadeDemo
        jsr     UnpackParallaxAssets
        jsr     UnpackAmigaMusicAssets
        ifne BUILD_GFX_PROFILE
        jsr     InitFullColourAssets
        jsr     BuildFullColourBackground ;immutable landscape, before title/music start
        move.b  #1,FullBackgroundReady
        endif

        ifeq BUILD_WHDLOAD
        movea.l 4.w,a6
        lea     GfxName(pc),a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)
        move.l  d0,GfxBase
        beq.w   ExitToDOS

        movea.l d0,a6
        move.l  gb_ActiView(a6),OldView
        sub.l   a1,a1
        jsr     _LVOLoadView(a6)
        jsr     _LVOWaitTOF(a6)
        jsr     _LVOWaitTOF(a6)
        jsr     _LVOOwnBlitter(a6)
        jsr     _LVOWaitBlit(a6)
        endif

        lea     CUSTOM,a5
        move.w  INTENAR(a5),d0          ;read saved interrupt enables, not write-only INTENA
        ori.w   #$8000,d0
        move.w  d0,OldIntena
        move.w  DMACONR(a5),d0
        ori.w   #$8000,d0
        move.w  d0,OldDmacon

        ; Disable interrupts during hardware setup, enable Master + Blitter DMA
        move.w  #$7FFF,INTENA(a5)
        move.w  #$7FFF,INTREQ(a5)
        move.w  #$7FFF,DMACON(a5)
        move.w  #$8640,DMACON(a5)       ; DMAF_SETCLR | DMAF_MASTER | DMAF_BLITTER | DMAF_BLITHOG

        ; Initialize Hardware Sprite pointers in CopperList
        bsr.w   InitSpritePtrs

        ; Original arcade title, followed by an unattended Stage 1 demonstration.
        bsr.w   InitAttract

        ; Initialize Paula 4-Channel Arcade Music & SFX Engine
        jsr     InitAudio

        ; Install CopperList and enable Bitplane + Copper + Blitter + Sprite + Audio DMA!
        lea     CUSTOM,a5
        move.l  #CopperList,COP1LCH(a5)
        move.w  #0,COPJMP1(a5)
        move.w  #$83EF,DMACON(a5)       ; SETCLR | MASTER | RASTER | COPPER | BLITTER | SPRITE | AUD0..3

; ============================================================================
; MAIN 50HZ GAME & SCROLLER LOOP
; ============================================================================
MainLoop:
        ; Gameplay waits when its completed frame is presented. Title/game-over
        ; have no composition pass, so pace those screens here instead.
        tst.b   UiPage
        bne.s   .wait_screen
        tst.b   GameOverMode
        bne.s   .wait_screen
        tst.b   AttractMode
        beq.s   .poll
        cmpi.b  #2,AttractPhase
        beq.s   .poll
.wait_screen:
        bsr.w   WaitVBL
.poll:
        bsr.w   PollKeyboard
        bsr.w   ReadPad
        ifne BUILD_WHDLOAD
        lea     KeyState,a0
        moveq   #0,d0
        move.b  WHDQuitKey(pc),d0
        tst.b   (a0,d0.w)
        bne.w   ShutDown
        endif
        tst.b   UiPage
        beq.s   .no_front_page
        jsr     UpdateFrontPage
        bsr.w   UpdateAudio
        bra.w   MainLoop
.no_front_page:
        lea     KeyState(pc),a0
        tst.b   $45(a0)                 ; ESC works during the intro as well as play
        bne.w   ShutDown
        jsr     TryOpenFrontPage
        tst.b   UiPage
        bne.w   MainLoop

        tst.b   GameOverMode
        bne.w   GameOverLoop

        tst.b   AttractMode
        beq.s   .render_game
        cmpi.b  #2,AttractPhase
        beq.s   .render_game            ; demo time advances with game logic below
        bsr.w   UpdateAttract
        tst.b   AttractMode
        beq.s   .render_game
        cmpi.b  #2,AttractPhase
        bne.w   MainLoop                ; title artwork has its own fixed pointers
.render_game:
        ; Run physics before composing the matching camera, BOBs and sprites.
        tst.b   AttractMode
        bne.w   .update_game            ; demo inputs are supplied inside UpdatePlayer
        lea     KeyState(pc),a0

        ; Stage switching is disabled during play.  Shoulder buttons and
        ; Return/Start must never replace the active stage with a debug map.

        ; Check 'F' ($23) toggle for Free-Fly / 8-Way Map Inspect Mode
        move.b  $23(a0),d0
        move.b  PrevFlyKey(pc),d1
        move.b  d0,PrevFlyKey
        tst.b   d0
        beq.s   .no_ftoggle
        tst.b   d1
        bne.s   .no_ftoggle
        tst.b   LP_State
        bne.s   .no_ftoggle
        tst.b   DeathActive
        bne.s   .no_ftoggle
        not.b   FlyMode
        clr.b   GrappleState
        clr.w   PlayerVY
.no_ftoggle:

.update_game:
        bsr.w   CountGameLogicSteps
.logic_step:
        tst.b   LP_State
        beq.s   .active_level
        jsr     UpdateLevelProgress
        jsr     HandleLevelFlow
        bsr.w   UpdateAudio
        bra.w   .logic_done
.active_level:
        jsr     UpdateLevelBonusClock
        tst.w   d0
        beq.s   .clock_ready
        bsr.w   KillPlayer
.clock_ready:
        tst.b   AttractMode
        beq.s   .player_step
        bsr.w   UpdateAttract
        tst.b   AttractMode
        beq.s   .player_step
        cmpi.b  #2,AttractPhase
        bne.w   MainLoop
.player_step:
        ; Keep the PAL simulation clock independent of a slower display frame.
        tst.b   DeathActive
        beq.s   .alive_player
        addq.w  #1,AnimTick
        jsr     UpdatePlayerDeath
        tst.w   d0
        beq.s   .enemy_step
        jsr     FinishPlayerDeath
        bra.s   .enemy_step
.alive_player:
        tst.b   AttractMode
        beq.s   .controlled_player
        tst.b   DemoPlaybackActive
        beq.s   .controlled_player
        jsr     UpdateArcadeDemoActor
        bra.s   .enemy_step
.controlled_player:
        bsr.w   UpdatePlayer
.enemy_step:
        bsr.w   UpdateEnemyLogic        ; build the visible BOB list once, after streaming
        jsr     UpdateObjects
        tst.b   AttractMode
        beq.s   .follow_camera
        tst.b   DemoPlaybackActive
        bne.s   .camera_ready
.follow_camera:
        bsr.w   UpdateCamera
        jsr     ClampLevelCamera
.camera_ready:
        tst.b   DeathActive
        bne.s   .no_progress
        jsr     UpdateLevelProgress
        jsr     HandleLevelFlow
.no_progress:
        bsr.w   UpdateAudio
.logic_done:
        tst.b   GameOverMode
        bne.s   .present_frame
        subq.w  #1,LogicSteps
        bgt.w   .logic_step
.present_frame:
        jsr     ComposeGameFrame        ; publish only after every blit has completed
        jsr     CountPresentedFrame

        ; The completed frame has just been latched in the bottom border.
        tst.b   AttractMode
        beq.s   .game_hud
        jsr     RenderFPS
        bra.w   MainLoop
.game_hud:
        tst.b   HudDirty
        beq.w   MainLoop
        clr.b   HudDirty
        bsr.w   UpdateHudCoords
        bra.w   MainLoop

GameOverLoop:
        bsr.w   UpdateGameOver
        bra.w   MainLoop

; ============================================================================
; UPDATE PLAYER & BIONIC ARM SWINGING PHYSICS
; ============================================================================
UpdatePlayer:
        addq.w  #1,AnimTick
        tst.b   EntryActive
        beq.s   .read_player_input
        bsr.w   UpdateEntry
        rts
.read_player_input:
        lea     KeyState(pc),a0
        move.w  CUSTOM+JOY1DAT,d7

        ; Decode directional inputs into bitflags:
        ;   d6: bit 0 = Right, bit 1 = Left, bit 2 = Down, bit 3 = Up
        moveq   #0,d6

        ; Right: JOY1DAT bit 1, Right Arrow ($4E), or 'D' ($22)
        btst    #1,d7
        bne.s   .in_r
        tst.b   $4E(a0)
        bne.s   .in_r
        tst.b   $22(a0)
        beq.s   .chk_in_l
.in_r:  bset    #0,d6

.chk_in_l:
        ; Left: JOY1DAT bit 9, Left Arrow ($4F), or 'A' ($20)
        btst    #9,d7
        bne.s   .in_l
        tst.b   $4F(a0)
        bne.s   .in_l
        tst.b   $20(a0)
        beq.s   .chk_in_d
.in_l:  bset    #1,d6

.chk_in_d:
        ; Down: (bit 1 ^ bit 0) of JOY1DAT, Down Arrow ($4D), or 'S' ($21)
        move.w  d7,d0
        lsr.w   #1,d0
        eor.w   d7,d0
        btst    #0,d0
        bne.s   .in_d
        tst.b   $4D(a0)
        bne.s   .in_d
        tst.b   $21(a0)
        beq.s   .chk_in_u
.in_d:  bset    #2,d6

.chk_in_u:
        ; Up: (bit 9 ^ bit 8) of JOY1DAT, Up Arrow ($4C), or 'W' ($11)
        move.w  d7,d0
        lsr.w   #1,d0
        eor.w   d7,d0
        btst    #8,d0
        bne.s   .in_u
        tst.b   $4C(a0)
        bne.s   .in_u
        tst.b   $11(a0)
        beq.s   .chk_buttons
.in_u:  bset    #3,d6

.chk_buttons:
        tst.b   AttractMode
        beq.s   .real_dirs
        bsr.w   DemoDirections
.real_dirs:
        move.b  d6,InputDirs

        ; Decode Fire / Grapple button:
        ;   B / blue button, Space ($40), 'Z' ($31), Left Shift ($60)
        moveq   #0,d5
        btst    #0,PadButtons
        bne.s   .fire_on
        tst.b   $40(a0)
        bne.s   .fire_on
        tst.b   $31(a0)
        bne.s   .fire_on
        tst.b   $60(a0)
        beq.s   .fire_done
.fire_on:
        moveq   #1,d5
.fire_done:
        tst.b   AttractMode
        beq.s   .real_fire
        bsr.w   DemoFire
.real_fire:
        move.b  PrevFireBtn(pc),d0
        move.b  d5,PrevFireBtn
        not.b   d0
        and.b   d5,d0
        move.b  d0,FireJustPressed
        tst.b   AttractMode
        beq.s   .real_arm_edge
        move.b  DemoActionPress,d0
        andi.b  #1,d0
        move.b  d0,FireJustPressed
.real_arm_edge:

        ; Decode Jump button:
        ;   Pad X / CD32 green, 'X' ($32), 'C' ($33), Left/Right Alt ($64/$65)
        moveq   #0,d4
        btst    #3,PadButtons
        bne.s   .jmp_on
        tst.b   $32(a0)
        bne.s   .jmp_on
        tst.b   $33(a0)
        bne.s   .jmp_on
        tst.b   $64(a0)
        bne.s   .jmp_on
        tst.b   $65(a0)
        beq.s   .jmp_done
.jmp_on:
        moveq   #1,d4
.jmp_done:
        tst.b   AttractMode
        beq.s   .real_jump
        moveq   #0,d4
.real_jump:
        move.b  PrevJumpBtn(pc),d0
        move.b  d4,PrevJumpBtn
        not.b   d0
        and.b   d4,d0
        move.b  d0,JumpJustPressed

        ; --------------------------------------------------------------------
        ; Check Free-Fly Mode ('F' toggle)
        ; --------------------------------------------------------------------
        tst.b   FlyMode
        beq.s   .normal_physics
        moveq   #6,d0
        tst.b   d5                      ; Hold Fire/Shift for 10 px/frame turbo fly
        beq.s   .fly_spd
        moveq   #10,d0
.fly_spd:
        btst    #0,d6
        beq.s   .fly_l
        move.w  #1,FacingDir
        add.w   d0,PlayerX
.fly_l:
        btst    #1,d6
        beq.s   .fly_d
        clr.w   FacingDir
        sub.w   d0,PlayerX
.fly_d:
        btst    #2,d6
        beq.s   .fly_u
        add.w   d0,PlayerY
.fly_u:
        btst    #3,d6
        beq.s   .fly_clamp
        sub.w   d0,PlayerY
.fly_clamp:
        move.b  #1,OnGround
        bra.w   ClampPlayerWorld

        ; --------------------------------------------------------------------
        ; Normal Playable Super Joe & Bionic Arm State Machine
        ; --------------------------------------------------------------------
.normal_physics:
        tst.b   DropTimer
        beq.s   .no_dt
        subq.b  #1,DropTimer
.no_dt:
        tst.b   LatchAnimTimer
        beq.s   .no_lt
        subq.b  #1,LatchAnimTimer
.no_lt:
        tst.b   VaultFlipTimer
        beq.s   .no_vt
        subq.b  #1,VaultFlipTimer
.no_vt:
        tst.b   GrappleState
        beq.s   .no_at
        clr.b   ChuteMode               ; Firing the arm cuts the parachute
        addq.w  #1,ArmAnimTick
.no_at:

        ; Dispatch on GrappleState:
        ;   0 = Idle/Retracted
        ;   1 = Extending Claw
        ;   2 = Retracting Claw
        ;   3 = Pendulum Swinging on Branch!
        ;   4 = Vertical Climb / Reel-In onto Branch!
        moveq   #0,d0
        move.b  GrappleState(pc),d0
        cmpi.w  #3,d0
        beq.w   .state_swinging
        cmpi.w  #4,d0
        beq.w   .state_climbing

        ; --------------------------------------------------------------------
        ; Check if player just pressed Fire to launch the Bionic Arm!
        ; --------------------------------------------------------------------
        tst.b   FireJustPressed
        beq.s   .upd_active_claw

        ; Update facing direction if Left or Right is held at the moment of firing
        btst    #0,d6
        beq.s   .chk_fire_face_l
        move.w  #1,FacingDir
        bra.s   .fire_face_done
.chk_fire_face_l:
        btst    #1,d6
        beq.s   .fire_face_done
        clr.w   FacingDir
.fire_face_done:

        clr.w   ArmAnimTick
        clr.b   VaultFlipTimer
        move.w  #12,GrappleDist
        move.b  #1,GrappleState
        moveq   #$13,d0
        jsr     PlayNativeSFX

        ; Shoot straight up (90 deg) ONLY if holding UP without Left or Right!
        move.b  d6,d0
        andi.b  #$0B,d0                 ; Up (bit 3) + Left/Right (bits 0..1)
        cmpi.b  #$08,d0                 ; Pure Up?
        bne.s   .fire_diag
        clr.w   GrappleDir
        bsr.w   SyncClawToDist
        bra.s   .upd_active_claw

.fire_diag:
        ; Shoot 45 degrees diagonally up-forward!
        tst.w   FacingDir
        beq.s   .fire_diag_left
        move.w  #1,GrappleDir
        bsr.w   SyncClawToDist
        bra.s   .upd_active_claw
.fire_diag_left:
        move.w  #-1,GrappleDir
        bsr.w   SyncClawToDist

.upd_active_claw:
        ; Update Extending (1) or Retracting (2) Bionic Claw
        cmpi.b  #1,GrappleState
        beq.s   .do_extend
        cmpi.b  #2,GrappleState
        bne.w   .ground_air_move

        ; State 2: Retracting Claw smoothly along the cable back to Joe's hand
        subq.w  #8,GrappleDist
        cmpi.w  #10,GrappleDist
        bgt.s   .retract_step
        clr.b   GrappleState
        bra.w   .ground_air_move
.retract_step:
        bsr.w   SyncClawToDist
        bra.w   .ground_air_move

.do_extend:
        ; Advance Claw in 2 half-steps per frame so we never skip thin branches!
        moveq   #1,d3
.ext_substep:
        addq.w  #4,GrappleDist
        bsr.w   SyncClawToDist

        ; Check if Claw hit a grappleable branch / platform!
        move.w  ClawX(pc),d0
        move.w  ClawY(pc),d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.w   .chk_claw_wall

        ; Make sure the branch is above Super Joe's feet!
        move.w  PlayerY(pc),d1
        subi.w  #12,d1
        cmp.w   d1,d0
        bge.w   .chk_claw_wall

        ; *** LATCHED ONTO BRANCH! ***
        move.w  ClawX(pc),AnchorX
        move.w  d0,AnchorSurfaceY
        addi.w  #4,d0
        move.w  d0,AnchorY
        move.w  d0,ClawY
        clr.b   OnGround
        clr.b   VaultFlipTimer
        move.b  #6,LatchAnimTimer       ; 6-frame arcade jaw-closing snap ($154A8)
        clr.w   PlayerVX
        clr.w   PlayerVY
        moveq   #$12,d0
        jsr     PlayNativeSFX

        ; Did we fire straight up (GrappleDir == 0) or diagonally (GrappleDir != 0)?
        tst.w   GrappleDir
        bne.s   .enter_swing
        move.b  #4,GrappleState         ; State 4: Vertical Reel-In / Climb!
        rts

.enter_swing:
        move.b  #3,GrappleState         ; State 3: Pendulum Swing!
        ; Compute initial rope radius R from vertical distance ((PlayerY - 16) - AnchorY)
        move.w  PlayerY(pc),d0
        subi.w  #16,d0
        sub.w   AnchorY(pc),d0
        ; Multiply by ~1.375 for 45-degree diagonal distance to Joe's center
        move.w  d0,d1
        asr.w   #2,d1
        add.w   d1,d0
        asr.w   #1,d1
        add.w   d1,d0
        cmpi.w  #36,d0
        bge.s   .r_min_ok
        moveq   #36,d0
.r_min_ok:
        cmpi.w  #96,d0
        ble.s   .r_max_ok
        moveq   #96,d0
.r_max_ok:
        move.w  d0,SwingRadius

        ; Set initial pendulum angle & angular velocity based on GrappleDir
        tst.w   GrappleDir
        bmi.s   .init_swing_left
        ; Fired up-right: Joe starts at -42 deg (Arcade Angle 5, down-left of anchor) swinging right!
        move.w  #(-42*256),SwingAngle
        move.w  #$0130,SwingOmega
        move.w  #1,FacingDir
        bra.w   .apply_pendulum_pos

.init_swing_left:
        ; Fired up-left: Joe starts at +42 deg (Arcade Angle 13, down-right of anchor) swinging left!
        move.w  #(42*256),SwingAngle
        move.w  #-$0130,SwingOmega
        clr.w   FacingDir
        bra.w   .apply_pendulum_pos

.chk_claw_wall:
        ; Check if claw hit solid wall/ceiling or reached max length (92 px)
        move.w  ClawX(pc),d0
        move.w  ClawY(pc),d1
        bsr.w   GetTileCol
        andi.w  #$C000,d0               ; Wall ($8000) or Ceiling ($4000)
        bne.s   .start_retract
        cmpi.w  #92,GrappleDist
        bge.s   .start_retract
        dbf     d3,.ext_substep
        bra.s   .ground_air_move

.start_retract:
        move.b  #2,GrappleState

        ; --------------------------------------------------------------------
        ; Ground Walking, Jumping, and Mid-Air Falling Physics
        ; --------------------------------------------------------------------
.ground_air_move:
        move.b  InputDirs(pc),d6

        ; Horizontal movement (Left / Right)
        tst.b   OnGround
        beq.s   .air_horiz

        ; On ground: if crouching (Down held), don't walk horizontally
        btst    #2,d6
        bne.w   .horiz_done

        moveq   #0,d0
        btst    #0,d6                   ; Right
        beq.s   .chk_gl
        move.w  #1,FacingDir
        bsr.w   GroundWalkStep
        bra.s   .try_move_x
.chk_gl:
        btst    #1,d6                   ; Left
        beq.w   .horiz_done
        clr.w   FacingDir
        bsr.w   GroundWalkStep
        neg.w   d0
        bra.s   .try_move_x

.air_horiz:
        ; In mid-air: blend launch momentum (PlayerVX) with air steering
        move.w  PlayerVX(pc),d0
        btst    #0,d6
        beq.s   .chk_al
        move.w  #1,FacingDir
        moveq   #3,d0
        bra.s   .try_move_x
.chk_al:
        btst    #1,d6
        beq.s   .try_move_x
        clr.w   FacingDir
        moveq   #-3,d0

.try_move_x:
        tst.w   d0
        beq.s   .horiz_done
        ; Check wall collision at (PlayerX + d0 + sign*10, PlayerY - 12)
        move.w  PlayerX(pc),d2
        add.w   d0,d2
        move.w  d2,d3
        tst.w   d0
        bmi.s   .wall_l
        addi.w  #8,d3
        bra.s   .chk_wall_pt
.wall_l:
        subi.w  #8,d3
.chk_wall_pt:
        movem.l d0/d2,-(sp)
        move.w  d3,d0
        move.w  PlayerY(pc),d1
        subi.w  #14,d1
        bsr.w   GetTileCol
        move.w  d0,d3
        movem.l (sp)+,d0/d2
        tst.w   d3                      ; bit 15 = Wall ($8000)
        bmi.s   .hit_wall_x
        move.w  d2,PlayerX
        bra.s   .horiz_done
.hit_wall_x:
        clr.w   PlayerVX
.horiz_done:

        ; Check Jump / Drop-through when OnGround
        tst.b   OnGround
        beq.w   .in_air_vert

        ; Standing on branch/ground:
        ; Check if Down + Jump is pressed -> Drop down through tree branch!
        btst    #2,d6                   ; Down held?
        beq.s   .chk_normal_jump
        tst.b   JumpJustPressed
        beq.w   .chk_still_supported
        ; Only allow drop-through if not at the very bottom ground (PlayerY < 1990)
        cmpi.w  #1990,PlayerY
        bge.w   .chk_still_supported
        clr.b   OnGround
        move.b  #10,DropTimer
        addi.w  #6,PlayerY
        move.w  #$0180,PlayerVY
        bra.w   ClampPlayerWorld

.chk_normal_jump:
        ; Jump if JumpJustPressed ('X'/'C'/Alt) OR if Up pressed without Fire
        tst.b   JumpJustPressed
        bne.s   .do_jump
        tst.b   AttractMode
        bne.s   .chk_still_supported   ; native demo UP aims/reels; it never jumps
        btst    #3,d6                   ; Up held?
        beq.s   .chk_still_supported
        tst.b   PrevFireBtn             ; Not holding Fire?
        bne.s   .chk_still_supported
        tst.b   WasUpHeld
        bne.s   .chk_still_supported
.do_jump:
        clr.b   OnGround
        move.w  #-$05C0,PlayerVY        ; Strong arcade jump (-5.75 px/frame)
        btst    #0,d6
        beq.s   .jmp_chk_l
        move.w  #2,PlayerVX
        bra.s   .in_air_vert
.jmp_chk_l:
        btst    #1,d6
        beq.s   .in_air_vert
        move.w  #-2,PlayerVX
        bra.s   .in_air_vert

.chk_still_supported:
        ; Verify there is still a branch/platform under Joe's feet (PlayerX +/- 6, PlayerY + 2)
        move.w  PlayerX(pc),d0
        subq.w  #6,d0
        move.w  PlayerY(pc),d1
        addq.w  #2,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bpl.s   .snap_support
        move.w  PlayerX(pc),d0
        addq.w  #6,d0
        move.w  PlayerY(pc),d1
        addq.w  #2,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bpl.s   .snap_support

        ; Walked off the edge of a branch!
        clr.b   OnGround
        clr.w   PlayerVY
        bra.w   .update_up_latch

.snap_support:
        move.w  d0,PlayerY
        clr.w   PlayerVY
        clr.w   PlayerVX
        bra.w   .update_up_latch

        ; --------------------------------------------------------------------
        ; Mid-Air Gravity & Landing on Branches
        ; --------------------------------------------------------------------
.in_air_vert:
        move.w  PlayerY(pc),d4          ; d4 = OldPlayerY
        tst.b   ChuteMode
        beq.s   .no_chute_fall
        move.w  ChuteReleaseY(pc),d0
        cmp.w   PlayerY(pc),d0
        bgt.s   .chute_descent
        ; The arcade releases its canopy before touchdown, then uses Joe's
        ; ordinary falling pose.  Keep the existing fall speed continuous.
        clr.b   ChuteMode
        bra.s   .no_chute_fall
.chute_descent:
        move.w  #$0180,PlayerVY         ; Parachute: steady 1.5 px/frame descent
        moveq   #1,d0
        btst    #0,AnimTick+1
        beq.s   .chute_step
        addq.w  #1,d0
.chute_step:
        add.w   d0,PlayerY
        bra.s   .check_landing
.no_chute_fall:
        move.w  PlayerVY(pc),d0
        addi.w  #$0054,d0               ; Gravity (+0.33 px/frame^2)
        cmpi.w  #$0700,d0               ; Terminal velocity (+7 px/frame)
        ble.s   .vy_ok
        move.w  #$0700,d0
.vy_ok:
        move.w  d0,PlayerVY
        asr.w   #8,d0                   ; Integer delta Y
        add.w   d0,PlayerY

.check_landing:
        tst.b   ChuteMode
        bne.w   .update_up_latch        ; an entry canopy cannot land on a branch
        ; Only check landing on branches when falling (PlayerVY >= 0) and DropTimer == 0
        tst.w   PlayerVY
        bmi.w   .update_up_latch
        tst.b   DropTimer
        bne.w   .update_up_latch

        ; Check feet at (PlayerX, PlayerY), (PlayerX - 6, PlayerY), (PlayerX + 6, PlayerY)
        move.w  PlayerX(pc),d0
        move.w  PlayerY(pc),d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bpl.s   .check_land_y

        move.w  PlayerX(pc),d0
        subq.w  #6,d0
        move.w  PlayerY(pc),d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bpl.s   .check_land_y

        move.w  PlayerX(pc),d0
        addq.w  #6,d0
        move.w  PlayerY(pc),d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.w   .update_up_latch

.check_land_y:
        ; d0 = SurfaceY of branch/platform. Did feet cross or touch SurfaceY?
        move.w  d4,d1
        subq.w  #6,d1
        cmp.w   d1,d0
        blt.w   .update_up_latch        ; Branch top was well above OldPlayerY
        cmp.w   PlayerY(pc),d0
        bgt.w   .update_up_latch        ; Feet haven't reached SurfaceY yet

        ; Landed cleanly on branch!
        move.w  d0,PlayerY
        clr.w   PlayerVY
        clr.w   PlayerVX
        clr.b   VaultFlipTimer
        clr.b   ChuteMode
        move.b  #1,OnGround
        bra.w   .update_up_latch

        ; ====================================================================
        ; STATE 3: PENDULUM SWINGING ON BIONIC ARM!
        ; ====================================================================
.state_swinging:
        ; 1. Check if player pressed Jump or Fire to release & vault into mid-air!
        move.b  JumpJustPressed(pc),d0
        or.b    FireJustPressed(pc),d0
        beq.s   .swing_pump

        ; Launch Super Joe into mid-air with tangential swing momentum & somersault flip!
        clr.b   GrappleState
        clr.b   OnGround
        move.b  #15,VaultFlipTimer      ; 15-frame arcade somersault flip ($14994)
        move.w  SwingOmega(pc),d0
        asr.w   #6,d0                   ; Convert angular velocity to horizontal VX (-5..+5)
        cmpi.w  #-5,d0
        bge.s   .vx_min_ok
        moveq   #-5,d0
.vx_min_ok:
        cmpi.w  #5,d0
        ble.s   .vx_max_ok
        moveq   #5,d0
.vx_max_ok:
        move.w  d0,PlayerVX
        move.w  #-$04E0,PlayerVY        ; Upward vault boost (-4.875 px/frame)
        bra.w   .update_up_latch

.swing_pump:
        ; 2. Check Up / Down to reel in (climb up onto branch) or lengthen cable
        btst    #3,d6                   ; Up held?
        beq.s   .chk_swing_down
        subq.w  #2,SwingRadius
        ; Dampen swing angle toward 0 as we climb up to the branch
        move.w  SwingAngle(pc),d0
        asr.w   #3,d0
        sub.w   d0,SwingAngle
        cmpi.w  #22,SwingRadius
        bgt.s   .swing_physics
        ; Reached the branch! Vault right onto top of branch!
        move.w  AnchorX(pc),PlayerX
        move.w  AnchorSurfaceY(pc),PlayerY
        clr.b   GrappleState
        move.b  #1,OnGround
        clr.w   PlayerVX
        clr.w   PlayerVY
        bra.w   .update_up_latch

.chk_swing_down:
        btst    #2,d6                   ; Down held?
        beq.s   .swing_physics
        cmpi.w  #96,SwingRadius
        bge.s   .swing_physics
        addq.w  #1,SwingRadius

.swing_physics:
        ; 3. Pendulum Angular Acceleration:
        ;    Gravity restoring torque = -(SwingAngle >> 8) * 3
        move.w  SwingAngle(pc),d0
        asr.w   #8,d0                   ; theta in -64..+64
        move.w  d0,d1
        add.w   d0,d0
        add.w   d1,d0                   ; theta * 3
        sub.w   d0,SwingOmega

        ; Player Left / Right swing pumping!
        btst    #0,d6                   ; Right
        beq.s   .chk_pump_l
        move.w  #1,FacingDir
        addi.w  #28,SwingOmega
.chk_pump_l:
        btst    #1,d6                   ; Left
        beq.s   .damp_omega
        clr.w   FacingDir
        subi.w  #28,SwingOmega

.damp_omega:
        ; Slight air damping: SwingOmega -= (SwingOmega >> 6)
        move.w  SwingOmega(pc),d0
        asr.w   #6,d0
        sub.w   d0,SwingOmega

        ; Clamp SwingOmega to [-$03C0, +$03C0]
        move.w  SwingOmega(pc),d0
        cmpi.w  #-$03C0,d0
        bge.s   .om_min_ok
        move.w  #-$03C0,d0
.om_min_ok:
        cmpi.w  #$03C0,d0
        ble.s   .om_max_ok
        move.w  #$03C0,d0
.om_max_ok:
        move.w  d0,SwingOmega

        ; Advance SwingAngle and clamp to [-64 deg, +64 deg]
        add.w   d0,SwingAngle
        move.w  SwingAngle(pc),d0
        cmpi.w  #(-64*256),d0
        bge.s   .ang_min_ok
        move.w  #(-64*256),SwingAngle
        neg.w   SwingOmega
        asr.w   SwingOmega
        bra.s   .apply_pendulum_pos
.ang_min_ok:
        cmpi.w  #(64*256),d0
        ble.s   .apply_pendulum_pos
        move.w  #(64*256),SwingAngle
        neg.w   SwingOmega
        asr.w   SwingOmega

.apply_pendulum_pos:
        move.w  PlayerY(pc),SwingPrevFeetY
        ; Exact arcade pendulum formula ($136B0..$136E4):
        ;   CenterX = AnchorX + (R * sin(theta)) >> 8
        ;   CenterY = AnchorY + (R * cos(theta)) >> 8
        ;   PlayerY (feet) = CenterY + 16
        move.w  SwingAngle(pc),d0
        asr.w   #8,d0                   ; integer angle -64..+64
        addi.w  #64,d0                  ; table index 0..128
        and.w   #$00FF,d0
        add.w   d0,d0                   ; word offset
        lea     SinTable(pc),a1
        move.w  (a1,d0.w),d1            ; sin(theta) (-256..+256)
        lea     CosTable(pc),a1
        move.w  (a1,d0.w),d2            ; cos(theta) (0..+256)

        move.w  SwingRadius(pc),d3
        muls.w  d3,d1
        asr.l   #8,d1                   ; d1 = R * sin(theta) / 256
        muls.w  d3,d2
        asr.l   #8,d2                   ; d2 = R * cos(theta) / 256

        move.w  AnchorX(pc),d0
        add.w   d1,d0
        move.w  d0,PlayerX
        move.w  AnchorY(pc),d0
        add.w   d2,d0
        addi.w  #16,d0
        move.w  d0,PlayerY
        bsr.w   ResolveSwingGround
        bra.s   .update_up_latch

        ; ====================================================================
        ; STATE 4: VERTICAL CLIMB / REEL-IN ONTO BRANCH
        ; ====================================================================
.state_climbing:
        move.w  AnchorX(pc),PlayerX
        subq.w  #4,PlayerY
        move.w  AnchorSurfaceY(pc),d0
        cmp.w   PlayerY(pc),d0
        blt.s   .update_up_latch
        ; Reached top of branch!
        move.w  d0,PlayerY
        clr.b   GrappleState
        move.b  #1,OnGround
        clr.w   PlayerVY
        clr.w   PlayerVX

.update_up_latch:
        ; If extending or retracting while moving/falling, keep claw anchored to Joe
        cmpi.b  #1,GrappleState
        beq.s   .sync_claw_now
        cmpi.b  #2,GrappleState
        bne.s   .no_sync_claw
.sync_claw_now:
        bsr.w   SyncClawToDist
.no_sync_claw:
        moveq   #0,d0
        btst    #3,InputDirs
        sne     d0
        move.b  d0,WasUpHeld

ClampPlayerWorld:
        ; Native ordinary walking stays inside the visible corridor. Airborne
        ; motion and a live tether retain their full movement range.
        tst.b   FlyMode
        bne.s   .world_x
        tst.b   EntryActive
        bne.s   .world_x
        tst.b   DeathActive
        bne.s   .world_x
        tst.b   OnGround
        beq.s   .world_x
        tst.b   GrappleState
        bne.s   .world_x
        move.w  CamX,d0
        addi.w  #16,d0
        cmp.w   PlayerX,d0
        ble.s   .view_right
        move.w  d0,PlayerX
.view_right:
        addi.w  #288,d0
        cmp.w   PlayerX,d0
        bge.s   .world_x
        move.w  d0,PlayerX
.world_x:
        cmpi.w  #16,PlayerX
        bge.s   .px_min
        move.w  #16,PlayerX
.px_min:
        cmpi.w  #2032,PlayerX
        ble.s   .px_max
        move.w  #2032,PlayerX
.px_max:
        cmpi.w  #36,PlayerY
        bge.s   .py_min
        move.w  #36,PlayerY
.py_min:
        ; A valid attached swing is not a free fall.  Its feet can cross the
        ; old 2014 threshold while the rope remains attached above the floor.
        cmpi.b  #3,GrappleState
        bge.s   .py_max
        tst.b   FlyMode
        bne.s   .map_fall
        tst.b   EntryActive
        bne.s   .map_fall
        tst.b   OnGround
        bne.s   .map_fall
        tst.w   PlayerVY
        ble.s   .map_fall
        move.w  PlayerY,d0
        sub.w   CamY,d0
        cmpi.w  #232,d0                 ; native downward viewport-loss edge
        bgt.s   .fall
.map_fall:
        cmpi.w  #2080,PlayerY           ; genuinely below the 2048px map + body height
        ble.s   .py_max
        tst.b   FlyMode
        bne.s   .py_land
.fall:
        ; Begin the deferred fatal sequence; FinishPlayerDeath owns the life.
        bsr.w   KillPlayer
        tst.b   DeathActive
        beq.s   .py_max
        ; Native viewport loss bypasses tumble/lying audio, just as a map fall.
        move.b  #3,DeathPhase
        move.w  #1,DeathTimer
        rts
.py_land:
        move.w  #2014,PlayerY
        clr.w   PlayerVY
        clr.b   VaultFlipTimer
        move.b  #1,OnGround
.py_max:
        rts

; Sweep downward-moving swing feet across every touched tile row. A low
; pendulum must land on the stone floor before the out-of-map test can run.
ResolveSwingGround:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  PlayerY(pc),d5
        move.w  SwingPrevFeetY(pc),d4
        cmp.w   d4,d5
        ble.s   .done
        subq.w  #4,d4
        move.w  d4,d6
        andi.w  #$FFF0,d6
.row:
        move.w  PlayerX(pc),d0
        move.w  d6,d1
        bsr.w   CheckPlatformAt
        tst.w   d0
        bmi.s   .next
        cmp.w   d4,d0
        blt.s   .next
        cmp.w   d5,d0
        bgt.s   .next
        move.w  d0,PlayerY
        clr.w   PlayerVX
        clr.w   PlayerVY
        clr.b   GrappleState
        clr.b   VaultFlipTimer
        move.b  #1,OnGround
        bra.s   .done
.next:
        addi.w  #16,d6
        cmp.w   d5,d6
        ble.s   .row
.done:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; ----------------------------------------------------------------------------
; GroundWalkStep -> d0 = pixels to walk this frame.
; Arcade walk = 1.00 px/frame @ 60.096 Hz = 60 px/sec; on 50 Hz that is 1.2 px/frame,
; so walk 1 px, plus an extra pixel on every 5th frame.
; ----------------------------------------------------------------------------
GroundWalkStep:
        moveq   #0,d2
        move.w  AnimTick(pc),d2
        divu    #5,d2
        swap    d2
        moveq   #1,d0
        tst.w   d2
        bne.s   .gws_done
        addq.w  #1,d0
.gws_done:
        rts

; ============================================================================
; SYNC CLAW (ClawX, ClawY) TO (PlayerX, PlayerY, GrappleDir, GrappleDist)
; Uses exact arcade hand launch offsets ($12B7A..$12B8E):
;   - 90 deg Up (GrappleDir == 0): HandX = PlayerX + (FacingDir ? -4 : +5), ClawY = (PlayerY - 20) - GrappleDist
;   - 45 deg Diag (GrappleDir != 0): ClawX = PlayerX + GrappleDir * GrappleDist, ClawY = (PlayerY - 16) - GrappleDist
; ============================================================================
SyncClawToDist:
        move.w  PlayerX(pc),d0
        move.w  PlayerY(pc),d1
        tst.w   GrappleDir
        bne.s   .sync_diag
        ; 90 deg Straight Up
        tst.w   FacingDir
        bne.s   .up_right_hand
        addq.w  #5,d0
        bra.s   .up_set_y
.up_right_hand:
        subq.w  #4,d0
.up_set_y:
        move.w  d0,ClawX
        subi.w  #20,d1
        sub.w   GrappleDist(pc),d1
        move.w  d1,ClawY
        rts

.sync_diag:
        bmi.s   .diag_l
        add.w   GrappleDist(pc),d0
        bra.s   .diag_y
.diag_l:
        sub.w   GrappleDist(pc),d0
.diag_y:
        move.w  d0,ClawX
        subi.w  #16,d1
        sub.w   GrappleDist(pc),d1
        move.w  d1,ClawY
        rts

; ============================================================================
; SMOOTH CAMERA TRACKING (Follows Super Joe within 2048x2048 World)
; ============================================================================
UpdateCamera:
        tst.b   EntryActive
        bne.w   .entry_camera_fixed
        ; Entry uses all eight sprite channels.  Keep its horizontal camera
        ; aligned for the standard fetch that leaves SPR6/7 DMA slots free.
        tst.b   ChuteMode
        bne.w   .track_y
        ; TargetCamX = PlayerX - 160
        move.w  PlayerX(pc),d0
        subi.w  #160,d0
        bpl.s   .cx_min
        moveq   #0,d0
.cx_min:
        cmpi.w  #MAP_MAX_X,d0
        ble.s   .cx_max
        move.w  #MAP_MAX_X,d0
.cx_max:
        sub.w   CamX(pc),d0
        asr.w   #2,d0                   ; Smooth proportional step (delta / 4)
        cmpi.w  #-8,d0
        bge.s   .dx_min
        moveq   #-8,d0
.dx_min:
        cmpi.w  #8,d0
        ble.s   .dx_max
        moveq   #8,d0
.dx_max:
        add.w   d0,CamX

.track_y:
        ; TargetCamY = PlayerY - 136
        move.w  PlayerY(pc),d1
        subi.w  #136,d1
        bpl.s   .cy_min
        moveq   #0,d1
.cy_min:
        cmpi.w  #MAP_MAX_Y,d1
        ble.s   .cy_max
        move.w  #MAP_MAX_Y,d1
.cy_max:
        sub.w   CamY(pc),d1
        asr.w   #2,d1
        cmpi.w  #-8,d1
        bge.s   .dy_min
        moveq   #-8,d1
.dy_min:
        cmpi.w  #8,d1
        ble.s   .dy_max
        moveq   #8,d1
.dy_max:
        add.w   d1,CamY
.entry_camera_fixed:
        rts

; ============================================================================
; TILE COLLISION LOOKUP (Uses Arcade 0x0CFE / 0x148E / 0x18D6 Flags in Blks)
; Input:  d0.w = WorldX (0..2047), d1.w = WorldY (0..2047)
; Output: d0.w = packed block-tile word:
;           Bit 15 ($8000): Solid Vertical Wall
;           Bit 14 ($4000): Solid Ceiling Overhang
;           Bits 10..13:    Platform/Branch height (0=air, 3..15=branch surface)
;           Bits 0..9:      tile_id
; ============================================================================
GetTileCol:
        movem.l d1-d3/a0,-(sp)
        lsr.w   #4,d0
        andi.w  #$007F,d0               ; map_tx (0..127)
        lsr.w   #4,d1
        andi.w  #$007F,d1               ; map_ty (0..127)

        move.w  d1,d2
        andi.w  #$00FE,d2
        lsl.w   #6,d2                   ; (map_ty >> 1) * 128
        move.w  d0,d3
        andi.w  #$00FE,d3               ; (map_tx >> 1) * 2
        add.w   d3,d2
        movea.l CurrentBMap(pc),a0
        move.w  (a0,d2.w),d2            ; block_id * 8

        btst    #0,d1
        beq.s   .top
        addq.w  #4,d2
.top:   btst    #0,d0
        beq.s   .left
        addq.w  #2,d2
.left:  movea.l CurrentBlks(pc),a0
        move.w  (a0,d2.w),d0
        movem.l (sp)+,d1-d3/a0
        rts

; ============================================================================
; CHECK PLATFORM / BRANCH AT (d0.w = WorldX, d1.w = WorldY)
; Output: d0.w = SurfaceY (if platform/branch present at tile), or -1 if none
; ============================================================================
CheckPlatformAt:
        move.w  d0,-(sp)
        move.w  d1,-(sp)
        bsr.s   GetTileCol
        lsr.w   #8,d0
        lsr.w   #2,d0
        andi.w  #$000F,d0               ; c_plat (0..15)
        beq.s   .no_plat
        move.w  (sp)+,d1
        addq.l  #2,sp
        andi.w  #$07F0,d1               ; ty * 16
        addi.w  #16,d1
        sub.w   d0,d1                   ; SurfaceY = (ty * 16) + (16 - c_plat)
        move.w  d1,d0
        rts
.no_plat:
        move.w  (sp)+,d1
        move.w  (sp)+,d0
        jmp     CheckObjectPlatformAt

; ============================================================================
; UPDATE HARDWARE SPRITES
;   - SPR0..SPR3: Super Joe (32x32, 15-color attached pairs, 40 arcade poses)
;   - SPR4..SPR5: Bionic Arm Chained 15-Color Attached Channel (All Links 0..9!)
;     (Note: DDFSTRT=$0030 uses DMA slots $30..$36, so SPR4+5 at $28..$2E is
;      100% active across all 320 pixels and chains every link seamlessly!)
; ============================================================================
InitSpritePtrs:
        lea     CopSprPtrs,a0
        move.l  #Spr0Buf,d0
        bsr.s   .set_one
        move.l  #Spr1Buf,d0
        bsr.s   .set_one
        move.l  #Spr2Buf,d0
        bsr.s   .set_one
        move.l  #Spr3Buf,d0
        bsr.s   .set_one
        move.l  #Spr4Buf,d0
        bsr.s   .set_one
        move.l  #Spr5Buf,d0
        bsr.s   .set_one
        move.l  #Spr6Buf,d0
        bsr.s   .set_one
        move.l  #Spr7Buf,d0
.set_one:
        move.w  d0,6(a0)
        swap    d0
        move.w  d0,2(a0)
        addq.l  #8,a0
        rts

UpdateSprites:
        movem.l d0-d7/a0-a4,-(sp)
        move.w  #32,JoeSpriteHeight
        move.w  #32,JoeSpriteTopOffset
        tst.b   AttractMode
        beq.s   .visible_actor
        tst.b   DemoPlaybackActive
        beq.s   .visible_actor
        tst.b   DemoActorVisible
        bne.s   .visible_actor
        bsr.w   HideGameSprites
        movem.l (sp)+,d0-d7/a0-a4
        rts
.visible_actor:

        ; Four attached 16x64 pairs display the complete original parachute
        ; without erasing / repainting its pixels in the scrolling playfield.
        tst.b   ChuteMode
        beq.s   .normal_sprites
        bsr.w   UpdateChuteSprites
        movem.l (sp)+,d0-d7/a0-a4
        rts
.normal_sprites:
        clr.l   Spr6Buf
        clr.l   Spr7Buf
        tst.b   DeathActive
        beq.s   .living_pose
        jsr     GetPlayerDeathSprite
        move.w  DeathSpriteIndex,d0
        ori.w   #$4000,d0
        cmp.w   PrevPoseIdx(pc),d0
        beq.w   .update_joe_pos
        move.w  d0,PrevPoseIdx
        bra.w   .pose_addr_done
.living_pose:
        tst.b   AttractMode
        beq.s   .select_game_pose
        tst.b   DemoPlaybackActive
        beq.s   .select_game_pose
        jsr     GetArcadeDemoPose
        move.w  d1,JoeSpriteHeight
        move.w  d2,JoeSpriteTopOffset
        cmp.w   PrevPoseIdx(pc),d0
        beq.w   .update_joe_pos
        move.w  d0,PrevPoseIdx
        bra.w   .pose_addr_done
.select_game_pose:

        ; --------------------------------------------------------------------
        ; 1. Select Super Joe Pose (0..19 + 20*FacingDir) from Arcade Tables
        ; --------------------------------------------------------------------
        moveq   #0,d0
        move.b  GrappleState(pc),d1
        cmpi.b  #3,d1
        beq.w   .pose_swing
        cmpi.b  #4,d1
        beq.w   .pose_climb
        tst.b   d1
        bne.s   .pose_fire

        ; Not grappling: check ground vs air
        tst.b   OnGround
        beq.s   .pose_air
        btst    #2,InputDirs            ; Crouching?
        bne.s   .pose_crouch
        move.b  InputDirs(pc),d1
        andi.b  #$03,d1                 ; Moving Left or Right?
        beq.w   .pose_selected          ; Pose 0 = Idle ($144A6: 0x444)
        move.w  AnimTick(pc),d0
        lsr.w   #2,d0
        andi.w  #3,d0
        addq.w  #1,d0                   ; Poses 1..4 = Run cycle ($1433A: 0x406..0x404)
        bra.w   .pose_selected

.pose_crouch:
        moveq   #5,d0                   ; Pose 5 = Crouch ($143FA: 0x440)
        bra.w   .pose_selected

.pose_air:
        ; Check if performing mid-air somersault vault flip ($14994: 0x490..0x494)
        moveq   #0,d1
        move.b  VaultFlipTimer(pc),d1
        beq.s   .check_chute_pose
        moveq   #17,d0
        cmpi.w  #10,d1
        bge.w   .pose_selected
        moveq   #18,d0
        cmpi.w  #5,d1
        bge.w   .pose_selected
        moveq   #19,d0
        bra.w   .pose_selected
.check_chute_pose:
        tst.b   ChuteMode
        beq.s   .normal_jump_pose
        moveq   #11,d0                  ; Use fire/air pose or special pose for parachute
        bra.w   .pose_selected
.normal_jump_pose:
        moveq   #6,d0                   ; Pose 6 = Jump/Fall ($14826: 0x436)
        bra.w   .pose_selected

.pose_fire:
        tst.w   GrappleDir
        beq.s   .pose_fire_up
        tst.b   OnGround
        bne.s   .pose_fire_diag_gnd
        moveq   #11,d0                  ; Pose 11 = Mid-Air Fire 45 deg ($1474C: 0x460)
        bra.w   .pose_selected
.pose_fire_diag_gnd:
        moveq   #7,d0                   ; Pose 7 = Ground Fire 45 Recoil ($14512: 0x452)
        cmpi.w  #3,ArmAnimTick
        blt.w   .pose_selected
        moveq   #8,d0                   ; Pose 8 = Ground Fire 45 Hold ($14526: 0x454)
        bra.w   .pose_selected
.pose_fire_up:
        moveq   #9,d0                   ; Pose 9 = Ground Fire 90 Up Recoil ($14552: 0x466)
        cmpi.w  #3,ArmAnimTick
        blt.s   .pose_selected
        moveq   #10,d0                  ; Pose 10 = Ground Fire 90 Up Hold ($14566: 0x470)
        bra.s   .pose_selected

.pose_climb:
        move.w  #9,CurrentSwingAng
.pose_climb_anim:
        moveq   #16,d0                  ; Pose 16 = Climb / Pull-up ($147BE: 0x4B0)
        btst    #2,AnimTick+1
        beq.s   .pose_selected
        moveq   #13,d0                  ; Alternate with Pose 13 (0x482) while reeling in
        bra.s   .pose_selected

.pose_swing:
        ; Compute exact Arcade Swing Angle index (0..18) from SwingAngle
        move.w  SwingAngle(pc),d0
        asr.w   #8,d0                   ; theta in -64..+64
        muls.w  #6,d0
        addi.l  #32,d0
        asr.l   #6,d0
        addi.w  #9,d0                   ; ang in 0..18 (9 = 0 deg vertical)
        bpl.s   .sw_ang_min
        moveq   #0,d0
.sw_ang_min:
        cmpi.w  #18,d0
        ble.s   .sw_ang_max
        moveq   #18,d0
.sw_ang_max:
        move.w  d0,CurrentSwingAng

        ; If holding Up while swinging -> climbing pose (16 / 13)
        btst    #3,InputDirs
        bne.s   .pose_climb_anim

        ; Look up exact arcade swing pose (12..15) from $148F4 (Left) or $14942 (Right)
        lea     ArcadeSwingPoseLeft(pc),a0
        tst.w   FacingDir
        beq.s   .sw_lookup_pose
        lea     ArcadeSwingPoseRight(pc),a0
.sw_lookup_pose:
        move.b  (a0,d0.w),d0
        andi.l  #$000000FF,d0           ; clear MULS sign-extension before long frame offset
        ; The ROM selects a complete pose from angle and facing only.  Tiles
        ; $488..$48E are its lower rows, not alternate 32x32 animation frames.

.pose_selected:
        ; Add 20 if FacingDir == 1 (Right-facing pre-baked bank 20..39)
        tst.w   FacingDir
        beq.s   .dir_added
        addi.w  #20,d0
.dir_added:
        cmp.w   PrevPoseIdx(pc),d0
        beq.w   .update_joe_pos
        move.w  d0,PrevPoseIdx

        ; Copy 512 bytes (4 x 128B) from JoeSpritesData + d0*512 to Spr0Buf..Spr3Buf
        ; Poses 0..39 are linear; extra swing poses (40..43 Left, 60..63 Right) live at
        ; JoeSpritesData + 25680 (4 Left then 4 Right).
        cmpi.w  #40,d0
        blt.s   .pose_linear
        cmpi.w  #60,d0
        blt.s   .pose_extra
        subi.w  #56,d0                  ; 60..63 -> 4..7
        bra.s   .pose_extra2
.pose_extra:
        subi.w  #40,d0                  ; 40..43 -> 0..3
.pose_extra2:
        lsl.w   #8,d0
        add.l   d0,d0
        lea     JoeSpritesData+25680,a0
        adda.l  d0,a0
        bra.s   .pose_addr_done
.pose_linear:
        lsl.w   #8,d0
        add.l   d0,d0                   ; d0 * 512
        lea     JoeSpritesData,a0
        adda.l  d0,a0
.pose_addr_done:

        lea     Spr0Buf+4,a1
        move.w  JoeSpriteHeight(pc),d7
        subq.w  #1,d7
.cp0:   move.l  (a0)+,(a1)+
        dbf     d7,.cp0
        clr.l   (a1)                   ; terminate at 32 rows after the 64-row chute

        lea     Spr1Buf+4,a1
        move.w  JoeSpriteHeight(pc),d7
        subq.w  #1,d7
.cp1:   move.l  (a0)+,(a1)+
        dbf     d7,.cp1
        clr.l   (a1)

        lea     Spr2Buf+4,a1
        move.w  JoeSpriteHeight(pc),d7
        subq.w  #1,d7
.cp2:   move.l  (a0)+,(a1)+
        dbf     d7,.cp2
        clr.l   (a1)

        lea     Spr3Buf+4,a1
        move.w  JoeSpriteHeight(pc),d7
        subq.w  #1,d7
.cp3:   move.l  (a0)+,(a1)+
        dbf     d7,.cp3
        clr.l   (a1)

.update_joe_pos:
        ; ScreenX = PlayerX - 16 - CamX, ScreenY = PlayerY - 32 - CamY
        move.w  PlayerX(pc),d0
        subi.w  #16,d0
        sub.w   CamX(pc),d0
        move.w  PlayerY(pc),d1
        sub.w   JoeSpriteTopOffset(pc),d1
        sub.w   CamY(pc),d1
        move.w  JoeSpriteHeight(pc),d2
        bsr.w   CalcSprCtrlWords        ; Returns d3.l = POS:CTL
        move.l  d3,Spr0Buf
        ori.w   #$0080,d3               ; Set ATT bit 7 on odd attached sprite!
        move.l  d3,Spr1Buf

        ; Right 16x32 half at ScreenX + 16
        move.w  PlayerX(pc),d0
        sub.w   CamX(pc),d0
        move.w  PlayerY(pc),d1
        sub.w   JoeSpriteTopOffset(pc),d1
        sub.w   CamY(pc),d1
        move.w  JoeSpriteHeight(pc),d2
        bsr.w   CalcSprCtrlWords
        move.l  d3,Spr2Buf
        ori.w   #$0080,d3               ; Set ATT bit 7 on Spr3!
        move.l  d3,Spr3Buf

        ; --------------------------------------------------------------------
        ; 2. Build Bionic Arm Link List (Top-to-Bottom: k=0 Claw, k=1..N Wire)
        ;    and Emit into Attached Sprite Pair SPR4+5 (Midpoint Scanline Handoff)
        ; --------------------------------------------------------------------
        tst.b   GrappleState
        bne.s   .arm_active
        clr.l   Spr4Buf
        clr.l   Spr5Buf
        movem.l (sp)+,d0-d7/a0-a4
        rts

.arm_active:
        lea     ArmLinkList(pc),a4
        moveq   #0,d7                   ; d7 = TotalLinks emitted (max 10)

        cmpi.b  #3,GrappleState
        bge.w   .arm_swing_or_climb

        ; --- Extending (State 1) or Retracting (State 2) ---
        move.w  ClawX(pc),d4
        sub.w   CamX(pc),d4             ; d4 = ClawScreenX
        move.w  ClawY(pc),d5
        sub.w   CamY(pc),d5             ; d5 = ClawScreenY

        tst.w   GrappleDir
        bne.s   .ext_diag

        ; 90 deg Straight Up: Select Claw Tile (20..23) from $15422 sequence
        move.w  ArmAnimTick(pc),d1
        moveq   #20,d0                  ; 20: 0x4DE compact emerging
        cmpi.w  #2,d1
        blt.s   .ext_up_claw_ok
        moveq   #21,d0                  ; 21: 0x4D8 jaws sprung 180 deg wide open!
        cmpi.w  #4,d1
        blt.s   .ext_up_claw_ok
        moveq   #22,d0                  ; 22: 0x4D9 jaws 90 deg open
        cmpi.w  #6,d1
        blt.s   .ext_up_claw_ok
        moveq   #23,d0                  ; 23: 0x4DA jaws V-open in flight
.ext_up_claw_ok:
        moveq   #19,d6                  ; d6 = Wire Tile 19 (0x4C8 vertical extending wire)
        moveq   #0,d1                   ; d1 = wx (0.00 px/link)
        move.w  #(12*256),d2            ; d2 = wy (+12.00 px/link downward)
        move.w  GrappleDist(pc),d3
        subq.w  #4,d3                   ; d3 = max wire distance right to Joe's hand
        move.w  #12,ArmDistStep
        bra.w   .emit_links_loop

.ext_diag:
        ; 45 deg Diagonal Up-Right (25..29) or Up-Left (31..35) from $15438 / $15470
        moveq   #25,d0                  ; Base tile for Up-Right
        moveq   #5,d6                   ; Wire Tile 5 (0x4C4 Up-Right)
        move.w  #(-9*256),d1            ; wx = -9.00 px/link (stepping down-left from claw)
        tst.w   GrappleDir
        bpl.s   .ext_diag_dir_ok
        moveq   #31,d0                  ; Base tile for Up-Left
        moveq   #13,d6                  ; Wire Tile 13 (0x4C4 X-flip Up-Left)
        move.w  #(9*256),d1             ; wx = +9.00 px/link (stepping down-right from claw)
.ext_diag_dir_ok:
        move.w  ArmAnimTick(pc),d2
        cmpi.w  #2,d2
        blt.s   .ext_diag_claw_ok       ; +0: 0x4DC compact emerging
        addq.w  #1,d0
        cmpi.w  #5,d2
        blt.s   .ext_diag_claw_ok       ; +1: 0x4A2 jaws sprung wide open!
        addq.w  #1,d0
        cmpi.w  #8,d2
        blt.s   .ext_diag_claw_ok       ; +2: 0x4AA jaws closing
        addq.w  #1,d0                   ; +3: 0x4A0 in-flight A
        btst    #2,d2
        beq.s   .ext_diag_claw_ok
        addq.w  #1,d0                   ; +4: 0x4A3 in-flight B
.ext_diag_claw_ok:
        move.w  #(9*256),d2             ; wy = +9.00 px/link downward
        move.w  GrappleDist(pc),d3
        subq.w  #4,d3                   ; max wire distance right to Joe's hand
        move.w  #9,ArmDistStep
        bra.w   .emit_links_loop

.arm_swing_or_climb:
        ; --- Pendulum Swinging (State 3) or Vertical Climb (State 4) ---
        move.w  AnchorX(pc),d4
        sub.w   CamX(pc),d4             ; d4 = AnchorScreenX
        move.w  AnchorY(pc),d5
        sub.w   CamY(pc),d5             ; d5 = AnchorScreenY
        move.w  CurrentSwingAng(pc),d6  ; d6 = Swing Angle index (0..18), also Wire TileIdx!

        ; Select Claw Tile from $15616 (or $154A8 jaw-latching snap if LatchAnimTimer > 0)
        lea     ArcadeSwingClawTable(pc),a0
        moveq   #0,d0
        move.b  (a0,d6.w),d0
        move.b  LatchAnimTimer(pc),d1
        beq.s   .sw_claw_ok
        ; Jaw-closing latch animation ($154A8) on first 6 frames of branch contact:
        tst.w   GrappleDir
        bne.s   .latch_diag
        moveq   #22,d0                  ; 0x4D9
        cmpi.b  #4,d1
        bge.s   .sw_claw_ok
        moveq   #23,d0                  ; 0x4DA
        bra.s   .sw_claw_ok
.latch_diag:
        bmi.s   .latch_diag_l
        moveq   #27,d0                  ; 0x4AA Up-Right
        cmpi.b  #4,d1
        bge.s   .sw_claw_ok
        moveq   #28,d0                  ; 0x4A0 Up-Right
        bra.s   .sw_claw_ok
.latch_diag_l:
        moveq   #33,d0                  ; 0x4AA Up-Left
        cmpi.b  #4,d1
        bge.s   .sw_claw_ok
        moveq   #34,d0                  ; 0x4A0 Up-Left
.sw_claw_ok:
        ; Look up 12.00 px/link step (wx, wy) from ArcadeWireStepTable ($151CE)
        move.w  d6,d1
        lsl.w   #2,d1
        lea     ArcadeWireStepTable(pc),a0
        move.w  0(a0,d1.w),d1           ; d1 = wx (16.8 signed)
        move.w  CurrentSwingAng(pc),d2
        lsl.w   #2,d2
        move.w  2(a0,d2.w),d2           ; d2 = wy (16.8 positive downward)

        ; Compute rope length R
        move.w  SwingRadius(pc),d3
        cmpi.b  #4,GrappleState
        bne.s   .got_sw_r
        move.w  PlayerY(pc),d3
        subi.w  #16,d3
        sub.w   AnchorY(pc),d3
.got_sw_r:
        subq.w  #6,d3                   ; Stop wire links right at Super Joe's raised hand!
        move.w  #12,ArmDistStep

.emit_links_loop:
        ; Emit Link 0 (Grabber Claw) at (d4, d5) with TileIdx d0
        move.w  d4,(a4)+
        move.w  d5,(a4)+
        move.w  d0,(a4)+
        addq.w  #1,d7

        ; Step down the cable emitting Wire Links (k = 1..9) with TileIdx d6
        ; Use 32-bit fixed-point so ScreenX >= 128 never sign-overflows 16-bit!
        ext.l   d4
        lsl.l   #8,d4                   ; cur_x_fp (24.8 signed)
        ext.l   d5
        lsl.l   #8,d5                   ; cur_y_fp (24.8 signed)
        ext.l   d1                      ; wx (24.8 signed)
        ext.l   d2                      ; wy (24.8 signed)
        move.w  ArmDistStep(pc),d0      ; current distance along cable
.wire_lp:
        cmp.w   d3,d0
        bgt.s   .links_done
        cmpi.w  #10,d7
        bge.s   .links_done
        add.l   d1,d4                   ; cur_x_fp += wx
        add.l   d2,d5                   ; cur_y_fp += wy
        move.l  d4,d0
        asr.l   #8,d0
        move.w  d0,(a4)+                ; ScreenX
        move.l  d5,d0
        asr.l   #8,d0
        move.w  d0,(a4)+                ; ScreenY
        move.w  d6,(a4)+                ; Wire TileIdx
        addq.w  #1,d7
        sub.w   ArmDistStep(pc),d3
        move.w  ArmDistStep(pc),d0
        bra.s   .wire_lp

.links_done:
        ; Chain all Bionic Arm links (k = 0..N-1) into Attached Sprite Pair SPR4 + SPR5
        lea     ArmLinkList(pc),a0
        lea     Spr4Buf,a2
        lea     Spr5Buf,a3
        move.w  d7,d5
        bsr.s   BuildArmChannel

        movem.l (sp)+,d0-d7/a0-a4
        rts

; ============================================================================
; BUILD ATTACHED 15-COLOR HARDWARE SPRITE CHANNEL (All Links 0..N-1 Chained)
; Input:  a0 = start in ArmLinkList (stride 6 bytes = 1 link: ScreenX, ScreenY, TileIdx)
;         a2 = Even Sprite Buffer (Spr4Buf)
;         a3 = Odd Attached Sprite Buffer (Spr5Buf)
;         d5.w = Total links to emit (1..10)
; ============================================================================
BuildArmChannel:
        move.w  #-100,d6                ; d6.w = prev_vstop_screen
.ch_loop:
        tst.w   d5
        ble.w   .ch_done

        move.w  0(a0),d0                ; ScreenX (center)
        subq.w  #8,d0                   ; x0 = ScreenX - 8
        move.w  2(a0),d1                ; ScreenY (center)
        subq.w  #8,d1                   ; y0 = ScreenY - 8
        move.w  4(a0),d4                ; TileIdx (0..39)
        addq.l  #6,a0                   ; Advance to next link (k+1)!
        subq.w  #1,d5

        ; Check horizontal visibility (-16 .. 319)
        cmpi.w  #-16,d0
        blt.s   .ch_loop
        cmpi.w  #320,d0
        bge.s   .ch_loop

        ; Look up active scanline bounds (r_start, r_end) from ArmTileBounds
        move.w  d4,d2
        add.w   d2,d2
        lea     ArmTileBounds,a1
        moveq   #0,d3
        move.b  0(a1,d2.w),d3           ; d3 = r_start (0..15)
        moveq   #0,d7
        move.b  1(a1,d2.w),d7           ; d7 = r_end (0..15)

        ; Enforce non-overlapping DMA rule: y0 + r_start >= prev_vstop_screen + 1
        move.w  d6,d2
        addq.w  #1,d2                   ; min_top_y = prev_vstop_screen + 1
        bpl.s   .min_top_pos
        moveq   #0,d2                   ; Also clamp to top of screen (y >= 0)
.min_top_pos:
        sub.w   d1,d2                   ; req_r_start = min_top_y - y0
        cmp.w   d3,d2
        ble.s   .rstart_ok
        move.w  d2,d3                   ; r_start = req_r_start
.rstart_ok:

        ; Midpoint handoff to next link (k+1) so consecutive links share scanlines evenly!
        tst.w   d5
        ble.s   .no_next_handoff
        move.w  2(a0),d2                ; next_ly = next link's ScreenY (center)
        move.w  d1,d0
        addq.w  #8,d0                   ; ly = current link's ScreenY (y0 + 8)
        cmp.w   d0,d2
        ble.s   .no_next_handoff
        add.w   d0,d2
        asr.w   #1,d2                   ; mid_y = (ly + next_ly) >> 1
        sub.w   d1,d2                   ; max_r_end = mid_y - y0
        cmp.w   d7,d2
        bge.s   .no_next_handoff
        move.w  d2,d7                   ; r_end = max_r_end
.no_next_handoff:
        move.w  -6(a0),d0               ; Restore x0 = ScreenX - 8
        subq.w  #8,d0

        ; Clamp bottom to HUD split (y0 + r_end <= 223)
        move.w  #223,d2
        sub.w   d1,d2                   ; max_r_end = 223 - y0
        cmp.w   d7,d2
        bge.s   .rend_ok
        move.w  d2,d7                   ; r_end = max_r_end
.rend_ok:

        ; Verify r_start <= r_end and within 0..15
        cmp.w   d7,d3
        bgt.w   .ch_loop
        cmpi.w  #15,d3
        bgt.w   .ch_loop
        tst.w   d7
        bmi.w   .ch_loop

        ; Compute top_y = y0 + r_start, height = r_end - r_start + 1
        add.w   d3,d1                   ; d1 = top_y
        move.w  d7,d2
        sub.w   d3,d2
        addq.w  #1,d2                   ; d2 = height (1..16)
        move.w  d1,d6
        add.w   d2,d6                   ; prev_vstop_screen = top_y + height

        ; Write control words to Even (a2) and Odd Attached (a3) sprite buffers
        move.w  d3,-(sp)                ; save r_start
        bsr.s   CalcSprCtrlWords        ; d0=x0, d1=top_y, d2=height -> d3.l = POS:CTL
        move.l  d3,(a2)+
        ori.w   #$0080,d3               ; Set ATT bit 7 on Odd Attached Sprite!
        move.l  d3,(a3)+
        move.w  (sp)+,d3                ; restore r_start

        ; Copy `height` scanlines of Even (P0,P1) and Odd (P2,P3) data
        lsl.w   #7,d4                   ; TileIdx * 128
        lsl.w   #2,d3                   ; r_start * 4
        add.w   d3,d4
        lea     ArmSpritesData,a1
        adda.w  d4,a1                   ; Even plane data at +0, Odd plane data at +64
        subq.w  #1,d2                   ; height - 1 for dbf
.cp_rows:
        move.l  (a1),(a2)+
        move.l  64(a1),(a3)+
        addq.l  #4,a1
        dbf     d2,.cp_rows
        bra.w   .ch_loop

.ch_done:
        clr.l   (a2)+                   ; Terminate Even Sprite DMA list
        clr.l   (a3)+                   ; Terminate Odd Attached Sprite DMA list
        rts

; ============================================================================
; COMPUTE AMIGA HARDWARE SPRITE CONTROL WORDS (SPRxPOS & SPRxCTL)
; Input:  d0.w = ScreenX, d1.w = ScreenY, d2.w = Height
; Output: d3.l = (SPRxPOS << 16) | SPRxCTL (or 0 if offscreen)
; ============================================================================
CalcSprCtrlWords:
        movem.l d0-d2/d4,-(sp)
        ; Check if offscreen horizontally or vertically (above HUD at y=224)
        cmpi.w  #-16,d0
        blt.s   .offscreen
        cmpi.w  #320,d0
        bge.s   .offscreen
        cmpi.w  #-16,d1
        blt.s   .offscreen
        cmpi.w  #224,d1
        bge.s   .offscreen

        ; Clamp top/bottom to playfield (0..224)
        tst.w   d1
        bpl.s   .y_top_ok
        moveq   #0,d1
.y_top_ok:
        move.w  d1,d4
        add.w   d2,d4                   ; VSTOP_screen = ScreenY + Height
        cmpi.w  #224,d4
        ble.s   .y_bot_ok
        move.w  #224,d4
.y_bot_ok:
        cmp.w   d1,d4
        ble.s   .offscreen

        addi.w  #127,d0                 ; HSTART = ScreenX + 127
        addi.w  #44,d1                  ; VSTART = ScreenY + 44 ($2C)
        addi.w  #44,d4                  ; VSTOP  = VSTOP_screen + 44

        moveq   #0,d3
        ; SPRxPOS: (VSTART & $FF) << 8 | (HSTART >> 1)
        move.w  d1,d3
        andi.w  #$00FF,d3
        lsl.w   #8,d3
        move.w  d0,d2
        lsr.w   #1,d2
        andi.w  #$00FF,d2
        or.w    d2,d3
        swap    d3

        ; SPRxCTL: (VSTOP & $FF) << 8 | (VSTART[8] << 2) | (VSTOP[8] << 1) | HSTART[0]
        move.w  d4,d2
        andi.w  #$00FF,d2
        lsl.w   #8,d2
        btst    #8,d1
        beq.s   .no_vs8
        bset    #2,d2
.no_vs8:
        btst    #8,d4
        beq.s   .no_ve8
        bset    #1,d2
.no_ve8:
        btst    #0,d0
        beq.s   .no_hs0
        bset    #0,d2
.no_hs0:
        move.w  d2,d3
        movem.l (sp)+,d0-d2/d4
        rts

.offscreen:
        moveq   #0,d3
        movem.l (sp)+,d0-d2/d4
        rts

; ============================================================================
; LOAD STAGE & INITIALIZE FULL SCREEN + PLAYER SPAWN
; Input: d0.w = stage number (0..5)
; ============================================================================
LoadStage:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.w  #GAME_STAGE_COUNT,d0
        blo.s   .edition_stage_ready
        moveq   #0,d0                  ;unavailable indices always restart stage1
.edition_stage_ready:
        jsr     CancelPlayerDeath
        jsr     StopNativeEffects
        move.w  #$0100,CUSTOM+DMACON    ; hide the previous picture during tile/palette load
        bsr.w   HideGameSprites
        jsr     BeginLevelLoading

        ; Restore the scrolling 336px fetch after the static 320px intro picture.
        move.w  #$0113,CopHudBackground+2
        move.w  #$0FD2,CopHudForeground+2
        move.w  #$0030,CopFetchStart+2
        move.w  #(ROW_STRIDE-42),CopModulo+2
        move.w  #(ROW_STRIDE-42),CopModulo+6

        move.w  d0,CurrentStage
        jsr     InitLevelBonus
        mulu.w  #24,d0
        lea     StageDirectory(pc),a4
        adda.w  d0,a4

        move.l  0(a4),CurrentPal
        move.l  4(a4),CurrentBMap
        move.l  8(a4),CurrentBlks
        move.l  12(a4),CurrentTilesLZ
        movea.l CurrentBMap,a0
        lea     ActiveBMap,a1
        jsr     LZSS_Decompress
        move.l  #ActiveBMap,CurrentBMap

        ; Spawn Super Joe on initial platform & center camera
        move.w  16(a4),d0               ; Spawn PlayerX
        move.w  d0,PlayerX
        move.w  d0,PrevHudX
        move.w  18(a4),d1               ; Spawn PlayerY (feet on platform)
        move.w  d1,EntryTargetY
        move.w  d1,d2
        subi.w  #74,d2                 ; native chute releases at feet 1928
        move.w  d2,ChuteReleaseY
        subi.w  #CHUTE_DROP,d1          ; Parachute in from above the landing platform
        bpl.s   .spawn_y_ok
        moveq   #40,d1
.spawn_y_ok:
        move.w  d1,PlayerY
        move.w  d1,PrevHudY

        subi.w  #160,d0
        bpl.s   .scx_ok
        moveq   #0,d0
.scx_ok:
        move.w  d0,CamX
        subi.w  #156,d1
        bpl.s   .scy_ok
        moveq   #0,d1
.scy_ok:
        cmpi.w  #MAP_MAX_Y,d1
        ble.s   .scy_max
        move.w  #MAP_MAX_Y,d1
.scy_max:
        move.w  d1,CamY

        ; Original Stage 1 entry begins above the viewport and keeps the
        ; camera at the bottom of the map until Joe reaches the stone floor.
        tst.w   CurrentStage
        bne.s   .entry_camera_ready
        clr.w   CamX
        move.w  #MAP_MAX_Y,CamY
.entry_camera_ready:

        clr.w   PlayerVX
        clr.w   PlayerVY
        move.w  #1,FacingDir
        clr.b   OnGround                ; Parachuting in: falls until a branch / ground is reached
        move.b  #1,ChuteMode
        move.b  #1,EntryActive
        clr.w   EntryFraction
        clr.w   EntryStepPhase
        jsr     ConfigureStageEntry
        move.w  #-1,ChuteClipRows
        clr.b   GrappleState
        clr.b   FlyMode
        clr.b   DropTimer
        clr.b   LatchAnimTimer
        clr.b   VaultFlipTimer
        clr.b   InputDirs
        clr.b   WasUpHeld
        clr.b   FireJustPressed
        clr.b   JumpJustPressed
        ; Consume a held start/fire button so it cannot immediately cut the chute.
        move.b  #1,PrevFireBtn
        move.b  #1,PrevJumpBtn
        move.b  #1,PrevNextKey
        clr.b   PrevShootBtn
        move.w  #-1,PrevPoseIdx

        ; 1. Load 32-color palette into CopperList
        movea.l CurrentPal(pc),a0
        lea     CopColors+2,a1
        moveq   #31,d7
.pal_loop:
        move.w  (a0)+,(a1)
        addq.l  #4,a1
        dbf     d7,.pal_loop

        ; Shared native atlas reconstructs exact reduced or full-colour tiles.
        jsr     PrepareColourProfile
        tst.b   FullChipActive
        bne.w   .tiles_ready

        ; 3. Draw full 22x16 visible tile window
        bsr.w   InitBlitterRegs

        move.w  CamX(pc),d0
        lsr.w   #4,d0
        move.w  d0,OldTileX
        move.w  CamY(pc),d1
        lsr.w   #4,d1
        move.w  d1,OldTileY

        moveq   #15,d7
        move.w  OldTileY(pc),d5
.row_loop:
        moveq   #21,d6
        move.w  OldTileX(pc),d4
.col_loop:
        move.w  d4,d0
        move.w  d5,d1
        bsr.w   DrawMapTile
        addq.w  #1,d4
        dbf     d6,.col_loop
        addq.w  #1,d5
        dbf     d7,.row_loop

        bsr.w   EndBlitterHog

.tiles_ready:
        ; 4. Initialize hidden/visible frame storage and object state.
        bsr.w   RenderHudBanner
        bsr.w   UpdateHudCoords

        move.l  #GameFrame0,FrameDrawPtr
        move.l  #GameFrame1,FrameShowPtr
        move.w  #-1,FrameHistory0
        move.w  #-1,FrameHistory1

        bsr.w   InitEnemies
        jsr     InitObjects
        jsr     InitLevelProgress
        jsr     ResetProgressHud
        jsr     ConfigureParallax
        jsr     ConfigureFullColour
        jsr     StartStageMusic

        tst.b   AttractMode
        beq.s   .hud_ready
        bsr.w   RenderDemoHud
.hud_ready:
        jsr     ComposeGameFrame
        jsr     EndLevelLoading
        move.w  #$8100,CUSTOM+DMACON
        move.w  #$0010,CUSTOM+INTREQ
        bsr.w   ResetGameClock          ; stage-loading time is not simulation debt
        jsr     ResetFPS
        movem.l (sp)+,d0-d7/a0-a6
        rts

; ============================================================================
; STREAM EDGES (Split-Phase X/Y Fast Blitter-Nasty Tile Strip Streaming)
; ============================================================================
StreamEdges:
        clr.w   DidBlitStrip

        move.w  CamX(pc),d4
        lsr.w   #4,d4
        move.w  CamY(pc),d5
        lsr.w   #4,d5

        cmp.w   OldTileX(pc),d4
        bne.s   .do_x_stream
        cmp.w   OldTileY(pc),d5
        bne.s   .do_y_stream
        rts

.do_x_stream:
        move.w  #1,DidBlitStrip
        bsr.w   InitBlitterRegs

.chk_right:
        move.w  OldTileX(pc),d0
        cmp.w   d4,d0
        bge.s   .chk_left
        addq.w  #1,d0
        move.w  d0,OldTileX
        addi.w  #21,d0
        move.w  d0,d2
        move.w  OldTileY(pc),d3
        moveq   #15,d7
.r_loop:
        move.w  d2,d0
        move.w  d3,d1
        bsr.w   DrawMapTile
        addq.w  #1,d3
        dbf     d7,.r_loop
        bra.s   .chk_right

.chk_left:
        move.w  OldTileX(pc),d0
        cmp.w   d4,d0
        ble.s   .finish_x
        subq.w  #1,d0
        move.w  d0,OldTileX
        move.w  d0,d2
        move.w  OldTileY(pc),d3
        moveq   #15,d7
.l_loop:
        move.w  d2,d0
        move.w  d3,d1
        bsr.w   DrawMapTile
        addq.w  #1,d3
        dbf     d7,.l_loop
        bra.s   .chk_left

.finish_x:
        bra.w   EndBlitterHog

.do_y_stream:
        move.w  #1,DidBlitStrip
        bsr.w   InitBlitterRegs

.chk_down:
        move.w  OldTileY(pc),d1
        cmp.w   d5,d1
        bge.s   .chk_up
        addq.w  #1,d1
        move.w  d1,OldTileY
        addi.w  #15,d1
        move.w  d1,d3
        move.w  OldTileX(pc),d2
        moveq   #21,d7
.d_loop:
        move.w  d2,d0
        move.w  d3,d1
        bsr.w   DrawMapTile
        addq.w  #1,d2
        dbf     d7,.d_loop
        bra.s   .chk_down

.chk_up:
        move.w  OldTileY(pc),d1
        cmp.w   d5,d1
        ble.s   .finish_y
        subq.w  #1,d1
        move.w  d1,OldTileY
        move.w  d1,d3
        move.w  OldTileX(pc),d2
        moveq   #21,d7
.u_loop:
        move.w  d2,d0
        move.w  d3,d1
        bsr.w   DrawMapTile
        addq.w  #1,d2
        dbf     d7,.u_loop
        bra.s   .chk_up

.finish_y:
        bra.w   EndBlitterHog

; ============================================================================
; DRAW MAP TILE (Inlined 4-Mirror Torus Blits)
; Input: d0.w = map_tx (0..127), d1.w = map_ty (0..127), a5 = CUSTOM ($DFF000)
; ============================================================================
DrawMapTile:
        movem.l d2-d5/a0-a2,-(sp)

        andi.w  #$007F,d0
        andi.w  #$007F,d1

        move.w  d1,d2
        andi.w  #$00FE,d2
        lsl.w   #6,d2
        move.w  d0,d3
        andi.w  #$00FE,d3
        add.w   d3,d2
        movea.l CurrentBMap(pc),a2
        move.w  (a2,d2.w),d2

        btst    #0,d1
        beq.s   .top_half
        addq.w  #4,d2
.top_half:
        btst    #0,d0
        beq.s   .left_half
        addq.w  #2,d2
.left_half:
        movea.l CurrentBlks(pc),a2
        moveq   #0,d3
        move.w  (a2,d2.w),d3
        andi.w  #$03FF,d3               ; mask 10-bit tile_id (strip collision bits)
        lsl.l   #5,d3                   ; tile_id * 32
        move.l  d3,d4
        lsl.l   #2,d3                   ; tile_id * 128
        add.l   d4,d3                   ; tile_id * 160
        lea     ActiveTileSheet,a0
        adda.l  d3,a0

        move.w  d1,d3
        andi.w  #15,d3
        move.w  d3,d4
        lsl.w   #2,d4
        lea     RowYTable(pc),a1
        move.l  (a1,d4.w),d4

        move.w  d0,d2
        andi.w  #31,d2
        moveq   #0,d5
        move.w  d2,d5
        add.w   d5,d5
        add.l   d5,d4
        lea     ScreenBuffer,a1
        adda.l  d4,a1

.w1:    btst    #6,DMACONR(a5)
        bne.s   .w1
        move.l  a0,BLTAPTH(a5)
        move.l  a1,BLTDPTH(a5)
        move.w  #$1401,BLTSIZE(a5)

        cmpi.w  #22,d2
        bge.s   .chk_y_mirror
        lea     64(a1),a2
.w2:    btst    #6,DMACONR(a5)
        bne.s   .w2
        move.l  a0,BLTAPTH(a5)
        move.l  a2,BLTDPTH(a5)
        move.w  #$1401,BLTSIZE(a5)

.chk_y_mirror:
        cmpi.w  #14,d3
        bge.s   .done_tile
        adda.l  #(16*TILE_ROW_BYTES),a1
.w3:    btst    #6,DMACONR(a5)
        bne.s   .w3
        move.l  a0,BLTAPTH(a5)
        move.l  a1,BLTDPTH(a5)
        move.w  #$1401,BLTSIZE(a5)

        cmpi.w  #22,d2
        bge.s   .done_tile
        lea     64(a1),a2
.w4:    btst    #6,DMACONR(a5)
        bne.s   .w4
        move.l  a0,BLTAPTH(a5)
        move.l  a2,BLTDPTH(a5)
        move.w  #$1401,BLTSIZE(a5)

.done_tile:
        movem.l (sp)+,d2-d5/a0-a2
        rts

InitBlitterRegs:
        lea     CUSTOM,a5
        move.w  #$8400,DMACON(a5)
        bsr.s   WaitBlitter
        move.w  #$09F0,BLTCON0(a5)
        move.w  #$0000,BLTCON1(a5)
        move.l  #$FFFFFFFF,BLTAFWM(a5)
        move.w  #0,BLTAMOD(a5)
        move.w  #(ROW_PLANE_BYTES-2),BLTDMOD(a5)
        rts

EndBlitterHog:
        lea     CUSTOM,a5
        bsr.s   WaitBlitter
        move.w  #$0400,DMACON(a5)
        rts

WaitBlitter:
        jsr     ServiceBackgroundTasks
        tst.b   CUSTOM+DMACONR
.wait:
        btst    #6,CUSTOM+DMACONR
        bne.s   .wait
        rts

; ============================================================================
; UPDATE COPPER BITPLANE POINTERS & HARDWARE FINE SCROLL
; ============================================================================
UpdateCopperPointers:
        tst.b   ChuteMode
        beq.s   .scrolling_fetch
        ; SPR6/7 occupy DMA slots $30..$36: fetch from $38 during entry.
        ; Chute camera X is held at its initial word-aligned position.
        move.w  #$0038,CopFetchStart+2
        move.w  #(FRAME_ROW_STRIDE-40),CopModulo+2
        move.w  #(FRAME_ROW_STRIDE-40),CopModulo+6
        clr.w   CopScroll+2
        bra.s   .plane_pointers
.scrolling_fetch:
        move.w  #$0030,CopFetchStart+2
        move.w  #(FRAME_ROW_STRIDE-42),CopModulo+2
        move.w  #(FRAME_ROW_STRIDE-42),CopModulo+6
        move.w  CamX(pc),d0
        not.w   d0
        andi.w  #15,d0
        move.w  d0,d1
        lsl.w   #4,d1
        or.w    d1,d0
        move.w  d0,CopScroll+2

.plane_pointers:
        move.w  CamY(pc),d1
        andi.w  #15,d1
        mulu.w  #FRAME_ROW_STRIDE,d1

        movea.l FrameShowPtr(pc),a0
        adda.l  #FRAME_ORIGIN,a0
        adda.l  d1,a0
        move.l  a0,d0

        lea     CopBplPtrs,a1
        moveq   #4,d7
.bpl_loop:
        move.w  d0,6(a1)
        swap    d0
        move.w  d0,2(a1)
        swap    d0
        addi.l  #FRAME_PLANE_BYTES,d0
        addq.l  #8,a1
        dbf     d7,.bpl_loop
        jsr     UpdateParallaxDisplay
        rts

; Compose into the hidden frame. Map streaming never touches a displayed
; frame, and no BOB is erased from the picture being scanned by the display.
ComposeGameFrame:
        ifne BUILD_GFX_PROFILE
        jmp     ComposeFullColourFrame
        endif
        bsr.w   StreamEdges
        bsr.w   StreamEdges            ; finish both axes after diagonal movement
        lea     FrameHistory0,a0
        movea.l FrameDrawPtr(pc),a1
        cmpa.l  #GameFrame0,a1
        beq.s   .history
        lea     FrameHistory1,a0
.history:
        move.l  a0,FrameHistoryPtr
        bsr.w   BuildBobList
        jsr     BuildObjectBobs
        movea.l FrameHistoryPtr(pc),a0
        move.w  OldTileX(pc),d0
        cmp.w   (a0),d0
        bne.s   .full_background
        move.w  OldTileY(pc),d0
        cmp.w   2(a0),d0
        bne.s   .full_background
        bsr.w   FindChangedBobs
        tst.w   ChangedBobCount
        beq.s   .draw
        bsr.w   RestoreFrameBobs
        bra.s   .draw
.full_background:
        bsr.w   MarkAllBobsDirty
        bsr.w   CopyFrameBackground
.draw:
        bsr.w   DrawDirtyBobs
        bsr.w   WaitBlitter
        movea.l FrameHistoryPtr(pc),a0
        move.w  OldTileX(pc),(a0)+
        move.w  OldTileY(pc),(a0)+
        move.w  DrawnCount(pc),d0
        move.w  d0,(a0)+
        beq.s   .ready
        lea     DrawnList,a1
        subq.w  #1,d0
.save_bob:
        move.l  (a1)+,(a0)+
        move.w  (a1)+,(a0)+
        dbf     d0,.save_bob
.ready:

        ; A long render may have left an old Copper interrupt pending. Discard
        ; it and wait for a fresh bottom border before changing display pointers.
        move.w  #$0010,CUSTOM+INTREQ
        bsr.w   WaitVBL
        move.l  FrameShowPtr(pc),d0
        move.l  FrameDrawPtr(pc),FrameShowPtr
        move.l  d0,FrameDrawPtr
        bsr.w   UpdateCopperPointers
        tst.b   GameOverMode
        beq.s   .sprites
        jsr     HideGameSprites
        rts
.sprites:
        bsr.w   UpdateSprites
        rts

MarkAllBobsDirty:
        lea     BobDrawFlags,a0
        moveq   #-1,d0
        moveq   #31,d1
.fill:  move.l  d0,(a0)+
        dbf     d1,.fill
        move.w  #128,ChangedBobCount
        rts

; Match the stable painter-order list against this hidden frame's history.
; A changed list length redraws all BOBs. Otherwise retain identical BOBs and
; expand a conservative dirty rectangle through every overlapping footprint,
; so cached foreground objects keep their original priority over moving ones.
FindChangedBobs:
        lea     BobDrawFlags,a0
        moveq   #31,d0
.clear: clr.l   (a0)+
        dbf     d0,.clear
        clr.w   ChangedBobCount
        movea.l FrameHistoryPtr(pc),a1
        move.w  4(a1),d0
        cmp.w   BobCount(pc),d0
        bne.w   MarkAllBobsDirty
        tst.w   d0
        beq.w   .done
        move.w  #32767,DirtyLeft
        move.w  #32767,DirtyTop
        move.w  #-32768,DirtyRight
        move.w  #-32768,DirtyBottom
        addq.l  #6,a1
        lea     BobList,a2
        lea     BobDrawFlags,a3
        move.w  d0,d7
        subq.w  #1,d7
.compare:
        move.l  (a1),d0
        cmp.l   (a2),d0
        bne.s   .changed
        move.w  4(a1),d0
        cmp.w   4(a2),d0
        beq.s   .next
.changed:
        move.b  #1,(a3)
        addq.w  #1,ChangedBobCount
        move.w  (a1),d4
        move.w  2(a1),d5
        bsr.w   GrowDirtyRect
        move.w  (a2),d4
        move.w  2(a2),d5
        bsr.w   GrowDirtyRect
.next:
        addq.l  #6,a1
        addq.l  #6,a2
        addq.l  #1,a3
        dbf     d7,.compare
        tst.w   ChangedBobCount
        beq.s   .done
.expand:
        clr.b   DirtyExpanded
        lea     BobList,a2
        lea     BobDrawFlags,a3
        move.w  BobCount(pc),d7
        subq.w  #1,d7
.overlap:
        tst.b   (a3)
        bne.s   .overlap_next
        move.w  (a2),d4
        move.w  d4,d0
        andi.w  #$FFF0,d0
        cmp.w   DirtyRight(pc),d0
        bge.s   .overlap_next
        addi.w  #48,d0
        cmp.w   DirtyLeft(pc),d0
        ble.s   .overlap_next
        move.w  2(a2),d5
        cmp.w   DirtyBottom(pc),d5
        bge.s   .overlap_next
        move.w  d5,d0
        addi.w  #32,d0
        cmp.w   DirtyTop(pc),d0
        ble.s   .overlap_next
        move.b  #1,(a3)
        addq.w  #1,ChangedBobCount
        bsr.s   GrowDirtyRect
.overlap_next:
        addq.l  #6,a2
        addq.l  #1,a3
        dbf     d7,.overlap
        tst.b   DirtyExpanded
        bne.s   .expand
.done:  rts

; d4/d5=world BOB origin. The blitter footprint is three words by32 rows.
GrowDirtyRect:
        move.w  d4,d0
        andi.w  #$FFF0,d0
        cmp.w   DirtyLeft(pc),d0
        bge.s   .right
        move.w  d0,DirtyLeft
        move.b  #1,DirtyExpanded
.right:
        addi.w  #48,d0
        cmp.w   DirtyRight(pc),d0
        ble.s   .top
        move.w  d0,DirtyRight
        move.b  #1,DirtyExpanded
.top:
        cmp.w   DirtyTop(pc),d5
        bge.s   .bottom
        move.w  d5,DirtyTop
        move.b  #1,DirtyExpanded
.bottom:
        move.w  d5,d0
        addi.w  #32,d0
        cmp.w   DirtyBottom(pc),d0
        ble.s   .done
        move.w  d0,DirtyBottom
        move.b  #1,DirtyExpanded
.done:  rts

; A reused frame has its own previous BOB list. Copy their 48px-wide word
; footprints from the clean map cache before drawing any current objects.
RestoreFrameBobs:
        movea.l FrameHistoryPtr(pc),a3
        move.w  4(a3),d6
        beq.w   .done
        addq.l  #6,a3
        lea     BobDrawFlags,a4
        lea     CUSTOM,a5
        bsr.w   WaitBlitter
        move.w  #$8400,DMACON(a5)
        move.w  #$09F0,BLTCON0(a5)
        clr.w   BLTCON1(a5)
        move.l  #$FFFFFFFF,BLTAFWM(a5)
        subq.w  #1,d6
.bob:
        move.w  (a3)+,d4
        move.w  (a3)+,d5
        moveq   #0,d3
        move.w  (a3)+,d3
        tst.b   (a4)+
        beq.w   .skip
        lsl.w   #2,d3
        lea     BobBoundsData,a2
        adda.w  d3,a2
        moveq   #0,d0
        move.b  (a2),d0
        add.w   d0,d5                 ; restore only the rows that were drawn
        moveq   #0,d7
        move.b  3(a2),d7
        move.w  d4,d0
        andi.w  #15,d0
        beq.s   .width_ready
        addq.w  #1,d7
.width_ready:
        moveq   #0,d3
        move.b  1(a2),d3
        mulu.w  #NUM_PLANES,d3
        lsl.w   #6,d3
        or.w    d7,d3
        move.w  d5,d0
        andi.w  #255,d0
        mulu.w  #ROW_STRIDE,d0
        lea     ScreenBuffer,a0
        adda.l  d0,a0
        move.w  d4,d0
        asr.w   #4,d0
        move.w  d0,d1
        andi.w  #31,d0
        add.w   d0,d0
        moveq   #0,d2
        move.b  2(a2),d2
        add.w   d2,d0
        adda.w  d0,a0
        sub.w   OldTileX(pc),d1
        addq.w  #2,d1
        add.w   d1,d1
        add.w   d2,d1
        move.w  OldTileY(pc),d0
        lsl.w   #4,d0
        move.w  d5,d2
        sub.w   d0,d2
        addi.w  #32,d2
        mulu.w  #FRAME_ROW_STRIDE,d2
        movea.l FrameDrawPtr(pc),a1
        adda.l  d2,a1
        adda.w  d1,a1
        bsr.w   WaitBlitter
        add.w   d7,d7
        neg.w   d7
        addi.w  #ROW_PLANE_BYTES,d7
        move.w  d7,BLTAMOD(a5)
        addi.w  #(FRAME_PLANE_BYTES-ROW_PLANE_BYTES),d7
        move.w  d7,BLTDMOD(a5)
        move.l  a0,BLTAPTH(a5)
        move.l  a1,BLTDPTH(a5)
        move.w  d3,BLTSIZE(a5)
.skip:
        dbf     d6,.bob
        bra.w   EndBlitterHog
.done:  rts

CopyFrameBackground:
        lea     CUSTOM,a5
        bsr.w   WaitBlitter
        move.w  #$8400,DMACON(a5)
        move.w  #$09F0,BLTCON0(a5)
        clr.w   BLTCON1(a5)
        move.l  #$FFFFFFFF,BLTAFWM(a5)
        move.w  #(ROW_PLANE_BYTES-44),BLTAMOD(a5)
        move.w  #(FRAME_PLANE_BYTES-44),BLTDMOD(a5)
        move.w  OldTileY(pc),d0
        andi.w  #15,d0
        mulu.w  #TILE_ROW_BYTES,d0
        lea     ScreenBuffer,a0
        adda.l  d0,a0
        move.w  OldTileX(pc),d0
        andi.w  #31,d0
        add.w   d0,d0
        adda.w  d0,a0
        movea.l FrameDrawPtr(pc),a1
        adda.l  #FRAME_ORIGIN,a1
        ; 240 lines cover the 224px view plus up to15px fine Y scroll. Split
        ; into two 600-row blits to respect the OCS 1024-row BLTSIZE limit.
        moveq   #1,d7
.half:
        bsr.w   WaitBlitter
        move.l  a0,BLTAPTH(a5)
        move.l  a1,BLTDPTH(a5)
        move.w  #((120*NUM_PLANES<<6)|22),BLTSIZE(a5)
        adda.l  #(120*ROW_STRIDE),a0
        adda.l  #(120*FRAME_ROW_STRIDE),a1
        dbf     d7,.half
        bra.w   EndBlitterHog

; ============================================================================
; WAIT FOR END-OF-VIEWPORT COPPER LATCH (Scanline 284 / $11C)
; ============================================================================
WaitVBL:
        btst    #4,CUSTOM+INTREQR+1
        beq.s   WaitVBL
        move.w  #$0010,CUSTOM+INTREQ
        rts

; CIA-A's existing 24-bit TOD counter is clocked by vertical sync. Reading
; high first latches the low16 bits until low is read; no timer is reconfigured.
ReadGameClock:
        move.b  $BFEA01,d0
        moveq   #0,d0
        move.b  $BFE901,d0
        lsl.w   #8,d0
        move.b  $BFE801,d0
        rts

ResetGameClock:
        bsr.s   ReadGameClock
        move.w  d0,LogicClockLast
        move.w  #1,LogicSteps
        rts

CountGameLogicSteps:
        bsr.s   ReadGameClock
        move.w  d0,d1
        sub.w   LogicClockLast(pc),d1
        move.w  d0,LogicClockLast
        tst.w   d1
        bne.s   .elapsed
        moveq   #1,d1
.elapsed:
        cmpi.w  #4,d1
        bls.s   .bounded
        moveq   #4,d1                  ; bound catch-up under extreme rendering load
.bounded:
        move.w  d1,LogicSteps
        rts

; ============================================================================
; POLL AMIGA KEYBOARD (CIAA SDR + Handshake)
; ============================================================================
PollKeyboard:
        lea     KeyState(pc),a0
.drain_keys:
        btst    #3,CIAAICR
        beq.s   .done_keys
        move.b  CIAASDR,d0
        ori.b   #$40,CIAACRA
        ; HRM keyboard handshake >=85us. Three beam-line changes take at
        ; least128us on PAL, independent of the selected CPU multiplier.
        move.w  d2,-(sp)
        moveq   #2,d1
.hs_wait:
        move.b  VHPOSR+CUSTOM,d2
.hs_line:
        cmp.b   VHPOSR+CUSTOM,d2
        beq.s   .hs_line
        dbf     d1,.hs_wait
        move.w  (sp)+,d2
        andi.b  #$BF,CIAACRA

        not.b   d0
        ror.b   #1,d0
        move.w  d0,d1
        andi.w  #$007F,d1
        btst    #7,d0
        seq     (a0,d1.w)
        bra.s   .drain_keys
.done_keys:
        rts

; ============================================================================
; HUD RENDERING (8x8 Arcade Font in Bottom 16-Scanline Split)
; ============================================================================
RenderHudBanner:
        lea     HudBuffer,a0
        move.w  #(640/4)-1,d7
.clr:   clr.l   (a0)+
        dbf     d7,.clr

        move.l  #HudBuffer,d0
        lea     CopHudBpl,a1
        move.w  d0,6(a1)
        swap    d0
        move.w  d0,2(a1)

        move.w  CurrentStage(pc),d0
        mulu.w  #24,d0
        lea     StageDirectory(pc),a4
        adda.w  d0,a4
        movea.l 20(a4),a0
        lea     HudBuffer+1,a1
        bsr.s   DrawHudString
        jsr     RenderRoundStageHud
        rts

DrawHudHex12:
        move.w  d0,d2
        moveq   #2,d3
        rol.w   #4,d2
.hex_lp:
        rol.w   #4,d2
        move.w  d2,d0
        andi.w  #$000F,d0
        cmpi.w  #10,d0
        blt.s   .is_dig
        addi.w  #'A'-10,d0
        bra.s   .put
.is_dig:
        addi.w  #'0',d0
.put:   bsr.s   DrawHudChar
        dbf     d3,.hex_lp
        rts

DrawHudString:
        moveq   #0,d0
        move.b  (a0)+,d0
        beq.s   .done
        bsr.s   DrawHudChar
        bra.s   DrawHudString
.done:  rts

DrawHudChar:
        subi.w  #$20,d0
        andi.w  #$003F,d0
        lsl.w   #3,d0
        lea     ArcadeFont,a2
        adda.w  d0,a2
        move.b  0(a2),0*40(a1)
        move.b  1(a2),1*40(a1)
        move.b  2(a2),2*40(a1)
        move.b  3(a2),3*40(a1)
        move.b  4(a2),4*40(a1)
        move.b  5(a2),5*40(a1)
        move.b  6(a2),6*40(a1)
        move.b  7(a2),7*40(a1)
        addq.l  #1,a1
        rts

; ============================================================================
; LZSS DECOMPRESSOR
; ============================================================================
LZSS_Decompress:
        move.l  (a0)+,d7
        adda.l  d7,a1
        movea.l a1,a3
        suba.l  d7,a1
.outer:
        cmpa.l  a3,a1
        bge.s   .done
        move.b  (a0)+,d6
        moveq   #7,d5
.bit_loop:
        cmpa.l  a3,a1
        bge.s   .done
        btst    d5,d6
        beq.s   .match
        move.b  (a0)+,(a1)+
        dbf     d5,.bit_loop
        bra.s   .outer
.match:
        moveq   #0,d0
        move.b  (a0)+,d0
        lsl.w   #8,d0
        move.b  (a0)+,d0
        move.w  d0,d1
        lsr.w   #4,d0
        andi.w  #$000F,d1
        addq.w  #2,d1
        movea.l a1,a2
        suba.w  d0,a2
.copy_lp:
        move.b  (a2)+,(a1)+
        dbf     d1,.copy_lp
        dbf     d5,.bit_loop
        bra.s   .outer
.done:  rts

; ============================================================================
; PAULA 4-CHANNEL MAME YM2151 ARCADE AUDIO ENGINE
;   - Streams actual YM2151 OPM 8-channel FM Stage 1 In-Game Music recorded
;     directly from MAME (`mame bionicc`, Sound ID $01) via hardware-latched
;     double buffering (`AudioBufA` / `AudioBufB`, 2,048 bytes per block at
;     PER = 465 / 7,628 Hz) on AUD0 (Left) + AUD1 (Right).
;   - Plays captured native sound IDs on AUD2 + AUD3, with their full lengths.
;     $13 arm launch, $12 latch, $14 gun; $16/$1A/$1E enemy deaths, $20 Joe
;     fatal lying pose, $19 heavy projectile and $22 live hive buzz.
;   - Press 'M' ($37) to toggle music mute on/off.
; ============================================================================
InitArcadeAudio:
        lea     CUSTOM,a5
        move.w  #$000F,DMACON(a5)       ; Disable AUD0..AUD3 DMA during setup
        move.w  #$0780,INTREQ(a5)       ; Clear AUD0..AUD3 interrupt request bits

        clr.w   MusicBlockIdx
        clr.b   MusicMuted
        clr.b   SfxState

        ; Pre-fill AudioBufA (Block 0) and AudioBufB (Block 1) from Fast RAM
        lea     AudioBufA,a1
        bsr.w   CopyNextMusicBlock
        lea     AudioBufB,a1
        bsr.w   CopyNextMusicBlock

        ; Point AUD0 (Left) & AUD1 (Right) to AudioBufA (1024 words = 2048 bytes)
        move.l  #AudioBufA,AUD0LCH(a5)
        move.w  #1024,AUD0LEN(a5)
        move.w  #465,AUD0PER(a5)        ; 7,628 Hz PAL
        move.w  #56,AUD0VOL(a5)

        move.l  #AudioBufA,AUD1LCH(a5)
        move.w  #1024,AUD1LEN(a5)
        move.w  #465,AUD1PER(a5)
        move.w  #56,AUD1VOL(a5)

        ; Point AUD2 & AUD3 to SilenceBuf initially
        move.l  #SilenceBuf,AUD2LCH(a5)
        move.w  #16,AUD2LEN(a5)
        move.w  #465,AUD2PER(a5)
        move.w  #0,AUD2VOL(a5)

        move.l  #SilenceBuf,AUD3LCH(a5)
        move.w  #16,AUD3LEN(a5)
        move.w  #465,AUD3PER(a5)
        move.w  #0,AUD3VOL(a5)

        ; MusicState = 1: waiting for initial AudioBufA latch so we can queue AudioBufB
        move.b  #1,MusicState
        move.w  #$8203,DMACON(a5)       ; Enable AUD0 + AUD1 DMA!
        rts

; Copy 2,048 bytes (512 longwords) from Fast RAM (MusicPart1 / MusicPart2) to a1
CopyNextMusicBlock:
        movem.l d0-d1/a0,-(sp)
        moveq   #0,d0
        move.w  MusicBlockIdx(pc),d0
        move.w  d0,d1
        addq.w  #1,d1
        cmpi.w  #204,d1                 ; Reached end of 54.9s track (Block 204)?
        blt.s   .idx_ok
        moveq   #13,d1                  ; Loop seamlessly back to Block 13 (bar-1 after Intro)!
.idx_ok:
        move.w  d1,MusicBlockIdx

        cmpi.w  #102,d0
        blt.s   .in_part1
        subi.w  #102,d0
        lsl.l   #8,d0
        lsl.l   #3,d0                   ; (block - 102) * 2048
        lea     MusicPart2,a0
        adda.l  d0,a0
        bra.s   .do_copy
.in_part1:
        lsl.l   #8,d0
        lsl.l   #3,d0                   ; block * 2048
        lea     MusicPart1,a0
        adda.l  d0,a0
.do_copy:
        move.w  #(2048/16)-1,d0         ; Copy 2048 bytes (128 x 16B)
.cp_lp:
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        move.l  (a0)+,(a1)+
        dbf     d0,.cp_lp
        movem.l (sp)+,d0-d1/a0
        rts

; Trigger one-shot 2,048-byte MAME YM2151 SFX sample pointed to by a1 on AUD2+AUD3
TriggerSFX:
        move.w  #$000C,CUSTOM+DMACON    ; Stop AUD2+AUD3 DMA immediately so Paula resets
        move.l  a1,PendingSfxPtr
        move.w  #1024,PendingSfxWords
        move.w  #465,PendingSfxPeriod
        move.b  #1,SfxState
        rts

UpdateAudio:
        movem.l d0-d1/a0-a1/a5,-(sp)
        lea     CUSTOM,a5
        tst.w   NativeSfxBusyTicks
        beq.s   .busy_ready
        subq.w  #1,NativeSfxBusyTicks
.busy_ready:
        tst.b   UiPage
        bne.s   .ambient_done
        tst.b   AttractMode
        beq.s   .ambient_play
        tst.b   AttractPhase
        beq.s   .ambient_done
.ambient_play:
        jsr     UpdateNativeAmbient
.ambient_done:

        ; 1. Check 'M' key ($37) edge-trigger to toggle Music Mute
        lea     KeyState(pc),a0
        move.b  $37(a0),d0
        beq.s   .no_m_edge
        tst.b   PrevMuteKey
        bne.s   .no_m_edge
        not.b   MusicMuted
        beq.s   .unmute_mus
        move.w  #0,AUD0VOL(a5)
        move.w  #0,AUD1VOL(a5)
        bra.s   .no_m_edge
.unmute_mus:
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        bhs.s   .pcm_volume
        tst.w   CurrentMusicTrack
        bne.s   .no_m_edge
.pcm_volume:
        move.w  #56,AUD0VOL(a5)
        move.w  #56,AUD1VOL(a5)
.no_m_edge:
        move.b  d0,PrevMuteKey
        tst.w   CurrentMusicTrack
        beq.s   .amiga_tick_done
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        blo.s   .amiga_tick
        jsr     TickC64Music
        bra.s   .amiga_tick_done
.amiga_tick:
        jsr     TickAmigaMusic
.amiga_tick_done:

        ; 2. Handle AUD2+AUD3 Centered Stereo One-Shot SFX State Machine
        cmpi.b  #1,SfxState
        bne.s   .chk_sfx_latch
        ; State 1: Start AUD2+AUD3 DMA on PendingSfxPtr (2048 bytes = 1024 words)
        move.l  PendingSfxPtr(pc),d0
        move.l  d0,AUD2LCH(a5)
        move.l  d0,AUD3LCH(a5)
        move.w  PendingSfxWords,AUD2LEN(a5)
        move.w  PendingSfxWords,AUD3LEN(a5)
        move.w  PendingSfxPeriod,AUD2PER(a5)
        move.w  PendingSfxPeriod,AUD3PER(a5)
        move.w  #64,AUD2VOL(a5)         ; Full volume (64)
        move.w  #64,AUD3VOL(a5)
        move.w  #$0600,INTREQ(a5)
        move.w  #$820C,DMACON(a5)       ; Enable AUD2 + AUD3 DMA!
        move.b  #2,SfxState
        bra.s   .sfx_done
.chk_sfx_latch:
        cmpi.b  #2,SfxState
        bne.s   .sfx_done
        btst    #1,INTREQR(a5)          ; wait for the actual AUD2 block latch
        beq.s   .sfx_done
        move.w  #$0600,INTREQ(a5)
        ; State 2 (1 frame later): Queue SilenceBuf into AUD2/AUD3 LCH/LEN so after
        ; the 2048-byte SFX finishes playing once, Paula loops silently on 32 zero bytes!
        move.l  #SilenceBuf,AUD2LCH(a5)
        move.w  #16,AUD2LEN(a5)
        move.l  #SilenceBuf,AUD3LCH(a5)
        move.w  #16,AUD3LEN(a5)
        clr.b   SfxState
.sfx_done:
        bsr.w   ServiceArcadeMusicDMA
.audio_done:
        movem.l (sp)+,d0-d1/a0-a1/a5
        rts

; Pure audio-DMA maintenance; no simulation, ambient sounds or music ticks.
ServiceArcadeMusicDMA:
        tst.b   MusicInitialized
        beq.w   .quick_return
        cmpi.w  #C64_JUKEBOX_FIRST,CurrentMusicTrack
        blo.s   .arcade
        jmp     ServiceC64MusicDMA
.arcade:
        tst.w   CurrentMusicTrack
        bne.w   .quick_return
        movem.l d0-d1/a0-a1/a5,-(sp)
        lea     CUSTOM,a5

        ; 3. Check if Paula AUD0 just latched its next 2,048-byte buffer (INTREQR bit 7)
        btst    #7,INTREQR+1(a5)
        beq.s   .done
        move.w  #$0180,INTREQ(a5)       ; Clear AUD0 + AUD1 interrupt request flags

        cmpi.b  #1,MusicState
        bne.s   .chk_ms2
        ; MusicState 1: AudioBufA just started -> queue pre-filled AudioBufB for next swap!
        move.l  #AudioBufB,AUD0LCH(a5)
        move.l  #AudioBufB,AUD1LCH(a5)
        move.b  #2,MusicState
        bra.s   .done

.chk_ms2:
        cmpi.b  #2,MusicState
        bne.s   .ms3
        ; MusicState 2: AudioBufA finished and AudioBufB is now playing -> refill & queue AudioBufA!
        lea     AudioBufA,a1
        bsr.w   CopyNextMusicBlock
        move.l  #AudioBufA,AUD0LCH(a5)
        move.l  #AudioBufA,AUD1LCH(a5)
        move.b  #3,MusicState
        bra.s   .done

.ms3:
        ; MusicState 3: AudioBufB finished and AudioBufA is now playing -> refill & queue AudioBufB!
        lea     AudioBufB,a1
        bsr.w   CopyNextMusicBlock
        move.l  #AudioBufB,AUD0LCH(a5)
        move.l  #AudioBufB,AUD1LCH(a5)
        move.b  #2,MusicState

.done:
        movem.l (sp)+,d0-d1/a0-a1/a5
.quick_return:
        rts

; ============================================================================
; CLEAN SHUTDOWN & RESTORE AMIGAOS
; ============================================================================
ShutDown:
        lea     CUSTOM,a5
        bsr.w   WaitBlitter
        move.w  #0,AUD0VOL(a5)
        move.w  #0,AUD1VOL(a5)
        move.w  #0,AUD2VOL(a5)
        move.w  #0,AUD3VOL(a5)
        move.w  #$7FFF,INTENA(a5)
        move.w  #$7FFF,INTREQ(a5)
        move.w  #$7FFF,DMACON(a5)

        ifne BUILD_WHDLOAD
        jsr     SavePreferences
        movea.l WHDQuitCallback(pc),a0
        jmp     (a0)                   ;WHDLoad restores the saved host system
        else
        movea.l GfxBase(pc),a6
        move.l  gb_copinit(a6),COP1LCH(a5)
        move.w  #0,COPJMP1(a5)

        move.w  OldDmacon(pc),DMACON(a5)
        move.w  OldIntena(pc),INTENA(a5)

        movea.l OldView(pc),a1
        jsr     _LVOLoadView(a6)
        jsr     _LVOWaitTOF(a6)
        jsr     _LVOWaitTOF(a6)
        jsr     _LVODisownBlitter(a6)

        movea.l a6,a1
        movea.l 4.w,a6
        jsr     _LVOCloseLibrary(a6)
        jsr     SavePreferences

ExitToDOS:
        movem.l (sp)+,d0-d7/a0-a6
        moveq   #0,d0
        rts
        endif

; ============================================================================
; VARIABLES, SIN/COS TABLES & STAGE DIRECTORY
; ============================================================================
        ifne BUILD_WHDLOAD
WHDQuitCallback: dc.l 0
WHDPreferencesCallback: dc.l 0
WHDQuitKey:     dc.b $59
                EVEN
        endif
GfxBase:        dc.l 0
OldView:        dc.l 0
OldIntena:      dc.w 0
OldDmacon:      dc.w 0

CurrentStage:   dc.w 0
CamX:           dc.w 0
CamY:           dc.w 0
OldTileX:       dc.w 0
OldTileY:       dc.w 0
DidBlitStrip:   dc.w 0
FrameDrawPtr:   dc.l GameFrame0
FrameShowPtr:   dc.l GameFrame1
FrameHistoryPtr: dc.l FrameHistory0
FrameHistory0:  dc.w -1,-1,0
               ds.b (128*6)
FrameHistory1:  dc.w -1,-1,0
               ds.b (128*6)
BobDrawFlags:   ds.b 128
ChangedBobCount: dc.w 0
DirtyLeft:      dc.w 0
DirtyTop:       dc.w 0
DirtyRight:     dc.w 0
DirtyBottom:    dc.w 0
DirtyExpanded:  dc.b 0
                EVEN
LogicClockLast: dc.w 0
LogicSteps:     dc.w 1
PrevHudX:       dc.w -1
PrevHudY:       dc.w -1

; --- Super Joe & Bionic Arm State Variables ---
PlayerX:        dc.w 176
PlayerY:        dc.w 2000
PlayerVX:       dc.w 0
PlayerVY:       dc.w 0
ChuteReleaseY:  dc.w 0
EntryTargetY:   dc.w 0
EntryFraction:  dc.w 0
EntryStepPhase: dc.w 0
ChuteClipRows:  dc.w -1
ChuteVisibleRows: dc.w 64
PadSerialRaw:   dc.w 0
SwingPrevFeetY: dc.w 0
PlayerPlatformIndex: dc.w -1
ClawPlatformIndex: dc.w -1
ObjectCount:    dc.w 0
ObjectPlatformCount: dc.w 0
FacingDir:      dc.w 1                  ; 1 = Right, 0 = Left
PrevPoseIdx:    dc.w -1
JoeSpriteHeight: dc.w 32
JoeSpriteTopOffset: dc.w 32
AnimTick:       dc.w 0
ArmAnimTick:    dc.w 0
CurrentSwingAng:dc.w 9
ArmDistStep:    dc.w 12

ClawX:          dc.w 0
ClawY:          dc.w 0
ClawVX:         dc.w 0
ClawVY:         dc.w 0
GrappleDir:     dc.w 1
GrappleDist:    dc.w 0
AnchorX:        dc.w 0
AnchorY:        dc.w 0
AnchorSurfaceY: dc.w 0
SwingRadius:    dc.w 48
SwingAngle:     dc.w 0                  ; 8.8 fixed point (-64..+64 deg)
SwingOmega:     dc.w 0                  ; 8.8 fixed point angular velocity

Lives:          dc.w 3
OnGround:       dc.b 1
ChuteMode:      dc.b 0                  ; 1 = parachuting down (spawn / respawn)
EntryActive:    dc.b 0                  ; input locked until the floor, including free fall
PadButtons:     dc.b 0                  ; CD32 bits: Blue/B=0, Red/A=1, Play/Start=6
PadIsCD32:      dc.b 0
GrappleState:   dc.b 0                  ; 0=Idle, 1=Extend, 2=Retract, 3=Swing, 4=Climb
RetractTimer:   dc.b 0
DropTimer:      dc.b 0
LatchAnimTimer: dc.b 0
VaultFlipTimer: dc.b 0
FlyMode:        dc.b 0
InputDirs:      dc.b 0
PrevFireBtn:    dc.b 0
FireJustPressed:dc.b 0
PrevJumpBtn:    dc.b 0
JumpJustPressed:dc.b 0
WasUpHeld:      dc.b 0
PrevNextKey:    dc.b 0
PrevFlyKey:     dc.b 0
PrevMuteKey:    dc.b 0
MusicMuted:     dc.b 0
SfxState:       dc.b 0
MusicState:     dc.b 0
AttractMode:    dc.b 1                  ; 1 = attract/title screen
AttractPhase:   dc.b 0                  ; 0 = original title, 2 = playable demo
GameOverMode:   dc.b 0
GameOverStartHeld: dc.b 0
                EVEN
AttractTimer:   dc.w 0
GameOverTimer:  dc.w 0

PendingSfxPtr:  dc.l 0
MusicBlockIdx:  dc.w 0

; Scratch list for up to 10 Bionic Arm Links (6 bytes each: ScreenX.w, ScreenY.w, TileIdx.w)
ArmLinkList:    ds.w 30

; Exact Arcade 19-Angle Swing Pose Tables ($148F4 Left, $14942 Right)
ArcadeSwingPoseLeft:
        dc.b 12,12,12,12,12,12, 13,13,13,13, 14,14,14,14, 15,15,15,15,15
ArcadeSwingPoseRight:
        dc.b 15,15,15,15,15, 14,14,14,14, 13,13,13,13, 12,12,12,12,12,12

; Exact Arcade 19-Angle Clamped Grabber Claw Tile Table ($15616)
ArcadeSwingClawTable:
        dc.b 37,37,37, 30,30,30,30,30, 24,24,24, 36,36,36,36,36, 38,38,38
        EVEN

; Exact Arcade 19-Angle Pendulum Wire Step Table ($151CE, 12.00 px/link in 8.8 fixed point)
ArcadeWireStepTable:
        dc.w -3000,  -588               ; Ang  0 (-98 deg)
        dc.w -3072,     0               ; Ang  1 (-90 deg)
        dc.w -3000,   588               ; Ang  2 (-80 deg)
        dc.w -2832,  1164               ; Ang  3 (-70 deg)
        dc.w -2544,  1704               ; Ang  4 (-58 deg)
        dc.w -2160,  2160               ; Ang  5 (-45 deg)
        dc.w -1704,  2544               ; Ang  6 (-32 deg)
        dc.w -1164,  2832               ; Ang  7 (-20 deg)
        dc.w  -588,  3000               ; Ang  8 (-10 deg)
        dc.w     0,  3072               ; Ang  9 (  0 deg Vertical)
        dc.w   588,  3000               ; Ang 10 (+10 deg)
        dc.w  1164,  2832               ; Ang 11 (+20 deg)
        dc.w  1704,  2544               ; Ang 12 (+32 deg)
        dc.w  2160,  2160               ; Ang 13 (+45 deg)
        dc.w  2544,  1704               ; Ang 14 (+58 deg)
        dc.w  2832,  1164               ; Ang 15 (+70 deg)
        dc.w  3000,   588               ; Ang 16 (+80 deg)
        dc.w  3072,     0               ; Ang 17 (+90 deg)
        dc.w  3000,  -588               ; Ang 18 (+98 deg)

CurrentPal:     dc.l 0
CurrentBMap:    dc.l 0
CurrentBlks:    dc.l 0
CurrentTilesLZ: dc.l 0

KeyState:       ds.b 128

; Precomputed byte offsets for 16 tile rows in ScreenBuffer (by * 8640)
RowYTable:
        dc.l 0*8640,  1*8640,  2*8640,  3*8640
        dc.l 4*8640,  5*8640,  6*8640,  7*8640
        dc.l 8*8640,  9*8640,  10*8640, 11*8640
        dc.l 12*8640, 13*8640, 14*8640, 15*8640

; 129-entry Sin/Cos Tables for Pendulum Angles -64..+64 (-90 deg .. +90 deg, scaled by 256)
SinTable:
        dc.w -256,-256,-256,-255,-255,-254,-253,-252,-251,-250,-248,-247,-245,-243,-241,-239
        dc.w -237,-234,-232,-229,-226,-223,-220,-217,-213,-209,-206,-202,-198,-194,-190,-185
        dc.w -181,-176,-172,-167,-162,-157,-152,-147,-142,-136,-131,-125,-120,-114,-109,-103
        dc.w  -97, -91, -85, -79, -73, -67, -61, -55, -49, -43, -37, -31, -25, -19, -13,  -6
        dc.w    0,   6,  13,  19,  25,  31,  37,  43,  49,  55,  61,  67,  73,  79,  85,  91
        dc.w   97, 103, 109, 114, 120, 125, 131, 136, 142, 147, 152, 157, 162, 167, 172, 176
        dc.w  181, 185, 190, 194, 198, 202, 206, 209, 213, 217, 220, 223, 226, 229, 232, 234
        dc.w  237, 239, 241, 243, 245, 247, 248, 250, 251, 252, 253, 254, 255, 255, 256, 256
        dc.w  256

CosTable:
        dc.w    0,   6,  13,  19,  25,  31,  37,  43,  49,  55,  61,  67,  73,  79,  85,  91
        dc.w   97, 103, 109, 114, 120, 125, 131, 136, 142, 147, 152, 157, 162, 167, 172, 176
        dc.w  181, 185, 190, 194, 198, 202, 206, 209, 213, 217, 220, 223, 226, 229, 232, 234
        dc.w  237, 239, 241, 243, 245, 247, 248, 250, 251, 252, 253, 254, 255, 255, 256, 256
        dc.w  256, 256, 256, 255, 255, 254, 253, 252, 251, 250, 248, 247, 245, 243, 241, 239
        dc.w  237, 234, 232, 229, 226, 223, 220, 217, 213, 209, 206, 202, 198, 194, 190, 185
        dc.w  181, 176, 172, 167, 162, 157, 152, 147, 142, 136, 131, 125, 120, 114, 109, 103
        dc.w   97,  91,  85,  79,  73,  67,  61,  55,  49,  43,  37,  31,  25,  19,  13,   6
        dc.w    0

; Stage Directory (24 bytes per entry: Pal, BMap, Blks, TilesLZ, SpawnX.w, SpawnY.w, TitlePtr)
StageDirectory:
        ; Stage 1: original entry center X=128; first landing is the stone floor.
        dc.l Stage0_Pal, Stage0_BMap, Stage0_Blks, Stage0_TilesLZ
        dc.w 128, 2002
        dc.l TitleStage1

TitleStage1:    dc.b "1:BASE ENTRANCE",0
                EVEN
EditionDemoMode: dc.w BUILD_DEMO
EditionStageCount: dc.w GAME_STAGE_COUNT
GfxName:        dc.b "graphics.library",0
                EVEN

        include "enemies.i"
        include "inputs.i"
        include "attract.i"
        include "object_defs.i"
        include "object_spawns.i"
        include "objects.i"
        include "object_bank_defs.i"
        include "object_loader.i"
        include "music_loader.i"
        include "parallax.i"
        include "native_sfx_defs.i"
        include "native_audio.i"
        include "level_bonus.i"
        include "death.i"
        include "progression.i"
        include "progression_ui.i"
        include "highscores.i"
        include "front_end.i"
        include "music_selection.i"
        include "c64_music.i"
        include "amiga_music.i"
        include "fps.i"
        include "graphics_profile.i"
        include "loading.i"
        include "title_graphics.i"
        ifne BUILD_GFX_PROFILE
        include "fullcolor_assets.i"
        include "fullcolor_render.i"
        include "fullcolor_background_fast.i"
        endif

; ============================================================================
; FONT, SPRITES & STAGE ASSETS (Separate Hunks for Kickstart 1.x Compatibility)
; ============================================================================
        SECTION PackedSprites,DATA
SpriteAssetsLZ:
        incbin "data/sprite_assets.lz"
ArmSpritesData  EQU (JoeSpritesData+20480)
ArmTileBounds   EQU (ArmSpritesData+5120)
        EVEN

        SECTION AttractData,DATA
        include "attract_motion_defs.i"
        include "attract_motion_poses.i"
DemoMotionLZ: incbin "data/attract_motion.lz"
        EVEN
DemoExtraPosesLZ: incbin "data/attract_extra_poses.lz"
        EVEN
AttractTitlePalette:
        ifne BUILD_GFX_PROFILE
        incbin "data/attract_title_full_pal_hi.bin"
        else
        incbin "data/attract_title_reduced_pal.bin"
        endif
AttractTitleLZ:
        ifne BUILD_GFX_PROFILE
        incbin "data/attract_title_full.lz"
        else
        incbin "data/attract_title_reduced.lz"
        endif
        EVEN

        SECTION ObjectData,DATA
        ifeq BUILD_GFX_PROFILE
        include "object_bank_data.i"
        else
ObjectDataLZ0: dc.l 0               ;reduced-bank compatibility labels only
ObjectDataLZ1: dc.l 0
        endif
        EVEN

        SECTION Stage0Data,DATA
Stage0_Pal:     incbin "data/stage0_parallax_pal.bin"
Stage0_BMap:    incbin "data/stage0_bmap.lz"
Stage0_Blks:    incbin "data/stage0_blks.bin"
Stage0_TilesLZ:
        ifeq BUILD_GFX_PROFILE
        incbin "data/stage0_parallax_tiles.lz"
        endif
                EVEN
ParallaxAssetsLZ: incbin "data/parallax_background.lz"
                EVEN


        SECTION MusicData1,DATA
MusicPart1Packed: incbin "data/music_part1.huf"
                EVEN

        SECTION MusicData2,DATA
MusicPart2Packed: incbin "data/music_part2.huf"
                EVEN

        SECTION MusicTables,DATA
MusicHuffmanTableLZ: incbin "data/music_huff_table.lz"
                EVEN

        SECTION ExtendedData,DATA
JoeDeathSpritesLZ: incbin "data/joe_death_sprites.lz"
NativeSfxLZ:    incbin "data/native_sfx.lz"
                EVEN

; ============================================================================
; CHIP RAM COPPERLIST & HARDWARE SPRITE DMA BUFFERS
; ============================================================================
        include "title_graphics_data.i"
        include "loading_data.i"
        ifne BUILD_GFX_PROFILE
        include "fullcolor_assets_data.i"
        endif

        SECTION Copper,DATA_C

CopperList:
        dc.w DIWSTRT, $2C81             ; Display window start (320x240)
        dc.w DIWSTOP, $1CC1             ; Display window stop  (line $11C = 284)
CopFetchStart:
        dc.w DDFSTRT, $0030             ; Wide fetch (21 words = 336px) for scroll
        dc.w DDFSTOP, $00D0
CopDepth:
        dc.w BPLCON0, $5200             ;5 foreground planes; stage1 may add background
        dc.w BPLCON3, $0020             ;AGA bank0; blank borders when ECSENA is set
CopFetchMode:
        dc.w $01FC,$0000                ;AGA bitplane fetch mode; sprites stay16bit
CopSpriteBank:
        dc.w $010C,$0011                ;attached sprites use colours17..31
CopScroll:
        dc.w BPLCON1, $0000             ; Fine horizontal scroll delay (0..15)
CopPriority:
        dc.w BPLCON2, $0024             ; All Hardware Sprites in front of Playfield!
CopModulo:
        dc.w BPL1MOD, (ROW_STRIDE-42)   ; 498 bytes modulo for interleaved 5 planes
        dc.w BPL2MOD, (ROW_STRIDE-42)

CopBplPtrs:
        dc.w $00E0, $0000, $00E2, $0000 ; BPL1PTH/L
        dc.w $00E4, $0000, $00E6, $0000 ; BPL2PTH/L
        dc.w $00E8, $0000, $00EA, $0000 ; BPL3PTH/L
        dc.w $00EC, $0000, $00EE, $0000 ; BPL4PTH/L
        dc.w $00F0, $0000, $00F2, $0000 ; BPL5PTH/L
CopParallaxBplPtr:
        dc.w $00F4, $0000, $00F6, $0000 ;BG bitplane6, independent phase bank
        dc.w $00F8, $0000, $00FA, $0000 ;full-colour plane7
        dc.w $00FC, $0000, $00FE, $0000 ;full-colour plane8

CopSprPtrs:
        dc.w $0120, $0000, $0122, $0000 ; SPR0PTH/L (Joe Left Even)
        dc.w $0124, $0000, $0126, $0000 ; SPR1PTH/L (Joe Left Odd, Attached)
        dc.w $0128, $0000, $012A, $0000 ; SPR2PTH/L (Joe Right Even)
        dc.w $012C, $0000, $012E, $0000 ; SPR3PTH/L (Joe Right Odd, Attached)
        dc.w $0130, $0000, $0132, $0000 ; SPR4PTH/L (Arm Ch A Even: Links 0,2,4,6,8)
        dc.w $0134, $0000, $0136, $0000 ; SPR5PTH/L (Arm Ch A Odd Attached)
        dc.w $0138, $0000, $013A, $0000 ; SPR6PTH/L (Arm Ch B Even: Links 1,3,5,7,9)
        dc.w $013C, $0000, $013E, $0000 ; SPR7PTH/L (Arm Ch B Odd Attached)

        dc.w BPLCON3,$2020
CopParallaxMirror:
        dc.w $0180,0, $0182,0, $0184,0, $0186,0
        dc.w $0188,0, $018A,0, $018C,0, $018E,0
        dc.w $0190,0, $0192,0, $0194,0, $0196,0
        dc.w $0198,0, $019A,0, $019C,0, $019E,0
        dc.w $01A0,0, $01A2,0, $01A4,0, $01A6,0
        dc.w $01A8,0, $01AA,0, $01AC,0, $01AE,0
        dc.w $01B0,0, $01B2,0, $01B4,0, $01B6,0
        dc.w $01B8,0, $01BA,0, $01BC,0, $01BE,0
        dc.w BPLCON3,$0020
CopColors:
        dc.w $0180,$0000, $0182,$0000, $0184,$0000, $0186,$0000
        dc.w $0188,$0000, $018A,$0000, $018C,$0000, $018E,$0000
        dc.w $0190,$0000, $0192,$0000, $0194,$0000, $0196,$0000
        dc.w $0198,$0000, $019A,$0000, $019C,$0000, $019E,$0000
        dc.w $01A0,$0000, $01A2,$0000, $01A4,$0000, $01A6,$0000
        dc.w $01A8,$0000, $01AA,$0000, $01AC,$0000, $01AE,$0000
        dc.w $01B0,$0000, $01B2,$0000, $01B4,$0000, $01B6,$0000
        dc.w $01B8,$0000, $01BA,$0000, $01BC,$0000, $01BE,$0000

CopPaletteJump:
        dc.w COP2LCH,0,COP2LCL,0,COPJMP2,0
        ; --- Split at scanline 268 ($10C) for non-scrolling 16-line HUD bar ---
CopParallaxJump:
        dc.w COP2LCH,0,COP2LCL,0,COPJMP2,0
CopPlainHudWait:
        dc.w $FFDF, $FFFE               ; Wait for vertical line 255
CopHudCommon:
        dc.w $0C07, $FFFE               ; Wait for line 268 ($10C): exactly16 HUD rows
        dc.w $01FC,$0000                ;standard16-bit HUD fetch
        dc.w BPLCON0, $1200             ; 1 bitplane for crisp 8x8 arcade HUD text
        dc.w BPLCON1, $0000
        dc.w BPLCON2, $0000             ; Hide sprites behind HUD bar
        dc.w DDFSTRT, $0038             ; Standard 320px (20 words) fetch
        dc.w DDFSTOP, $00D0
        dc.w BPL1MOD, $0000
CopHudBackground:
        dc.w COLOR00, $0113             ; HUD background (dark arcade blue)
CopHudForeground:
        dc.w COLOR00+2, $0FD2           ; HUD text (bright arcade gold)
CopHudBpl:
        dc.w $00E0, $0000, $00E2, $0000 ; HUD BPL1PTH/L

        ; --- Clean bottom border at line 284 ($11C) & set Copper frame latch ---
        dc.w $1C07, $FFFE               ; Wait for line 284 ($11C)
        dc.w BPLCON0, $0200             ; Disable bitplane DMA in bottom border
        dc.w COLOR00, $0000
        dc.w INTREQ, $8010              ; Set INTF_COPER ($0010) frame-ready flag!

        dc.w $FFFF, $FFFE               ; End of CopperList

        ifne BUILD_GFX_PROFILE
FullPaletteCopper:
CNTR SET 0
        REPT 8
        dc.w BPLCON3,((CNTR<<13)|$0020)
CNTR SET CNTR+1
CLRREG SET $0180
        REPT 32
        dc.w CLRREG,0
CLRREG SET CLRREG+2
        ENDR
        ENDR
        dc.w BPLCON3,$0020
        dc.w COP2LCH,0,COP2LCL,0,COPJMP2,0
FullPaletteCopperEnd:
        endif

        EVEN
NullSprite:
        dc.l 0

; Hardware Sprite Buffers in Chip RAM:
;   Spr0Buf..Spr3Buf: room for 64-line entry; normal Joe uses 32 lines.
Spr0Buf:        ds.b 264
Spr1Buf:        ds.b 264
Spr2Buf:        ds.b 264
Spr3Buf:        ds.b 264
;   Spr4Buf..Spr5Buf: Chained 15-color Attached Sprites for All 10 Links (up to 10 x 60B + 4B -> 640B each)
Spr4Buf:        ds.b 640
Spr5Buf:        ds.b 640
Spr6Buf:        ds.b 264
Spr7Buf:        ds.b 264

; Paula Audio Double-Buffers & MAME YM2151 SFX Samples in Chip RAM:
                EVEN
AudioBufA:      ds.b 2048
AudioBufB:      ds.b 2048
SilenceBuf:     ds.b 32

; ============================================================================
; CHIP RAM BSS (Split into <256KB Hunks for Kickstart 1.3 Loader)
; ============================================================================
        SECTION ChipScreen,BSS_C
ScreenBuffer:   ds.b (TOTAL_BUF_LINES*ROW_STRIDE) ; 259,200 bytes (480 lines)

        SECTION ChipFrames,BSS_C
GameFrame0:     ds.b FRAME_BYTES
GameFrame1:     ds.b FRAME_BYTES

        SECTION ChipTiles,BSS_C
ActiveTileSheet:ds.b (480*160)                    ; 76,800 bytes
HudBuffer:      ds.b (16*40)                      ; 640 bytes
BobSheet:       ds.b (BOB_TOTAL_FRAMES*BOB_FRAME_BYTES)

        SECTION BobRaw,BSS
RawBobs:        ds.b BOB_RAW_BYTES

        SECTION UnpackedSprites,BSS
ArcadeFont:     ds.b 512
JoeSpritesData: ds.b 29776
EnemyBobsDefault: ds.b (72*640)
ParachuteSpriteData: ds.b 2048
BobBoundsData:  ds.b ((BOB_ENEMY_FRAMES+OBJ_FRAME_COUNT)*4)

        SECTION UnpackedMusic1,BSS
MusicPart1:     ds.b 208896
        SECTION UnpackedMusic2,BSS
MusicPart2:     ds.b 208896
        SECTION MusicScratch,BSS
MusicDecodeTable: ds.b 8192
        include "amiga_music_bss.i"
        include "c64_music_bss.i"

        SECTION DeathSprites,BSS
JoeDeathSpritesData: ds.b JOE_DEATH_DATA_BYTES
        SECTION NativeSounds,BSS_C
NativeSfxData:  ds.b NATIVE_SFX_BANK_BYTES

        include "object_bank_bss.i"

        SECTION ObjectState,BSS
ActiveBMap:     ds.b 8192
RawObjectScratch: ds.b (256*512)
DemoMotionData: ds.b DEMO_MOTION_BYTES
DemoExtraPoseData: ds.b DEMO_EXTRA_POSE_BYTES
ObjectList:     ds.b (MAX_OBJECTS*OB_SIZE)
ObjectPlatformPointers: ds.l MAX_OBJECTS

        SECTION ParallaxState,BSS
ParallaxRowPalette: ds.b 2048
ParallaxDemoCoords: ds.b (1560*4)
ParallaxColorSlots: ds.l 224
        SECTION ParallaxCopper,BSS_C
ParallaxCopperRows: ds.b PARA_COPPER_BYTES
        SECTION ParallaxChip0,BSS_C
ParallaxBank0: ds.b PARA_BANK_BYTES
        SECTION ParallaxChip1,BSS_C
ParallaxBank1: ds.b PARA_BANK_BYTES
        SECTION ParallaxChip2,BSS_C
ParallaxBank2: ds.b PARA_BANK_BYTES
        SECTION ParallaxChip3,BSS_C
ParallaxBank3: ds.b PARA_BANK_BYTES
        SECTION ParallaxChip4,BSS_C
ParallaxBank4: ds.b PARA_BANK_BYTES
        SECTION ParallaxChip5,BSS_C
ParallaxBank5: ds.b PARA_BANK_BYTES
        ifne BUILD_GFX_PROFILE
        include "fullcolor_assets_bss.i"
        endif
        END
