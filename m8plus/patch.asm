%include "kerneldefs.inc"
%include "patchseg.inc"

BITS	32
	cpu	586
	org HIGHCODE_BASE

; -------------------------------------------------------------------------------------------------
; Helper Functions
;
; -------------------------------------------------------------------------------------------------

; NTSTATUS __stdcall XboxHDMI_W32(uchar reg, uint32_t value)
_XboxHDMI_W32:
    push ebp
    mov ebp,esp
    mov eax, dword [ebp + 0Ch]
    push eax
    push 1
    mov cl, byte [ebp + 8]
    push ecx
    push HDMI_I2C_ADDRESS
    call FUNC_HalWriteSMBusValue
    mov edx, dword [ebp + 0Ch]
    shr edx, 10h
    push edx
    push 1
    movzx eax, byte [ebp + 8]
    add eax, 2
    push eax
    push HDMI_I2C_ADDRESS
    call FUNC_HalWriteSMBusValue
    pop ebp
    ret 8

; NTSTATUS __stdcall XboxHDMI_W8(UCHAR CommandCode, UCHAR DataValue)
_XboxHDMI_W8:
    push ebp
    mov ebp, esp
    movzx eax, byte [ebp + 0Ch]
    push eax
    push 0
    mov cl, byte [ebp + 8]
    push ecx
    push HDMI_I2C_ADDRESS
    call FUNC_HalWriteSMBusValue
    pop ebp
    ret 8

;__declspec(naked) NTSTATUS __stdcall XboxHDMI_AV_R8(UCHAR CommandCode, ULONG *DataValue)
_XboxHDMI_AV_R8:
    push ebp
    mov ebp, esp
    mov eax, dword [ebp + 0x0C]
    push eax
    push 0
    mov cl, byte [ebp + 0x08]
    push ecx
    push 0x86
    call FUNC_HalReadSMBusValue
    pop ebp
    ret 8

;__declspec(naked) NTSTATUS __stdcall XboxHDMI_AV_R32(UCHAR CommandCode, ULONG *DataValue)
_XboxHDMI_AV_R32:
    push ebp
    mov ebp, esp
    sub esp, 0Ch
    mov dword [ebp - 4], 0
    mov dword [ebp - 0Ch], 0
    jmp _XboxHDMI_AV_R32_0001119F
_XboxHDMI_AV_R32_00011196:
    mov eax, dword [ebp - 0Ch]
    add eax, 1
    mov dword [ebp - 0Ch], eax
_XboxHDMI_AV_R32_0001119F:
    cmp dword [ebp - 0Ch], 4
    jae _XboxHDMI_AV_R32_000111C9
    lea ecx, [ebp - 8]
    push ecx
    movzx edx, byte [ebp + 8]
    add edx, dword [ebp - 0Ch]
    push edx
    call _XboxHDMI_AV_R8
    or eax, dword [ebp - 4]
    mov dword [ebp - 4],eax
    mov eax, dword [ebp + 0Ch]
    add eax, dword [ebp - 0Ch]
    mov cl, byte [ebp - 8]
    mov byte [eax], cl
    jmp _XboxHDMI_AV_R32_00011196
_XboxHDMI_AV_R32_000111C9:
    mov eax, dword [ebp - 4]
    mov esp, ebp
    pop ebp
    ret 8

; -------------------------------------------------------------------------------------------------
; Function Hooks
;
; -------------------------------------------------------------------------------------------------
; Jump Offset:
;      m8plus 0x80030f3d
;        Stack is increased by two words for tracking XboxHDMI detection and as scratch
;
;        BEFORE:
;          80030f3d 55              PUSH       EBP
;          80030f3e 8b ec           MOV        EBP,ESP
;  *       80030f40 83 ec 1c        SUB        ESP,0x1c
;          80030f43 8b 4d 10        MOV        ECX,dword ptr [EBP + Mode]
;          80030f46 85 c9           TEST       ECX,ECX
;          80030f48 75 08           JNZ        LAB_80030f52
;          80030f4a b9 01 01        MOV        ECX,0xf010101
;                   01 0f
;          80030f4f 89 4d 10        MOV        dword ptr [EBP + Mode],ECX
;          80030f52 8a 15 6c        MOV        DL,byte ptr [TVEncoderSMBusID]
;                   c3 03 80
;          80030f58 53              PUSH       EBX
;          80030f59 56              PUSH       ESI
;        AFTER:
;          80030f3d 55              PUSH       EBP
;          80030f3e 8b ec           MOV        EBP,ESP
;          80030f40 83 ec 24        SUB        ESP,0x24
;          80030f43 e9 e6 f3        JMP        LAB_8003032e
;                   ff ff
;          80030f48 8b 4d 10        MOV        ECX,dword ptr [EBP + Mode]
;          80030f4b 85 c9           TEST       ECX,ECX
;          80030f4d 75 09           JNZ        LAB_80030f58
;          80030f4f b9 01 01        MOV        ECX,0xf010101
;                   01 0f
;          80030f54 89 4d 10        MOV        dword ptr [EBP + Mode],ECX
;          80030f57 90              NOP
;          80030f58 53              PUSH       EBX
;          80030f59 56              PUSH       ESI
AvSetDisplayMode_Preamble:
    ; Attempt to write to XboxHDMI
    PUSH 0
    PUSH 0
    CALL _XboxHDMI_W8
    ; Store result on stack
    MOV dword [EBP + -0x20], EAX
    ; Check if write was successful
    TEST EAX, EAX
    JNZ AvSetDisplayMode_Preamble_Ret
    ; Send orginal video mode
    PUSH dword [EBP + 0x10]
    PUSH 0x3E
    CALL _XboxHDMI_REG_W32
    ; Handle Mode = 0 (Force 480P)
    MOV  ECX, dword [EBP + 0x10]
    OR   ECX, ECX
    JNZ  AvSetDisplayMode_Preamble_Force480P
    ; Set Mode 7 (640x480P)
    MOV  ECX, 0x88070701
AvSetDisplayMode_Preamble_Force480P:
    ; HD flag is stored as the MSB in mode, if it's not set
    ; then store value and end the 480p patch
    JS   AvSetDisplayMode_Preamble_480p_Store
    ; Check if buffer is 640x480 or 720x480
    TEST CH, 0x1
    ; Set Mode 8 (720x480p)
    MOV  ECX, 0x88080801
    JZ   AvSetDisplayMode_Preamble_480p_Store
    ; Set Mode 7 (640x480p)
    MOV  ECX, 0x88070701
AvSetDisplayMode_Preamble_480p_Store:
    ; Store final video mode back on to the stack
    MOV  dword [EBP + 0x10], EAX
    ; Send final video mode
    PUSH dword [EBP + 0x10]
    PUSH 0x42
    CALL _XboxHDMI_REG_W32
    ; Send encoder info
    PUSH dword [ADDR_TVEncoderSMBusID]
    PUSH 0x50
    CALL _XboxHDMI_W8
    ; Send game region
    PUSH dword [ADDR_XboxGameRegion]
    PUSH 0x51
    CALL _XboxHDMI_W8
    ; Send title ID
    PUSH 0x00010118
    CALL FUNC_MmIsAddressValid
    TEST EAX, EAX
    ; Set 0xFFFFFFFF to indicate no title ID (system boot)
    MOV  EAX, 0xFFFFFFFF
    JZ   AvSetDisplayMode_Preamble_TitleID_Write
    MOV  EAX, 0x00010118
    MOV  EAX, dword [EAX]
    MOV  EAX, dword [EAX + 0x8]
AvSetDisplayMode_Preamble_TitleID_Write:
    PUSH EAX
    PUSH 0x52
    CALL _XboxHDMI_REG_W32
    ; Wait 100ms
    PUSH 100000
    CALL FUNC_KeStallExecutionProcessor
AvSetDisplayMode_Preamble_Ret:
    ; Patch back in orginal code
    MOV  DL, byte [ADDR_TVEncoderSMBusID]
    ; Jump back to orginal code
    JMP  0x80030F48

; AvSetDisplayMode_CRTC
; Jump Offsets/Size (Kernel):
;      m8plus 0x800314CC / 7
;        BEFORE:
;          800314C9 8B 4D 08        MOV        ECX, dword [EBP + 0x08]
;  *       800314CC 8A 09           MOV        CL, byte [ECX]
;  *       800314CE 80 F9 13        CMP        CL, 0x13
;  *       800314D1 8A 10           MOV        DL, byte [EAX]
;          800314D3 75 05           JNZ        0x800314DA
;          800314D5 8A 55 18        MOV        DL, byte [EBP + 0x18]
;        AFTER:
;          800314C9 E9 90 EE        JMP        AvSetDisplayMode_CRTC
;                   FF FF
;          800314CE 90              NOP ; HACK: NOP'ed to cleanup Ghidra decompiler output
;          800314CF 90              NOP
;          800314D0 90              NOP
;          800314D1 90              NOP
;          800314D2 90              NOP
;          800314D3 75 05           JNZ        0x800314DA
;          800314D5 8A 55 18        MOV        DL, byte [EBP + 0x18]
;
AvSetDisplayMode_CRTC:
    ; Check detectedXboxHDMI
    MOV  ECX, dword [EBP + -0x20]
    TEST ECX, ECX
    ; Restore CRTC register (declobber ECX/CL)
    MOV ECX, dword [EBP + 0x08]
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_CRTC_NoDevice
    ; Preserve registers
    PUSH EAX
    PUSH ECX
    PUSH EDX
    ; Calculate the index of AV_TABLE_CRTCREGISTERS_DATA that's currently being read
    MOV EAX, AV_TABLE_CRTCREGISTERS_DATA   ; AV_TABLE_CRTCREGISTERS_DATA pointer
    MOV EAX, dword [EAX]                   ; AV_TABLE_CRTCREGISTERS_DATA address
    SUB ECX, EAX                           ; Calc index offset NOTE: ECX is set right before patch
    ADD ECX, 0x68                          ; XboxHDMI timing table offset for current CRTC values
    ; Read timing value from XboxHDMI via the SMBus
    LEA  EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX                ; *DataValue
    PUSH ECX                ; CommandCode   - Read address
    CALL _XboxHDMI_AV_R8
    ; Restore registers
    POP EDX
    POP ECX
    POP EAX
    ;
    MOV DL, byte [EBP + -0x24] ; Store CRTC register value in DL
    ; Jump back to orginal code
    JMP AvSetDisplayMode_CRTC_Ret
AvSetDisplayMode_CRTC_NoDevice:
    ; Patch back in orginal code
    MOV DL, byte [EAX]
AvSetDisplayMode_CRTC_Ret:
    ; Patch back in orginal code
    MOV CL, byte [ECX]
    CMP CL, 0x13
    ; Jump back to orginal code
    JMP 0x800314D3

; AvSetDisplayMode_DAC
; Jump Patch Offsets/Size (Kernel):
;      m8plus 0x80031418 / 5
;        EDX = Address of the current header value of AV_TABLE_DACREGISTERS_DATA being read
;
;        BEFORE:
;          80031416 8B 38           MOV        EDI, dword [EAX]             ; Load NV register value from table
;  *       80031418 8B 1A           MOV        EBX, dword [EDX]             ; Move NV register offset into register
;  *       8003141A 83 C0 04        ADD        EAX, 0x4                     ; Inc table offset for loop
;  *       8003141D 89 3C 1E        MOV        dword [ESI + EBX * 0x1], EDI ; Set NV register value
;          80031423 3B C1           CMP        EAX, ECX
;        AFTER:
;          80031416 8B 38           MOV        EDI,dword [EAX]
;          80031418 E9 0E F6        JMP        _PatchLookupTableDAC
;                   FF FF
;          8003141D 83 C0 04        ADD        EAX, 0x4
;          80031420 83 C2 04        ADD        EDX, 0x4
;          80031423 3B C1           CMP        EAX, ECX
;
AvSetDisplayMode_DAC:
    ; Check detectedXboxHDMI
    MOV  EBX, dword [EBP + -0x20]
    TEST EBX, EBX
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_DAC_Ret
    ; Preserve registers
    PUSH EAX
    PUSH ECX ; Current header read address
    PUSH EDX
    ; Calculate the index of AV_TABLE_DACREGISTERS_DATA that's currently being read
    MOV EAX, AV_TABLE_DACREGISTERS_DATA ; AV_TABLE_DACREGISTERS_DATA pointer
    MOV EAX, dword [EAX]                ; AV_TABLE_DACREGISTERS_DATA address
    SUB EDX, EAX                        ; Calc index offset
    ; Read timing value from XboxHDMI via SMBus
    LEA  EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX                ; *DataValue
    PUSH EDX                ; XboxHDMI timing table offset for DAC values
    CALL _XboxHDMI_AV_R32
    ; Restore registers
    POP EDX
    POP ECX
    POP EAX
    ; Set value
    MOV EDI, [EBP + -0x24]
AvSetDisplayMode_DAC_Ret:
    MOV EBX, dword [EDX]             ; Move NV register offset into register
    MOV dword [ESI + EBX * 0x1], EDI ; Set NV register value
    ; Jump back to orginal code
    JMP 0x8003141D

; AvSetDisplayMode_FpDebug0
; Jump Patch Offsets/Size (Kernel):
;      m8plus 0x80031418 / 5
;        BEFORE:
;          80031546 0F B6 45 12     MOVZX      EAX, byte [EBP + Mode + 0x2]
;  *       8003154A 8B 04 85        MOV        EAX, dword [EAX * 0x4 + 0x80036EA0]
;                   A0 6E 03 80
;          80031551 6A 01           PUSH       0x1
;        AFTER:80030A5E
;          80031546 0F B6 45 12     MOVZX      EAX, byte [EBP + Mode + 0x2]
;          8003154A E9 0F F5        JMP        AvSetDisplayMode_FpDebug0
;                   FF FF
;          8003154F 90              NOP
;          80031550 90              NOP
;          80031551 6A 01           PUSH       0x1
AvSetDisplayMode_FpDebug0:
    ; Check detectedXboxHDMI
    MOV  EBX, dword [EBP + -0x20]
    TEST EBX, EBX
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_FpDebug0_NoDevice
    ; Preserve registers
    PUSH EAX
    PUSH ECX
    PUSH EDX
    ;
    LEA EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX               ; *DataValue
    PUSH 0x8A              ; XboxHDMI timing table offset for CRTC values
    CALL _XboxHDMI_AV_R32
    ; Restore registers
    POP EDX
    POP ECX
    POP EAX
    ; Set value
    MOV EAX, [EBP + -0x24]
    JMP AvSetDisplayMode_FpDebug0_Ret
AvSetDisplayMode_FpDebug0_NoDevice:
    ; Original logic (Fallback in case SMBus fails to read)
    DB 0x8B ; MOV EAX, dword [EAX * 0X4 - 0X7FFB3EE0]
    DB 0x04
    DB 0x85
    DB 0xA0
    DB 0x6E
    DB 0x03
    DB 0x80
AvSetDisplayMode_FpDebug0_Ret:
    ; Jump back to orginal code
    JMP 0x80031551
