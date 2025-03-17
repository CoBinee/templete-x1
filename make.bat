@echo off
z88dk-z80asm -mz80 -l -o=crt0.o crt0.asm
z88dk-z80asm -mz80 -l -o=xcs.o xcs.asm
z88dk-z80asm -mz80 -l -o=app.o app.asm
z88dk-z80asm -b -mz80 -split-bin -g -o=x1.bin crt0.o xcs.0 app.o
z88dk-appmake +x1 -b x1_boot.bin -o x1.d88 --org 0000
