############################################################################
# 
# Filename: build.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/20/2026
#
# Description: This file is what you assemble in RARS to create the 
#              Z-machine emulator executable.
#
# Functions:
#
############################################################################# 

## include constants, macros, and the story code
.include "z_game.s"
.include "tables.s"
.include "macros.s"
.include "constants.s"




.text
.globl start
start:
    DEBUG_7SEG_IMM(0xA001)
    j main

## include main and stuff
.include "main.s"
.include "opcodes.s"
.include "math.s"
.include "opcode_utils.s"
.include "objects.s"
.include "strings.s"
.include "vga.s"
.include "z_memory.s"
.include "dictionary.s"
