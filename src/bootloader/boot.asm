org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 header
;
jmp short start
nop

bdb_oem:  db 'MSWIN4.1'  ; 8 bytes
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880  ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type: db 0F0h  ; F0 = 3.5" floppy disc
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0

; extended boot record
ebr_drive_number: db 0  ; 0x00 floppy, 0x80 hdd, useless
                  db 0  ; reserved byte
ebr_signature: db 29h
ebr_volume_id: db 12h, 34h, 56h, 78h  ; serial number
ebr_volume_label: db 'OS_1       '  ; 11 bytes, padded with spaces
ebr_system_id: db 'FAT12   '  ; 8 bytes, padded with spaces

;
; Code goes here
;

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

    ; read something from floppy disc
    ; BIOS should set dl to drive number
    mov [ebr_drive_number], dl

    mov ax, 1  ; LBA=1, second sector from disc
    mov cl, 1  ; 1 sector to read .. 
    mov bx, 0x7E00  ; data should be after the bootloader
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed 
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h  ; wait for a keypress
    jmp 0FFFFh:0  ; jump to beginning of BIOS, should reboot


.halt:
    cli
    hlt  ; disable interrupts, this way CPU can't get out of the "halt" state

;
; Disc routines
;

;
; Converts an LBA address to CHS address
; Parameters
;  - ax: LBA address
; Returns:
;  - cx [bits 0-5]: sector number
;  - cx [bits 6-15] : cylinder
;  - dh : head
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx  ; dx = 0
    div word [bdb_sectors_per_track]  ; ax = LBA / SectorsPerTrack
                                      ; dx = LBA % SectorsPerTrack

    inc dx  ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx

    xor dx, dx  ; dx = 0
    div word [bdb_heads]  ; ax = (LBA / SectorsPerTrack) / Head = cylinder
                          ; dx = (LBA / SectorsPerTrack) % Head = head
    
    mov dh, dl  ; dh = head
    mov ch, al  ; ch = cylinder (lower 8 bits) 
    shl ah, 6
    or  cl, ah  ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, dl  ; restore DL
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - ex:bx: memory address where to store read data
;
disk_read:

    push ax  ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx  ; temporarily save CL (number of sectors to read)
    call lba_to_chs  ; compute CHS
    pop ax  ; AL = number of sectors to read

    mov ah, 02
    mov di, 3  ; retry count

.retry:
    pusha  ; save all registers, we don't know what bios modifies
    stc  ; set carry flag, some BIOS'es don't set it
    int 13h  ; carry flag cleared = success
    jnc .done  ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error


.done:
    popa

    push ax  ; restore registers modified
    push bx
    push cx
    push dx
    push di
    ret

;
; Reset disc controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Read from disc failed!', ENDL, 0

; repeats the instruction to store the value 0 in memory (a byte) as many times 
; as needed to fill the remaining space in the boot  sector, up to a maximum of
; 510 bytes

times 510-($-$$) db 0         
dw 0AA55H
