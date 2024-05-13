org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
    jmp main

;
; Prints a string to the screen
; Params:
;   - ds:si points to the string
;
puts:
    ; save register we will modify
    push si
    push ax
    push bx

.loop:
    lodsb  ; loads next character in al
    or al, al  ; verify if the next character in null?
    jz .done

    mov ah, 0x0e  ; call bios interrupt (Write charater in TTY mode)
    mov bh, 0
    int 0x10  ; invokes interrupt 0x10, which is a software interrupt that 
              ; invokes various video services provided by the BIOS

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret


main:
    ; setup data segements
    mov ax, 0
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00  ; stack grows downwards from where we are loaded in memory

    ; print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt


msg_hello: db 'Hello world!', ENDL, 0

; repeats the instruction to store the value 0 in memory (a byte) as many times 
; as needed to fill the remaining space in the boot  sector, up to a maximum of
; 510 bytes

times 510-($-$$) db 0         
dw 0AA55H
