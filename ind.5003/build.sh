#!/usr/bin/env bash
nasm -f bin -o patch.bin patch.asm
cp xboxkrnl_org.img xboxkrnl.img
dd conv=notrunc skip=$((0x0340)) seek=$((0x0340)) count=$((0x2AD80)) if=xboxkrnl.img.bin of=xboxkrnl.img bs=1
