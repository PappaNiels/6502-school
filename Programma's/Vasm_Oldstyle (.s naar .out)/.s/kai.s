;.org 8000
.org $8000
lda #0
sta RESULT+2
ldx #16

L1      LSR NUM2+1   ;Get low bit of NUM2
        ROR NUM2
        BCC L2       ;0 or 1?
        TAY          ;If 1, add NUM1 (hi byte of RESULT is in A)
        CLC
        LDA NUM1
        ADC RESULT+2
        STA RESULT+2
        TYA
        ADC NUM1+1
L2      ROR A        ;"Stairstep" shift
        ROR RESULT+2
        ROR RESULT+1
        ROR RESULT
        DEX
        BNE L1
        STA RESULT+3
;vanaf hier wave patroon:
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