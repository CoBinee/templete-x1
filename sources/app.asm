; app.asm - アプリケーション
;

; モジュールの宣言
;
    module  app


; ファイルの参照
;
    include "xcs.inc"
    include "app.inc"


; コードの定義
;
    section app

; プログラムのエントリポイント
;
    org     XCS_APP_START

_app_entry:

    ; グラフィックを背面に設定
    call    _xcs_set_priority_back

    ; カウンタの初期化
    xor     a
    ld      (app_update_counter), a

    ; サウンドの初期化
    ld      hl, $0000
    ld      ($e000), hl

    ; 乱数の初期化
    call    _xcs_get_random_number
    ld      (app_update_random), a

; アプリケーションの更新
;
_app_update:

    ; XCS の更新
    call    _xcs_update

    ; ファイルリストの表示
    ld      a, (_xcs_key_code_edge)
    cp      'F'
    jr      nz, app_update_files_end
    call    app_files
    jr      app_update_next
.app_update_files_end

    ; イメージの表示
    ld      a, (_xcs_key_code_edge)
    cp      'I'
    jr      nz, app_update_image_end
    call    app_draw_image
    jr      app_update_next
.app_update_image_end

    ; PCG の定義
    ld      a, (_xcs_key_code_edge)
    cp      'P'
    jr      nz, app_update_pcg_end
    call    app_load_pcg
    jr      app_update_next
.app_update_pcg_end

    ; タイルセットの表示
    ld      a, (_xcs_key_code_edge)
    cp      'T'
    jr      nz, app_update_tileset_end
    call    app_draw_tileset
    jr      app_update_next
.app_update_tileset_end

    ; BGM の再生
    ld      a, (_xcs_key_code_edge)
    cp      'B'
    jr      nz, app_update_bgm_end
    call    app_play_bgm
    jr      app_update_next
.app_update_bgm_end

    ; SE の再生
    ld      a, (_xcs_key_code_edge)
    cp      'E'
    jr      nz, app_update_se_end
    call    app_play_se
    jr      app_update_next
.app_update_se_end

    ; 乱数の更新
    ld      a, (_xcs_key_code_edge)
    cp      'R'
    jr      nz, app_update_random_end
    call    _xcs_get_random_number
    ld      (app_update_random), a
    jr      app_update_next
.app_update_random_end

    ; 更新の継続
.app_update_next

    ; カウンタの更新
    ld      a, (app_update_counter)
    add     a, $01
    daa
    cp      $60
    jr      c, app_update_count
    xor     a
.app_update_count
    ld      (app_update_counter), a

    ; カウンタの表示
;   ld      a, (app_update_counter)
    ld      de, $0000
    call    _xcs_print_hex_chars
    ld      a, (app_update_counter)
    ld      de, $0000
    call    _xcs_debug_print_hex_chars

    ; キーの表示
    ld      a, (_xcs_key_code_push)
    ld      de, $0002
    call    _xcs_print_hex_chars
    ld      a, (_xcs_key_code_push)
    ld      de, $0002
    call    _xcs_debug_print_hex_chars
    ld      a, (_xcs_key_code_edge)
    ld      de, $0004
    call    _xcs_print_hex_chars
    ld      a, (_xcs_key_code_edge)
    ld      de, $0004
    call    _xcs_debug_print_hex_chars

    ; スティックの表示
    ld      a, (_xcs_stick_push)
    ld      de, $0006
    call    _xcs_print_hex_chars
    ld      a, (_xcs_stick_push)
    ld      de, $0006
    call    _xcs_debug_print_hex_chars
    ld      a, (_xcs_stick_edge)
    ld      de, $0008
    call    _xcs_print_hex_chars
    ld      a, (_xcs_stick_edge)
    ld      de, $0008
    call    _xcs_debug_print_hex_chars

    ; 乱数の表示
    ld      a, (app_update_random)
    ld      de, $000a
    call    _xcs_print_hex_chars
    ld      a, (app_update_random)
    ld      de, $000a
    call    _xcs_debug_print_hex_chars

    ; 垂直帰線期間の終了待ち
    call    _xcs_wait_v_dsip_off

    ; 繰り返し
    jp      _app_update

; カウンタ
.app_update_counter
    defs    $01

; 乱数
.app_update_random
    defs    $01

; ファイルリストを表示する
;
app_files:

    ; スクリーン 1 に設定
    call    _xcs_set_screen_1

    ; ファイルリストの表示
    call    _xcs_files

    ; 終了
    ret

; イメージファイルを表示する
;
app_draw_image:

;   ; ファイルの読み込み
;   ld      de, app_draw_image_filename
;   ld      hl, $8000
;   call    _xcs_bload

    ; スクリーン 0 に設定
    call    _xcs_set_screen_0

    ; VRAM のクリア
    call    app_clear_vram

;   ; イメージの描画
;   ld      de, $8000
;   call    _xcs_draw_image

    ; イメージの読み込み
    ld      de, app_draw_image_filename
    call    _xcs_load_image

    ; 終了
    ret

; ファイル名
.app_draw_image_filename
    defb    "image        gvr", $00

; PCG を定義する
;
app_load_pcg:

    ; ファイルの読み込み
    ld      de, app_load_pcg_filename
    ld      hl, $8000
    call    _xcs_bload

    ; スクリーン 0 に設定
    call    _xcs_set_screen_0

    ; VRAM のクリア
    call    app_clear_vram

    ; テキストの描画
    ld      bc, XCS_IO_TEXT_VRAM_0 + 4 * XCS_IO_TEXT_VRAM_SIZE_X + 12
    ld      d, $00
    ld      a, $10
.app_load_pcg_y
    ld      l, $10
.app_load_pcg_x
    out     (c), d
    inc     bc
    inc     d
    dec     l
    jr      nz, app_load_pcg_x
    ld      hl, XCS_IO_TEXT_VRAM_SIZE_X - $10
    add     hl, bc
    ld      c, l
    ld      b, h
    dec     a
    jr      nz, app_load_pcg_y

    ; PCG の定義
    ld      de, $8000
    call    _xcs_load_pcg

    ; 終了
    ret

; ファイル名
.app_load_pcg_filename
    defb    "bg           pcg", $00

; タイルセットを表示する
;
app_draw_tileset:

    ; ファイルの読み込み
    ld      de, app_draw_tileset_filename
    ld      hl, $8000
    call    _xcs_bload

    ; スクリーン 0 に設定
    call    _xcs_set_screen_0

    ; VRAM のクリア
    call    app_clear_vram

    ; タイルセットの描画
    ld      c, $00
    ld      d, $04
.app_draw_tileset_y
    ld      e, $0c
.app_draw_tileset_x
    push    bc
    push    de
    ld      hl, $8000
    ld      a, c
    call    _xcs_draw_8x8_tile
    pop     de
    pop     bc
    inc     c
    inc     e
    ld      a, e
    cp      $0c + $10
    jr      c, app_draw_tileset_x
    inc     d
    ld      a, d
    cp      $04 + $10
    jr      c, app_draw_tileset_y

    ; 終了
    ret

; ファイル名
.app_draw_tileset_filename
    defb    "sprite       ts ", $00

; BGM を再生する
;
app_play_bgm:

    ; 曲の再生中
    call    _xcs_is_play_bgm
    or      a
    jr      nz, app_play_bgm_stop

    ; サウンドの読み込み
    ld      hl, ($e000)
    ld      a, h
    or      l
    jr      nz, app_play_bgm_play
    ld      de, app_play_bgm_filename
    ld      hl, $e000
    call    _xcs_load_sound

    ; 曲の再生
.app_play_bgm_play
    ld      a, $00
    ld      c, $01
    call    _xcs_play_bgm
    jr      app_play_bgm_end

    ; 曲の停止
.app_play_bgm_stop
    call    _xcs_stop_bgm

    ; 終了
.app_play_bgm_end
    ret

; ファイル名
.app_play_bgm_filename
    defb    "song         snd", $00

; SE を再生する
;
app_play_se:

    ; サウンドの読み込み
    ld      hl, ($e000)
    ld      a, h
    or      l
    jr      nz, app_play_se_play
    ld      de, app_play_bgm_filename
    ld      hl, $e000
    call    _xcs_load_sound

    ; 曲の再生
.app_play_se_play
    ld      a, $01
    call    _xcs_play_se

    ; 終了
    ret

; VRAM をクリアする
;
app_clear_vram:

    ; グラフィックのクリア
    ld      d, $00
    call    _xcs_clear_graphic_vram

    ; テキストのクリア
    ld      d, ' '
    call    _xcs_clear_text_vram_0

    ; 終了
    ret
