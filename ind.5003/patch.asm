%include "kerneldefs.inc"

BITS	32
	cpu	586
	org 0x80035167

; -------------------------------------------------------------------------------------------------
; Freeing up space and cleanup
;      NOP Range: 0X80035167 - 0X8003539E
; -------------------------------------------------------------------------------------------------

; Patch out calls to AvpCommitMacrovisionMode()
;        BEFORE:
;          80035D86 FF 75 F4        PUSH       dword ptr [EBP + local_10]
;          80035D89 56              PUSH       ESI
;          80035D8A E8 6E F5        CALL       AvpCommitMacrovisionMode
;                   FF FF
;        AFTER:
;          80035D86 90              NOP
;          80035D87 90              NOP
;          80035D88 90              NOP
;          80035D89 90              NOP
;          80035D8A 90              NOP
;          80035D8B 90              NOP
;          80035D8C 90              NOP
;          80035D8D 90              NOP
;          80035D8E 90              NOP

; Patch out calls to AvpSetWSSBits()
;        BEFORE:
;          8003589b 52              PUSH       EDX=>DAT_fd000000
;          8003589c e8 04 f9        CALL       AvpSetWSSBits
;                   ff ff
;        AFTER:
;          8003589b 90              NOP
;          8003589c 90              NOP
;          8003589d 90              NOP
;          8003589e 90              NOP
;          8003589f 90              NOP
;          800358a0 90              NOP
;
;        BEFORE:
;          80035faa 56              PUSH       ESI
;          80035fab a3 58 31        MOV        [AvpCurrentMode],EAX
;                   04 80
;          80035fb0 e8 f0 f1        CALL       AvpSetWSSBits
;                   ff ff
;        AFTER:
;          80035faa 90              NOP
;          80035fab a3 58 31        MOV        [AvpCurrentMode],EAX
;                   04 80
;          80035fb0 90              NOP
;          80035fb1 90              NOP
;          80035fb2 90              NOP
;          80035fb3 90              NOP
;          80035fb4 90              NOP


; -------------------------------------------------------------------------------------------------
; Helper Functions
;
; -------------------------------------------------------------------------------------------------

; __stdcall NTSTATUS XboxHDMI_W32(uchar reg, uint32_t value)
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

; __stdcall NTSTATUS XboxHDMI_W8(UCHAR CommandCode, UCHAR DataValue)
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

; __stdcall NTSTATUS XboxHDMI_AV_R8(UCHAR CommandCode, ULONG *DataValue)
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

; __stdcall NTSTATUS XboxHDMI_AV_R32(UCHAR CommandCode, ULONG *DataValue)
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

; AvSetDisplayMode:
;   Increase stack by two words for tracking XboxHDMI detection and as scratch
;   TODO: We're increasing it by three to match m8plus, this can be rewritten to two.
;        BEFORE:
;          8003597b 55              PUSH       EBP
;          8003597c 8b ec           MOV        EBP,ESP
;          8003597e 83 ec 18        SUB        ESP,0x18
;        AFTER:
;          8003597b 55              PUSH       EBP
;          8003597c 8b ec           MOV        EBP,ESP
;          8003597e 83 ec 24        SUB        ESP,0x24

; AvSetDisplayMode:
;   Patch in AvSetDisplayMode_Preamble hook
;        BEFORE:
;          800359e6 8b 5d 10        MOV        EBX,dword ptr [EBP + Mode]
;          800359e9 85 db           TEST       EBX,EBX
;          800359eb 75 08           JNZ        0x800359f5
;        AFTER:
;          800359e6 e9 3b f8        JMP        AvSetDisplayMode_Preamble
;                   ff ff
;          800359eb 75 08           JNZ        LAB_800359f5

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
    CALL _XboxHDMI_W32
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
    MOV  dword [EBP + 0x10], ECX
    ; Send final video mode
    PUSH dword [EBP + 0x10]
    PUSH 0x42
    CALL _XboxHDMI_W32
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
    CALL _XboxHDMI_W32
    ; Wait 100ms
    PUSH 100000
    CALL FUNC_KeStallExecutionProcessor
AvSetDisplayMode_Preamble_Ret:
    ; Patch back in orginal code
    MOV  EBX, dword [EBP + 0x10]
    TEST EBX, EBX
    ; Jump back to orginal code
    JMP  0x800359EB
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; AvSetDisplayMode:
;   Patch in AvSetDisplayMode_CRTC hook
;        EAX = gAvpCRTCRegisters
;        ECX = CRTC index for current CRTC table.
;         CL = Which CRTC register is being set.
;
;        BEFORE:
;          80035eab 8b 4d f8        MOV        ECX, dword [EBP + -0x8]
;          80035eae 8a 0c 08        MOV        CL, byte [EAX + ECX*0x1]
;          80035eb1 80 f9 13        CMP        CL, 0x13
;          80035eb4 8a 07           MOV        AL, byte [EDI]
;          80035eb6 75 05           JNZ        LAB_80035ebd
;        AFTER:
;          80035eab 8b 4d f8        MOV        ECX,dword ptr [EBP + local_c]
;          80035eae 8a 0c 08        MOV        CL,byte ptr [EAX + ECX*0x1]=>DAT_80015d60
;          80035eb1 e9 11 f4        JMP        AvSetDisplayMode_CRTC
;                   ff ff
;          80035eb6 75 05           JNZ        LAB_80035ebd
;
AvSetDisplayMode_CRTC:
    ; Preserve registers
    PUSH ECX
    ; Check detectedXboxHDMI
    MOV  ECX, dword [EBP + -0x20]
    TEST ECX, ECX
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_CRTC_NoDevice
    ; Preserve registers
    PUSH EAX
    PUSH EDX
    ; Calculate the XboxHDMI timing table offset for current CRTC value
    MOV ECX, dword [EBP + -0x8]
    ADD ECX, 0x68
    ; Read timing value from XboxHDMI via the SMBus
    LEA  EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX                ; *DataValue
    PUSH ECX                ; CommandCode   - Read address
    CALL _XboxHDMI_AV_R8
    ; Restore registers
    POP EDX
    POP EAX
    ;
    MOV AL, byte [EBP + -0x24] ; Store CRTC register value in DL
    ; Jump back to orginal code
    JMP AvSetDisplayMode_CRTC_Ret
AvSetDisplayMode_CRTC_NoDevice:
    ; Patch back in orginal code
    MOV AL, byte [EDI]
AvSetDisplayMode_CRTC_Ret:
    ; Restore registers
    POP ECX
    ; Patch back in orginal code
    CMP CL, 0x13
    ; Jump back to orginal code
    JMP 0x80035eb6
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; AvSetDisplayMode_AVP
; Jump Patch Offsets/Size (Kernel):
;      m8plus 0x80031418 / 5
;        EBX = AVP index for current AVP table.
;        ECX = Register value.
;
;        BEFORE:
;          80035DDC 8B 5D F8        MOV        EBX, dword [EBP + -0x8]
;          80035DDF 8B 15 FC        MOV        EDX, dword [0X800421FC]
;                   21 04 80
;          80035DE5 8B 08           MOV        ECX, dword [EAX]
;          80035DE7 8B 14 9A        MOV        EDX, dword [EDX + EBX*0x4]
;          80035DEA 83 C0 04        ADD        EAX, 0x4
;        AFTER:
;          80035DDC 8B 5D F8        MOV        EBX, DWORD [EBP + local_c]
;          80035DDF E9 23 F5        JMP        AvSetDisplayMode_AVP
;                   FF FF
;          80035DE4 8B 14 9A        MOV        EDX, dword [EDX + EBX*0X4]
;          80035DE7 90              NOP
;          80035DE8 90              NOP
;          80035DE9 90              NOP
;          80035DEA 83 C0 04        ADD        EAX, 0X4
;
AvSetDisplayMode_AVP:
    ; Check detectedXboxHDMI
    MOV  ECX, dword [EBP + -0x20]
    TEST ECX, ECX
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_AVP_NoDevice
    ; Preserve registers
    PUSH EAX
    ; Read timing value from XboxHDMI via SMBus
    LEA  EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX                ; *DataValue
    IMUL EAX, EBX, 0x04
    PUSH EAX                ; XboxHDMI timing table offset for AVP values
    CALL _XboxHDMI_AV_R32
    ; Restore registers
    POP EAX
    ; Set value
    MOV ECX, [EBP + -0x24]
    ; Jump back to orginal code
    JMP AvSetDisplayMode_AVP_Ret
AvSetDisplayMode_AVP_NoDevice:
    MOV ECX, dword [EAX]
AvSetDisplayMode_AVP_Ret:
    ; Patch back in orginal code
    MOV EDX, dword [AV_TABLE_AVPREGISTERS_DATA]
    ; Jump back to orginal code
    JMP 0x80035DE4
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP
NOP

; AvSetDisplayMode_FpDebug0
; Jump Patch Offsets/Size (Kernel):
;        BEFORE:
;          80035f38 0f b6 45 12     MOVZX      EAX,byte ptr [EBP + Mode+0x2]
;          80035f3c 8b 04 85        MOV        EAX,dword ptr [EAX*0x4 + DAT_80015fd0]
;                   d0 5f 01 80
;          80035f43 6a 01           PUSH       0x1
;        AFTER:
;          80031546 0F B6 45 12     MOVZX      EAX, byte [EBP + Mode + 0x2]
;          8003154A E9 0F F5        JMP        AvSetDisplayMode_FpDebug0
;                   FF FF
;          8003154F 90              NOP
;          80031550 90              NOP
;          80031551 6A 01           PUSH       0x1
AvSetDisplayMode_FpDebug0:
    ; Check detectedXboxHDMI
    MOV  ECX, dword [EBP + -0x20]
    TEST ECX, ECX
    ; Jump back to orginal code if HDMI is not detected
    JNZ AvSetDisplayMode_FpDebug0_NoDevice
    ;
    LEA EAX, [EBP + -0x24] ; Store return value on stack
    PUSH EAX               ; *DataValue
    PUSH 0x8A              ; XboxHDMI timing table offset for CRTC values
    CALL _XboxHDMI_AV_R32
    ; Set value
    MOV EAX, [EBP + -0x24]
    JMP AvSetDisplayMode_FpDebug0_Ret
AvSetDisplayMode_FpDebug0_NoDevice:
    ; Original logic (Fallback in case SMBus fails to read)
    DB 0x8B ; EAX,dword ptr [EAX*0x4 + DAT_80015fd0]
    DB 0x04
    DB 0x85
    DB 0xD0
    DB 0x5F
    DB 0x01
    DB 0x80
AvSetDisplayMode_FpDebug0_Ret:
    ; Jump back to orginal code
    JMP 0x80035F43
