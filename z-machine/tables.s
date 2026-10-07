############################################################################
# 
# Filename: tables.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/20/2026
#
# Description: This will eventually probably hold several tables... for now,
#              it just holds the zscii to ascii tables, and it will probably eventually
#              hold the ascii or ps/2 to zscii table as well
#
#
############################################################################# 

.data
.global ZSCII_CHAR_TABLE
ZSCII_CHAR_TABLE:
    # Alphabet A0 (Indices 0-31)
    .ascii "      abcdefghijklmnopqrstuvwxyz"
.global ALPHABET_A1
ALPHABET_A1:
    # Alphabet A1 (Indices 32-63)
    .ascii "      ABCDEFGHIJKLMNOPQRSTUVWXYZ"
.global ALPHABET_A2
ALPHABET_A2:
    # Alphabet A2 (Indices 64-95)
    # index 6 is 10-bit ZSCII escape (handled in code), index 7 is newline
    .ascii "       \r0123456789.,!?_#'\"/\\-:()"

.global PUNCT_TABLE
# this table holds the zscii values for punctuation and numbers in ascii, with the index - 32 (so space
# which is decimal 32 in ascii, is index 0 in this table)
PUNCT_TABLE:
    .byte -1 # space
    .byte 0x14 # exclamation point
    .byte 0x19 # quotation mark
    .byte 0x17 # pound sign
    .byte -1 # dollar sign
    .byte -1 # percent sign
    .byte -1 # ampersand
    .byte 0x18 # single quote
    .byte 0x1e # left parenthesis
    .byte 0x1f # right parenthesis
    .byte -1 # asterisk
    .byte -1 # plus sign
    .byte 0x13 # comma
    .byte 0x1c # hyphen
    .byte 0x12 # period
    .byte 0x1a # slash, dec 47
    .byte 0x08 # 0, dec 48
    .byte 0x09 # 1, dec 49
    .byte 0x0a # 2, dec 50
    .byte 0x0b # 3, dec 51
    .byte 0x0c # 4, dec 52
    .byte 0x0d # 5, dec 53
    .byte 0x0e # 6, dec 54
    .byte 0x0f # 7, dec 55
    .byte 0x10 # 8, dec 56
    .byte 0x11 # 9, dec 57
    .byte 0x1d # colon, dec 58
    .byte -1 # semicolon
    .byte -1 # less than
    .byte -1 # equals
    .byte -1 # greater than
    .byte 0x15 # question mark dec 63
.global PUNCT_TABLE_PART_2
PUNCT_TABLE_PART_2:    
    .byte -1 # left bracket, dec 91
    .byte 0x1b # backslash, dec 92
    .byte -1 # right bracket, dec 93
    .byte 0x07 # caret, dec 94
    .byte 0x16 # underscore, dec 95
