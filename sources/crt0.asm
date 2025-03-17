; crt0.asm - エントリポイント
;

; モジュールの宣言
;
    module  crt0


; ファイルの参照
;
    include "xcs.inc"


; 定数の定義
;
    defc    CRT0_STACK_BYTES                        =   $0100


; コードの定義
;
    section boot

; プログラムのエントリポイント
;
    org     $0000

    ; 処理の開始
    jr      crt0

    ; 空き
    nop
    nop
    nop
    nop

    ; CTC 割り込み処理
.crt0_ctc_interrupt
    ei
    ret

    ; CTC 割り込みベクタ
    public  _crt0_ctc_vector
_crt0_ctc_vector:
    defw    crt0_ctc_interrupt
    defw    crt0_ctc_interrupt
    defw    crt0_ctc_interrupt
    defw    crt0_ctc_interrupt

    ; 処理の実行
.crt0

    ; 割り込みの禁止
    di

    ; スタックの初期化
    ld      sp, stack_tail

    ; XCS の初期化
    call    _xcs_initialize

    ; 割り込みの許可
    ei

    ; アプリケーションの実行
    ld      de, crt0_run_filename
    ld      hl, XCS_APP_START
    jp      _xcs_brun

; 実行ファイル名
.crt0_run_filename
    defb    "temp_app     bin", $00


; スタック
;
stack:
    defs    CRT0_STACK_BYTES

stack_tail:


