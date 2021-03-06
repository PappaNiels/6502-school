PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003
PCR   = $600c
IFR   = $600d
IER   = $600e

E  = %10000000
RW = %01000000
RS = %00100000

DDRAM = %10000000
CGRAM = %01000000

sys_vars = $0200
sys_keypress = $0000 ; 1 byte

div_vars = $0201
div_dvr = div_vars + $0000 ; 1 byte
div_dnd = div_vars + $0001 ; 1 byte
div_qot = div_vars + $0001 ; 1 byte Same address as div_dnd, different name
div_mod = div_vars + $0002 ; 1 byte

get_pix_vars = $0203
pix_x   = get_pix_vars + $0000 ; 1 byte; x input
pix_y   = get_pix_vars + $0001 ; 1 byte; y input
pix_adr = get_pix_vars + $0002 ; 1 byte; CGRAM address output
pix_val = get_pix_vars + $0003 ; 1 byte; CGRAM value output

snake_vars = $0208
snake_xlist = snake_vars + $0000 ; 256 bytes
snake_ylist = snake_vars + $0100 ; 256 bytes
snake_x     = snake_vars + $0200 ; 1 byte
snake_y     = snake_vars + $0201 ; 1 byte
snake_head  = snake_vars + $0202 ; 1 byte position in x y list
snake_tail  = snake_vars + $0203 ; 1 byte position in x y list
snake_add   = snake_vars + $0204 ; 1 byte
snake_dir   = snake_vars + $0205 ; 1 byte
apple_x     = snake_vars + $0206 ; 1 byte
apple_y     = snake_vars + $0207 ; 1 byte

main_vars = $0410
main_a = main_vars + %0000 ; 1 byte
score  = main_vars + %0001 ; 1 byte

RND = $0412 ; 6 bytes

  org $8000
  
reset:
  ldx #$ff ; set stack to $ff
  txs
  cld      ; clear decimal flag
  cli      ; clear interrupt disable i.e. enables interrupts
  lda #$9b ; enable interrupts for CA1 and CA2
  sta IER
  lda #0   ; set all buttons to active low
  sta PCR

 ; initialize LCD
  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%11111111 ; Set all pins on port A to output
  sta DDRA
  lda #%00111000 ; Set 8bit mode, 2 line display, 5x8 font
  jsr lcd_instruction
  lda #%00001100 ; Set Cursor off, no blink
  jsr lcd_instruction
  lda #%00000110 ; Inc addr cntr, no display shift
  jsr lcd_instruction
  lda #%00000001 ; Clear Display
  jsr lcd_instruction
  
  ; clear CGRAM
  
  lda #CGRAM
  jsr lcd_instruction
  ldx #64
  lda #0
clearCGRAMloop
  jsr print_char
  dex
  bne clearCGRAMloop
  
  ; set up cgram positions on LCD
  
  lda #DDRAM
  jsr lcd_instruction
  lda #0
  jsr print_char
  lda #2
  jsr print_char
  lda #4
  jsr print_char
  lda #6
  jsr print_char
  lda #$ff
  jsr print_char
  lda #(DDRAM | $40)
  jsr lcd_instruction
  lda #1
  jsr print_char
  lda #3
  jsr print_char
  lda #5
  jsr print_char
  lda #7
  jsr print_char
  lda #$ff
  jsr print_char
  lda #" "
  jsr print_char
  lda #"S"
  jsr print_char
  lda #"c"
  jsr print_char
  lda #"o"
  jsr print_char
  lda #"r"
  jsr print_char
  lda #"e"
  jsr print_char
  lda #":"
  jsr print_char
  
  ; seed RNG
  lda #0
  sta sys_keypress
seed:
  lda sys_keypress
  bne seed_exit    ; run loop untill user presses a key
  inc RND+4
  bne seed
  jsr RAND
  inc RND+1
  jmp seed
seed_exit:
  lda #0
  sta sys_keypress
  
  ; initialize snake
  
  lda #0
  sta snake_dir   ; direction 0,1,2,3 : right,up,left,down
  sta snake_x     ; current x pos
  sta snake_y     ; current y pos
  sta snake_head  ; position of head in x y list
  sta snake_tail  ; position of tail in x y list
  sta score
  lda #3
  sta snake_add   ; add to snake length if > 0
  
  jsr new_apple   ; load the first apple
  jsr print_score
  
main:

  ; add the current pixel to the x y list
  
  ldx snake_head      ; load the current head index
  lda snake_x
  sta snake_xlist,x   ; store x position to x list
  lda snake_y
  sta snake_ylist,x   ; store y position to y list
  inc snake_head      ; increment the head index
  
  ; check if we hit an apple
  
  lda apple_x
  cmp snake_x         ; compare apple_x to snake_x
  bne mprint_pix      ; skip if they are not equal
  lda apple_y
  cmp snake_y         ; compare apple_y to snake_y
  bne mprint_pix      ; skip if they are not equal
  
  lda apple_x
  sta pix_x
  lda apple_y
  sta pix_y
  jsr get_pix
  lda pix_adr
  jsr lcd_instruction
  jsr read_LCD
  lda pix_adr
  jsr lcd_instruction
  txa
  eor pix_val
  jsr print_char
  jsr new_apple
  inc snake_add
  inc score
  jsr print_score

  ; print current pixel
  
mprint_pix:
  lda snake_x
  sta pix_x
  lda snake_y
  sta pix_y
  jsr get_pix         ; calculates values for CGRAM instruction and value to put in
  
  lda pix_adr         ; set CGRAM address
  jsr lcd_instruction

  jsr read_LCD        ; put the contents of the current line in x register
  lda pix_adr         ; reset CGRAM address (reading increments address counter)
  jsr lcd_instruction
  txa                 ; put the LCD data into the accumulator
  
  bit pix_val         ; test if our pixel is already set
  beq madd_pix        ; if it is, we ran into ourself
  jmp game_over       ; have to use jmp instead of bne due to 127 byte range of branch

madd_pix:
  ora pix_val         ; overlay the new pixel onto old line
  jsr print_char      ; print the new line to the CGRAM
  
  lda snake_add
  beq mclearold       ; branch if there is a tail piece to clear (typical)
  dec snake_add       ; decrement snake_add
  jmp mkey_start
  
  ; clear old tail pixel if needed
  
mclearold:            ; clear the tail of the snake
  ldx snake_tail      ; load the tail index value to x
  lda snake_xlist,x   ; load the tail position from x list
  sta pix_x
  lda snake_ylist,x   ; load the tail position from y list
  sta pix_y
  jsr get_pix         ; calculate the CGRAM address and value for this pixel
  lda pix_adr         ; set CGRAM address
  jsr lcd_instruction
  jsr read_LCD        ; read the LCD and store it to x
  lda pix_adr         ; reset CGRAM address
  jsr lcd_instruction
  txa                 ; put the LCD data in the accumulator
  eor pix_val         ; we are sure the bit is set in CGRAM so xor will clear it
  jsr print_char
  inc snake_tail      ; increment the tail position
  
  ; check buttons
  
mkey_start:
  ldx sys_keypress
  beq mdirstart
mkey_right:
  dex
  bne mkey_up
  lda #0
  sta snake_dir
  sta sys_keypress
  jmp mdirstart
mkey_up:
  dex
  bne mkey_left
  lda #1
  sta snake_dir
  lda #0
  sta sys_keypress
  jmp mdirstart
mkey_left:
  dex
  bne mkey_down
  lda #2
  sta snake_dir
  lda #0
  sta sys_keypress
  jmp mdirstart
mkey_down:
  lda #4
  sta snake_dir
  lda #0
  sta sys_keypress

mdirstart:
  
  ; move snake 1 space
  jsr waitFF
  
  ldx snake_dir
mdirright:            ; if dir is 0, we move right
  bne mdirup
  inc snake_x
  jmp mdirdone
mdirup:
  dex                 ; if x is 0, dir is 1 so we move up
  bne mdirleft
  dec snake_y
  jmp mdirdone
mdirleft:
  dex                 ; if x is 0, dir is 2 so we move left
  bne mdirdown
  dec snake_x
  jmp mdirdone
mdirdown:             ; if this code runs, dir is 3 so we move down
  inc snake_y
mdirdone:

  ; wall collision detection
  
  lda snake_y
  bit #$f0           ; if any bit in the top nibble is set in snake_y

  bne game_over       ; we hit the floor or ceiling
  lda snake_x
  cmp #20             ; if snake_x >= 20
  bcs game_over       ; we hit a left or right wall
  
  jmp main
  
game_over:
  lda #(DDRAM | 6)
  jsr lcd_instruction
  lda #"G"
  jsr print_char
  lda #"a"
  jsr print_char
  lda #"m"
  jsr print_char
  lda #"e"
  jsr print_char
  lda #" "
  jsr print_char
  lda #"o"
  jsr print_char
  lda #"v"
  jsr print_char
  lda #"e"
  jsr print_char
  lda #"r"
  jsr print_char
  lda #"!"
  jsr print_char
halt:
  jmp halt




; subroutines

new_apple:
  pha
  txa
  pha
new_apple_retry:
  jsr RAND
  lda RND
  sta div_dnd
  lda #20
  sta div_dvr
  jsr div
  lda div_mod
  sta apple_x
  sta pix_x
  jsr RAND
  lda RND
  and #15
  sta apple_y
  sta pix_y
  
  jsr get_pix
  lda pix_adr
  jsr lcd_instruction
  jsr read_LCD
  lda pix_adr
  jsr lcd_instruction
  txa
  bit pix_val
  bne new_apple_retry
  ora pix_val
  jsr print_char
  
  pla
  tax
  pla
  rts

get_pix: ; reads pix_x, pix_y; stores CGRAM instruction to pix_adr and value to pix_val
  pha
  txa
  pha
  lda div_dvr
  pha
  lda div_dnd
  pha
  lda div_mod
  pha
  
  lda #5
  sta div_dvr
  lda pix_x
  sta div_dnd
  jsr div        ; divide pix_x by 5
  asl div_qot    ; |
  asl div_qot    ; |
  asl div_qot    ; |
  asl div_qot    ; -> multiply quotient by 16
  lda div_qot    ; store to a
  clc
  adc pix_y      ; a is now the cgram address of the line with the current pixel
  ora #CGRAM     ; or the setCGRAM instruction onto the address
  sta pix_adr
  
  lda #%00010000 ; load a with a pixel on the left side of the row
  ldx div_mod    ; div_mod is pix_x mod 5, still set from the div subroutine
pix_1:
  beq pix_2      ; exit when x is 0
  lsr a          ; shift the pixel right if x is not zero
  dex
  jmp pix_1
pix_2:           ; a is now the new pixel
  sta pix_val
  
  pla
  sta div_mod
  pla
  sta div_dnd
  pla
  sta div_dvr
  pla
  tax
  pla
  rts

waitFF:
  pha
  txa
  pha
  tya
  pha
  
  ldx #0
  ldy #128
  
waitFF1:
  inx
  bne waitFF1
  iny
  bne waitFF1
  pla
  tay
  pla
  tax
  pla
  rts


div: ; divides dividend by divisor
  pha
  txa
  pha
  tya
  pha
  
  lda #0
  sta div_mod
  
  ldx #8
  clc
divLoop:
  rol div_dnd
  rol div_mod
  
  lda div_mod
  sec
  sbc div_dvr
  bcc divIgnore
  sta div_mod
divIgnore:
  dex
  bne divLoop
  rol div_dnd
  
  pla
  tay
  pla
  tax
  pla
  rts
  
print_score:
  pha
  
  lda #%00000100      ; set the display to print RTL
  jsr lcd_instruction
  lda #(DDRAM | $4f)    ; start at bottom right of screen
  jsr lcd_instruction
  
  lda score
  sta div_dnd
  lda #10
  sta div_dvr
print_score_loop:
  jsr div
  lda div_mod
  clc
  adc #"0"
  jsr print_char
  lda div_qot
  bne print_score_loop
  
  lda #%00000110
  jsr lcd_instruction
  
  pla
  rts
  
print_x: ; prints the decimal value of x to the screen

  php
  pha
  lda div_dvr
  pha
  lda div_dnd
  pha
  lda div_mod
  pha
  
  stx div_dnd
  lda #10
  sta div_dvr
print_xLoop:
  jsr div
  lda div_mod
  clc
  adc #"0"
  jsr print_char
  lda div_qot
  bne print_xLoop
  
  lda #" "
  jsr print_char
  jsr print_char
  
  pla
  sta div_mod
  pla
  sta div_dnd
  pla
  sta div_dvr
  pla
  plp
  rts

read_LCD: ; read store to x
  pha
  jsr lcd_wait
  lda #0
  sta DDRB
  lda #(RS | RW)
  sta PORTA
  lda #(RS | RW | E)
  sta PORTA
  lda PORTB
  and #%00011111 ; ignore the top 3 bits (just in case i guess?)
  tax
  lda #(RS | RW)
  sta PORTA
  lda #$FF
  sta DDRB
  pla
  rts

lcd_wait: ; wait for the LCD busy flag to clear
  pha
  lda #0
  sta DDRB
lcd_busy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcd_busy
  lda #RW
  sta PORTA
  lda #$FF
  sta DDRB
  pla
  rts
  
lcd_instruction:
  jsr lcd_wait
  sta PORTB
  lda #0         ; Clear RS/RW/E bits in A register
  sta PORTA
  lda #E
  sta PORTA      ; Set enable bit
  lda #0
  sta PORTA      ; Clear Enable bit
  rts
  
print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS        ; Set register select
  sta PORTA
  lda #(RS | E)  ; Set Enable bit
  sta PORTA
  lda #RS
  sta PORTA      ; Clear Enable bit
  rts

button_wait:
  pha
button_wait_tryagain
  lda sys_keypress
  beq button_wait_tryagain
  lda #0
  sta sys_keypress
button_wait_exit:
  pla
  rts
  
RAND
  pha
  txa
  pha
  
  sec
  lda RND + 1
  adc RND + 4
  adc RND + 5
  sta RND
  ldx #4
RAND_loop
  lda RND,x
  sta RND + 1,x
  dex
  bpl RAND_loop
  
  pla
  tax
  pla
  rts




nmi:
  rti
irq:
  pha
irq_button_right:
  lda IFR
  bit #1
  beq irq_button_up
  lda #1
  sta IFR ; clear interrupt
  sta sys_keypress
  jmp irq_exit
irq_button_up:
  lda IFR
  bit #2
  beq irq_button_left
  lda #2
  sta IFR ; clear interrupt
  sta sys_keypress
  jmp irq_exit
irq_button_left:
  lda IFR
  bit #8
  beq irq_button_down
  lda #8
  sta IFR ; clear interrupt
  lda #3
  sta sys_keypress
  jmp irq_exit
irq_button_down:
  lda IFR
  bit #16
  beq irq_wtf
  lda #16
  sta IFR ; clear interrupt
  lda #4
  sta sys_keypress
  jmp irq_exit
irq_wtf:
  ; what do I do here?
  lda #5
  sta sys_keypress
irq_exit:
  pla
  rti
  

  org $fffa
  word nmi
  word reset
  word irq