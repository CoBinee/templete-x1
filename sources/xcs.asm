; xcs.asm - X1 Control System
;

; モジュールの宣言
;
    module  xcs


; ファイルの参照
;
    include "xcs.inc"


; コードの定義
;
    section boot

; XCS を初期化する
;
_xcs_initialize:

    ; パレットの設定
    ld      bc, XCS_IO_PALETTE_BLUE
    ld      a, $aa
    out     (c), a
    inc     b
    ld      a, $cc
    out     (c), a
    inc     b
    ld      a, $f0
    out     (c), a

    ; プライオリティの設定／グラフィックをテキストの背面に
    call    _xcs_set_priority_back

    ; CRTC の設定
    call    _xcs_width_40

    ; 80C49 の設定
    ld      hl, xcs_initialize_80c49_key_vector
    ld      e, $02
    call    _xcs_send_80c49

    ; 8255 の設定
    ld      bc, XCS_IO_8255_C
    in      a, (c)
    set     XCS_IO_8255_C_80_40_BIT, a
    out     (c), a

    ; キーの初期化
    ld      hl, $0000
    ld      (_xcs_key_function_push), hl
    ld      (xcs_key_function_edge), hl
    ld      (xcs_key_function_last), hl

    ; スティックの初期化
    xor     a
    ld      (_xcs_stick_push), a
    ld      (_xcs_stick_edge), a
    ld      (xcs_stick_last), a

    ; PSG のクリア
    call    xcs_clear_psg

    ; テキストのクリア
    ld      d, XCS_IO_TEXT_ATTRIBUTE_PCG | XCS_IO_TEXT_ATTRIBUTE_WHITE
    call    _xcs_clear_text_attribute_0
    ld      d, ' '
    call    _xcs_clear_text_vram_0
    ld      d, XCS_IO_TEXT_ATTRIBUTE_WHITE
    call    _xcs_clear_text_attribute_1
    ld      d, ' '
    call    _xcs_clear_text_vram_1

    ; グラフィックのクリア
    ld      d, $00
    call    _xcs_clear_graphic_vram

    ; スクリーンの設定
;;  call    _xcs_set_screen_0
    call    _xcs_set_screen_1

    ; PCG 定義用の属性の設定
    ld      bc, XCS_IO_TEXT_ATTRIBUTE_0 + XCS_IO_TEXT_VRAM_BYTES
    ld      d, $0400 - XCS_IO_TEXT_VRAM_BYTES
    ld      a, XCS_IO_TEXT_ATTRIBUTE_PCG
.xcs_initialize_pcg_0
    out     (c), a
    inc     bc
    dec     d
    jr      nz, xcs_initialize_pcg_0
    ld      bc, XCS_IO_TEXT_ATTRIBUTE_1 + XCS_IO_TEXT_VRAM_BYTES
    ld      d, $0400 - XCS_IO_TEXT_VRAM_BYTES
;   ld      a, XCS_IO_TEXT_ATTRIBUTE_PCG
.xcs_initialize_pcg_1
    out     (c), a
    inc     bc
    dec     d
    jr      nz, xcs_initialize_pcg_1

    ; デバッグの初期化
    ld      de, ((XCS_IO_TEXT_VRAM_SIZE_Y - 1) << 8) | (0)
    ld      (xcs_debug_cursor), de

    ; ドライブ 0 のヘッドをトラック 0 にシークする
    call    xcs_fdc_0_restore

    ; FAT の読み込み
    call    xcs_fdc_0_load_fat

    ; ディレクトリの読み込み
    call    xcs_fdc_0_load_directory

    ; 終了
    ret

; キー入力割り込みベクタの初期値
.xcs_initialize_80c49_key_vector
    defb    $e4, $00

; XCS を更新する
;
_xcs_update:

    ; 垂直帰線期間待ち
    call    _xcs_wait_v_dsip_on

    ; キーの更新
    call    xcs_update_key

    ; スティックの更新
    call    xcs_update_stick

    ; PSG の更新
    call    xcs_update_psg

    ; スクリーンの切り替え
    ld      a, (_xcs_key_code_edge)
    cp      $09
    jr      nz, xcs_update_screen_end
    ld      a, (xcs_screen)
    or      a
    jr      z, xcs_update_screen_1
    call    _xcs_set_screen_0
    jr      xcs_update_screen_end
.xcs_update_screen_1
    call    _xcs_set_screen_1
.xcs_update_screen_end

    ; 終了
    ret

; ドライブ 0 のファイルリストを出力する
;
_xcs_files:

    ; ディレクトリの走査
    ld      de, xcs_fdc_0_directory
    ld      b, XCS_HU_DIRECTORY_ENTRY
.xcs_files_loop
    push    bc

    ; ファイルの存在
    ld      a, (de)
    or      a
    jr      z, xcs_files_next
    inc     a
    jr      z, xcs_files_next

    ; 改行
    call    _xcs_debug_newline

    ; ファイル名の表示
    call    xcs_fdc_get_directory_filename
    call    _xcs_debug_put_string

    ; ファイルサイズの表示
    push    de
    ld      a, ' '
    call    _xcs_debug_put_char
    ld      hl, XCS_HU_DIRECTORY_SIZE
    add     hl, de
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    call    _xcs_get_decimal_string_right
    call    _xcs_debug_put_string
    ld      hl, xcs_files_string
    call    _xcs_debug_put_string
    pop     de

    ; 次のディレクトリへ
.xcs_files_next
    ld      hl, XCS_HU_DIRECTORY_BYTES
    add     hl, de
    ex      de, hl
    pop     bc
    djnz    xcs_files_loop

    ; 終了
    ret

; 文字列
.xcs_files_string
    defb    " bytes", $00

; ドライブ 0 のバイナリファイルを読み込む
;
_xcs_bload:

    ; IN
    ;   de = ファイル名
    ;   hl = 読み込み先のアドレス

    ; 引数の保存
    ld      (xcs_bload_filename), de
    ld      (xcs_bload_address), hl

    ; リトライ
.xcs_bload_retry

    ; ファイルの検索
    ex      de, hl
    call    xcs_fdc_0_find_directory
    ld      a, d
    or      e
    jp      z, xcs_bload_error
    ld      hl, xcs_bload_string_load
    call    _xcs_debug_put_string
    ld      hl, (xcs_bload_filename)
    call    _xcs_debug_put_string
    ld      a, '\"'
    call    _xcs_debug_put_char

    ; ファイルサイズの取得
    ld      hl, XCS_HU_DIRECTORY_SIZE
    add     hl, de
    ld      c, (hl)
    inc     hl
    ld      b, (hl)
    ld      (xcs_bload_bytes), bc

    ; 開始クラスタの取得
    ld      hl, XCS_HU_DIRECTORY_START_CLUSTER
    add     hl, de
    ld      d, (hl)

    ; クラスタの読み込み／d = クラスタ番号
.xcs_bload_loop

    ; FAT の取得
    ld      c, d
    ld      b, $00
    ld      hl, xcs_fdc_0_fat
    add     hl, bc
    ld      a, (hl)
    ld      (xcs_bload_fat), a

    ; ヘッドの選択
    srl     d
    push    de
    jr      c, xcs_bload_head_1
    call    xcs_fdc_0_start_0
    jr      xcs_bload_head_end
.xcs_bload_head_1
    call    xcs_fdc_0_start_1
.xcs_bload_head_end
    pop     de

    ; 読み込むバイト数の取得
    ld      bc, (xcs_bload_bytes)
    ld      h, b
    ld      l, c
    ld      a, b
    cp      (XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES) >> 8
    jr      c, xcs_bload_bytes_end
    ld      bc, XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES
.xcs_bload_bytes_end
    or      a
    sbc     hl, bc
    ld      (xcs_bload_bytes), hl

    ; 読み込み先のアドレスの取得
    ld      hl, (xcs_bload_address)
    push    hl
    add     hl, bc
    ld      (xcs_bload_address), hl
    pop     hl

    ; 1 クラスタの読み込み
    ld      e, $00
    call    xcs_fdc_0_load_cluster

    ; 次のクラスタへ
    ld      hl, (xcs_bload_bytes)
    ld      a, h
    or      l
    jr      z, xcs_bload_end
    ld      a, (xcs_bload_fat)
    ld      d, a
    jr      xcs_bload_loop

    ; 終了
.xcs_bload_end
    call    xcs_fdc_0_stop
    ret

    ;  エラー
.xcs_bload_error
    call    _xcs_debug_newline
    ld      a, '\"'
    call    _xcs_debug_put_char
    ld      hl, (xcs_bload_filename)
    call    _xcs_debug_put_string
    ld      hl, xcs_bload_string_error
    call    _xcs_debug_put_string
    call    xcs_fdc_error
    ld      hl, (xcs_bload_address)
    ld      de, (xcs_bload_filename)
    jp      xcs_bload_retry

; ファイル名
.xcs_bload_filename
    defs    $02

; アドレス
.xcs_bload_address
    defs    $02

; ファイルサイズ
.xcs_bload_bytes
    defs    $02

; FAT
.xcs_bload_fat
    defs    $01

; 文字列
.xcs_bload_string_load
    defb    "\nLOAD\"", $00
.xcs_bload_string_error
    defb    "\" NOT FOUND.", $00

; ドライブ 0 へバイナリファイルを書き込む
;
_xcs_bsave:

    ; IN
    ;   de = ファイル名
    ;   hl = 書き込み元のアドレス
    ;   bc = 書き込むバイト数

    ; 引数の保存
    ld      (xcs_bsave_filename), de
    ld      (xcs_bsave_address), hl
    ld      (xcs_bsave_bytes), bc
    ld      (xcs_bsave_rest), bc

    ; リトライ
.xcs_bsave_retry

    ; FAT の取得
    ld      hl, XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES - $0001
    add     hl, bc
    srl     h
    srl     h
    srl     h
    srl     h
    push    hl
    call    xcs_fdc_0_get_free_fat_size
    pop     hl
    cp      h
    jp      c, xcs_bsave_error
    call    xcs_fdc_0_get_free_fat
    ld      (xcs_bsave_fat_start), a

    ; ディレクトリの取得
    ld      hl, (xcs_bsave_filename)
    call    xcs_fdc_0_find_directory
    ld      a, d
    or      e
    jr      z, xcs_bsave_directory_free
    ld      hl, XCS_HU_DIRECTORY_START_CLUSTER
    add     hl, de
    ld      a, (hl)
    jr      xcs_bsave_directory_end
.xcs_bsave_directory_free
    call    xcs_fdc_0_get_free_directory
    ld      a, d
    or      e
    jp      z, xcs_bsave_error
    ld      a, $ff
.xcs_bsave_directory_end
    ld      (xcs_bsave_directory), de
    ld      (xcs_bsave_fat_last), a
    ld      hl, xcs_bsave_string_save
    call    _xcs_debug_put_string
    ld      hl, (xcs_bsave_filename)
    call    _xcs_debug_put_string
    ld      a, '\"'
    call    _xcs_debug_put_char

    ; 開始クラスタの取得
    ld      a, (xcs_bsave_fat_start)

    ; クラスタの書き込み／a = クラスタ番号
.xcs_bsave_loop

    ; FAT の保存
    ld      (xcs_bsave_fat_current), a
    ld      d, a

    ; ヘッドの選択
    srl     d
    push    de
    jr      c, xcs_bsave_head_1
    call    xcs_fdc_0_start_0
    jr      xcs_bsave_head_end
.xcs_bsave_head_1
    call    xcs_fdc_0_start_1
.xcs_bsave_head_end
    pop     de

    ; 書き込むバイト数の取得
    ld      bc, (xcs_bsave_rest)
    ld      h, b
    ld      l, c
    ld      a, b
    cp      (XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES) >> 8
    jr      c, xcs_bsave_rest_end
    ld      bc, XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES
.xcs_bsave_rest_end
    or      a
    sbc     hl, bc
    ld      (xcs_bsave_rest), hl

    ; 書き込み先のアドレスの取得
    ld      hl, (xcs_bsave_address)
    push    hl
    add     hl, bc
    ld      (xcs_bsave_address), hl
    pop     hl

    ; 1 クラスタの書き込み
    ld      e, $00
    push    bc
    call    xcs_fdc_0_save_cluster
    pop     bc

    ; 次のクラスタへ
    ld      a, (xcs_bsave_fat_current)
    ld      e, a
    ld      d, $00
    ld      hl, xcs_fdc_0_fat
    add     hl, de
    ld      a, b
    cp      (XCS_HU_SECTOR_SIZE * XCS_HU_SECTOR_BYTES) >> 8
    jr      c, xcs_bsave_fat_terminate
    ld      (hl), e
    push    hl
    call    xcs_fdc_0_get_free_fat
    pop     hl
    ld      (hl), a
    jr      xcs_bsave_loop

    ; FAT の終端の設定
.xcs_bsave_fat_terminate
    ld      a, c
    or      a
    jr      z, xcs_bsave_fat_terminate_end
    inc     b
.xcs_bsave_fat_terminate_end
    ld      a, b
    or      XCS_HU_FAT_TERMINATE
    ld      (hl), a

    ; 上書き時の直前の FAT の消去
    ld      a, (xcs_bsave_fat_last)
    cp      $ff
    jr      z, xcs_bsave_fat_erase_end
.xcs_bsave_fat_erase_loop
    ld      e, a
    ld      d, $00
    ld      hl, xcs_fdc_0_fat
    add     hl, de
    ld      a, (hl)
    ld      (hl), $00
    bit     7, a
    jr      z, xcs_bsave_fat_erase_loop
.xcs_bsave_fat_erase_end

    ; ディレクトリの設定
    ld      de, (xcs_bsave_directory)
    ld      hl, XCS_HU_DIRECTORY_ATTRIBUTE
    add     hl, de
    ld      (hl), XCS_HU_DIRECTORY_ATTRIBUTE_BIN
    push    de
    ld      hl, XCS_HU_DIRECTORY_FILE_NAME
    add     hl, de
    ld      de, (xcs_bsave_filename)
    ex      de, hl
    ld      bc, XCS_HU_DIRECTORY_FILE_NAME_LENGTH + XCS_HU_DIRECTORY_FILE_EXTENSION_LENGTH
    ldir
    pop     de
    ld      hl, XCS_HU_DIRECTORY_PASSCODE
    add     hl, de
    ld      (hl), ' '
    ld      hl, XCS_HU_DIRECTORY_SIZE
    add     hl, de
    ld      bc, (xcs_bsave_bytes)
    ld      (hl), c
    inc     hl
    ld      (hl), b
    ld      hl, XCS_HU_DIRECTORY_LOAD_ADDRESS
    add     hl, de
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    ld      hl, XCS_HU_DIRECTORY_EXECUTE_ADDRESS
    add     hl, de
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    ld      hl, XCS_HU_DIRECTORY_MODIFIED_DATE
    add     hl, de
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    inc     hl
    ld      (hl), $00
    ld      hl, XCS_HU_DIRECTORY_START_CLUSTER
    add     hl, de
    ld      a, (xcs_bsave_fat_start)
    ld      (hl), a
    inc     hl
    ld      (hl), $00

;   ; モーターを止める
;   call    xcs_fdc_0_stop

    ; FAT の書き込み
    call    xcs_fdc_0_save_fat

    ; ディレクトリの書き込み
    call    xcs_fdc_0_save_directory
    
    ; 終了
    ret

    ;  エラー
.xcs_bsave_error
    call    _xcs_debug_newline
    ld      a, '\"'
    call    _xcs_debug_put_char
    ld      hl, (xcs_bsave_filename)
    call    _xcs_debug_put_string
    ld      hl, xcs_bsave_string_error
    call    _xcs_debug_put_string
    call    xcs_fdc_error
    ld      de, (xcs_bsave_filename)
    ld      hl, (xcs_bsave_address)
    ld      bc, (xcs_bsave_bytes)
    jp      xcs_bsave_retry

; ファイル名
.xcs_bsave_filename
    defs    $02

; アドレス
.xcs_bsave_address
    defs    $02

; ファイルサイズ
.xcs_bsave_bytes
    defs    $02

; 書き込む残りのサイズ
.xcs_bsave_rest
    defs    $02

; FAT
.xcs_bsave_fat_start
    defs    $01
.xcs_bsave_fat_current
    defs    $01
.xcs_bsave_fat_last
    defs    $01

; ディレクトリ
.xcs_bsave_directory
    defs    $02

; 文字列
.xcs_bsave_string_save
    defb    "\nSAVE\"", $00
.xcs_bsave_string_error
    defb    "\" NOT WRITE.", $00

; ドライブ 0 のバイナリファイルを実行する
;
_xcs_brun:

    ; IN
    ;   de = ファイル名
    ;   hl = 読み込み先のアドレス

    ; ファイルの読み込み
    push    hl
    call    _xcs_bload

    ; 実行
    pop     hl
    jp      (hl)

; ドライブ 0 の FAT を読み込む
;
xcs_fdc_0_load_fat:

    ; FAT はヘッド 0
    call    xcs_fdc_0_start_0

    ; FAT の読み込み
    ld      de, (XCS_HU_FAT_TRACK << 8) | XCS_HU_FAT_SECTOR
    ld      hl, xcs_fdc_0_fat
    ld      bc, XCS_HU_FAT_SIZE
    call    xcs_fdc_0_load_cluster

    ; ドライブの停止
    call    xcs_fdc_0_stop

    ; 終了
    ret

; ドライブ 0 の FAT を書き込む
;
xcs_fdc_0_save_fat:

    ; FAT はヘッド 0
    call    xcs_fdc_0_start_0

    ; FAT の書き込み
    ld      de, (XCS_HU_FAT_TRACK << 8) | XCS_HU_FAT_SECTOR
    ld      hl, xcs_fdc_0_fat
    ld      bc, XCS_HU_FAT_SIZE
    call    xcs_fdc_0_save_cluster

    ; ドライブの停止
    call    xcs_fdc_0_stop

    ; 終了
    ret

; ドライブ 0 の FAT で空いているクラスタの数を取得する
;
xcs_fdc_0_get_free_fat_size:

    ; OUT
    ;   a = 空いているクラスタの数

    ; FAT の走査
    ld      hl, xcs_fdc_0_fat
    ld      bc, (XCS_HU_FAT_SIZE << 8) | $00
.xcs_fdc_0_get_free_fat_size_loop
    ld      a, (hl)
    or      a
    jr      nz, xcs_fdc_0_get_free_fat_size_next
    inc     c
.xcs_fdc_0_get_free_fat_size_next
    inc     hl
    djnz    xcs_fdc_0_get_free_fat_size_loop
    ld      a, c

    ; 終了
    ret

; ドライブ 0 の FAT で空いているクラスタを取得する
;
xcs_fdc_0_get_free_fat:

    ; OUT
    ;   a = 空いているクラスタ

    ; FAT の走査
    ld      hl, xcs_fdc_0_fat
    ld      bc, (XCS_HU_FAT_SIZE << 8) | $00
.xcs_fdc_0_get_free_fat_loop
    ld      a, (hl)
    or      a
    jr      z, xcs_fdc_0_get_free_fat_end
    inc     hl
    inc     c
    djnz    xcs_fdc_0_get_free_fat_loop
    ld      c, $ff
.xcs_fdc_0_get_free_fat_end
    ld      a, c

    ; 終了
    ret

; ドライブ 0 のディレクトリを読み込む
;
xcs_fdc_0_load_directory:

    ; ディレクトリはヘッド 1
    call    xcs_fdc_0_start_1

    ; ディレクトリの読み込み
    ld      de, (XCS_HU_DIRECTORY_TRACK << 8) | XCS_HU_DIRECTORY_SECTOR
    ld      hl, xcs_fdc_0_directory
    ld      bc, XCS_HU_DIRECTORY_ENTRY * XCS_HU_DIRECTORY_BYTES
    call    xcs_fdc_0_load_cluster

    ; ドライブの停止
    call    xcs_fdc_0_stop

    ; 終了
    ret

; ドライブ 0 のディレクトリを書き込む
;
xcs_fdc_0_save_directory:

    ; ディレクトリはヘッド 1
    call    xcs_fdc_0_start_1

    ; ディレクトリの書き込み
    ld      de, (XCS_HU_DIRECTORY_TRACK << 8) | XCS_HU_DIRECTORY_SECTOR
    ld      hl, xcs_fdc_0_directory
    ld      bc, XCS_HU_DIRECTORY_ENTRY * XCS_HU_DIRECTORY_BYTES
    call    xcs_fdc_0_save_cluster

    ; ドライブの停止
    call    xcs_fdc_0_stop

    ; 終了
    ret

; ドライブ 0 のディレクトリを検索する
;
xcs_fdc_0_find_directory:

    ; IN
    ;   hl = ファイル名
    ; OUT
    ;   de = ディレクトリ / 0...なし

    ; ディレクトリの走査
    ld      de, xcs_fdc_0_directory
    ld      b, XCS_HU_DIRECTORY_ENTRY
.xcs_fdc_find_directory_loop

    ; ファイルの存在
    ld      a, (de)
    or      a
    jr      z, xcs_fdc_find_directory_next
    cp      $ff
    jr      z, xcs_fdc_find_directory_next

    ; ファイル名の比較
    push    hl
    push    de
    inc     de
    ld      c, XCS_HU_DIRECTORY_FILE_NAME_LENGTH + XCS_HU_DIRECTORY_FILE_EXTENSION_LENGTH
.xcs_fdc_find_directory_compare
    ld      a, (de)
    cp      (hl)
    jr      nz, xcs_fdc_find_directory_compare_end
    inc     de
    inc     hl
    dec     c
    jr      nz, xcs_fdc_find_directory_compare
.xcs_fdc_find_directory_compare_end
    pop     de
    pop     hl
    jr      z, xcs_fdc_find_directory_end

    ; 次のディレクトリへ
.xcs_fdc_find_directory_next
    push    hl
    ld      hl, XCS_HU_DIRECTORY_BYTES
    add     hl, de
    ex      de, hl
    pop     hl
    djnz    xcs_fdc_find_directory_loop

    ; なし
    ld      de, $0000

    ; 終了
.xcs_fdc_find_directory_end
    ret

; ドライブ 0 の空いているディレクトリを取得する
;
xcs_fdc_0_get_free_directory:

    ; OUT
    ;   de = ディレクトリ / 0...なし

    ; ディレクトリの走査
    ld      hl, xcs_fdc_0_directory
    ld      de, XCS_HU_DIRECTORY_BYTES
    ld      b, XCS_HU_DIRECTORY_ENTRY
.xcs_fdc_get_free_directory_loop

    ; ファイルの存在
    ld      a, (hl)
    or      a
    jr      z, xcs_fdc_get_free_directory_end
    cp      $ff
    jr      z, xcs_fdc_get_free_directory_end

    ; 次のディレクトリへ
    add     hl, de
    djnz    xcs_fdc_get_free_directory_loop

    ; なし
    ld      hl, $0000

    ; 終了
.xcs_fdc_get_free_directory_end
    ex      de, hl
    ret

; ディレクトリのファイル名を取得する
;
xcs_fdc_get_directory_filename:

    ; IN
    ;   de = ディレクトリ
    ; OUT
    ;   hl = ファイル名

    ; ファイル名の取得
    push    de
;   ld      hl, XCS_HU_DIRECTORY_FILE_NAME
;   add     hl, de
    ex      de, hl
    inc     hl
    ld      de, xcs_fdc_get_directory_filename_string
    ld      bc, XCS_HU_DIRECTORY_FILE_NAME_LENGTH + XCS_HU_DIRECTORY_FILE_EXTENSION_LENGTH
    ldir
    pop     de
    ld      hl, xcs_fdc_get_directory_filename_string

    ; 終了
    ret

; ファイル名
.xcs_fdc_get_directory_filename_string
    defs    XCS_HU_DIRECTORY_FILE_NAME_LENGTH + XCS_HU_DIRECTORY_FILE_EXTENSION_LENGTH
    defb    $00

; ドライブ 0 を開始する
;
xcs_fdc_0_start:

; ヘッド 0 の指定
xcs_fdc_0_start_0:

    ; ヘッド 0 を指定してモーターを動かす
    ld      bc, XCS_IO_FDC_MHD
    ld      a, XCS_IO_FDC_MHD_MOTOR_ON | XCS_IO_FDC_MHD_HEAD_0 | XCS_IO_FDC_MHD_DRIVE_0
    out     (c), a
    call    xcs_fdc_ready

    ; 終了
    ret

; ヘッド 1 の指定
xcs_fdc_0_start_1:

    ; ヘッド 1 を指定してモーターを動かす
    ld      bc, XCS_IO_FDC_MHD
    ld      a, XCS_IO_FDC_MHD_MOTOR_ON | XCS_IO_FDC_MHD_HEAD_1 | XCS_IO_FDC_MHD_DRIVE_0
    out     (c), a
    call    xcs_fdc_ready

    ; 終了
    ret

; ドライブ 0 を停止する
;
xcs_fdc_0_stop:

    ; モーターを止める
    ld      bc, XCS_IO_FDC_MHD
    ld      a, XCS_IO_FDC_MHD_MOTOR_OFF | XCS_IO_FDC_MHD_HEAD_0 | XCS_IO_FDC_MHD_DRIVE_0
    out     (c), a

    ; 終了
    ret

; ドライブ 0 をトラック 0 にシークする
;
xcs_fdc_0_restore:

    ; ドライブの開始
    call    xcs_fdc_0_start

    ; リストアコマンドの発行
    ld      bc, XCS_IO_FDC_COMMAND
    ld      a, XCS_IO_FDC_COMMAND_RESTORE
    out     (c), a
    call    xcs_fdc_ready

    ; 現在のトラックの取得
    ld      bc, XCS_IO_FDC_TRACK
    in      a, (c)
    ld      (xcs_fdc_0_track), a

    ; ドライブの停止
    call    xcs_fdc_0_stop

    ; 終了
    ret

; ドライブ 0 を目的のトラックにシークする
;
xcs_fdc_0_seek:

    ; IN
    ;   a = トラック番号

    ; シークの実行
    ld      bc, XCS_IO_FDC_DATA
    out     (c), a
    ld      bc, XCS_IO_FDC_TRACK
    ld      a, (xcs_fdc_0_track)
    out     (c), a
    ld      bc, XCS_IO_FDC_COMMAND
    ld      a, XCS_IO_FDC_COMMAND_SEEK
    out     (c), a
    call    xcs_fdc_ready

    ; 現在のトラックの取得
    ld      bc, XCS_IO_FDC_TRACK
    in      a, (c)
    ld      (xcs_fdc_0_track), a

    ; 終了
    ret

; ドライブ 0 の 1 クラスタを読み込む
;
xcs_fdc_0_load_cluster:

    ; IN
    ;   d  = トラック番号
    ;   e  = セクタ番号
    ;   hl = 読み込み先のアドレス
    ;   bc = 読み込むバイト数（クラスタのサイズ以下）

    ; 引数の保存
    push    hl
    push    bc

    ; トラックの指定
    push    de
    ld      a, d
    call    xcs_fdc_0_seek
    pop     de

    ; セクタの指定（1..16 を指定する）
    ld      bc, XCS_IO_FDC_SECTOR
    inc     e
    out     (c), e
    call    xcs_fdc_ready

    ; de に読み込むバイト数を設定
    pop     de
    pop     hl

    ; アドレスの設定
    ld      bc, XCS_IO_FDC_DATA
    exx
    ld      bc, XCS_IO_FDC_COMMAND

    ; READ DATA コマンドの発行
    ld      a, XCS_IO_FDC_COMMAND_MULTI_READ_DATA
    out     (c), a

    ; 少し待つ
    ld      a, $07
.xcs_fdc_0_load_cluster_wait
    dec     a
    jr      nz, xcs_fdc_0_load_cluster_wait

    ; データの読み込み
.xcs_fdc_0_load_cluster_read
    in      a, (c)
    bit     XCS_IO_FDC_STATUS_BUSY_BIT, a
    jr      z, xcs_fdc_0_load_cluster_end
    bit     XCS_IO_FDC_STATUS_DATA_REQUEST_BIT, a
    jr      z, xcs_fdc_0_load_cluster_read
    exx
    in      a, (c)
    ld      (hl), a
    inc     hl
    dec     de
    ld      a, d
    or      e
    exx
    jr      nz, xcs_fdc_0_load_cluster_read
    ld      a, XCS_IO_FDC_COMMAND_FORCE_INTERRUPT
    out     (c), a
    call    xcs_fdc_ready

    ; 終了
.xcs_fdc_0_load_cluster_end
    ret

; ドライブ 0 の 1 セクタをバッファに読み込む
;
xcs_fdc_0_load_buffer:

    ; IN
    ;   d = トラック番号
    ;   e = セクタ番号

    ; トラックの指定
    push    de
    ld      a, d
    call    xcs_fdc_0_seek
    pop     de

    ; セクタの指定（1..16 を指定する）
    ld      bc, XCS_IO_FDC_SECTOR
    inc     e
    out     (c), e
    call    xcs_fdc_ready

    ; アドレスの設定
    ld      bc, XCS_IO_FDC_COMMAND
    exx
    ld      bc, XCS_IO_FDC_DATA
    ld      hl, xcs_fdc_buffer
    exx

    ; READ DATA コマンドの発行
    ld      a, XCS_IO_FDC_COMMAND_READ_DATA
    out     (c), a

    ; 少し待つ
    ld      a, $07
.xcs_fdc_0_load_buffer_wait
    dec     a
    jr      nz, xcs_fdc_0_load_buffer_wait

    ; データの読み込み
.xcs_fdc_0_load_buffer_read
    in      a, (c)
    bit     XCS_IO_FDC_STATUS_BUSY_BIT, a
    jr      z, xcs_fdc_0_load_buffer_end
    bit     XCS_IO_FDC_STATUS_DATA_REQUEST_BIT, a
    jr      z, xcs_fdc_0_load_buffer_read
    exx
    in      a, (c)
    ld      (hl), a
    inc     hl
    exx
    jr      xcs_fdc_0_load_buffer_read

    ; 終了
.xcs_fdc_0_load_buffer_end
    ret

; ドライブ 0 の 1 クラスタへ書き込む
;
xcs_fdc_0_save_cluster:

    ; IN
    ;   d  = トラック番号
    ;   e  = セクタ番号
    ;   hl = 書き込み元のアドレス
    ;   bc = 書き込むバイト数（クラスタのサイズ以下）

    ; 引数の保存
    push    hl
    push    bc

    ; トラックの指定
    push    de
    ld      a, d
    call    xcs_fdc_0_seek
    pop     de

    ; セクタの指定（1..16 を指定する）
    ld      bc, XCS_IO_FDC_SECTOR
    inc     e
    out     (c), e
    call    xcs_fdc_ready

    ; de に書き込むバイト数を設定
    pop     de
    pop     hl

    ; アドレスの設定
    ld      bc, XCS_IO_FDC_DATA
    exx
    ld      bc, XCS_IO_FDC_COMMAND

    ; READ DATA コマンドの発行
    ld      a, XCS_IO_FDC_COMMAND_MULTI_WRITE_DATA
    out     (c), a

    ; 少し待つ
    ld      a, $07
.xcs_fdc_0_save_cluster_wait
    dec     a
    jr      nz, xcs_fdc_0_save_cluster_wait

    ; データの書き込み
.xcs_fdc_0_save_cluster_write
    in      a, (c)
    bit     XCS_IO_FDC_STATUS_BUSY_BIT, a
    jr      z, xcs_fdc_0_save_cluster_end
    bit     XCS_IO_FDC_STATUS_DATA_REQUEST_BIT, a
    jr      z, xcs_fdc_0_save_cluster_write
    exx
    ld      a, (hl)
    out     (c), a
    inc     hl
    dec     de
    ld      a, d
    or      e
    exx
    jr      nz, xcs_fdc_0_save_cluster_write
    ld      a, XCS_IO_FDC_COMMAND_FORCE_INTERRUPT
    out     (c), a
    call    xcs_fdc_ready

    ; 終了
.xcs_fdc_0_save_cluster_end
    ret

; ドライブ 0 の 1 セクタへバッファから書き込む
;
xcs_fdc_0_save_buffer:

    ; IN
    ;   d = トラック番号
    ;   e = セクタ番号

    ; トラックの指定
    push    de
    ld      a, d
    call    xcs_fdc_0_seek
    pop     de

    ; セクタの指定（1..16 を指定する）
    ld      bc, XCS_IO_FDC_SECTOR
    inc     e
    out     (c), e
    call    xcs_fdc_ready

    ; アドレスの設定
    ld      bc, XCS_IO_FDC_COMMAND
    exx
    ld      bc, XCS_IO_FDC_DATA
    ld      hl, xcs_fdc_buffer
    exx

    ; READ DATA コマンドの発行
    ld      a, XCS_IO_FDC_COMMAND_WRITE_DATA
    out     (c), a

    ; 少し待つ
    ld      a, $07
.xcs_fdc_0_save_buffer_wait
    dec     a
    jr      nz, xcs_fdc_0_save_buffer_wait

    ; データの書き込み
.xcs_fdc_0_save_buffer_read
    in      a, (c)
    bit     XCS_IO_FDC_STATUS_BUSY_BIT, a
    jr      z, xcs_fdc_0_save_buffer_end
    bit     XCS_IO_FDC_STATUS_DATA_REQUEST_BIT, a
    jr      z, xcs_fdc_0_save_buffer_read
    exx
    ld      a, (hl)
    out     (c), a
    inc     hl
    exx
    jr      xcs_fdc_0_save_buffer_read

    ; 終了
.xcs_fdc_0_save_buffer_end
    ret

; FDC が準備完了となるまで待つ
;
xcs_fdc_ready:

    ; レジスタの保存
    push    hl
    push    bc
    push    de

    ; ステータスの監視
.xcs_fdc_ready_retry
    ld      bc, XCS_IO_FDC_STATUS
    ld      de, $0000
.xcs_fdc_ready_loop
    in      a, (c)
    and     XCS_IO_FDC_STATUS_NOT_READY | XCS_IO_FDC_STATUS_BUSY
    jr      z, xcs_fdc_ready_end
    dec     de
    ld      a, d
    or      e
    jr      nz, xcs_fdc_ready_loop
    call    xcs_fdc_error
    jr      xcs_fdc_ready_retry

    ; レジスタの復帰
.xcs_fdc_ready_end
    pop     de
    pop     bc
    pop     hl

    ; 終了
    ret

; デバッグ用文字列
.xcs_fdc_ready_string_status
    defb    "  ", $00

; ディスクエラーを表示する
;
xcs_fdc_error:

    ; スクリーン 1 の設定
    call    _xcs_set_screen_1

    ; エラーメッセージの表示
    ld      hl, xcs_fdc_error_string
    call    _xcs_debug_put_string

    ; キー入力待ち
.xcs_fdc_error_loop
    call    _xcs_wait_v_dsip_off
    call    _xcs_wait_v_dsip_on
    call    xcs_update_key
    ld      a, (_xcs_key_code_edge)
    or      a
    jr      z, xcs_fdc_error_loop

    ; スクリーン 0 の設定
    call    _xcs_set_screen_0

    ; 終了
    ret

; エラーの文字列
.xcs_fdc_error_string
    defb    "\nDISK ERROR.\nINSERT CORRECT DISK AND HIT ANY KEY.", $00

; ドライブ 0 のトラック番号
;
.xcs_fdc_0_track
    defs    $01

; ドライブ 0 の FAT
;
.xcs_fdc_0_fat
    defs    XCS_HU_FAT_SIZE

; ドライブ 0 のディレクトリ（最大 XCS_HU_DIRECTORY_ENTRY まで）
;
.xcs_fdc_0_directory
    defs    XCS_HU_DIRECTORY_ENTRY * XCS_HU_DIRECTORY_BYTES

; 1 セクタ分の読み込みバッファ
;
.xcs_fdc_buffer
    defs    XCS_HU_SECTOR_BYTES

; 80C49 にデータを送信できるまで待つ
;
xcs_80c49_wait_sendable:

    ; 8255 の監視
    ld      bc, XCS_IO_8255_B
.xcs_80c49_wait_sendable_loop
    in      a, (c)
    and     XCS_IO_8255_B_IBF
    jr      nz, xcs_80c49_wait_sendable_loop

    ; 終了
    ret
    
; 80C49 からデータを受信できるまで待つ
;
xcs_80c49_wait_receivable:

    ; 8255 の監視
    ld      bc, XCS_IO_8255_B
.xcs_80c49_wait_receivable_loop
    in      a, (c)
    and     XCS_IO_8255_B_OBF
    jr      nz, xcs_80c49_wait_receivable_loop

    ; 終了
    ret

; 80C49 にデータを 1 byte 送信する
;
xcs_80c49_send_byte:

    ; IN
    ;   d = 送信データ

    ; 送信待ち
    call    xcs_80c49_wait_sendable

    ; 1 byte の送信
    ld      bc, XCS_IO_80C49
    out     (c), d

    ; 終了
    ret

; 80C49 からデータを 1 byte 受信する
;
xcs_80c49_receive_byte:

    ; OUT
    ;   d = 受信データ

    ; 送信待ち
    call    xcs_80c49_wait_receivable

    ; 1 byte の受信
    ld      bc, XCS_IO_80C49
    in      d, (c)

    ; 終了
    ret

; 80C49 にデータを送る
;
_xcs_send_80c49:

    ; IN
    ;   e  = 送信データバイト数
    ;   hl = 送信データの参照（1 byte 目はコマンド）

    ; コマンドの送信
    ei
    ld      d, (hl)
    call    xcs_80c49_send_byte
    inc     hl
    dec     e
    di

    ; データの送信
.xcs_send_80c49_loop
    ld      d, (hl)
    call    xcs_80c49_send_byte
    inc     hl
    dec     e
    jr      nz, xcs_send_80c49_loop

    ; 終了
    ei
    ret

; 80C49 からデータを受け取る
;
_xcs_receive_80c49:

    ; IN
    ;   d  = コマンド
    ;   e  = 受信データバイト数
    ;   hl = 受信データの格納場所

    ; コマンドの送信
    ei
    call    xcs_80c49_send_byte
    di

    ; データの受信
.xcs_receive_80c49_loop
    call    xcs_80c49_receive_byte
    ld      (hl), d
    inc     hl
    dec     e
    jr      nz, xcs_receive_80c49_loop

    ; 終了
    ei
    ret

; キーを更新する
;
xcs_update_key:

    ; 直前のキーの更新
    ld      hl, (_xcs_key_function_push)
    ld      (xcs_key_function_last), hl

    ; キーの取得
    ld      hl, _xcs_key_function_push
    ld      de, (XCS_IO_80C49_GET_KEY << 8) | $02
    call    _xcs_receive_80c49

    ; キーデータの更新
    ld      a, (_xcs_key_function_push)
    cpl
    ld      (_xcs_key_function_push), a
    ld      a, (xcs_key_code_last)
    ld      e, a
    ld      a, (_xcs_key_code_push)
    cp      e
    jr      nz, xcs_update_key_edge
    xor     a
.xcs_update_key_edge
    ld      (_xcs_key_code_edge), a

    ; 終了
    ret

; キーデータ
;
_xcs_key_function_push:
    defs    $01
_xcs_key_code_push:
    defs    $01
.xcs_key_function_edge
    defs    $01
_xcs_key_code_edge:
    defs    $01
.xcs_key_function_last
    defs    $01
.xcs_key_code_last
    defs    $01

; スティックを更新する
;
xcs_update_stick:

    ; 直前のスティックの更新
    ld      a, (_xcs_stick_push)
    ld      (xcs_stick_last), a

    ; スティックの取得
    ld      bc, XCS_IO_PSG_REGISTER
    ld      a, XCS_IO_PSG_REGISTER_PORT_A
    out     (c), a
    dec     b
    in      a, (c)

    ; スティックデータの更新
    cpl
    ld      (_xcs_stick_push), a
    ld      e, a
    ld      a, (xcs_stick_last)
    xor     e
    and     e
    ld      (_xcs_stick_edge), a

    ; 終了
    ret

; スティックデータ
;
_xcs_stick_push:
    defs    $01
_xcs_stick_edge:
    defs    $01
.xcs_stick_last
    defs    $01

; PSG をクリアする
;
xcs_clear_psg:

    ;  レジスタのクリア
    ld      hl, xcs_psg_register
    ld      b, XCS_IO_PSG_REGISTER_SIZE
    xor     a
.xcs_clear_psg_register
    ld      (hl), a
    inc     hl
    djnz    xcs_clear_psg_register
    ld      a, %00111111
    ld      (xcs_psg_register + XCS_IO_PSG_REGISTER_MIXING), a

    ; フラグのクリア
    ld      a, $ff
    ld      (xcs_psg_flag), a

    ; チャンネルのクリア
    ld      ix, xcs_psg_channel_a
    ld      de, XCS_PSG_CHANNEL_BYTES
    ld      b, XCS_PSG_CHANNEL_SIZE
    xor     a
.xcs_clear_psg_channel
    ld      (ix + XCS_PSG_CHANNEL_HEAD_L), a
    ld      (ix + XCS_PSG_CHANNEL_HEAD_H), a
    ld      (ix + XCS_PSG_CHANNEL_PLAY_L), a
    ld      (ix + XCS_PSG_CHANNEL_PLAY_H), a
    ld      (ix + XCS_PSG_CHANNEL_INSTRUMENT_L), a
    ld      (ix + XCS_PSG_CHANNEL_INSTRUMENT_H), a
    ld      (ix + XCS_PSG_CHANNEL_WAVE), a
    ld      (ix + XCS_PSG_CHANNEL_FRAME), a
    ld      (ix + XCS_PSG_CHANNEL_LOOP), a
    add     ix, de
    djnz    xcs_clear_psg_channel

    ; サウンドのクリア
    ld      hl, $0000
    ld      (xcs_psg_sound_instrument), hl
    ld      (xcs_psg_sound_song), hl

    ; 終了
    ret

; PSG を更新する
;
xcs_update_psg:

    ; チャンネル A の更新
    ld      ix, xcs_psg_channel_a
    call    xcs_update_psg_channel

    ; チャンネル B の更新
    ld      ix, xcs_psg_channel_b
    call    xcs_update_psg_channel

    ; チャンネル C の更新
    ld      ix, xcs_psg_channel_c
    call    xcs_update_psg_channel

    ; チャンネル D の更新
    ld      ix, xcs_psg_channel_d
    call    xcs_update_psg_channel

    ; レジスタの設定
    ld      bc, XCS_IO_PSG_REGISTER
    ld      a, (xcs_psg_flag)
    ld      d, a
.xcs_update_psg_register_01
    rr      d
    jr      nc, xcs_update_psg_register_23
    ld      hl, (xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_A)
    ld      e, $00
    out     (c), e
    dec     b
    out     (c), l
    inc     b
    inc     e
    out     (c), e
    dec     b
    out     (c), h
    inc     b
.xcs_update_psg_register_23
    rr      d
    jr      nc, xcs_update_psg_register_45
    ld      hl, (xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_B)
    ld      e, $02
    out     (c), e
    dec     b
    out     (c), l
    inc     b
    inc     e
    out     (c), e
    dec     b
    out     (c), h
    inc     b
.xcs_update_psg_register_45
    rr      d
    jr      nc, xcs_update_psg_register_8
    ld      hl, (xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_C)
    ld      e, $04
    out     (c), e
    dec     b
    out     (c), l
    inc     b
    inc     e
    out     (c), e
    dec     b
    out     (c), h
    inc     b
.xcs_update_psg_register_8
    rr      d
    jr      nc, xcs_update_psg_register_9
    ld      a, (xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_A)
    ld      e, $08
    out     (c), e
    dec     b
    out     (c), a
    inc     b
.xcs_update_psg_register_9
    rr      d
    jr      nc, xcs_update_psg_register_a
    ld      a, (xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_B)
    ld      e, $09
    out     (c), e
    dec     b
    out     (c), a
    inc     b
.xcs_update_psg_register_a
    rr      d
    jr      nc, xcs_update_psg_register_7
    ld      a, (xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_C)
    ld      e, $0a
    out     (c), e
    dec     b
    out     (c), a
    inc     b
.xcs_update_psg_register_7
    rr      d
    jr      nc, xcs_update_psg_register_end
    ld      a, (xcs_psg_register + XCS_IO_PSG_REGISTER_MIXING)
    ld      e, $07
    out     (c), e
    dec     b
    out     (c), a
;   inc     b
.xcs_update_psg_register_end

    ; フラグのクリア
    xor     a
    ld      (xcs_psg_flag), a

    ; 終了
    ret

; PSG のチャンネルを更新する
;
xcs_update_psg_channel:

    ; IN
    ;   ix = チャンネル

    ; サウンドの存在
    ld      d, (ix + XCS_PSG_CHANNEL_PLAY_H)
    ld      e, (ix + XCS_PSG_CHANNEL_PLAY_L)
    ld      a, d
    or      e
    jp      z, xcs_update_psg_channel_end
    
    ; フレームの監視
    ld      a, (ix + XCS_PSG_CHANNEL_FRAME)
    or      a
    jr      nz, xcs_update_psg_channel_ing

    ; 音長の設定
    inc     de
    inc     de
    ld      a, (de)
    ld      (ix + XCS_PSG_CHANNEL_FRAME), a
    dec     de
    dec     de

    ; 波形の設定
    xor     a
    ld      (ix + XCS_PSG_CHANNEL_WAVE), a

    ; 音符の処理
.xcs_update_psg_channel_ing

    ; 周波数の設定 / c = コマンド
    ld      l, (ix + XCS_PSG_CHANNEL_REGISTER_FREQUENCY_L)
    ld      h, (ix + XCS_PSG_CHANNEL_REGISTER_FREQUENCY_H)
    ld      a, (de)
    ld      c, a
    and     XCS_SOUND_NOTE_FREQUENCY_H_MASK
    ld      (hl), a
    inc     de
    dec     hl
    ld      a, (de)
    ld      (hl), a
    inc     de

    ; 音長は処理済み
    inc     de

    ; 波形の更新
    bit     XCS_SOUND_NOTE_CONTROL_REST_BIT, c
    jr      nz, xcs_update_psg_channel_wave_rest
.xcs_update_psg_channel_wave_note
    ld      hl, (xcs_psg_sound_instrument)
    ld      a, (de)
    push    af
    and     XCS_SOUND_NOTE_INSTRUMENT_MASK
    ld      d, $00
    add     a, a
    rl      d
    add     a, a
    rl      d
    ld      e, a
    add     hl, de
    ld      a, (ix + XCS_PSG_CHANNEL_WAVE)
    and     XCS_SOUND_WAVE_MASK
    ld      e, a
    ld      d, $00
    add     hl, de
    pop     af
    and     XCS_SOUND_NOTE_VOLUME_MASK
    or      (hl)
    ld      e, a
;   ld      d, $00
    ld      hl, xcs_psg_wave_volume
    add     hl, de
    ld      a, (hl)
    inc     (ix + XCS_PSG_CHANNEL_WAVE)
    jr      xcs_update_psg_channel_volume
.xcs_update_psg_channel_wave_rest
    xor     a

    ; 音量の設定
.xcs_update_psg_channel_volume
    ld      l, (ix + XCS_PSG_CHANNEL_REGISTER_VOLUME_L)
    ld      h, (ix + XCS_PSG_CHANNEL_REGISTER_VOLUME_H)
    ld      (hl), a

    ; ミキシングの設定
    ld      hl, xcs_psg_register + XCS_IO_PSG_REGISTER_MIXING
    ld      a, (ix + XCS_PSG_CHANNEL_MIXING)
    bit     XCS_SOUND_NOTE_CONTROL_REST_BIT, c
    jr      nz, xcs_update_psg_channel_mixing_rest
.xcs_update_psg_channel_mixing_note
    cpl
    and     (hl)
    jr      xcs_update_psg_channel_mixing_end
.xcs_update_psg_channel_mixing_rest
    or      (hl)
.xcs_update_psg_channel_mixing_end
    ld      (hl), a

    ; レジスタ更新フラグの設定
    ld      hl, xcs_psg_flag
    ld      a, (hl)
    or      (ix + XCS_PSG_CHANNEL_FLAG_FREQUENCY)
    or      (ix + XCS_PSG_CHANNEL_FLAG_VOLUME)
    or      XCS_PSG_FLAG_MIXING
    ld      (hl), a

    ; フレームの更新
    dec     (ix + XCS_PSG_CHANNEL_FRAME)
    jr      nz, xcs_update_psg_channel_end

    ; 音符の更新
    ld      h, (ix + XCS_PSG_CHANNEL_PLAY_H)
    ld      l, (ix + XCS_PSG_CHANNEL_PLAY_L)
    ld      de, XCS_SOUND_NOTE_BYTES
    add     hl, de
    ld      (ix + XCS_PSG_CHANNEL_PLAY_H), h
    ld      (ix + XCS_PSG_CHANNEL_PLAY_L), l
    bit     XCS_SOUND_NOTE_CONTROL_TERMINATE_BIT, (hl)
    jr      z, xcs_update_psg_channel_end
    ld      a, (ix + XCS_PSG_CHANNEL_LOOP)
    or      a
    jr      z, xcs_update_psg_channel_terminate
    ld      h, (ix + XCS_PSG_CHANNEL_HEAD_H)
    ld      l, (ix + XCS_PSG_CHANNEL_HEAD_L)
    ld      (ix + XCS_PSG_CHANNEL_PLAY_H), h
    ld      (ix + XCS_PSG_CHANNEL_PLAY_L), l
    jr      xcs_update_psg_channel_end

    ; 演奏の終了
.xcs_update_psg_channel_terminate

    ; サウンドの停止
    call    xcs_stop_psg_channel
;   jr      xcs_update_psg_channel_end

    ; 終了
.xcs_update_psg_channel_end
    ret

; チャンネルの再生を止める
;
xcs_stop_psg_channel:

    ; IN
    ;   in = チャンネル

    ; サウンドのクリア
    xor     a
    ld      (ix + XCS_PSG_CHANNEL_HEAD_L), a
    ld      (ix + XCS_PSG_CHANNEL_HEAD_H), a
    ld      (ix + XCS_PSG_CHANNEL_PLAY_L), a
    ld      (ix + XCS_PSG_CHANNEL_PLAY_H), a
    ld      (ix + XCS_PSG_CHANNEL_FRAME), a

    ; 音量の設定
    ld      l, (ix + XCS_PSG_CHANNEL_REGISTER_VOLUME_L)
    ld      h, (ix + XCS_PSG_CHANNEL_REGISTER_VOLUME_H)
    xor     a
    ld      (hl), a

    ; ミキシングの設定
    ld      hl, xcs_psg_register + XCS_IO_PSG_REGISTER_MIXING
    ld      a, (ix + XCS_PSG_CHANNEL_MIXING)
    or      (hl)
    ld      (hl), a

    ; レジスタ更新フラグの設定
    ld      hl, xcs_psg_flag
    ld      a, (hl)
    or      (ix + XCS_PSG_CHANNEL_FLAG_VOLUME)
    or      XCS_PSG_FLAG_MIXING
    ld      (hl), a

    ; 終了
    ret

; サウンドファイルを読み込む
;
_xcs_load_sound:
    
    ; IN
    ;   de = ファイル名
    ;   hl = 読み込み先のアドレス

    ; アドレスの保存
    push    hl

    ; ファイルの読み込み
    call    _xcs_bload

    ; PSG のクリア
    call    xcs_clear_psg

    ; アドレスの復帰
    pop     de
    ld      c, e
    ld      b, d

    ; 楽器の設定
    ld      hl, $0002
    add     hl, de
    ld      (xcs_psg_sound_instrument), hl

    ; 曲の設定
    dec     hl
    ld      d, (hl)
    dec     hl
    ld      e, (hl)
    add     hl, de
    ld      a, (hl)
    inc     hl
    ld      (xcs_psg_sound_song), hl

    ; 曲のオフセットの更新
    ld      d, a
    add     a, a
    add     a, d
.xcs_load_sound_song_loop
    push    af
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    ld      a, d
    or      e
    jr      z, xcs_load_sound_song_next
    dec     hl
    ex      de, hl
    add     hl, bc
    ex      de, hl
    ld      (hl), e
    inc     hl
    ld      (hl), d
.xcs_load_sound_song_next
    inc     hl
    pop     af
    dec     a
    jr      nz, xcs_load_sound_song_loop

    ; 終了
    ret

; BGM を再生する
;
_xcs_play_bgm:

    ; IN
    ;   a = 曲番号
    ;   c = 0..,ワンショット / else...ループ

    ; 曲の取得
    add     a, a
    ld      e, a
    add     a, a
    add     a, e
    ld      e, a
    ld      d, $00
    ld      hl, (xcs_psg_sound_song)
    add     hl, de

    ; チャンネル A の設定
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    inc     hl
    ld      (xcs_psg_channel_a + XCS_PSG_CHANNEL_HEAD), de
    ld      (xcs_psg_channel_a + XCS_PSG_CHANNEL_PLAY), de
    ld      a, c
    ld      (xcs_psg_channel_a + XCS_PSG_CHANNEL_LOOP), a

    ; チャンネル B の設定
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
    inc     hl
    ld      (xcs_psg_channel_b + XCS_PSG_CHANNEL_HEAD), de
    ld      (xcs_psg_channel_b + XCS_PSG_CHANNEL_PLAY), de
    ld      a, c
    ld      (xcs_psg_channel_b + XCS_PSG_CHANNEL_LOOP), a

    ; チャンネル C の設定
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
;   inc     hl
    ld      (xcs_psg_channel_c + XCS_PSG_CHANNEL_HEAD), de
    ld      (xcs_psg_channel_c + XCS_PSG_CHANNEL_PLAY), de
    ld      a, c
    ld      (xcs_psg_channel_c + XCS_PSG_CHANNEL_LOOP), a

    ; 終了
    ret

; BGM を停止する
;
_xcs_stop_bgm:

    ; チャンネル A の停止
    ld      ix, xcs_psg_channel_a
    call    xcs_stop_psg_channel

    ; チャンネル B の停止
    ld      ix, xcs_psg_channel_b
    call    xcs_stop_psg_channel

    ; チャンネル C の停止
    ld      ix, xcs_psg_channel_c
    call    xcs_stop_psg_channel

    ; 終了
    ret

; BGM が演奏中かどうかを判定する
;
_xcs_is_play_bgm:

    ; OUT
    ;   a = 0...停止 / else...演奏中

    ; チャンネルの監視
    ld      hl, (xcs_psg_channel_a + XCS_PSG_CHANNEL_PLAY)
    ld      a, h
    or      l
    jr      nz, xcs_is_play_bgm_ing
    ld      hl, (xcs_psg_channel_b + XCS_PSG_CHANNEL_PLAY)
    ld      a, h
    or      l
    jr      nz, xcs_is_play_bgm_ing
    ld      hl, (xcs_psg_channel_c + XCS_PSG_CHANNEL_PLAY)
    ld      a, h
    or      l
    jr      z, xcs_is_play_bgm_end

    ; 演奏中
.xcs_is_play_bgm_ing
    ld      a, $01

    ; 終了
.xcs_is_play_bgm_end
    ret

; SE を再生する
;
_xcs_play_se:

    ; IN
    ;   a = 曲番号

    ; 曲の取得
    add     a, a
    ld      e, a
    add     a, a
    add     a, e
    ld      e, a
    ld      d, $00
    ld      hl, (xcs_psg_sound_song)
    add     hl, de

    ; チャンネル D の設定
    ld      e, (hl)
    inc     hl
    ld      d, (hl)
;   inc     hl
    ld      (xcs_psg_channel_d + XCS_PSG_CHANNEL_HEAD), de
    ld      (xcs_psg_channel_d + XCS_PSG_CHANNEL_PLAY), de
    xor     a
    ld      (xcs_psg_channel_d + XCS_PSG_CHANNEL_LOOP), a

    ; 終了
    ret

; PSG データ
;

; レジスタ
.xcs_psg_register
    defs    XCS_IO_PSG_REGISTER_SIZE

; フラグ
.xcs_psg_flag
    defs    $01

; チャンネル
.xcs_psg_channel_a
    defw    $0000                                                   ; XCS_PSG_CHANNEL_HEAD
    defw    $0000                                                   ; XCS_PSG_CHANNEL_PLAY
    defw    $0000                                                   ; XCS_PSG_CHANNEL_INSTRUMENT
    defb    $00                                                     ; XCS_PSG_CHANNEL_WAVE
    defb    $00                                                     ; XCS_PSG_CHANNEL_FRAME
    defb    $00                                                     ; XCS_PSG_CHANNEL_LOOP
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_A_H    ; XCS_PSG_CHANNEL_REGISTER_FREQUENCY
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_A         ; XCS_PSG_CHANNEL_REGISTER_VOLUME
    defb    XCS_IO_PSG_MIXING_TONE_A                                ; XCS_PSG_CHANNEL_MIXING
    defb    XCS_PSG_FLAG_FREQUENCY_A                                ; XCS_PSG_CHANNEL_FLAG_FREQUENCY
    defb    XCS_PSG_FLAG_VOLUME_A                                   ; XCS_PSG_CHANNEL_FLAG_VOLUME
.xcs_psg_channel_b
    defw    $0000                                                   ; XCS_PSG_CHANNEL_HEAD
    defw    $0000                                                   ; XCS_PSG_CHANNEL_PLAY
    defw    $0000                                                   ; XCS_PSG_CHANNEL_INSTRUMENT
    defb    $00                                                     ; XCS_PSG_CHANNEL_WAVE
    defb    $00                                                     ; XCS_PSG_CHANNEL_FRAME
    defb    $00                                                     ; XCS_PSG_CHANNEL_LOOP
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_B_H    ; XCS_PSG_CHANNEL_REGISTER_FREQUENCY
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_B         ; XCS_PSG_CHANNEL_REGISTER_VOLUME
    defb    XCS_IO_PSG_MIXING_TONE_B                                ; XCS_PSG_CHANNEL_MIXING
    defb    XCS_PSG_FLAG_FREQUENCY_B                                ; XCS_PSG_CHANNEL_FLAG_FREQUENCY
    defb    XCS_PSG_FLAG_VOLUME_B                                   ; XCS_PSG_CHANNEL_FLAG_VOLUME
.xcs_psg_channel_c
    defw    $0000                                                   ; XCS_PSG_CHANNEL_HEAD
    defw    $0000                                                   ; XCS_PSG_CHANNEL_PLAY
    defw    $0000                                                   ; XCS_PSG_CHANNEL_INSTRUMENT
    defb    $00                                                     ; XCS_PSG_CHANNEL_WAVE
    defb    $00                                                     ; XCS_PSG_CHANNEL_FRAME
    defb    $00                                                     ; XCS_PSG_CHANNEL_LOOP
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_C_H    ; XCS_PSG_CHANNEL_REGISTER_FREQUENCY
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_C         ; XCS_PSG_CHANNEL_REGISTER_VOLUME
    defb    XCS_IO_PSG_MIXING_TONE_C                                ; XCS_PSG_CHANNEL_MIXING
    defb    XCS_PSG_FLAG_FREQUENCY_C                                ; XCS_PSG_CHANNEL_FLAG_FREQUENCY
    defb    XCS_PSG_FLAG_VOLUME_C                                   ; XCS_PSG_CHANNEL_FLAG_VOLUME
.xcs_psg_channel_d
    defw    $0000                                                   ; XCS_PSG_CHANNEL_HEAD
    defw    $0000                                                   ; XCS_PSG_CHANNEL_PLAY
    defw    $0000                                                   ; XCS_PSG_CHANNEL_INSTRUMENT
    defb    $00                                                     ; XCS_PSG_CHANNEL_WAVE
    defb    $00                                                     ; XCS_PSG_CHANNEL_FRAME
    defb    $00                                                     ; XCS_PSG_CHANNEL_LOOP
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_FREQUENCY_B_H    ; XCS_PSG_CHANNEL_REGISTER_FREQUENCY
    defw    xcs_psg_register + XCS_IO_PSG_REGISTER_VOLUME_B         ; XCS_PSG_CHANNEL_REGISTER_VOLUME
    defb    XCS_IO_PSG_MIXING_TONE_B                                ; XCS_PSG_CHANNEL_MIXING
    defb    XCS_PSG_FLAG_FREQUENCY_B                                ; XCS_PSG_CHANNEL_FLAG_FREQUENCY
    defb    XCS_PSG_FLAG_VOLUME_B                                   ; XCS_PSG_CHANNEL_FLAG_VOLUME

; 波形に対する音量
.xcs_psg_wave_volume
if false
    defb    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb    $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
    defb    $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02
    defb    $00, $00, $00, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $03, $03, $03
    defb    $00, $00, $01, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04
    defb    $00, $00, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $04, $05, $05
    defb    $00, $00, $01, $01, $02, $02, $02, $03, $03, $04, $04, $04, $05, $05, $06, $06
    defb    $00, $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07
    defb    $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08
    defb    $00, $01, $01, $02, $02, $03, $04, $04, $05, $05, $06, $07, $07, $08, $08, $09
    defb    $00, $01, $01, $02, $03, $03, $04, $05, $05, $06, $07, $07, $08, $09, $09, $0a
    defb    $00, $01, $01, $02, $03, $04, $04, $05, $06, $07, $07, $08, $09, $0a, $0a, $0b
    defb    $00, $01, $02, $02, $03, $04, $05, $06, $06, $07, $08, $09, $0a, $0a, $0b, $0c
    defb    $00, $01, $02, $03, $03, $04, $05, $06, $07, $08, $09, $0a, $0a, $0b, $0c, $0d
    defb    $00, $01, $02, $03, $04, $05, $06, $07, $07, $08, $09, $0a, $0b, $0c, $0d, $0e
    defb    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
else
    defb    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb    $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    defb    $00, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
    defb    $00, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03
    defb    $00, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04, $04, $04
    defb    $00, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $04, $05, $05, $05
    defb    $00, $01, $01, $02, $02, $02, $03, $03, $04, $04, $04, $05, $05, $06, $06, $06
    defb    $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $07
    defb    $00, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08, $08
    defb    $00, $01, $02, $02, $03, $03, $04, $05, $05, $06, $06, $07, $08, $08, $09, $09
    defb    $00, $01, $02, $02, $03, $04, $04, $05, $06, $06, $07, $08, $08, $09, $0a, $0a
    defb    $00, $01, $02, $03, $03, $04, $05, $06, $06, $07, $08, $09, $09, $0a, $0b, $0b
    defb    $00, $01, $02, $03, $04, $04, $05, $06, $07, $08, $08, $09, $0a, $0b, $0c, $0c
    defb    $00, $01, $02, $03, $04, $05, $06, $07, $07, $08, $09, $0a, $0b, $0c, $0d, $0d
    defb    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0e
    defb    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
endif

; サウンドファイル
.xcs_psg_sound_instrument
    defs    $02
.xcs_psg_sound_song
    defs    $02

; 垂直帰線期間まで待つ
;
_xcs_wait_v_dsip_on:

    ; 垂直帰線期間待ち
    ld      bc, XCS_IO_8255_B
.xcs_wait_on_v_disp_loop
    in      a, (c)
;   bit     XCS_IO_8255_B_V_DISP_BIT, a
;   jr      nz, xcs_wait_on_v_disp_loop
    jp      m, xcs_wait_on_v_disp_loop

    ; 終了
    ret

; 垂直帰線期間の終了を待つ
;
_xcs_wait_v_dsip_off:

    ; 垂直帰線期間待ち
    ld      bc, XCS_IO_8255_B
.xcs_wait_off_v_disp_loop
    in      a, (c)
;   bit     XCS_IO_8255_B_V_DISP_BIT, a
;   jr      z, xcs_wait_off_v_disp_loop
    jp      p, xcs_wait_off_v_disp_loop

    ; 終了
    ret

; WIDTH 40 に画面を設定する
;
_xcs_width_40:

    ; WIDTH 40 に設定
    ld      hl, xcs_set_crtc_40
    jr      xcs_set_crtc

; WIDTH 80 に画面を設定する
;
_xcs_width_80:

    ; WIDTH 80 に設定
    ld      hl, xcs_set_crtc_80
;   jr      xcs_set_crtc

; CRTC を設定する
;
.xcs_set_crtc

    ; IN
    ;   hl = CRTC のデータ列

    ; CRTC の設定
    ld      de, $1000
    ld      bc, XCS_IO_CRTC_REGISTER
.xcs_set_crtc_loop
    out     (c), e
    inc     c
    ld      a, (hl)
    out     (c), a
    dec     c
    inc     hl
    inc     e
    dec     d
    jr      nz, xcs_set_crtc_loop

    ; 終了
    ret

; CRTC の初期値
.xcs_set_crtc_40
    defb     55, 40, 45, 52, 31,  2, 25, 28,  0,  7,  0,  0,  0,  0,  0,  0
.xcs_set_crtc_80
    defb    111, 80, 89, 56, 31,  2, 25, 28,  0,  7,  0,  0,  0,  0,  0,  0

; スクリーンを設定する
;

; スクリーン 0 に設定
_xcs_set_screen_0:

    ; $0000 から表示に設定
    xor     a
    jr      xcs_set_screen

; スクリーン 1 に設定
_xcs_set_screen_1:

    ; $0400 から表示に設定
    ld      a, $04
;   jr      xcs_set_screen

; 指定されたスクリーンの設定
.xcs_set_screen
    ld      (xcs_screen), a
    ld      bc, XCS_IO_CRTC_REGISTER
    ld      d, $0c
    out     (c), d
    inc     c
    out     (c), a
    dec     c
    inc     d
    out     (c), d
    inc     c
    xor     a
    out     (c), a

    ; 終了
    ret

; 現在のスクリーン
;
.xcs_screen
    defs    $01

; プライオリティをグラフィックをテキストの前面に設定する
;
_xcs_set_priority_front:

    ; プライオリティの設定
    ld      bc, XCS_IO_PRIORITY
    ld      a, %11111111
    out     (c), a

    ; 終了
    ret

; プライオリティをグラフィックをテキストの背面に設定する
;
_xcs_set_priority_back:

    ; プライオリティの設定
    ld      bc, XCS_IO_PRIORITY
    xor     a
    out     (c), a

    ; 終了
    ret

; PCG を定義する
;
; 256 キャラクタの定義
_xcs_load_pcg:

    ; IN
    ;   de = PCG パターン

    ; 256 キャラクタの定義
    xor     a
.xcs_load_pcg_loop
    push    af
    call    _xcs_load_pcg_1
    pop     af
    inc     a
    jr      nz, xcs_load_pcg_loop

    ; 終了
    ret

; 1 キャラクタの定義
_xcs_load_pcg_1:

    ; IN
    ;   de = PCG パターン
    ;   a  = ASCII コード

    ; HL にパターンを設定
    ex      de, hl

    ; 更新する ASCII コードをテキスト VRAM に書き込む
    ld      bc, XCS_IO_TEXT_VRAM_0 + XCS_IO_TEXT_VRAM_BYTES
.xcs_load_pcg_1_code
    out     (c), a
    inc     c
    jr      nz, xcs_load_pcg_1_code

    ; アドレスの設定
    ld      de, XCS_IO_PCG_GREEN + $0100 | $08

    ; 割り込み禁止の設定
    di

    ; 垂直帰線期間の開始を待つ
;   call    _xcs_wait_v_dsip_off
;   call    _xcs_wait_v_dsip_on
    ld      bc, XCS_IO_8255_B
.xcs_load_pcg_1_off
    in      a, (c)
    jp      p, xcs_load_pcg_1_off
.xcs_load_pcg_1_on
    in      a, (c)
    jp      m, xcs_load_pcg_1_on

    ; 1 キャラクタの定義／1 ループ 250 ステートで処理する
.xcs_load_pcg_1_loop
    ld      b, d                                ;  4
    outi                                        ; 16
    outi                                        ; 16
    outi                                        ; 16 -> 52

    ; 250 - (52 + 18) = 180 ステートの処理待ち
    ld      a, 11                               ;  7
.xcs_load_pcg_1_wait
    dec     a                                   ;  4
    jp      nz, xcs_load_pcg_1_wait             ; 10 -> 14 * 11 = 154
    ld      a, $00                              ;  7
    nop                                         ;  4
    nop                                         ;  4
    nop                                         ;  4 -> 7 + 154 + (7 + 4 * 3) = 26

    ; 1 ラインの完了
    inc     c                                   ;  4
    dec     e                                   ;  4
    jp      nz, xcs_load_pcg_1_loop             ; 10 -> 18

    ; 割り込み禁止の解除
    ei

    ; DE にパターンを戻す
    ex      de, hl

    ; 終了
    ret

; VRAM のオフセットアドレスを計算する
;
_xcs_calc_vram_offset:

    ; IN
    ;   de = Y/X 位置
    ; OUT
    ;   bc = VRAM オフセットアドレス

    ; bc = d * 40 + e
    push    hl
    ld      l, d
    ld      h, $00
    add     hl, hl
    add     hl, hl
    add     hl, hl
    ld      c, l
    ld      b, h
    add     hl, hl
    add     hl, hl
    add     hl, bc
    ld      c, e
    ld      b, $00
    add     hl, bc
    ld      c, l
    ld      b, h
    pop     hl

    ; 終了  
    ret

; テキスト VRAM のアドレスを計算する
;
    ; IN
    ;   de = テキスト Y/X 位置
    ; OUT
    ;   bc = VRAM アドレス

; スクリーン 0 の計算
_xcs_calc_text_vram_0:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $30
    ld      b, a

    ; 終了
    ret

; スクリーン 1 の計算
_xcs_calc_text_vram_1:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $34
    ld      b, a

    ; 終了
    ret

; テキスト属性のアドレスを計算する
;
    ; IN
    ;   de = Y/X 位置
    ; OUT
    ;   bc = 属性アドレス

; スクリーン 0 の計算
_xcs_calc_text_attribute_0:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $20
    ld      b, a

    ; 終了
    ret

; スクリーン 1 の計算
_xcs_calc_text_attribute_1:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $24
    ld      b, a

    ; 終了
    ret

; テキスト VRAM をクリアする
;
    ; IN
    ;   d = クリアの値

; スクリーン 0 のクリア
_xcs_clear_text_vram_0:
    ld      bc, XCS_IO_TEXT_VRAM_0
    jr      xcs_clear_text

; スクリーン 1 のクリア
_xcs_clear_text_vram_1:
    ld      bc, XCS_IO_TEXT_VRAM_1
    jr      xcs_clear_text

; テキスト属性をクリアする
;
    ; IN
    ;   d = クリアの値

; スクリーン 0 のクリア
_xcs_clear_text_attribute_0:
    ld      bc, XCS_IO_TEXT_ATTRIBUTE_0
    jr      xcs_clear_text

; スクリーン 1 のクリア
_xcs_clear_text_attribute_1:
    ld      bc, XCS_IO_TEXT_ATTRIBUTE_1
;   jr      xcs_clear_text

; テキストをクリアする
;
.xcs_clear_text

    ; テキストのクリア
    ld      hl, XCS_IO_TEXT_VRAM_BYTES
.xcs_clear_text_loop
    out     (c), d
    inc     bc
    dec     hl
    ld      a, h
    or      l
    jr      nz, xcs_clear_text_loop

    ; 終了
    ret

; 指定した位置に 1 byte の 16 進数を表示する
;
_xcs_print_hex_chars:

    ; IN
    ;   de = テキスト Y/X 位置
    ;   a  = 値

    ; レジスタの保存
    push    bc
    push    de

    ; アドレス計算
    push    af
    call    _xcs_calc_text_vram_0

    ; 値の変換 
    pop     af
    call    _xcs_get_hex_chars

    ; 値の出力
    out     (c), d
    inc     bc
    out     (c), e

    ; レジスタの復帰
    pop     de
    pop     bc

    ; 終了
    ret

; 指定した位置に文字列を表示する
;
_xcs_print_string:

    ; IN
    ;   de = テキスト Y/X 位置
    ;   hl = 文字列

    ; レジスタの保存
    push    hl
    push    bc
    push    de

    ; アドレス計算
.xcs_print_string_calc
    call    _xcs_calc_text_vram_0

    ; 1 行の出力
.xcs_print_string_line
    ld      a, (hl)
    inc     hl
    or      a
    jr      z, xcs_print_string_end
    cp      $0a
    jr      z, xcs_print_string_newline
    out     (c), a
    inc     bc
    inc     e
    ld      a, e
    cp      XCS_IO_TEXT_VRAM_SIZE_X
    jr      c, xcs_print_string_line

    ; 改行
.xcs_print_string_newline
    inc     d
    jr      xcs_print_string_calc

    ; レジスタの復帰
.xcs_print_string_end
    pop     de
    pop     bc
    pop     hl

    ; 終了
    ret

; グラフィック VRAM のアドレスを計算する
;
    ; IN
    ;   de = タイル Y/X 位置
    ; OUT
    ;   bc = VRAM アドレス

; グラフィック青の計算
_xcs_calc_graphic_vram_blue:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $40
    ld      b, a

    ; 終了
    ret

; グラフィック赤の計算
_xcs_calc_graphic_vram_red:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $80
    ld      b, a

    ; 終了
    ret

; グラフィック緑の計算
_xcs_calc_graphic_vram_green:

    ; アドレスの計算
    call    _xcs_calc_vram_offset
    ld      a, b
    add     a, $c0
    ld      b, a

    ; 終了
    ret

; グラフィック VRAM をクリアする
;
_xcs_clear_graphic_vram:

    ; IN
    ;   d = クリアの値

    ; 同時アクセスモードの設定
    di
    ld      bc, XCS_IO_8255_C
    in      a, (c)
    set     XCS_IO_8255_C_DAM_SEL_BIT, a
    out     (c), a
    res     XCS_IO_8255_C_DAM_SEL_BIT, a
    out     (c), a
    ei

    ; グラフィックのクリア
    ld      bc, XCS_IO_GRAPHIC_VRAM_BLUE_RED_GREEN
    ld      de, ((XCS_IO_GRAPHIC_VRAM_SIZE_LINE / XCS_IO_GRAPHIC_VRAM_SIZE_Y) << 8) | $00
.xcs_clear_graphic_vram_line
    push    bc
    ld      hl, XCS_IO_GRAPHIC_VRAM_SIZE_X * XCS_IO_GRAPHIC_VRAM_SIZE_Y
.xcs_clear_graphic_vram_x8
    out     (c), e
    inc     bc
    dec     hl
    ld      a, h
    or      l
    jr      nz, xcs_clear_graphic_vram_x8
    pop     bc
    ld      a, b
    add     a, $08
    ld      b, a
    dec     d
    jr      nz, xcs_clear_graphic_vram_line

    ; 同時アクセスモードの解除
    in      a, (c)

    ; 終了
    ret

; グラフィック VRAM にイメージを描画する
;
_xcs_draw_image:

    ; IN
    ;   de = イメージのアドレス

    ; VRAM への転送
    ld      bc, XCS_IO_GRAPHIC_VRAM_BLUE | XCS_IO_GRAPHIC_VRAM_SIZE_PLANE
.xcs_draw_image_plane
    push    bc
    ld      c, $00
    ld      h, XCS_IO_GRAPHIC_VRAM_SIZE_LINE / XCS_IO_GRAPHIC_VRAM_SIZE_Y
.xcs_draw_image_line
    push    hl
    push    bc
    ld      hl, XCS_IO_GRAPHIC_VRAM_SIZE_X * XCS_IO_GRAPHIC_VRAM_SIZE_Y
.xcs_draw_image_x8
    ld      a, (de)
    out     (c), a
    inc     de
    inc     bc
    dec     hl
    ld      a, h
    or      l
    jr      nz, xcs_draw_image_x8
    ld      hl, $0018
    add     hl, de
    ex      de, hl
    pop     bc
    ld      a, b
    add     a, $08
    ld      b, a
    pop     hl
    dec     h
    jr      nz, xcs_draw_image_line
    pop     bc
    ld      a, b
    add     a, $40
    ld      b, a
    dec     c
    jr      nz, xcs_draw_image_plane

    ; 終了
    ret

; グラフィック VRAM にイメージを読み込む
;
_xcs_load_image:

    ; IN
    ;   de = ファイル名

    ; 引数の保存
    ld      (xcs_load_image_filename), de
    
    ; アドレスの設定
    ld      hl, XCS_IO_GRAPHIC_VRAM_BLUE
    ld      (xcs_load_image_address), hl

    ; リトライ
.xcs_load_image_retry

    ; ファイルの検索
    ex      de, hl
    call    xcs_fdc_0_find_directory
    ld      a, d
    or      e
    jp      z, xcs_load_image_error
    ld      hl, xcs_load_image_string_load
    call    _xcs_debug_put_string
    ld      hl, (xcs_load_image_filename)
    call    _xcs_debug_put_string
    ld      a, '\"'
    call    _xcs_debug_put_char

    ; ファイルサイズの取得
    ld      hl, XCS_HU_DIRECTORY_SIZE
    add     hl, de
    ld      c, (hl)
    inc     hl
    ld      b, (hl)
    ld      (xcs_load_image_bytes), bc

    ; 開始クラスタの取得
    ld      hl, XCS_HU_DIRECTORY_START_CLUSTER
    add     hl, de
    ld      d, (hl)

    ; クラスタの読み込み／d = クラスタ番号
.xcs_load_image_loop

    ; FAT の取得
    ld      c, d
    ld      b, $00
    ld      hl, xcs_fdc_0_fat
    add     hl, bc
    ld      a, (hl)
    ld      (xcs_load_image_fat), a

    ; ヘッドの選択
    srl     d
    push    de
    jr      c, xcs_load_image_head_1
    call    xcs_fdc_0_start_0
    jr      xcs_load_image_head_end
.xcs_load_image_head_1
    call    xcs_fdc_0_start_1
.xcs_load_image_head_end
    pop     de

    ; 1 クラスタの読み込みの開始
    ld      e, $00
.xcs_load_image_cluster

    ; 1 セクタの読み込み
    call    xcs_fdc_0_load_buffer
    ld      hl, xcs_fdc_buffer
    ld      bc, (xcs_load_image_address)
.xcs_load_image_vram
    ld      a, (hl)
    out     (c), a
    inc     hl
    inc     bc
    ld      a, c
    or      a
    jr      nz, xcs_load_image_vram
    ld      (xcs_load_image_address), bc
    ld      a, e
    and     $03
    jr      nz, xcs_load_image_cluster
    ld      a, b
    add     a, $04
    ld      (xcs_load_image_address + $0001), a
    and     $18
    jr      nz, xcs_load_image_cluster
    bit     6, a
    jr      z, xcs_load_image_cluster_next
    add     a, $40
    ld      (xcs_load_image_address + $0001), a
    
    ; 次のクラスタへ
.xcs_load_image_cluster_next
    ld      a, (xcs_load_image_bytes + $0001)
    sub     $10
    ld      (xcs_load_image_bytes + $0001), a
    jr      z, xcs_load_image_end
    ld      a, (xcs_load_image_fat)
    ld      d, a
    jr      xcs_load_image_loop

    ; 終了
.xcs_load_image_end
    call    xcs_fdc_0_stop
    ret

    ;  エラー
.xcs_load_image_error
    call    _xcs_debug_newline
    ld      a, '\"'
    call    _xcs_debug_put_char
    ld      hl, (xcs_load_image_filename)
    call    _xcs_debug_put_string
    ld      hl, xcs_load_image_string_error
    call    _xcs_debug_put_string
    call    xcs_fdc_error
    ld      de, (xcs_load_image_filename)
    jp      xcs_load_image_retry

; ファイル名
.xcs_load_image_filename
    defs    $02

; アドレス
.xcs_load_image_address
    defs    $02

; ファイルサイズ
.xcs_load_image_bytes
    defs    $02

; FAT
.xcs_load_image_fat
    defs    $01

; 文字列
.xcs_load_image_string_load
    defb    "\nLOAD\"", $00
.xcs_load_image_string_error
    defb    "\" NOT FOUND.", $00

; 8x8 サイズのタイルを取得する
;
_xcs_calc_8x8_tile:

    ; IN
    ;   hl = タイルセット
    ;   a  = タイル番号
    ; OUT
    ;   hl = タイルの参照

    ; アドレスの計算
    push    de
    ld      d, $00
    add     a, a
    rl      d
    add     a, a
    rl      d
    add     a, a
    rl      d
    ld      e, a
    add     hl, de
    add     hl, de
    add     hl, de
    pop     de

    ; 終了
    ret

; 8x8 サイズのタイルセットを描画する
;
_xcs_draw_8x8_tile:

    ; IN
    ;   de = タイル Y/X 位置
    ;   hl = タイルセット
    ;   a  = タイル番号

    ; タイルの取得
    call    _xcs_calc_8x8_tile

    ; VRAM アドレスの取得
    call    _xcs_calc_graphic_vram_blue

    ; タイルの描画
    ld      a, b
    inc     a
    ld      d, $03
.xcs_draw_8x8_tile_loop
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     a, $08
    ld      b, a
    outi
    add     $40 - ($08 * 7)
    dec     d
    jr      nz, xcs_draw_8x8_tile_loop

    ; 終了
    ret

; 16 進数の文字を取得する
;
_xcs_get_hex_chars:

    ; IN
    ;   a = 数値
    ; OUT
    ;   de = 数値の文字（上位／下位）

    ; 16 進数の文字に変換
    push    af
    srl     a
    srl     a
    srl     a
    srl     a
    cp      $0a
    sbc     $69
    daa
    ld      d, a
    pop     af
    and     $0f
    cp      $0a
    sbc     $69
    daa
    ld      e, a

    ; 終了
    ret

; 10 進数の文字列を取得する
;
_xcs_get_decimal_string:

    ; IN
    ;   de = 数値
    ; OUT
    ;   hl = 文字列

; 左詰めの文字列の取得
_xcs_get_decimal_string_left:

    ; 桁数の判定
	ld      hl, -10000
    add     hl, de
    jr      c, xcs_get_decimal_string_10000
	ld      hl, -1000
    add     hl, de
    ex      de, hl
    ld      de, xcs_get_decimal_string_string ; 10 (11)
	jr      c, xcs_get_decimal_string_1000
    inc     h
    dec     h
	jr      nz, xcs_get_decimal_string_100
    ld      a, l
    cp      100
    jr      nc, xcs_get_decimal_string_100
    cp      10
    jr      nc, xcs_get_decimal_string_10
    add     a, '0'
    jr      xcs_get_decimal_string_1

    ; 文字の取得
.xcs_get_decimal_string_sub_16
	ld      a, '0' - $01
.xcs_get_decimal_string_sub_loop
	inc     a
    add     hl, bc
    jr      c, xcs_get_decimal_string_sub_loop
    sbc     hl, bc
    ld      (de), a
    inc     de
    ret

    ; 10000 の位の取得
.xcs_get_decimal_string_10000
	ex      de, hl
    ld      de, xcs_get_decimal_string_string
    ld      bc, -10000
    call    xcs_get_decimal_string_sub_16

    ; 1000 の位の取得
.xcs_get_decimal_string_1000
	ld      bc, -1000
    call    xcs_get_decimal_string_sub_16

    ; 100 の位の取得
.xcs_get_decimal_string_100
	ld      bc, -100
    call    xcs_get_decimal_string_sub_16
	ld      a, l

    ; 10 の位の取得
.xcs_get_decimal_string_10
    ex      de, hl
    ld      bc, (('0' - $01) << 8) | (10)
.xcs_get_decimal_string_10_loop
	inc     b
    sub     c
	jr      nc, xcs_get_decimal_string_10_loop
    add     a, '0' + 10
    ld      (hl), b
    inc     hl

    ; 1 の位の取得
.xcs_get_decimal_string_1
	ld      (hl), a
    inc     hl
    ld      (hl), $00

    ; 終了
    ld      hl, xcs_get_decimal_string_string
    ret

; 右詰めの文字列の取得
_xcs_get_decimal_string_right:

    ; 文字列の取得
    call    _xcs_get_decimal_string_left

    ; 文字列の長さの取得
    push    hl
    ld      c, $05
.xcs_get_decimal_string_right_length
    ld      a, (hl)
    or      a
    jr      z, xcs_get_decimal_string_right_length_end
    inc     hl
    dec     c
    jr      xcs_get_decimal_string_right_length
.xcs_get_decimal_string_right_length_end
    pop     hl

    ; 右詰め
    ld      b, $00
    or      a
    sbc     hl, bc

    ; 終了
    ret

; 10 進数の文字列
    defb    "    "
.xcs_get_decimal_string_string
    defb    "00000", $00

; デバッグ画面の指定した位置に 1 byte の 16 進数を表示する
;
_xcs_debug_print_hex_chars:

    ; IN
    ;   de = テキスト Y/X 位置
    ;   a  = 値

    ; レジスタの保存
    push    bc
    push    de

    ; アドレス計算
    push    af
    call    _xcs_calc_text_vram_1

    ; 値の変換 
    pop     af
    call    _xcs_get_hex_chars

    ; 値の出力
    out     (c), d
    inc     bc
    out     (c), e

    ; レジスタの復帰
    pop     de
    pop     bc

    ; 終了
    ret

; デバッグ画面の指定した位置に文字列を表示する
;
_xcs_debug_print_string:

    ; IN
    ;   de = テキスト Y/X 位置
    ;   hl = 文字列

    ; レジスタの保存
    push    hl
    push    bc
    push    de

    ; レジスタの復帰
    pop     de
    pop     bc
    pop     hl

    ; 終了
    ret

; デバッグ画面に 1 byte の 16 進数を出力する
;
_xcs_debug_put_hex_chars:

    ; IN
    ;   a  = 値

    ; レジスタの保存
    push    hl
    push    de

    ; 値の変換
    call    _xcs_get_hex_chars

    ; 文字列の作成
    ld      hl, xcs_debug_put_hex_chars_string
    ld      (hl), d
    inc     hl
    ld      (hl), e
    dec     hl

    ; 文字列の出力
    call    _xcs_debug_put_string

    ; レジスタの復帰
    pop     de
    pop     hl

    ; 終了
    ret

; 文字列
.xcs_debug_put_hex_chars_string
    defb    "  ", $00

; デバッグ画面に 1 文字を出力する
;
_xcs_debug_put_char:

    ; IN
    ;   a  = 文字

    ; レジスタの保存
    push    hl

    ; 文字列の作成
    ld      hl, xcs_debug_put_char_string
    ld      (hl), a

    ; 文字列の出力
    call    _xcs_debug_put_string

    ; レジスタの復帰
    pop     hl

    ; 終了
    ret

; 文字列
.xcs_debug_put_char_string
    defb    " ", $00

; デバッグ画面に文字列を出力する
;
_xcs_debug_put_string:

    ; IN
    ;   hl = 文字列

    ; レジスタの保存
;   push    hl
    push    bc
    push    de

    ; カーソル位置の取得
    ld      de, (xcs_debug_cursor)

    ; アドレス計算
.xcs_debug_print_string_calc
    call    _xcs_calc_text_vram_1

    ; 1 行の出力
.xcs_debug_print_string_line
    ld      a, (hl)
    inc     hl
    or      a
    jr      z, xcs_debug_print_string_end
    cp      $0a
    jr      z, xcs_debug_print_string_newline
    out     (c), a
    inc     bc
    inc     e
    ld      a, e
    cp      XCS_IO_TEXT_VRAM_SIZE_X
    jr      c, xcs_debug_print_string_line

    ; 改行
.xcs_debug_print_string_newline
    call    xcs_debug_newline
    jr      xcs_debug_print_string_calc

    ; カーソル位置の保存
.xcs_debug_print_string_end
    ld      (xcs_debug_cursor), de

    ; レジスタの復帰
    pop     de
    pop     bc
;   pop     hl

    ; 終了
    ret

; デバッグ画面にメモリのダンプを表示する
;
    ; IN
    ;   hl = ダンプするメモリアドレス

    ; 16 bytes をダンプする
_xcs_debug_dump_16:

    ; メモリ内容の出力
    ld      b, $10
.xcs_debug_dump_16_loop
    push    bc
    ld      a, (hl)
    call    _xcs_debug_put_hex_chars
    pop     bc
    inc     hl
    djnz    xcs_debug_dump_16_loop

    ; 改行
    call    _xcs_debug_newline

    ; 終了
    ret

    ; 256 bytes を出力する
_xcs_debug_dump_256:

    ; 16 bytes を 16 行出力
    ld      a, $10
.xcs_debug_dump_256_loop
    push    af
    call    _xcs_debug_dump_16
    pop     af
    dec     a
    jr      nz, xcs_debug_dump_256_loop

    ; 終了
    ret

; デバッグ画面を改行する
;
_xcs_debug_newline:

    ; レジスタの保存
    push    de

    ; 改行
    ld      de, (xcs_debug_cursor)
    call    xcs_debug_newline
    ld      (xcs_debug_cursor), de

    ; レジスタの復帰
    pop     de

    ; 終了
    ret

xcs_debug_newline:

    ; IN
    ;   de = テキスト Y/X 位置
    ; OUT
    ;   de = 改行後のテキスト Y/X 位置

    ; 改行
    inc     d
    ld      a, d
    cp      XCS_IO_TEXT_VRAM_SIZE_Y
    jr      c, xcs_debug_newline_end
    call    _xcs_debug_scrollup
    ld      d, XCS_IO_TEXT_VRAM_SIZE_Y - 1
.xcs_debug_newline_end
    ld      e, $00

    ; 終了
    ret

; デバッグ画面をスクロールアップする
;
_xcs_debug_scrollup:

    ; レジスタの保存
    push    hl
    push    bc
    push    de

    ; スクロールアップ
    ld      hl, XCS_IO_TEXT_VRAM_1 + $0000
    ld      bc, XCS_IO_TEXT_VRAM_1 + $0028
    ld      de, 40 * (25 - 1)
.xcs_debug_scrollup_up
    in      a, (c)
    push    bc
    ld      c, l
    ld      b, h
    out     (c), a
    pop     bc
    inc     bc
    inc     hl
    dec     de
    ld      a, d
    or      e
    jr      nz, xcs_debug_scrollup_up

    ; 最下行のクリア
    ld      bc, XCS_IO_TEXT_VRAM_1 + 40 * (25 - 1)
    ld      de, $2028
.xcs_debug_scrollup_clear
    out     (c), d
    inc     bc
    dec     e
    jr      nz, xcs_debug_scrollup_clear

    ; レジスタの復帰
    pop     de
    pop     bc
    pop     hl

    ; 終了
    ret

; デバッグ画面のカーソル位置
;
.xcs_debug_cursor
    defs    $02
