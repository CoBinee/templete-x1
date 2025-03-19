# AppleII 向けにゲームをつくるための準備

[![Templete](http://img.youtube.com/vi/pVWaWU5oW-E/0.jpg)](https://www.youtube.com/watch?v=pVWaWU5oW-E)

## SIDELOAD
Releases にある templete-xxx.d88 ファイルをダウンロード、各種 X1 環境で動かしてください。

## 開発
- [Z88DK](https://z88dk.org/site/)

## デモ
- 320x200 サイズの一枚絵のファイルを読み込んで表示。
- PSG による 3ch の演奏と、1ch の SE の再生。
- 8×8 ピクセル単位のタイルマップを表示。
- PCG の 3 倍速定義。

## mac で SDLMAME を使って X1 エミュレータを動かす

### SDLMAME のインストール

https://sdlmame.lngn.net

SDLMAME をダウンロード、任意のフォルダに展開します。

### SDL2.0 のインストール

https://github.com/libsdl-org/SDL/releases

SDL2.0 をダウンロード、SDL2.framework を /Library/Frameworks に入れます。

※ SDL は 3.0 になっているようだけど、2.0 が指定されているので 2.0 の最新版を入れるようにします。

### IPL ROM の準備

#### ipl.x1

https://github.com/meister68k/X1_compatible_rom

X1 compatible ROM をダウンロード、X1_compatible_rom.bin のファイルサイズを 4096 bytes にして、ファイル名を ipl.bin に変更します。

### フォントの準備

#### fnt0808.x1

https://github.com/meister68k/X1_compatible_font

X1互換 8x8ドットフリーフォントをダウンロードします。

#### ank.fnt

中身は 8x16ドットサイズの 1bpp な ASCII 文字フォントが連続して 2 つ並んだ形の 8,192 bytes のファイルです。
どこで使われているかはよくわかってないのですが、全部 0 で埋まったファイルでもよいような気がします。

### x1.zip のインストール

ipl.x1, fnt0808.x1, ank.fnt の 3 つのファイルを x1.zip というファイル名で zip にまとめ、SDLMAME を展開したフォルダにある roms フォルダに入れあす。

### SDLMAME の起動

ターミナルで SDLMAME のフォルダから、

```
./mame x1 -w
```

で SDLMAME を起動します。
ディスクを指定する場合は、

```
./mame x1 -w -flop1 DIALIDEA.d88 -flop2 DIALIDEB.d88
```

と -flop オプションで指定できます。

### SDLMAME のメニュー

`fn`+`Delete` キーを押し、**UI controls enabled** と表示された後に `Tab` キーを押すとメニューが開きます。
**UI controls disabled** と表示された場合はもう一度 `fn`+`Delete` キーを押すと、メニューが有効になります。

### キーの割り当ての設定

デフォルトだといくつかのキーボードのキーにコントローラの操作が割り当てられており、二重に動作してしまうので、設定を変更して誤動作しないようにします。

設定の変更はメニューの **Input Settings** → **Input Assignment (this system)** から行います。

### MAME のビルド

Xcode command-line tools をインストールします。

https://github.com/mamedev/mame

MAME のソースコードをダウンロード、任意のフォルダに展開します。

SDL2.0 をインストールします。

MAME のソースコードのフォルダから、X1 のみを対象にビルドします。

```
make SUBTARGETS=x1 SOURCES=src/mame/sharp/x1.cpp
```

## mac で Z80 アセンブラの pasmo を動かす

https://pasmo.speccy.org

pasmo のソースコードをダウンロード、任意のフォルダに展開します。

```
./configure
```

Makefile の CXXFLAGS に  -std=c++14 を追記し、ビルドします。

```
make
make install
```

