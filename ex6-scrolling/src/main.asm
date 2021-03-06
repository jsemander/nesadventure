.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
.exportzp sprite_x, sprite_y, buttons1, direction, scroll_x, ppu_ctrl
sprite_x:   .res 1
sprite_y:   .res 1
buttons1:   .res 1
direction:  .res 1

scroll_x:   .res 1
ppu_ctrl:   .res 1

.segment "BSS"

.segment "CODE"
.import draw_sprite
.import update_sprite_position
.import update_scroll
.import read_controller1
.import draw_backgrounds

.proc irq_handler
  RTI
.endproc

.proc reset_handler
  SEI           ; turn on interrupts
  CLD           ; turn off non-existent decimal mode
  LDX #$00
  STX PPUCTRL   ; disable NMI
  STX PPUMASK   ; turn off display

vblankwait:     ; wait for PPU to fully boot up
  BIT PPUSTATUS
  BPL vblankwait

  JMP main
.endproc

.proc nmi_handler
  LDA #$00    ; draw SOMETHING first,
  STA OAMADDR ; in case we run out
  LDA #$02    ; of vblank time,
  STA OAMDMA  ; then update positions

  JSR read_controller1
  JSR update_sprite_position
  JSR draw_sprite

	JSR update_scroll

	LDA scroll_x  ; horizontal scroll
  STA PPUSCROLL
  LDA #$00			; vertical scroll
  STA PPUSCROLL
	LDA ppu_ctrl
	STA PPUCTRL
  RTI
.endproc

.proc main
  LDA #$70        ; set up initial sprite values
  STA sprite_x    ; these are stored in zeropage
  LDA #$30
  STA sprite_y

	LDA #$00
	STA scroll_x    ; no scroll on init

  LDX PPUSTATUS   ; reset PPUADDR latch
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR     ; set PPU to write to $3f00 (palette ram)

copy_palettes:
  LDA palettes,x  ; use indexed addressing into palette storage
  STA PPUDATA
  INX
  CPX #$20          ; have we copied 32 values?
  BNE copy_palettes ; if no, repeat

  ; set up the backgrounds
  ; here, we only need to do this once
  JSR draw_backgrounds

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA ppu_ctrl
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever     ; do nothing, forever
.endproc

.segment "RODATA"
palettes:
; background palettes
; first palette - trees
.byte $29, $09, $19, $17
; second palette - water
.byte $29, $11, $21, $31
; third palette - desert
.byte $29, $0f, $37, $26
; fourth palette - ???
.byte $29, $09, $19, $29

; sprite palettes
.byte $29, $11, $30, $26
.byte $29, $01, $0f, $31
.byte $29, $06, $16, $26
.byte $29, $09, $19, $29

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "backgrounds.chr"
