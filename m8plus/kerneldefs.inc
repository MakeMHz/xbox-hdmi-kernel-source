HDMI_I2C_ADDRESS equ 0x88

ADDR_XboxGameRegion                         equ 0x8003c158
ADDR_TVEncoderSMBusID                       equ 0x8003C36C

FUNC_HalWriteSMBusValue                     equ 0x80014743
FUNC_HalReadSMBusValue                      equ 0x800145f1
FUNC_AvSetDisplayMode                       equ 0x80030f3d
FUNC_KeStallExecutionProcessor              equ 0x80015530
FUNC_MmIsAddressValid                       equ 0x8001e54a

AV_TABLE_CRTCREGISTERS_DATA                 equ 0x8003c398
AV_TABLE_DACREGISTERS_DATA                  equ 0x8003c378
