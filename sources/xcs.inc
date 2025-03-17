; xcs.inc - X1 Control System
;

; アプリケーション
;
    defc    XCS_APP_START                               =   $1800

; I/O
;
    ; FDC
    defc    XCS_IO_FDC_STATUS                           =   $0ff8
    defc    XCS_IO_FDC_COMMAND                          =   $0ff8
    defc    XCS_IO_FDC_TRACK                            =   $0ff9
    defc    XCS_IO_FDC_SECTOR                           =   $0ffa
    defc    XCS_IO_FDC_DATA                             =   $0ffb
    defc    XCS_IO_FDC_MHD                              =   $0ffc
    defc    XCS_IO_FDC_STATUS_NOT_READY                 =   %10000000
    defc    XCS_IO_FDC_STATUS_WRITE_PROTECT             =   %01000000
    defc    XCS_IO_FDC_STATUS_HEAD_ENGAGED              =   %00100000
    defc    XCS_IO_FDC_STATUS_RECORD_TYPE               =   %00100000
    defc    XCS_IO_FDC_STATUS_WRITE_FAULT               =   %00100000
    defc    XCS_IO_FDC_STATUS_SEEK_ERROR                =   %00010000
    defc    XCS_IO_FDC_STATUS_RECORD_NOT_FOUND          =   %00010000
    defc    XCS_IO_FDC_STATUS_CRC_ERROR                 =   %00001000
    defc    XCS_IO_FDC_STATUS_TRACK00                   =   %00000100
    defc    XCS_IO_FDC_STATUS_LOST_DATA                 =   %00000100
    defc    XCS_IO_FDC_STATUS_INDEX                     =   %00000010
    defc    XCS_IO_FDC_STATUS_DATA_REQUEST              =   %00000010
    defc    XCS_IO_FDC_STATUS_BUSY                      =   %00000001
    defc    XCS_IO_FDC_STATUS_NOT_READY_BIT             =   7
    defc    XCS_IO_FDC_STATUS_WRITE_PROTECT_BIT         =   6
    defc    XCS_IO_FDC_STATUS_HEAD_ENGAGED_BIT          =   5
    defc    XCS_IO_FDC_STATUS_RECORD_TYPE_BIT           =   5
    defc    XCS_IO_FDC_STATUS_WRITE_FAULT_BIT           =   5
    defc    XCS_IO_FDC_STATUS_SEEK_ERROR_BIT            =   4
    defc    XCS_IO_FDC_STATUS_RECORD_NOT_FOUND_BIT      =   4
    defc    XCS_IO_FDC_STATUS_CRC_ERROR_BIT             =   3
    defc    XCS_IO_FDC_STATUS_TRACK00_BIT               =   2
    defc    XCS_IO_FDC_STATUS_LOST_DATA_BIT             =   2
    defc    XCS_IO_FDC_STATUS_INDEX_BIT                 =   1
    defc    XCS_IO_FDC_STATUS_DATA_REQUEST_BIT          =   1
    defc    XCS_IO_FDC_STATUS_BUSY_BIT                  =   0
    defc    XCS_IO_FDC_COMMAND_RESTORE                  =   %00000010
    defc    XCS_IO_FDC_COMMAND_SEEK                     =   %00011110
    defc    XCS_IO_FDC_COMMAND_STEP                     =   %00111010
    defc    XCS_IO_FDC_COMMAND_STEP_IN                  =   %01011010
    defc    XCS_IO_FDC_COMMAND_STEP_OUT                 =   %01111010
    defc    XCS_IO_FDC_COMMAND_READ_DATA                =   %10000000
    defc    XCS_IO_FDC_COMMAND_WRITE_DATA               =   %10100000
    defc    XCS_IO_FDC_COMMAND_MULTI_READ_DATA          =   %10010000
    defc    XCS_IO_FDC_COMMAND_MULTI_WRITE_DATA         =   %10110000
    defc    XCS_IO_FDC_COMMAND_READ_ADDRESS             =   %11000000
    defc    XCS_IO_FDC_COMMAND_READ_TRACK               =   %11100000
    defc    XCS_IO_FDC_COMMAND_WRITE_TRACK              =   %11110000
    defc    XCS_IO_FDC_COMMAND_FORCE_INTERRUPT          =   %11010000
    defc    XCS_IO_FDC_MHD_MOTOR_OFF                    =   %00000000
    defc    XCS_IO_FDC_MHD_MOTOR_ON                     =   %10000000
    defc    XCS_IO_FDC_MHD_HEAD_0                       =   %00000000
    defc    XCS_IO_FDC_MHD_HEAD_1                       =   %00010000
    defc    XCS_IO_FDC_MHD_DRIVE_0                      =   %10000000
    defc    XCS_IO_FDC_MHD_DRIVE_1                      =   %10000001
    defc    XCS_IO_FDC_MHD_DRIVE_2                      =   %10000010
    defc    XCS_IO_FDC_MHD_DRIVE_3                      =   %10000011
    
    ; パレット
    defc    XCS_IO_PALETTE_BLUE                         =   $1000
    defc    XCS_IO_PALETTE_RED                          =   $1100
    defc    XCS_IO_PALETTE_GREEN                        =   $1200

    ; プライオリティ
    defc    XCS_IO_PRIORITY                             =   $1300

    ; PCG
    defc    XCS_IO_PCG_BLUE                             =   $1500
    defc    XCS_IO_PCG_RED                              =   $1600
    defc    XCS_IO_PCG_GREEN                            =   $1700

    ; CRTC
    defc    XCS_IO_CRTC_REGISTER                        =   $1800
    defc    XCS_IO_CRTC_DATA                            =   $1801

    ; 80C49
    defc    XCS_IO_80C49                                =   $1900
    defc    XCS_IO_80C49_SET_KEY_VECTOR                 =   $e4
    defc    XCS_IO_80C49_GET_KEY                        =   $e6
    defc    XCS_IO_80C49_KEY_FUNCTION_10KEY             =   %10000000
    defc    XCS_IO_80C49_KEY_FUNCTION_INKEY             =   %01000000
    defc    XCS_IO_80C49_KEY_FUNCTION_REPEAT            =   %00100000
    defc    XCS_IO_80C49_KEY_FUNCTION_GRAPH             =   %00010000
    defc    XCS_IO_80C49_KEY_FUNCTION_CAPSLOCK          =   %00001000
    defc    XCS_IO_80C49_KEY_FUNCTION_KANA              =   %00000100
    defc    XCS_IO_80C49_KEY_FUNCTION_SHIFT             =   %00000010
    defc    XCS_IO_80C49_KEY_FUNCTION_CTRL              =   %00000001
    defc    XCS_IO_80C49_KEY_FUNCTION_10KEY_BIT         =   7
    defc    XCS_IO_80C49_KEY_FUNCTION_INKEY_BIT         =   6
    defc    XCS_IO_80C49_KEY_FUNCTION_REPEAT_BIT        =   5
    defc    XCS_IO_80C49_KEY_FUNCTION_GRAPH_BIT         =   4
    defc    XCS_IO_80C49_KEY_FUNCTION_CAPSLOCK_BIT      =   3
    defc    XCS_IO_80C49_KEY_FUNCTION_KANA_BIT          =   2
    defc    XCS_IO_80C49_KEY_FUNCTION_SHIFT_BIT         =   1
    defc    XCS_IO_80C49_KEY_FUNCTION_CTRL_BIT          =   0

    ; 8255
    defc    XCS_IO_8255_A                               =   $1a00
    defc    XCS_IO_8255_B                               =   $1a01
    defc    XCS_IO_8255_C                               =   $1a02
    defc    XCS_IO_8255_CONTROL                         =   $1a03
    defc    XCS_IO_8255_B_V_DISP                        =   %10000000
    defc    XCS_IO_8255_B_IBF                           =   %01000000
    defc    XCS_IO_8255_B_OBF                           =   %00100000
    defc    XCS_IO_8255_B_IPL_RESET                     =   %00010000
    defc    XCS_IO_8255_B_BUSY                          =   %00001000
    defc    XCS_IO_8255_B_CV_SYNC                       =   %00000100
    defc    XCS_IO_8255_B_READ_DATA                     =   %00000010
    defc    XCS_IO_8255_B_BREAK                         =   %00000001
    defc    XCS_IO_8255_B_V_DISP_BIT                    =   7
    defc    XCS_IO_8255_B_IBF_BIT                       =   6
    defc    XCS_IO_8255_B_OBF_BIT                       =   5
    defc    XCS_IO_8255_B_IPL_RESET_BIT                 =   4
    defc    XCS_IO_8255_B_BUSY_BIT                      =   3
    defc    XCS_IO_8255_B_CV_SYNC_BIT                   =   2
    defc    XCS_IO_8255_B_READ_DATA_BIT                 =   1
    defc    XCS_IO_8255_B_BREAK_BIT                     =   0
    defc    XCS_IO_8255_C_STROBE                        =   %10000000
    defc    XCS_IO_8255_C_80_40                         =   %01000000
    defc    XCS_IO_8255_C_DAM_SEL                       =   %00100000
    defc    XCS_IO_8255_C_SCROLL                        =   %00010000
    defc    XCS_IO_8255_C_WRITE_DATA                    =   %00000001
    defc    XCS_IO_8255_C_STROBE_BIT                    =   7
    defc    XCS_IO_8255_C_80_40_BIT                     =   6
    defc    XCS_IO_8255_C_DAM_SEL_BIT                   =   5
    defc    XCS_IO_8255_C_SCROLL_BIT                    =   4
    defc    XCS_IO_8255_C_WRITE_DATA_BIT                =   0

    ; PSG
    defc    XCS_IO_PSG_DATA                             =   $1b00
    defc    XCS_IO_PSG_REGISTER                         =   $1c00
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_A             =   $00
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_A_L           =   $00
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_A_H           =   $01
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_B             =   $02
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_B_L           =   $02
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_B_H           =   $03
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_C             =   $04
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_C_L           =   $04
    defc    XCS_IO_PSG_REGISTER_FREQUENCY_C_H           =   $05
    defc    XCS_IO_PSG_REGISTER_NOISE                   =   $06
    defc    XCS_IO_PSG_REGISTER_MIXING                  =   $07
    defc    XCS_IO_PSG_REGISTER_VOLUME_A                =   $08
    defc    XCS_IO_PSG_REGISTER_VOLUME_B                =   $09
    defc    XCS_IO_PSG_REGISTER_VOLUME_C                =   $0a
    defc    XCS_IO_PSG_REGISTER_ENVELOPE_CYCLE          =   $0b
    defc    XCS_IO_PSG_REGISTER_ENVELOPE_CYCLE_L        =   $0b
    defc    XCS_IO_PSG_REGISTER_ENVELOPE_CYCLE_H        =   $0c
    defc    XCS_IO_PSG_REGISTER_ENVELOPE_PATTERN        =   $0d
    defc    XCS_IO_PSG_REGISTER_PORT_A                  =   $0e
    defc    XCS_IO_PSG_REGISTER_PORT_B                  =   $0f
    defc    XCS_IO_PSG_REGISTER_SIZE                    =   $10
    defc    XCS_IO_PSG_MIXING_TONE_A                    =   %00000001
    defc    XCS_IO_PSG_MIXING_TONE_B                    =   %00000010
    defc    XCS_IO_PSG_MIXING_TONE_C                    =   %00000100
    defc    XCS_IO_PSG_MIXING_NOISE_A                   =   %00001000
    defc    XCS_IO_PSG_MIXING_NOISE_B                   =   %00010000
    defc    XCS_IO_PSG_MIXING_NOISE_C                   =   %00100000
    defc    XCS_IO_PSG_MIXING_PORT_A                    =   %01000000
    defc    XCS_IO_PSG_MIXING_PORT_B                    =   %10000000

    ; スティック
    defc    XCS_IO_STICK_UP                             =   %00000001
    defc    XCS_IO_STICK_DOWN                           =   %00000010
    defc    XCS_IO_STICK_LEFT                           =   %00000100
    defc    XCS_IO_STICK_RIGHT                          =   %00001000
    defc    XCS_IO_STICK_A                              =   %00100000
    defc    XCS_IO_STICK_B                              =   %01000000

    ; テキスト
    defc    XCS_IO_TEXT_ATTRIBUTE                       =   $2000
    defc    XCS_IO_TEXT_ATTRIBUTE_0                     =   $2000
    defc    XCS_IO_TEXT_ATTRIBUTE_1                     =   $2400
    defc    XCS_IO_TEXT_ATTRIBUTE_BYTES                 =   40 * 25
    defc    XCS_IO_TEXT_ATTRIBUTE_Hx2                   =   %10000000
    defc    XCS_IO_TEXT_ATTRIBUTE_Vx2                   =   %01000000
    defc    XCS_IO_TEXT_ATTRIBUTE_PCG                   =   %00100000
    defc    XCS_IO_TEXT_ATTRIBUTE_BLINK                 =   %00010000
    defc    XCS_IO_TEXT_ATTRIBUTE_REVERSE               =   %00001000
    defc    XCS_IO_TEXT_ATTRIBUTE_BLACK                 =   %00000000
    defc    XCS_IO_TEXT_ATTRIBUTE_BLUE                  =   %00000001
    defc    XCS_IO_TEXT_ATTRIBUTE_RED                   =   %00000010
    defc    XCS_IO_TEXT_ATTRIBUTE_MAGENTA               =   %00000011
    defc    XCS_IO_TEXT_ATTRIBUTE_GREEN                 =   %00000100
    defc    XCS_IO_TEXT_ATTRIBUTE_CYAN                  =   %00000101
    defc    XCS_IO_TEXT_ATTRIBUTE_YELLOW                =   %00000110
    defc    XCS_IO_TEXT_ATTRIBUTE_WHITE                 =   %00000111
    defc    XCS_IO_TEXT_ATTRIBUTE_COLOR_MASK            =   %00000111
    defc    XCS_IO_TEXT_ATTRIBUTE_Hx2_BIT               =   7
    defc    XCS_IO_TEXT_ATTRIBUTE_Vx2_BIT               =   6
    defc    XCS_IO_TEXT_ATTRIBUTE_PCG_BIT               =   5
    defc    XCS_IO_TEXT_ATTRIBUTE_BLINK_BIT             =   4
    defc    XCS_IO_TEXT_ATTRIBUTE_REVERSE_BIT           =   3
    defc    XCS_IO_TEXT_VRAM                            =   $3000
    defc    XCS_IO_TEXT_VRAM_0                          =   $3000
    defc    XCS_IO_TEXT_VRAM_1                          =   $3400
    defc    XCS_IO_TEXT_VRAM_SIZE_X                     =   40
    defc    XCS_IO_TEXT_VRAM_SIZE_Y                     =   25
    defc    XCS_IO_TEXT_VRAM_BYTES                      =   XCS_IO_TEXT_VRAM_SIZE_X * XCS_IO_TEXT_VRAM_SIZE_Y

    ; グラフィック
    defc    XCS_IO_GRAPHIC_VRAM_BLUE                    =   $4000
    defc    XCS_IO_GRAPHIC_VRAM_RED                     =   $8000
    defc    XCS_IO_GRAPHIC_VRAM_GREEN                   =   $c000
    defc    XCS_IO_GRAPHIC_VRAM_BLUE_RED_GREEN          =   $0000
    defc    XCS_IO_GRAPHIC_VRAM_RED_GREEN               =   $4000
    defc    XCS_IO_GRAPHIC_VRAM_BLUE_GREEN              =   $8000
    defc    XCS_IO_GRAPHIC_VRAM_BLUE_RED                =   $c000
    defc    XCS_IO_GRAPHIC_VRAM_SIZE_PLANE              =   3
    defc    XCS_IO_GRAPHIC_VRAM_SIZE_X                  =   40
    defc    XCS_IO_GRAPHIC_VRAM_SIZE_Y                  =   25
    defc    XCS_IO_GRAPHIC_VRAM_SIZE_LINE               =   200
    defc    XCS_IO_GRAPHIC_VRAM_BYTES                   =   XCS_IO_GRAPHIC_VRAM_SIZE_X * XCS_IO_GRAPHIC_VRAM_SIZE_LINE

; Hu-BASIC ファイルフォーマット
;
    defc    XCS_HU_TRACK_SIZE                           =   40
    defc    XCS_HU_HEAD_SIZE                            =   2
    defc    XCS_HU_CLUSTER_SIZE                         =   XCS_HU_TRACK_SIZE * XCS_HU_HEAD_SIZE
    defc    XCS_HU_SECTOR_SIZE                          =   16
    defc    XCS_HU_SECTOR_BYTES                         =   256

    ; ブートセクタ
    defc    XCS_HU_BOOT_TRACK                           =   0
    defc    XCS_HU_BOOT_HEAD                            =   0
    defc    XCS_HU_BOOT_CLUSTER                         =   XCS_HU_BOOT_TRACK * XCS_HU_HEAD_SIZE + XCS_HU_BOOT_TRACK
    defc    XCS_HU_BOOT_SECTOR                          =   0
    defc    XCS_HU_BOOT_FLAG                            =   $00
    defc    XCS_HU_BOOT_STARTUP_LABEL                   =   $01
    defc    XCS_HU_BOOT_FILE_EXTENSION                  =   $0e
    defc    XCS_HU_BOOT_SIZE                            =   $12
    defc    XCS_HU_BOOT_LOAD_ADDRESS                    =   $14
    defc    XCS_HU_BOOT_EXECUTE_ADDRESS                 =   $16
    defc    XCS_HU_BOOT_MODIFIED_DATE                   =   $18
    defc    XCS_HU_BOOT_START_SECTOR                    =   $1e
    defc    XCS_HU_BOOY_BYTES                           =   $20
    defc    XCS_HU_BOOT_FLAG_OFF                        =   $00
    defc    XCS_HU_BOOT_FLAG_BOOTABLE                   =   $01
    defc    XCS_HU_BOOT_STARTUP_LABEL_LENGTH            =   13
    defc    XCS_HU_BOOT_FILE_EXTENSION_LENGTH           =   4
    defc    XCS_HU_BOOT_MODIFIED_DATE_YEAR              =   0
    defc    XCS_HU_BOOT_MODIFIED_DATE_MONTH_WEEK        =   1
    defc    XCS_HU_BOOT_MODIFIED_DATE_DAY               =   2
    defc    XCS_HU_BOOT_MODIFIED_DATE_HOURS             =   3
    defc    XCS_HU_BOOT_MODIFIED_DATE_MINUTES           =   4
    defc    XCS_HU_BOOT_MODIFIED_DATE_SECONDS           =   5
    defc    XCS_HU_BOOT_MODIFIED_DATE_BYTES             =   6

    ; ファイルアロケーションテーブル
    defc    XCS_HU_FAT_TRACK                            =   0
    defc    XCS_HU_FAT_HEAD                             =   0
    defc    XCS_HU_FAT_CLUSTER                          =   XCS_HU_FAT_TRACK * XCS_HU_HEAD_SIZE + XCS_HU_FAT_HEAD
    defc    XCS_HU_FAT_SECTOR                           =   14
    defc    XCS_HU_FAT_SIZE                             =   XCS_HU_CLUSTER_SIZE
    defc    XCS_HU_FAT_FREE                             =   $00
    defc    XCS_HU_FAT_TERMINATE                        =   %10000000
    defc    XCS_HU_FAT_TERMINATE_BIT                    =   7

    ; ディレクトリ
    defc    XCS_HU_DIRECTORY_TRACK                      =   0
    defc    XCS_HU_DIRECTORY_HEAD                       =   1
    defc    XCS_HU_DIRECTORY_CLUSTER                    =   XCS_HU_DIRECTORY_TRACK * XCS_HU_HEAD_SIZE + XCS_HU_DIRECTORY_HEAD
    defc    XCS_HU_DIRECTORY_SECTOR                     =   0
    defc    XCS_HU_DIRECTORY_ATTRIBUTE                  =   $00
    defc    XCS_HU_DIRECTORY_FILE_NAME                  =   $01
    defc    XCS_HU_DIRECTORY_FILE_EXTENSION             =   $0e
    defc    XCS_HU_DIRECTORY_PASSCODE                   =   $11
    defc    XCS_HU_DIRECTORY_SIZE                       =   $12
    defc    XCS_HU_DIRECTORY_LOAD_ADDRESS               =   $14
    defc    XCS_HU_DIRECTORY_EXECUTE_ADDRESS            =   $16
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE              =   $18
    defc    XCS_HU_DIRECTORY_START_CLUSTER              =   $1e
    defc    XCS_HU_DIRECTORY_BYTES                      =   $20
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_KILL             =   $00
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_BIN              =   $01
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_BAS              =   $02
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_ASC              =   $04
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_HIDDEN           =   $10
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_VERIFY           =   $20
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_READ_ONLY        =   $40
    defc    XCS_HU_DIRECTORY_ATTRIBUTE_DIRECTORY        =   $80
    defc    XCS_HU_DIRECTORY_FILE_NAME_LENGTH           =   13
    defc    XCS_HU_DIRECTORY_FILE_EXTENSION_LENGTH      =   3
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_YEAR         =   0
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_MONTH_WEEK   =   1
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_DAY          =   2
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_HOURS        =   3
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_MINUTES      =   4
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_SECONDS      =   5
    defc    XCS_HU_DIRECTORY_MODIFIED_DATE_BYTES        =   6
    defc    XCS_HU_DIRECTORY_SECTOR_ENTRY               =   XCS_HU_SECTOR_BYTES / XCS_HU_DIRECTORY_BYTES
    defc    XCS_HU_DIRECTORY_ENTRY                      =   $10

; PSG
;
    defc    XCS_PSG_CHANNEL_A                           =   $00
    defc    XCS_PSG_CHANNEL_B                           =   $01
    defc    XCS_PSG_CHANNEL_C                           =   $02
    defc    XCS_PSG_CHANNEL_D                           =   $03
    defc    XCS_PSG_CHANNEL_SIZE                        =   $04
    defc    XCS_PSG_CHANNEL_HEAD                        =   $00
    defc    XCS_PSG_CHANNEL_HEAD_L                      =   $00
    defc    XCS_PSG_CHANNEL_HEAD_H                      =   $01
    defc    XCS_PSG_CHANNEL_PLAY                        =   $02
    defc    XCS_PSG_CHANNEL_PLAY_L                      =   $02
    defc    XCS_PSG_CHANNEL_PLAY_H                      =   $03
    defc    XCS_PSG_CHANNEL_INSTRUMENT                  =   $04
    defc    XCS_PSG_CHANNEL_INSTRUMENT_L                =   $04
    defc    XCS_PSG_CHANNEL_INSTRUMENT_H                =   $05
    defc    XCS_PSG_CHANNEL_WAVE                        =   $06
    defc    XCS_PSG_CHANNEL_FRAME                       =   $07
    defc    XCS_PSG_CHANNEL_LOOP                        =   $08
    defc    XCS_PSG_CHANNEL_REGISTER_FREQUENCY          =   $09
    defc    XCS_PSG_CHANNEL_REGISTER_FREQUENCY_L        =   $09
    defc    XCS_PSG_CHANNEL_REGISTER_FREQUENCY_H        =   $0a
    defc    XCS_PSG_CHANNEL_REGISTER_VOLUME             =   $0b
    defc    XCS_PSG_CHANNEL_REGISTER_VOLUME_L           =   $0b
    defc    XCS_PSG_CHANNEL_REGISTER_VOLUME_H           =   $0c
    defc    XCS_PSG_CHANNEL_MIXING                      =   $0d
    defc    XCS_PSG_CHANNEL_FLAG_FREQUENCY              =   $0e
    defc    XCS_PSG_CHANNEL_FLAG_VOLUME                 =   $0f
    defc    XCS_PSG_CHANNEL_BYTES                       =   $10
    defc    XCS_PSG_FLAG_FREQUENCY_A                    =   %00000001
    defc    XCS_PSG_FLAG_FREQUENCY_B                    =   %00000010
    defc    XCS_PSG_FLAG_FREQUENCY_C                    =   %00000100
    defc    XCS_PSG_FLAG_VOLUME_A                       =   %00001000
    defc    XCS_PSG_FLAG_VOLUME_B                       =   %00010000
    defc    XCS_PSG_FLAG_VOLUME_C                       =   %00100000
    defc    XCS_PSG_FLAG_MIXING                         =   %01000000
    defc    XCS_PSG_FLAG_FREQUENCY_A_BIT                =   0
    defc    XCS_PSG_FLAG_FREQUENCY_B_BIT                =   1
    defc    XCS_PSG_FLAG_FREQUENCY_C_BIT                =   2
    defc    XCS_PSG_FLAG_VOLUME_A_BIT                   =   3
    defc    XCS_PSG_FLAG_VOLUME_B_BIT                   =   4
    defc    XCS_PSG_FLAG_VOLUME_C_BIT                   =   5
    defc    XCS_PSG_FLAG_MIXING_BIT                     =   6

; サウンドフォーマット
;
    defc    XCS_SOUND_WAVE_BYTES                        =   $40
    defc    XCS_SOUND_WAVE_MASK                         =   $3f
    defc    XCS_SOUND_NOTE_FREQUENCY_H                  =   $00
    defc    XCS_SOUND_NOTE_CONTROL                      =   $00
    defc    XCS_SOUND_NOTE_FREQUENCY_L                  =   $01
    defc    XCS_SOUND_NOTE_FRAME                        =   $02
    defc    XCS_SOUND_NOTE_VOLUME                       =   $03
    defc    XCS_SOUND_NOTE_INSTRUMENT                   =   $03
    defc    XCS_SOUND_NOTE_BYTES                        =   $04
    defc    XCS_SOUND_NOTE_FREQUENCY_H_MASK             =   $0f
    defc    XCS_SOUND_NOTE_CONTROL_REST_BIT             =   4
    defc    XCS_SOUND_NOTE_CONTROL_TERMINATE_BIT        =   7
    defc    XCS_SOUND_NOTE_VOLUME_MASK                  =   $0f
    defc    XCS_SOUND_NOTE_INSTRUMENT_MASK              =   $f0


; 関数の宣言
;
    extern  _xcs_initialize
    extern  _xcs_update
    extern  _xcs_files
    extern  _xcs_bload
    extern  _xcs_bsave
    extern  _xcs_brun
    extern  _xcs_send_80c49
    extern  _xcs_receive_80c49
    extern  _xcs_load_sound
    extern  _xcs_play_bgm
    extern  _xcs_stop_bgm
    extern  _xcs_is_play_bgm
    extern  _xcs_play_se
    extern  _xcs_wait_v_dsip_on
    extern  _xcs_wait_v_dsip_off
    extern  _xcs_width_40
    extern  _xcs_width_80
    extern  _xcs_set_screen_0
    extern  _xcs_set_screen_1
    extern  _xcs_set_priority_front
    extern  _xcs_set_priority_back
    extern  _xcs_load_pcg
    extern  _xcs_load_pcg_1
    extern  _xcs_calc_vram_offset
    extern  _xcs_calc_text_vram_0
    extern  _xcs_calc_text_vram_1
    extern  _xcs_calc_text_attribute_0
    extern  _xcs_calc_text_attribute_1
    extern  _xcs_clear_text_vram_0
    extern  _xcs_clear_text_vram_1
    extern  _xcs_set_text_vram_0
    extern  _xcs_set_text_vram_1
    extern  _xcs_clear_text_attribute_0
    extern  _xcs_clear_text_attribute_1
    extern  _xcs_print_hex_chars
    extern  _xcs_print_string
    extern  _xcs_calc_graphic_vram_blue
    extern  _xcs_calc_graphic_vram_red
    extern  _xcs_calc_graphic_vram_green
    extern  _xcs_clear_graphic_vram
    extern  _xcs_draw_image
    extern  _xcs_calc_8x8_tile
    extern  _xcs_draw_8x8_tile
    extern  _xcs_get_hex_chars
    extern  _xcs_get_decimal_string
    extern  _xcs_get_decimal_string_left
    extern  _xcs_get_decimal_string_right

    ; デバッグ
    extern  _xcs_debug_print_hex_chars
    extern  _xcs_debug_print_string
    extern  _xcs_debug_put_hex_chars
    extern  _xcs_debug_put_char
    extern  _xcs_debug_put_string
    extern  _xcs_debug_dump_16
    extern  _xcs_debug_dump_256
    extern  _xcs_debug_newline
    extern  _xcs_debug_scrollup


; 変数の宣言
;
    extern  _xcs_key_function_push
    extern  _xcs_key_code_push
    extern  _xcs_key_code_edge
    extern  _xcs_stick_push
    extern  _xcs_stick_edge
