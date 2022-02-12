  .org $8000

NUM = 10

MULT10:
  ASL NUM         ;multiply by 2
  STA TEMP    ;temp store in TEMP
  ASL NUM        ;again multiply by 2 (*4)
  ASL NUM        ;again multiply by 2 (*8)
  CLC
  ADC TEMP    ;as result, A = x*8 + x*2
  RTS

TEMP    .byte 0

reset:
  lda #$ff
  sta $6002

  lda #$50
  sta $6000

loop:
  ror
  sta $6000

  jmp loop

  .org $fffc
  .word reset
  .word $0000