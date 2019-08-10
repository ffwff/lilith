.section .text
.global kidle_loop

kidle_loop:
    hlt
    jmp kidle_loop
