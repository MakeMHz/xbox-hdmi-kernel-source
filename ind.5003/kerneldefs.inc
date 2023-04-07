HDMI_I2C_ADDRESS equ 0x88

ADDR_XboxGameRegion                         equ 0x80042D68
ADDR_TVEncoderSMBusID                       equ 0x80042BF4

FUNC_HalWriteSMBusValue                     equ 0x80018254
FUNC_HalReadSMBusValue                      equ 0x80018179
FUNC_AvSetDisplayMode                       equ 0x8003597b
FUNC_KeStallExecutionProcessor              equ 0x80018f20
FUNC_MmIsAddressValid                       equ 0x80022d8a

AV_TABLE_CRTCREGISTERS_DATA                 equ 0x800421f8
AV_TABLE_AVPREGISTERS_DATA                  equ 0x800421FC ; AvpRegisters
