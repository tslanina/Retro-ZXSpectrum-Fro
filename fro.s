;************************
; FRO by dox/dc-s
; Frogger clone in 
; less than 500 bytes
; tomasz@slanina.pl
;************************

MAX_X equ 16
MAX_Y equ 12


DEFAULT_SPEED       equ $d
DIFFICULTY_SPEED    equ 6

PLAYER_START         equ $80b

CLR_BLACK           equ %00000000
CLR_GREEN           equ %00100100
CLR_YELLOW          equ %00110110

CLR_HOME            equ %01110110

CLR_RED             equ %01010010
CLR_BLUE            equ %01001001
CLR_WHITE           equ %01111111
CLR_MAGENTA         equ %01011011
CLR_LBLUE           equ %01101101
CLR_PLAYER          equ %01100000


VAR_KEY             equ $c002
VAR_PLAYER_Y        equ $c003
VAR_PLAYER_X        equ $c004

BACK_TOP            equ $d0
BUFFER_TOP          equ $d8
SCREEN_TOP          equ $58
COUNTERS_TOP        equ $d9 
COUNTERS_RST_TOP    equ $db

    org 0xe000

start:
    xor a
    out (254),a

    exx
    ld l,a  ; level num
    ld h,a  ; flags
    exx

    ld hl,PLAYER_START
    ld [VAR_PLAYER_Y],hl

;********************
; "decompress" screen
;********************
    ld hl,screen
    ld de,BUFFER_TOP * 256

.inner_scr:
    ld b,[hl]
    inc hl  
    ld a,[hl]
    inc hl
.loop_write:
    ld [de],a
    inc de
    djnz .loop_write
    dec a  ; 1 is the last value, used to clear the counters  area (should be 0, but 0 is  (black) color of the road
    jr nz, .inner_scr

;**************
; add objects 
;**************

    ; hl points to objects
    ld d,BUFFER_TOP 
.loop:
    ld e,[hl]
    ;ld e,a
    inc hl
    ld b,[hl]
    inc hl
    ld a,[hl]
    inc hl
.set
    ld [de],a
    inc e
    djnz .set
    cp CLR_WHITE
    jr nz,.loop

.done:

;********************
; reset counter base
;********************

    ld hl,COUNTERS_RST_TOP*256
    ld bc,$900+DEFAULT_SPEED
.lloop:
    ld [hl],c
    inc hl
    djnz .lloop

.main_loop:
    halt
    exx
.lo:
    srl d
    rr e
    ex af,af'
    ld a,e
    or a
    jr z,.donesnd
    ex af,af'
    jr nc,.play
    or $10
.play:
    out (254),a
.donesnd:
    exx

;*****************
; update counters
;*****************

    ld de,COUNTERS_TOP*256 +8; d900
    ld hl,COUNTERS_RST_TOP*256 +8;da00
    
    ld bc,$901 ; 9 lines (2 on top at the bootom one will not scroll), c contains 1 for "and c" in next loop
    push bc
.counters_loop: 
    ld a,[de]
    dec  a
    jr nz,.nextline
    
    ld a,[hl] ; restore level counters

.nextline:
    ld [de],a
    dec hl
    dec de
    djnz .counters_loop

;****************
; scroll
;****************
    inc de   ;de pointed to d900-1
    pop bc
    ld  hl,BUFFER_TOP*256+2*16

.scroll_loop:
    ld a,[de] ; check counters for potential trigger
    inc de
    dec a ;cp 1
    jr z,.trigger
    xor a
    jr .doscorll

.trigger:
    ld a,e
    and c
    inc a

.doscorll
    push bc
    push de

    call scroll
    inc hl
    pop de
    pop bc
    djnz .scroll_loop

    call read_controlls

;*********************
; copy to back buffer
;*********************
    ld hl, BUFFER_TOP*256 ; d8
    ld d, BACK_TOP ; d0
    ld e,l
    ld b,e
    ld c,d ; bc should contains 16*12, but a bit more is also ok ;)
    ldir

;***************************
; check player automovement
;***************************

    ld de, VAR_PLAYER_Y

    ld a,[de]
    sub 2
    cp 3
    jr  nc,.no_water

    ; water

    ld c,a

    ld h,COUNTERS_TOP
    ld l,a
    ld a,[hl]
    dec a ; cp 1
    jr nz,.no_water

    bit 0,c
    inc de ; x coord

    ld a,[de]
    jr nz,.move_player_left

    cp MAX_X-1
    jr nc,.no_home

    inc a
    jr .skipdec

.move_player_left:
    or a
    jr nz,.decrement

    jr .no_home

.decrement:

    dec a
.skipdec:
    ld [de],a
    dec de ; points back to y coord

.no_water:

;******************************
; calculate screen coordinates
;******************************

    ld a,[de] ; y coord
    add a,a
    add a,a
    add a,a 
    add a,a
    ld l,a
    ld h,BACK_TOP
    inc de ; x coord 
    ld a,[de]
    or l
    ld l,a

    ld a,[hl]  ; collision check
    bit 6,a
    jr z, .nocollide
    
    cp CLR_HOME
    jr nz,.no_home

    ld h,BUFFER_TOP
    ld [hl],CLR_PLAYER
    ld h,BACK_TOP
    jr .setup ; a contains value different than 1, so sets a level end flag

.no_home:
    ld a,1 ; die flag

.setup:
    exx
    ld h,a
    exx

;****************
; draw player
;****************

.nocollide:

    ld [hl],CLR_PLAYER

;****************
; draw screen
;****************

    ld hl, BACK_TOP * 256
    ld de, SCREEN_TOP * 256

    ld a, 12
.y_loop:
    push af

    ld c,2
.xx_loop:
    ld b,16
    push hl
.x_loop:
    ld a,[hl]
    ld [de],a
    inc de
    ld [de],a
    inc de
    inc hl
    djnz .x_loop

    dec c
    jr z, .exit_loop
    pop hl
    jr  .xx_loop
.exit_loop:
    inc sp ; instead pop
    inc sp
    pop af
    dec a
    jr nz, .y_loop

    exx
    ld a,h
    exx
    or a
    jr z,.goend

    dec a
    jr z,.gameover

    ;next level

    ld c,DIFFICULTY_SPEED

    exx
    inc l
    ld a,l
    ld h,0
    exx
    ld ix,COUNTERS_RST_TOP*256
    dec a
    jr nz,.nolevel1
    
    ld [ix+6],c
    ld a,CLR_MAGENTA
    ld [BUFFER_TOP*256+1+16*8],a
    jr .restart

.nolevel1:
    dec a
    jr nz,.nolevel3
    ld [ix+1],c
    jr .restart

.nolevel3:
    dec a
    jr nz,.nolevel4
    ld [ix+5],c

.restart:
    ld hl,PLAYER_START
    ld [VAR_PLAYER_Y],hl

.goend: 
    jp .main_loop

.nolevel4:
    ld a,$fe

.gameover:
    cpl
    ld [.gover_mask+1],a ; modify the code below (mask of and)

.wait_loop:
    ld b,60
.dead:
    
    halt
    ld a,b

.gover_mask:
    and 1  ; mask modified by code
    out (254),a
    djnz .dead  

    jp start
                
scroll:
;0 - no scroll
;1 - left 
;2 - right

    cp 1
    jr c,.skip_scroll
    ld b,16
    jr z,.left

    push hl

.scroll_right:
    ld a,[hl]
    ld [hl],c
    ld c,a
    inc hl
    djnz .scroll_right

    pop de
    ld a,c
    ld [de],a
    dec hl
    ret

.left:
    call .skip_scroll
    push hl

.scroll_left:
    ld a,[hl]
    ld [hl],c
    ld c,a
    dec hl
    djnz .scroll_left
    pop hl
    ld [hl],c
    ret

.skip_scroll:
    ld a,15
    add a,l
    ld l,a
    ret

;*******************************
; Check controlls
;*******************************

read_controlls:
    ld de,VAR_KEY
    in a,($1f) ; kempston port
    cpl
    or a
    jr z,.nokempston ; no  interface

; swap left<->right bits

    ld c,a
    and %11111100
    rr c
    jr nc, .x1
    or 2
.x1:
    rr c
    adc a,0
    jr .input

.nokempston:

; 0 <-
; 1 ->
; 2 v
; 3 ^

    ld bc, $f7fe; read keyboard / sinclair 1
    in a,(c)

.input: 
    cpl
    push af
    ld c,a
    ld a,[de]
    xor c
    and c
    ld c,a
    pop af
    ld [de],a ;check state change

    inc de
    inc de

    ld a,[de]
    rr c
    jr nc,.no_left
    or a
    ret z
    dec a
    jr .update_coord

.no_left:
    rr c
    jr nc,.no_right
    inc a
    cp MAX_X
    ret nc

.update_coord:
    ld [de],a
    exx
    ld de,%1000101010110011 ; noise pattern to generate sound
    exx
    ret

.no_right:
    dec de ; points to y coord
    ld a,[de]
    rr c
    jr nc,.no_down
    inc a
    cp MAX_Y
    ret nc
.update_y:
    jr .update_coord

.no_down:
    rr c
    ret nc
    or a
    ret z
    dec a
    jr .update_coord

;*******************************
; Screen data as
;  db legth, color
;*******************************

screen:
    db 2*16,CLR_MAGENTA
    db 3*16,CLR_BLUE
    db 2*16,CLR_GREEN
    db 4*16,CLR_BLACK
    db 1*16,CLR_GREEN
    db 10*16,1 ; counters

;******************************
; Game objects in format:
;  db offset, length, color
;******************************
    
objects:
    db 2+1*16
    db 1, CLR_HOME

    db 5+1*16
    db 1,CLR_HOME

    db 10+1*16
    db 1,CLR_HOME

    db 13+1*16
    db 1, CLR_HOME

    db 4+2*16
    db 3,CLR_YELLOW
    db 2+3*16
    db 4,CLR_YELLOW
    db 11+4*16
    db 5,CLR_YELLOW

    db 4+7*16
    db 3,CLR_LBLUE
    db 10+7*16
    db 3,CLR_LBLUE

    db 1+9*16
    db 2,CLR_RED
    db 6+9*16
    db 2,CLR_RED
    db 12+9*16
    db 2,CLR_RED

    db 4+10*16
    db 3,CLR_LBLUE
    db 12+10*16
    db 4,CLR_WHITE ; last one must be CLR_WHITE =  end marker

end start



