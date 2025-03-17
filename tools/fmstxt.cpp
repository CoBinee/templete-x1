/*
    FamiStudio テキストフォーマットの変換
*/

// 参照ファイル
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>


// FamiStudio テキストフォーマット
//
struct fms_attribute {
    char *name;
    char *value;
    struct fms_attribute *next;
};
struct fms_object {
    char *name;
    struct fms_attribute *attribute;
    struct fms_object *next;
};

// サウンドフォーマット
//

// 楽器
#define SOUND_INSTRUMENT_WAVE_SIZE                      64
struct sound_instrument {
    char *name;
    unsigned char wave[SOUND_INSTRUMENT_WAVE_SIZE];
    struct sound_instrument *next;
};

// 曲
#define SOUND_SONG_CHANNEL_SIZE                         3
struct sound_note {
    int time;
    int duration;
    int volume;
    char *value;
    char *instrument;
    struct sound_note *next;
};
struct sound_pattern {
    char *name;
    struct sound_note *note;
    struct sound_pattern *next;
};
struct sound_pattern_instance {
    int time;
    char *pattern;
    struct sound_pattern_instance *next;
};
struct sound_channel {
    char *type;
    struct sound_pattern *pattern;
    struct sound_pattern_instance *pattern_instance;
    struct sound_channel *next;
};
struct sound_song {
    char *name;
    int pattern_size;
    int pattern_frame;
    struct sound_channel *channel;
    struct sound_song *next;
};

// 内部関数
//
static void make_sound(const char *input_path, const char *output_path, bool verbose);
static char *load_txt(const char *txt_path);
static void delete_txt(char *txt);
static struct fms_object *list_object(char *txt, bool verbose);
static void delete_object_list(struct fms_object *object_list);
static int islrlf(int c);
static struct fms_object *get_object(struct fms_object *object, const char *name);
static struct fms_attribute *get_attribute(struct fms_object *object, const char *name);
static struct sound_instrument *list_instrument(struct fms_object *object_list, bool verbose);
static void delete_instrument_list(struct sound_instrument *instrument_list);
static void write_instrument(FILE *output_file, struct sound_instrument *instrument_list, bool verbose);
static struct sound_song *list_song(struct fms_object *object_list, bool verbose);
static void delete_song_list(struct sound_song *song_list);
static void write_song(FILE *output_file, struct sound_song *song_list, struct sound_instrument *instrument_list, bool verbose);
static void save_sound(const char *output_path, struct sound_instrument *instrument_list, struct sound_song *song_list, bool verbose);

// 内部変数
//


// プログラムのエントリポイント
//
int main(int argc, const char *argv[])
{
    // 入力ファイルの初期化
    const char *input_path = NULL;

    // 出力ファイルの初期化
    const char *output_path = NULL;

    // verbose の初期化
    bool verbose = false;

    // 引数の確認
    while (--argc > 0) {
        ++argv;
        if (strcasecmp(*argv, "-o") == 0) {
            if (--argc > 0) {
                ++argv;
                output_path = *argv;
            }
        } else if (strcasecmp(*argv, "-v") == 0) {
            verbose = true;
        } else {
            input_path = *argv;
        }
    }

    // サウンドファイルの作成
    if (input_path != NULL && output_path != NULL) {
        make_sound(input_path, output_path, verbose);

    // ヘルプの表示
    } else {
        printf("Convert Famistduio .txt file:\n");
        printf("fmstxt [-v] -o <output file> <input_file>\n");
    }

    // 終了
    return 0;
}

// FamiStudio テキストを変換してサウンドファイルを作成する
//
static void make_sound(const char *input_path, const char *output_path, bool verbose)
{
    // テキストの読み込み
    char *txt = load_txt(input_path);

    // オブジェクトのリスト化
    struct fms_object *object_list = list_object(txt, verbose);

    // 楽器のリスト化
    if (verbose) {
        printf("Listing instruments...\n");
    }
    struct sound_instrument *instrument_list = list_instrument(object_list, verbose);

    // 曲のリスト化
    if (verbose) {
        printf("Listing songs...\n");
    }
    struct sound_song *song_list = list_song(object_list, verbose);

    // サウンドの書き出し
    save_sound(output_path, instrument_list, song_list, verbose);

    // 曲の破棄
    delete_song_list(song_list);

    // 楽器リストの破棄
    delete_instrument_list(instrument_list);

    // オブジェクトリストの破棄
    delete_object_list(object_list);

    // テキストの解放
    delete_txt(txt);
}

// テキストを読み込む
//
static char *load_txt(const char *txt_path)
{
    // ファイルサイズの取得
    struct stat txt_stat;
    if (stat(txt_path, &txt_stat) != 0) {
        fprintf(stderr, "error: load_txt() - %s file not stated.\n", txt_path);
        exit(1);
    }
    int txt_bytes = txt_stat.st_size;

    // バッファの確保
    char *txt = new char[txt_bytes + 1];
    if (txt == NULL) {
        fprintf(stderr, "error: load_txt() - buffer is not allocated.\n");
        exit(1);
    }
    memset(txt, 0x00, txt_bytes);

    // ファイルを開く
    FILE *txt_file = fopen(txt_path, "rb");
    if (txt_file == NULL) {
        fprintf(stderr, "error: load_txt() - %s file not opened.\n", txt_path);
        exit(1);
    }

    // ファイルを読み込む
    size_t read_count = fread(txt, txt_bytes, 1, txt_file);
    if (read_count != 1) {
        fprintf(stderr, "error: load_txt() - %s file is not read.\n", txt_path);
        exit(1);
    }

    // ファイルを閉じる
    fclose(txt_file);

    // 終了
    return txt;
}

// テキストを破棄する
//
static void delete_txt(char *txt)
{
    delete[] txt;
}

// オブジェクトをリスト化する
//
static struct fms_object *list_object(char *txt, bool verbose)
{
    // オブジェクトの初期化
    struct fms_object *object_list = NULL;
    struct fms_object *object_last = NULL;

    // テキストの走査
    while (*txt != '\0') {

        // オブジェクト名の取得
        while (isblank(*txt) != 0) {
            ++txt;
        }
        if (isalpha(*txt) != 0) {

            // オブジェクトの作成
            struct fms_object *object = new struct fms_object;
            if (object == NULL) {
                fprintf(stderr, "error: list_object() - object is not allocated.\n");
                exit(1);
            }
            if (object_list == NULL) {
                object_list = object;
            }
            if (object_last != NULL) {
                object_last->next = object;
            }
            object_last = object;

            // オブジェクトの設定
            object->name = txt;
            object->attribute = NULL;
            object->next = NULL;
            while (isalnum(*txt) != 0) {
                ++txt;
            }
            if (*txt != '\0') {
                *txt = '\0';
                ++txt;
            }

            // 属性の初期化
            struct fms_attribute *attribute_last = NULL;

            // 属性の取得
            while (*txt != '\0' && islrlf(*txt) == 0) {
                while (isblank(*txt) != 0) {
                    ++txt;
                }
                if (isalpha(*txt) != 0) {
                    char *name = txt;
                    while (isalnum(*txt) != 0) {
                        ++txt;
                    }
                    if (*txt != '\0') {
                        *txt = '\0';
                        ++txt;
                    }
                    while (*txt != '\0' && *txt != '"') {
                        ++txt;
                    }
                    if (*txt == '"') {
                        ++txt;
                        char *value = txt;
                        while (*txt != '\0' && *txt != '"') {
                            ++txt;
                        }
                        if (*txt == '"') {
                            *txt = '\0';
                            ++txt;

                            // 属性の作成
                            struct fms_attribute *attribute = new struct fms_attribute;
                            if (attribute == NULL) {
                                fprintf(stderr, "error: list_object() - attribute is not allocated.\n");
                                exit(1);
                            }
                            if (object->attribute == NULL) {
                                object->attribute = attribute;
                            }
                            if (attribute_last != NULL) {
                                attribute_last->next = attribute;
                            }
                            attribute_last = attribute;

                            // 属性の設定
                            attribute->name = name;
                            attribute->value = value;
                            attribute->next = NULL;
                        }
                    }
                }
            }
        }

        // 次の行へ
        while (*txt != '\0' && islrlf(*txt) == 0) {
            ++txt;
        }
        while (*txt != '\0' && islrlf(*txt) != 0) {
            ++txt;
        }
    }

    // 終了
    return object_list;
}

// オブジェクトリストを破棄する
//
static void delete_object_list(struct fms_object *object_list)
{
    struct fms_object *object = object_list;
    while (object != NULL) {
        struct fms_attribute *attribute = object->attribute;
        while (attribute != NULL) {
            struct fms_attribute *next = attribute->next;
            delete attribute;
            attribute = next;
        }
        {
            struct fms_object *next = object->next;
            delete object;
            object = next;
        }
    }
}

// 改行コードかどうかを判定する
//
static int islrlf(int c)
{
    return c == '\r' || c == '\n' ? 1 : 0;
}

// 指定された名前のオブジェクトを取得する
//
static struct fms_object *get_object(struct fms_object *object, const char *name)
{
    while (object != NULL && strcasecmp(object->name, name) != 0) {
        object = object->next;
    }
    return object;
}

// 指定された名前の属性を取得する
//
static struct fms_attribute *get_attribute(struct fms_object *object, const char *name)
{
    struct fms_attribute *attribute = object->attribute;
    while (attribute != NULL && strcasecmp(attribute->name, name) != 0) {
        attribute = attribute->next;
    }
    return attribute;
}

// 楽器をリスト化する
//
static struct sound_instrument *list_instrument(struct fms_object *object_list, bool verbose)
{
    // 文字列の定義
    static const char *string_instrument = "Instrument";
    static const char *string_envelope = "Envelope";
    static const char *string_name = "Name";
    static const char *string_type = "Type";
    static const char *string_volume = "Volume";
    static const char *string_values = "Values";

    // 楽器の初期化
    struct sound_instrument *instrument_list = NULL;
    struct sound_instrument *instrument_last = NULL;

    // オブジェクトの走査
    struct fms_object *object_instrument = get_object(object_list, string_instrument);
    while (object_instrument != NULL) {

        // 楽器の作成
        struct sound_instrument *instrument = new struct sound_instrument;
        if (instrument == NULL) {
            fprintf(stderr, "error: list_instrument() - instrument is not allocated.\n");
            exit(1);
        }
        if (instrument_list == NULL) {
            instrument_list = instrument;
        }
        if (instrument_last != NULL) {
            instrument_last->next = instrument;
        }
        instrument_last = instrument;

        // 楽器の設定
        {
            struct fms_attribute *attribute_name = get_attribute(object_instrument, string_name);
            if (attribute_name == NULL) {
                fprintf(stderr, "error: list_instrument() - instrument: no 'Name' attribute.\n");
                exit(1);
            }
            instrument->name = attribute_name->value;
            for (int i = 0; i < SOUND_INSTRUMENT_WAVE_SIZE; i++) {
                instrument->wave[i] = 15 << 4;
            }
            instrument->next = NULL;
            if (verbose) {
                printf("Instrument: name='%s'\n", instrument->name);
            }
        }

        // ネストされたオブジェクトの走査
        struct fms_object *object_nest = object_instrument->next;
        while (object_nest != NULL) {

            // エンベロープ
            if (strcasecmp(object_nest->name, string_envelope) == 0) {

                // エンベロープの設定
                struct fms_object *object_envelope = object_nest;
                struct fms_attribute *attribute_type = get_attribute(object_envelope, string_type);
                if (attribute_type != NULL && strcasecmp(attribute_type->value, string_volume) == 0) {

                    // 波形の設定
                    struct fms_attribute *attribute_values = get_attribute(object_envelope, string_values);
                    if (attribute_values != NULL) {
                        const char *s = attribute_values->value;
                        int index = 0;
                        while (index < SOUND_INSTRUMENT_WAVE_SIZE && *s != '\0') {
                            int value = 0;
                            while (isdigit(*s) != 0) {
                                value = value * 10 + *s - '0';
                                ++s;
                            }
                            while (isblank(*s) != 0 || *s == ',') {
                                ++s;
                            }
                            instrument->wave[index] = value << 4;
                            ++index;
                        }
                        int refer = 0;
                        while (index < SOUND_INSTRUMENT_WAVE_SIZE) {
                            instrument->wave[index] = instrument->wave[refer];
                            ++index;
                            ++refer;
                        }
                    }
                }

            // それ以外はネストの終了
            } else {
                break;
            }

            // 次のネストへ
            object_nest = object_nest->next;
        }

        // 次のオブジェクトへ
        object_instrument = get_object(object_instrument->next, string_instrument);
    }

    // 終了
    return instrument_list;
}

// 楽器リストを破棄する
//
static void delete_instrument_list(struct sound_instrument *instrument_list)
{
    struct sound_instrument *instrument = instrument_list;
    while (instrument != NULL) {
        struct sound_instrument *next = instrument->next;
        delete instrument;
        instrument = next;
    }
}

// 楽器を書き出す
static void write_instrument(FILE *output_file, struct sound_instrument *instrument_list, bool verbose)
{
    // 楽器数のカウント
    int instrument_count = 0;
    {
        struct sound_instrument *instrument = instrument_list;
        while (instrument != NULL) {
            ++instrument_count;
            instrument = instrument->next;
        }
    }

    // オフセットの書き出し
    {
        unsigned short offset = instrument_count * SOUND_INSTRUMENT_WAVE_SIZE + sizeof (unsigned short);
        size_t write_count = fwrite(&offset, sizeof (unsigned short), 1, output_file);
        if (write_count != 1) {
            fprintf(stderr, "error: write_instrument() - instrument offset is not write.\n");
            exit(1);
        }
    }

    // 波形データの書き出し
    {
        struct sound_instrument *instrument = instrument_list;
        while (instrument != NULL) {
            size_t write_count = fwrite(instrument->wave, SOUND_INSTRUMENT_WAVE_SIZE * sizeof (unsigned char), 1, output_file);
            if (write_count != 1) {
                fprintf(stderr, "error: write_instrument() - instrument wave is not write.\n");
                exit(1);
            }
            instrument = instrument->next;
        }
    }
}

// 曲をリスト化する
//
static struct sound_song *list_song(struct fms_object *object_list, bool verbose)
{
    // 文字列の定義
    static const char *string_song = "Song";
    static const char *string_channel = "Channel";
    static const char *string_pattern_custom_settings = "PatternCustomSettings";
    static const char *string_pattern = "Pattern";
    static const char *string_note = "Note";
    static const char *string_pattern_instance = "PatternInstance";
    static const char *string_name = "Name";
    static const char *string_length = "Length";
    static const char *string_pattern_length = "PatternLength";
    static const char *string_note_length = "NoteLength";
    static const char *string_type = "Type";
    static const char *string_time = "Time";
    static const char *string_duration = "Duration";
    static const char *string_value = "Value";
    static const char *string_instrument = "Instrument";
    static const char *string_volume = "Volume";

    // 楽器の初期化
    struct sound_song *song_list = NULL;
    struct sound_song *song_last = NULL;

    // オブジェクトの走査
    struct fms_object *object_song = get_object(object_list, string_song);
    while (object_song != NULL) {

        // 曲の作成
        struct sound_song *song = new struct sound_song;
        if (song == NULL) {
            fprintf(stderr, "error: list_song() - song is not allocated.\n");
            exit(1);
        }
        if (song_list == NULL) {
            song_list = song;
        }
        if (song_last != NULL) {
            song_last->next = song;
        }
        song_last = song;

        // 曲の設定
        {
            struct fms_attribute *attribute_name = get_attribute(object_song, string_name);
            if (attribute_name == NULL) {
                fprintf(stderr, "error: list_song() - song: no 'Name' attribute.\n");
                exit(1);
            }
            song->name = attribute_name->value;
            struct fms_attribute *attribute_length = get_attribute(object_song, string_length);
            if (attribute_length == NULL) {
                fprintf(stderr, "error: list_song() - song: 'Length' attribute.\n");
                exit(1);
            }
            song->pattern_size = atoi(attribute_length->value);
            struct fms_attribute *attribute_pattern_length = get_attribute(object_song, string_pattern_length);
            if (attribute_pattern_length == NULL) {
                fprintf(stderr, "error: list_song() - song: no 'PatternLength' attribute.\n");
                exit(1);
            }
            int pattern_length = atoi(attribute_pattern_length->value);
            struct fms_attribute *attribute_note_length = get_attribute(object_song, string_note_length);
            if (attribute_note_length == NULL) {
                fprintf(stderr, "error: list_song() - song: no 'NoteLength' attribute.\n");
                exit(1);
            }
            int note_length = atoi(attribute_note_length->value);
            song->pattern_frame = pattern_length * note_length;
            song->channel = NULL;
            song->next = NULL;
            if (verbose) {
                printf("Song: name='%s'\n", song->name);
            }
        }

        // ネストされたオブジェクトの走査
        struct fms_object *object_nest = object_song->next;
        while (object_nest != NULL) {

            // チャンネル
            if (strcasecmp(object_nest->name, string_channel) == 0) {

                // チャンネルの作成
                struct sound_channel *channel = new struct sound_channel;
                if (channel == NULL) {
                    fprintf(stderr, "error: list_song() - channel is not allocated.\n");
                    exit(1);
                }
                if (song->channel == NULL) { 
                    song->channel = channel;
                } else {
                    struct sound_channel *p = song->channel;
                    while (p->next != NULL) {
                        p = p->next;
                    }
                    p->next = channel;
                }

                // チャンネルの設定
                struct fms_object *object_channel = object_nest;
                {
                    struct fms_attribute *attribute_type = get_attribute(object_nest, string_type);
                    if (attribute_type == NULL) {
                        fprintf(stderr, "error: list_song() - channel: no 'Type' attribute.\n");
                        exit(1);
                    }
                    channel->type = attribute_type->value;
                    channel->pattern = NULL;
                    channel->pattern_instance = NULL;
                    channel->next = NULL;
                    if (verbose) {
                        printf("  Channel: type='%s'\n", channel->type);
                    }
                }

                // チャンネルにネストされたオブジェクトの走査
                object_nest = object_nest->next;
                while (object_nest != NULL) {

                    // パターン
                    if (strcasecmp(object_nest->name, string_pattern) == 0) {

                        // パターンの作成
                        struct sound_pattern *pattern = new struct sound_pattern;
                        if (pattern == NULL) {
                            fprintf(stderr, "error: list_song() - pattern is not allocated.\n");
                            exit(1);
                        }
                        if (channel->pattern == NULL) { 
                            channel->pattern = pattern;
                        } else {
                            struct sound_pattern *p = channel->pattern;
                            while (p->next != NULL) {
                                p = p->next;
                            }
                            p->next = pattern;
                        }

                        // パターンの設定
                        {
                            struct fms_attribute *attribute_name = get_attribute(object_nest, string_name);
                            if (attribute_name == NULL) {
                                fprintf(stderr, "error: list_song() - pattern: no 'Name' attribute.\n");
                                exit(1);
                            }
                            pattern->name = attribute_name->value;
                            pattern->note = NULL;
                            pattern->next = NULL;
                            if (verbose) {
                                printf("    Pattern: name='%s'\n", pattern->name);
                            }
                        }

                        // パターンにネストされたオブジェクトの走査
                        object_nest = object_nest->next;
                        while (object_nest != NULL) {

                            // 音符
                            if (strcasecmp(object_nest->name, string_note) == 0) {

                                // 音符の作成
                                struct sound_note *note = new struct sound_note;
                                if (note == NULL) {
                                    fprintf(stderr, "error: list_song() - note is not allocated.\n");
                                    exit(1);
                                }
                                if (pattern->note == NULL) { 
                                    pattern->note = note;
                                } else {
                                    struct sound_note *p = pattern->note;
                                    while (p->next != NULL) {
                                        p = p->next;
                                    }
                                    p->next = note;
                                }

                                //  音符の設定
                                {
                                    struct fms_attribute *attribute_time = get_attribute(object_nest, string_time);
                                    if (attribute_time == NULL) {
                                        fprintf(stderr, "error: list_song() - note: no 'Time' attribute.\n");
                                        exit(1);
                                    }
                                    note->time = atoi(attribute_time->value);
                                    struct fms_attribute *attribute_duration = get_attribute(object_nest, string_duration);
                                    if (attribute_duration != NULL) {
                                        note->duration = atoi(attribute_duration->value);
                                    } else {
                                        note->duration = -1;
                                    }
                                    struct fms_attribute *attribute_value = get_attribute(object_nest, string_value);
                                    if (attribute_value != NULL) {
                                        note->value = attribute_value->value;
                                    } else {
                                        note->value = NULL;
                                    }
                                    struct fms_attribute *attribute_instrument = get_attribute(object_nest, string_instrument);
                                    if (attribute_instrument != NULL) {
                                        note->instrument = attribute_instrument->value;
                                    } else {
                                        note->instrument = NULL;
                                    }
                                    struct fms_attribute *attribute_volume = get_attribute(object_nest, string_volume);
                                    if (attribute_volume != NULL) {
                                        note->volume = atoi(attribute_volume->value);
                                    } else {
                                        note->volume = -1;
                                    }
                                    note->next = NULL;
                                }

                            // それ以外は終了
                            } else {
                                break;
                            }

                            // 次のネストへ
                            object_nest = object_nest->next;
                        }
                        if (verbose) {
                            struct sound_note *p = pattern->note;
                            int n = 0;
                            while (p != NULL) {
                                ++n;
                                p = p->next;
                            }
                            printf("      Note: %d notes.\n", n);
                        }

                    // パターンインスタンス
                    } else if (strcasecmp(object_nest->name, string_pattern_instance) == 0) {

                        // パターンインスタンスの作成
                        struct sound_pattern_instance *pattern_instance = new struct sound_pattern_instance;
                        if (pattern_instance == NULL) {
                            fprintf(stderr, "error: list_song() - pattern instance is not allocated.\n");
                            exit(1);
                        }
                        if (channel->pattern_instance == NULL) { 
                            channel->pattern_instance = pattern_instance;
                        } else {
                            struct sound_pattern_instance *p = channel->pattern_instance;
                            while (p->next != NULL) {
                                p = p->next;
                            }
                            p->next = pattern_instance;
                        }

                        // パターンインスタンスの設定
                        {
                            struct fms_attribute *attribute_time = get_attribute(object_nest, string_time);
                            if (attribute_time == NULL) {
                                fprintf(stderr, "error: list_song() - pattern instance: no 'Time' attribute.\n");
                                exit(1);
                            }
                            pattern_instance->time = atoi(attribute_time->value);
                            struct fms_attribute *attribute_pattern = get_attribute(object_nest, string_pattern);
                            if (attribute_time == NULL) {
                                fprintf(stderr, "error: list_song() - pattern instance: no 'Pattern' attribute.\n");
                                exit(1);
                            }
                            pattern_instance->pattern = attribute_pattern->value;
                            if (verbose) {
                                printf("    Pattern instance: [%d] %s\n", pattern_instance->time, pattern_instance->pattern);
                            }
                        }

                        // 次のネストへ
                        object_nest = object_nest->next;

                    // それ以外は終了
                    } else {
                        break;
                    }
                }

            // パターンカスタムセッティング
            } else if (strcasecmp(object_nest->name, string_pattern_custom_settings) == 0) {

                // 次のネストへ
                object_nest = object_nest->next;

            // それ以外はネストの終了
            } else {
                break;
            }
        }

        // 次のオブジェクトへ
        object_song = get_object(object_song->next, string_song);
    }

    // 終了
    return song_list;
}

// 楽器リストを破棄する
//
static void delete_song_list(struct sound_song *song_list)
{
    struct sound_song *song = song_list;
    while (song != NULL) {
        struct sound_channel *channel = song->channel;
        while (channel != NULL) {
            struct sound_pattern *pattern = channel->pattern;
            while (pattern != NULL) {
                struct sound_note *note = pattern->note;
                while (note != NULL) {
                    struct sound_note *next = note->next;
                    delete note;
                    note = next;
                }
                struct sound_pattern *next = pattern->next;
                delete pattern;
                pattern = next;
            }
            struct sound_pattern_instance *pattern_instance = channel->pattern_instance;
            while (pattern_instance != NULL) {
                struct sound_pattern_instance *next = pattern_instance->next;
                delete pattern_instance;
                pattern_instance = next;
            }
            struct sound_channel *next = channel->next;
            delete channel;
            channel = next;
        }
        struct sound_song *next = song->next;
        delete song;
        song = next;
    }
}

// 曲を書き出す
//
static void write_song(FILE *output_file, struct sound_song *song_list, struct sound_instrument *instrument_list, bool verbose)
{
    // 文字列の定義
    static const char *string_square1 = "Square1";
    static const char *string_square2 = "Square2";
    static const char *string_triangle = "Triangle";

    // 音階の定義
    static const int scale_size = 12 * 8;
    static const char *scale_name[] = {
    //  C       C#      D       D#      E       F       F#      G       G#      A       A#      B
        "C0",   "C#0",  "D0",   "D#0",  "E0",   "F0",   "F#0",  "G0",   "G#0",  "A0",   "A#0",  "B0",       // O1
        "C1",   "C#1",  "D1",   "D#1",  "E1",   "F1",   "F#1",  "G1",   "G#1",  "A1",   "A#1",  "B1",       // O2
        "C2",   "C#2",  "D2",   "D#2",  "E2",   "F2",   "F#2",  "G2",   "G#2",  "A2",   "A#2",  "B2",       // O3
        "C3",   "C#3",  "D3",   "D#3",  "E3",   "F3",   "F#3",  "G3",   "G#3",  "A3",   "A#3",  "B3",       // O4
        "C4",   "C#4",  "D4",   "D#4",  "E4",   "F4",   "F#4",  "G4",   "G#4",  "A4",   "A#4",  "B4",       // O5
        "C5",   "C#5",  "D5",   "D#5",  "E5",   "F5",   "F#5",  "G5",   "G#5",  "A5",   "A#5",  "B5",       // O6
        "C6",   "C#6",  "D6",   "D#6",  "E6",   "F6",   "F#6",  "G6",   "G#6",  "A6",   "A#6",  "B6",       // O7
        "C7",   "C#7",  "D7",   "D#7",  "E7",   "F7",   "F#7",  "G7",   "G#7",  "A7",   "A#7",  "B7",       // O8
    };
    static const unsigned short scale_frequency[] = {
    //  C       C#      D       D#      E       F       F#      G       G#      A       A#      B
        0x0eef, 0x0e17, 0x0d4d, 0x0c8e, 0x0bda, 0x0b2f, 0x0a8f, 0x09f7, 0x0968, 0x08e1, 0x0862, 0x07e9,     // O1
        0x0777, 0x070b, 0x06a6, 0x0647, 0x05ed, 0x0597, 0x0547, 0x04fb, 0x04b4, 0x0470, 0x0431, 0x03f4,     // O2
        0x03bb, 0x0385, 0x0353, 0x0323, 0x02f6, 0x02cb, 0x02a3, 0x027d, 0x025a, 0x0238, 0x0218, 0x01fa,     // O3
        0x01dd, 0x01c2, 0x01a9, 0x0191, 0x017b, 0x0165, 0x0151, 0x013e, 0x012d, 0x011c, 0x010c, 0x00fd,     // O4
        0x00ee, 0x00e1, 0x00d4, 0x00c8, 0x00bd, 0x00b2, 0x00a8, 0x009f, 0x0096, 0x008e, 0x0086, 0x007e,     // O5
        0x0077, 0x0070, 0x006a, 0x0064, 0x005e, 0x0059, 0x0054, 0x004f, 0x004b, 0x0047, 0x0043, 0x003f,     // O6
        0x003b, 0x0038, 0x0035, 0x0032, 0x002f, 0x002c, 0x002a, 0x0027, 0x0025, 0x0023, 0x0021, 0x001f,     // O7
        0x001d, 0x001c, 0x001a, 0x0019, 0x0017, 0x0016, 0x0015, 0x0013, 0x0012, 0x0011, 0x0010, 0x000f,     // O8
    };

    // 曲数のカウント
    unsigned char song_count = 0;
    {
        struct sound_song *song = song_list;
        while (song != NULL) {
            ++song_count;
            song = song->next;
        }
    }

    // 曲数の書き出し
    {
        size_t write_count = fwrite(&song_count, sizeof (unsigned char), 1, output_file);
        if (write_count != 1) {
            fprintf(stderr, "error: write_song() - song count is not write.\n");
            exit(1);
        }
    }

    // オフセットの作成
    unsigned short *song_offset = new unsigned short[song_count * SOUND_SONG_CHANNEL_SIZE];
    if (song_offset == NULL) {
        fprintf(stderr, "error: write_song() - song offset is not allocated.\n");
        exit(1);
    }
    memset(song_offset, 0x00, song_count * SOUND_SONG_CHANNEL_SIZE * sizeof (unsigned short));

    // オフセットの仮の書き出し
    int offset_position = ftell(output_file);
    {
        size_t write_count = fwrite(song_offset, song_count * SOUND_SONG_CHANNEL_SIZE * sizeof (unsigned short), 1, output_file);
        if (write_count != 1) {
            fprintf(stderr, "error: write_song() - song offset is not write.\n");
            exit(1);
        }
    }

    // 曲の走査
    struct sound_song *song = song_list;
    int song_index = 0;
    while (song != NULL) {

        // チャンネルの取得
        struct sound_channel *channel = song->channel;
        while (channel != NULL) {

            // チャンネル番号の取得
            int channel_index = -1;
            if (strcasecmp(channel->type, string_square1) == 0 && channel->pattern_instance != NULL) {
                channel_index = 0;
            } else if (strcasecmp(channel->type, string_square2) == 0 && channel->pattern_instance != NULL) {
                channel_index = 1;
            } else if (strcasecmp(channel->type, string_triangle) == 0 && channel->pattern_instance != NULL) {
                channel_index = 2;
            }
            if (channel_index >= 0) {

                // チャンネルの初期化
                int channel_volume = 15;
                int channel_pattern_time = 0;

                // オフセットの設定
                song_offset[song_index * SOUND_SONG_CHANNEL_SIZE + channel_index] = ftell(output_file);

                // パターンインスタンスの走査
                struct sound_pattern_instance *pattern_instance = channel->pattern_instance;
                while (pattern_instance != NULL) {

                    // パターンの取得
                    struct sound_pattern *pattern = channel->pattern;
                    while (pattern != NULL && strcasecmp(pattern_instance->pattern, pattern->name) != 0) {
                        pattern = pattern->next;
                    }
                    if (pattern == NULL) {
                        fprintf(stderr, "error: write_song() - illegal pattern '%s'.\n", pattern_instance->pattern);
                        exit(1);
                    }

                    // 音符の走査
                    struct sound_note *note = pattern->note;
                    while (note != NULL) {

                        // 音符データの初期化
                        unsigned short note_frequency = 0x0000;
                        unsigned char note_duration = 0x00;
                        unsigned char note_instrument = 0x00;

                        // 空白の時間
                        if (note->time > channel_pattern_time) {

                            // 休符の指定
                            note_frequency = 0x1000;
                            note_duration = note->time - channel_pattern_time;
                            note_instrument = 0x00;

                        // 音符の存在
                        } else {

                            // 時間の確認
                            if (note->time != channel_pattern_time) {
                                fprintf(stderr, "error: write_song() - illegal note time [%d].\n", note->time);
                                exit(1);
                            }

                            // 音量の更新
                            if (note->volume >= 0) {
                                channel_volume = note->volume;
                            }

                            // 音符の指定
                            if (note->value != NULL) {
                                for (int i = 0; i < scale_size; i++) {
                                    if (strcasecmp(note->value, scale_name[i]) == 0) {
                                        note_frequency = scale_frequency[i];
                                        break;
                                    }
                                }
                                note_duration = note->duration;
                                {
                                    struct sound_instrument *instrument = instrument_list;
                                    int i = 0;
                                    while (instrument != NULL) {
                                        if (strcasecmp(note->instrument, instrument->name) == 0) {
                                            note_instrument = i;
                                            break;
                                        }
                                        instrument = instrument->next;
                                        ++i;
                                    }
                                }

                            // 休符の指定
                            } else {
                                ;
                            }

                            // 次の音符へ
                            note = note->next;
                        }

                        // 音符の書き出し
                        if (note_duration > 0) {
                            unsigned char buffer[4] = {
                                (unsigned char)(note_frequency >> 8), 
                                (unsigned char)(note_frequency & 0xff), 
                                note_duration, 
                                note_frequency != 0x1000 ? (unsigned char)((note_instrument << 4) | channel_volume) : 0x00, 
                            };
                            size_t write_count = fwrite(buffer, 0x04 * sizeof (unsigned char), 1, output_file);
                            if (write_count != 1) {
                                fprintf(stderr, "error: write_song() - song note is not write.\n");
                                exit(1);
                            }
                        }

                        // 時間の更新
                        channel_pattern_time = channel_pattern_time + note_duration;
                    }

                    // パターンを跨ぐ
                    if (channel_pattern_time >= song->pattern_frame) {
                        channel_pattern_time = channel_pattern_time - song->pattern_frame;

                    // パターンに足りない
                    } else if (channel_pattern_time < song->pattern_frame) {

                        // 休符の書き出し
                        unsigned char buffer[4] = {
                            0x10, 
                            0x00, 
                            (unsigned char)(song->pattern_frame - channel_pattern_time), 
                            0x00, 
                        };
                        size_t write_count = fwrite(buffer, 0x04 * sizeof (unsigned char), 1, output_file);
                        if (write_count != 1) {
                            fprintf(stderr, "error: write_song() - song note is not write.\n");
                            exit(1);
                        }

                        // 時間の更新
                        channel_pattern_time = 0;
                    }

                    // 次のパターンインスタンスへ
                    pattern_instance = pattern_instance->next;
                }

                // チャンネルの終端の書き出し
                {
                    static const unsigned char buffer[4] = {
                        0x80, 
                        0x00, 
                        0x00, 
                        0x00, 
                    };
                    size_t write_count = fwrite(buffer, 0x04 * sizeof (unsigned char), 1, output_file);
                    if (write_count != 1) {
                        fprintf(stderr, "error: write_song() - song terminate is not write.\n");
                        exit(1);
                    }
                }
            }

            // 次のチャンネルへ
            channel = channel->next;
        }

        // 次の曲へ
        song = song->next;
        ++song_index;
    }

    // オフセットの上書き
    {
        fseek(output_file, offset_position, SEEK_SET);
        size_t write_count = fwrite(song_offset, song_count * SOUND_SONG_CHANNEL_SIZE * sizeof (unsigned short), 1, output_file);
        if (write_count != 1) {
            fprintf(stderr, "error: write_song() - song offset is not write.\n");
            exit(1);
        }
    }
}

// サウンドファイルを書き出す
//
static void save_sound(const char *output_path, struct sound_instrument *instrument_list, struct sound_song *song_list, bool verbose)
{
    // ファイルを開く
    FILE *sound_file = fopen(output_path, "w+b");
    if (sound_file == NULL) {
        fprintf(stderr, "error: save_sound() - %s file not opened.\n", output_path);
        exit(1);
    }

    // 楽器の書き出し
    write_instrument(sound_file, instrument_list, verbose);

    // 曲の書き出し
    write_song(sound_file, song_list, instrument_list, verbose);

    // ファイルを閉じる
    fclose(sound_file);
}
