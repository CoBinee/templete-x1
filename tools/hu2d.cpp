/*
    Hu-BASIC フォーマットの 2D ディスクの .d88 ファイルを作成する 
*/

// 参照ファイル
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>


// Hu-BASIC ファイルフォーマット
//
#define HU_TRACK_SIZE                           40
#define HU_HEAD_SIZE                            2
#define HU_CLUSTER_SIZE                         HU_TRACK_SIZE * HU_HEAD_SIZE
#define HU_SECTOR_SIZE                          16
#define HU_SECTOR_BYTES                         256

// ブートセクタ
#define HU_BOOT_TRACK                           0
#define HU_BOOT_HEAD                            0
#define HU_BOOT_SECTOR                          0
#define HU_BOOT_FLAG_OFF                        0x00
#define HU_BOOT_FLAG_BOOTABLE                   0x01
#define HU_BOOT_STARTUP_LABEL_LENGTH            13
#define HU_BOOT_FILE_EXTENSION_LENGTH           4
#define HU_BOOT_MODIFIED_DATE_YEAR              0
#define HU_BOOT_MODIFIED_DATE_MONTH_WEEK        1
#define HU_BOOT_MODIFIED_DATE_DAY               2
#define HU_BOOT_MODIFIED_DATE_HOURS             3
#define HU_BOOT_MODIFIED_DATE_MINUTES           4
#define HU_BOOT_MODIFIED_DATE_SECONDS           5
#define HU_BOOT_MODIFIED_DATE_BYTES             6
struct hu_boot {
    unsigned char boot_flag;
    char startup_label[HU_BOOT_STARTUP_LABEL_LENGTH];
    char file_extension[HU_BOOT_FILE_EXTENSION_LENGTH];
    unsigned short size;
    unsigned short load_address;
    unsigned short excute_address;
    unsigned char modified_data[HU_BOOT_MODIFIED_DATE_BYTES];
    unsigned short start_sector;
};

// ファイルアロケーションテーブル
#define HU_FAT_TRACK                            0
#define HU_FAT_HEAD                             0
#define HU_FAT_SECTOR                           14
#define HU_FAT_SIZE                             HU_CLUSTER_SIZE
#define HU_FAT_FREE                             0x00
#define HU_FAT_TERMINATE                        0x80

// ディレクトリ
#define HU_DIRECTORY_TRACK                      0
#define HU_DIRECTORY_HEAD                       1
#define HU_DIRECTORY_SECTOR                     0
#define HU_DIRECTORY_ATTRIBUTE_KILL             0x00
#define HU_DIRECTORY_ATTRIBUTE_BIN              0x01
#define HU_DIRECTORY_ATTRIBUTE_BAS              0x02
#define HU_DIRECTORY_ATTRIBUTE_ASC              0x04
#define HU_DIRECTORY_ATTRIBUTE_HIDDEN           0x10
#define HU_DIRECTORY_ATTRIBUTE_VERIFY           0x20
#define HU_DIRECTORY_ATTRIBUTE_READ_ONLY        0x40
#define HU_DIRECTORY_ATTRIBUTE_DIRECTORY        0x80
#define HU_DIRECTORY_FILE_NAME_LENGTH           13
#define HU_DIRECTORY_FILE_EXTENSION_LENGTH      3
#define HU_DIRECTORY_MODIFIED_DATE_YEAR         0
#define HU_DIRECTORY_MODIFIED_DATE_MONTH_WEEK   1
#define HU_DIRECTORY_MODIFIED_DATE_DAY          2
#define HU_DIRECTORY_MODIFIED_DATE_HOURS        3
#define HU_DIRECTORY_MODIFIED_DATE_MINUTES      4
#define HU_DIRECTORY_MODIFIED_DATE_SECONDS      5
#define HU_DIRECTORY_MODIFIED_DATE_BYTES        6
struct hu_directory {
    unsigned char attribute;
    char file_name[HU_DIRECTORY_FILE_NAME_LENGTH];
    char file_extension[HU_DIRECTORY_FILE_EXTENSION_LENGTH];
    char passcode;
    unsigned short size;
    unsigned short load_address;
    unsigned short excute_address;
    unsigned char modified_data[HU_DIRECTORY_MODIFIED_DATE_BYTES];
    unsigned short start_cluster;
};

// d88 ファイルフォーマット／Hu-BASIC 2D Disk Image
//

// ヘッダ
#define D88_HEADER_IMAGE_NAME_LENGTH            17
#define D88_HEADER_RESERVED_BYTES               9
#define D88_HEADER_PROTECT_OFF                  0x00
#define D88_HEADER_PROTECT_ON                   0x10
#define D88_HEADER_MEDIA_TYPE_2D                0x00
#define D88_HEADER_MEDIA_TYPE_2DD               0x10
#define D88_HEADER_MEDIA_TYPE_2HD               0x20
#define D88_HEADER_MEDIA_TYPE_1D                0x30
#define D88_HEADER_MEDIA_TYPE_1DD               0x40
#define D88_HEADER_OFFSET_SIZE                  164
struct d88_header {
    char image_name[D88_HEADER_IMAGE_NAME_LENGTH];
    unsigned char reserved[D88_HEADER_RESERVED_BYTES];
    unsigned char protect;
    unsigned char media_type;
    unsigned int disk_size;
    unsigned int offset[D88_HEADER_OFFSET_SIZE];
};

// トラック

// セクタ
#define D88_SECTOR_SECTOR_SIZE_128              0x00
#define D88_SECTOR_SECTOR_SIZE_256              0x01
#define D88_SECTOR_SECTOR_SIZE_512              0x02
#define D88_SECTOR_SECTOR_SIZE_1024             0x03
#define D88_SECTOR_DENSITY_DOUBLE               0x00
#define D88_SECTOR_DENSITY_SINGLE               0x40
#define D88_SECTOR_DDAM_NORMAL                  0x00
#define D88_SECTOR_DDAM_DELETED                 0x10
#define D88_SECTOR_FDC_STATUS_NORMAL            0x00
#define D88_SECTOR_FDC_STATUS_DELETED           0x10
#define D88_SECTOR_FDC_STATUS_ERROR_ID_CRC      0xa0
#define D88_SECTOR_FDC_STATUSERROR_DATA_CRC     0xb0
#define D88_SECTOR_FDC_STATUS_NOMARK_ADDRESS    0xe0
#define D88_SECTOR_FDC_STATUS_NOMARK_DATA       0xf0
#define D88_SECTOR_RESERVED_BYTES               5
struct d88_sector {
    unsigned char cylinder;
    unsigned char head;
    unsigned char sector;
    unsigned char sector_size;
    unsigned short number_of_sector;
    unsigned char density;
    unsigned char ddam;
    unsigned char fdc_status;
    unsigned char reserved[D88_SECTOR_RESERVED_BYTES];
    unsigned short actual_size;
    unsigned char data[HU_SECTOR_BYTES];
};

// ディスク
struct d88_disk {
    struct d88_header header;
    struct d88_sector sector[HU_TRACK_SIZE][HU_HEAD_SIZE][HU_SECTOR_SIZE];
};


// 内部関数
//
static void view_disk(const char *view_path);
static void make_disk(const char *output_path, const char *input_path[], const char *label, bool d88);
static void format_disk(struct d88_disk *disk);
static void add_file(struct d88_disk *disk, const char *input_path);
static void set_boot(struct d88_disk *disk, const char *label);
static hu_directory *get_free_directory(struct d88_disk *disk);
static int get_free_cluster(struct d88_disk *disk);
static unsigned char get_bcd(unsigned char decimal);
static void dump_sector(struct d88_disk *disk, int track, int head, int sector, const char *name);


// プログラムのエントリポイント
//
int main(int argc, const char *argv[])
{
    // 閲覧ファイルの初期化
    const char *view_path = NULL;

    // 出力ファイルの初期化
    const char *output_path = NULL;

    // ラベルの初期化
    const char *label = NULL;

    // ディスクフォーマットの初期化
    bool d88 = true;

    // 入力ファイルの初期化
    const char *input_path[HU_FAT_SIZE];
    for (int i = 0; i < HU_FAT_SIZE; i++) {
        input_path[i] = NULL;
    }

    // 引数の確認
    while (--argc > 0) {
        ++argv;
        if (strcasecmp(*argv, "-v") == 0) {
            if (--argc > 0) {
                ++argv;
                view_path = *argv;
            }
        } else if (strcasecmp(*argv, "-o") == 0) {
            if (--argc > 0) {
                ++argv;
                output_path = *argv;
            }
        } else if (strcasecmp(*argv, "-l") == 0) {
            if (--argc > 0) {
                ++argv;
                label = *argv;
            }
        } else if (strcasecmp(*argv, "-d88") == 0) {
            d88 = true;
        } else if (strcasecmp(*argv, "-2d") == 0) {
            d88 = false;
        } else {
            int i = 0;
            while (i < HU_FAT_SIZE && input_path[i] != NULL) {
                i++;
            }
            if (i < HU_FAT_SIZE) {
                input_path[i] = *argv;
            }
        }
    }

    // ファイルの閲覧
    if (view_path != NULL) {
        view_disk(view_path);

    // ファイルの作成
    } else if (output_path != NULL) {
        make_disk(output_path, input_path, label, d88);

    // ヘルプの表示
    } else {
        printf("View .d88 file:\n");
        printf("hu2d -v <d88 file>\n");
        printf("Create .d88 or .2d file:\n");
        printf("hu2d -o <d88 file> [-l label] [-d88|-2d] files...\n");
    }

    // 終了
    return 0;
}

// ディスクを閲覧する
//
static void view_disk(const char *view_path)
{
    // ディスクの作成
    struct d88_disk *disk = NULL;
    disk = new struct d88_disk;
    if (disk == NULL) {
        fprintf(stderr, "error: view_disk() - buffer is not allocated.\n");
        exit(1);
    }

    // ファイルを開く
    FILE *view_file = fopen(view_path, "rb");
    if (view_file == NULL) {
        fprintf(stderr, "error: view_disk() - %s file not opened.\n", view_path);
        exit(1);
    }

    // ファイルを読み込む
    size_t read_count = fread(disk, sizeof (struct d88_disk), 1, view_file);
    if (read_count != 1) {
        fprintf(stderr, "error: view_disk() - %s file is not read.\n", view_path);
        exit(1);
    }

    // ファイルを閉じる
    fclose(view_file);

    // ブートセクタの表示
    // dump_sector(disk, HU_BOOT_TRACK, HU_BOOT_HEAD, HU_BOOT_SECTOR, "BOOT");

    // FAT の表示
    // dump_sector(disk, HU_FAT_TRACK, HU_FAT_HEAD, HU_FAT_SECTOR, "FAT");

    // ファイルリストの表示
    printf("FILES\n");
    {
        int sector = HU_DIRECTORY_SECTOR;
        int offset = 0;
        struct hu_directory *directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
        while (directory->attribute != 0xff) {
            static const char *week[] = {"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT", };
            printf(
                "%.13s.%.3s, % 6d bytes, %02x/%02d/%02x(%s) %02x:%02x:%02x\n", 
                directory->file_name, 
                directory->file_extension, 
                directory->size, 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_YEAR], 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_MONTH_WEEK] >> 4, 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_DAY], 
                week[directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_MONTH_WEEK] & 0x0f], 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_HOURS], 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_MINUTES], 
                directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_SECONDS]
            );
            offset = offset + sizeof (struct hu_directory);
            if (offset >= HU_SECTOR_BYTES) {
                ++sector;
                offset = 0;
            }
            directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
        }
    }

    // ディスクの破棄
    delete disk;
}

// ディスクを作成する
//
static void make_disk(const char *output_path, const char *input_path[], const char *label, bool d88)
{
    // ディスクの作成
    struct d88_disk *disk = NULL;
    disk = new struct d88_disk;

    // ディスクのフォーマット
    format_disk(disk);

    // 入力ファイルの追加
    for (int i = 0; i < HU_FAT_SIZE; i++) {
        if (input_path[i] != NULL) {
            add_file(disk, input_path[i]);
        }
    }

    // ブートセクタの設定
    set_boot(disk, label);

    // ファイルを開く
    FILE *output_file = fopen(output_path, "wb");
    if (output_file == NULL) {
        fprintf(stderr, "error: make_disk() - %s file not created.\n", output_path);
        exit(1);
    }

    // ファイルを書き出す
    if (d88) {
        size_t write_count = fwrite(disk, sizeof (struct d88_disk), 1, output_file);
        if (write_count != 1) {
            fprintf(stderr, "error: make_disk() - %s file is not write.\n", output_path);
            exit(1);
        }
    } else {
        for (int track = 0; track < HU_TRACK_SIZE; track++) {
            for (int head = 0; head < HU_HEAD_SIZE; head++) {
                for (int sector = 0; sector < HU_SECTOR_SIZE; sector++) {
                    size_t write_count = fwrite(disk->sector[track][head][sector].data, HU_SECTOR_BYTES, 1, output_file);
                    if (write_count != 1) {
                        fprintf(stderr, "error: make_disk() - %s file is not write.\n", output_path);
                        exit(1);
                    }
                }
            }
        }

    }

    // ファイルを閉じる
    fclose(output_file);

    // ディスクの破棄
    delete disk;
}

// ディスクをフォーマットする
//
static void format_disk(struct d88_disk *disk)
{
    // 0xff で埋める
    memset(disk, 0xff, sizeof (struct d88_disk));

    // ヘッダの初期化
    {
        d88_header *header = &disk->header;

        // ディスク名の設定
        memset(header->image_name, 0x00, D88_HEADER_IMAGE_NAME_LENGTH);

        // 予約領域の設定
        memset(header->reserved, 0x00, D88_HEADER_RESERVED_BYTES);

        // プロテクトの設定
        header->protect = D88_HEADER_PROTECT_OFF;

        // ディスクの種類の設定
        header->media_type = D88_HEADER_MEDIA_TYPE_2D;

        // ディスクサイズの設定
        header->disk_size = sizeof (struct d88_disk);

        // オフセットの設定
        memset(header->offset, 0x00, D88_HEADER_OFFSET_SIZE * sizeof (unsigned int));
        for (int track = 0; track < HU_TRACK_SIZE; track++) {
            for (int head = 0; head < HU_HEAD_SIZE; head++) {
                int i = track * HU_HEAD_SIZE + head;
                header->offset[i] = (unsigned int)((unsigned long)disk->sector[track][head] - (unsigned long)disk);
            }
        }
    }

    // セクタの初期化
    {
        // ヘッダの設定
        for (int track = 0; track < HU_TRACK_SIZE; track++) {
            for (int head = 0; head < HU_HEAD_SIZE; head++) {
                for (int sector = 0; sector < HU_SECTOR_SIZE; sector++) {
                    disk->sector[track][head][sector].cylinder = track;
                    disk->sector[track][head][sector].head = head;
                    disk->sector[track][head][sector].sector = sector + 1;
                    disk->sector[track][head][sector].sector_size = D88_SECTOR_SECTOR_SIZE_256;
                    disk->sector[track][head][sector].number_of_sector = HU_SECTOR_SIZE;
                    disk->sector[track][head][sector].density = D88_SECTOR_DENSITY_DOUBLE;
                    disk->sector[track][head][sector].ddam = D88_SECTOR_DDAM_NORMAL;
                    disk->sector[track][head][sector].fdc_status = D88_SECTOR_FDC_STATUS_NORMAL;
                    memset(disk->sector[track][head][sector].reserved, 0x00, D88_SECTOR_RESERVED_BYTES);
                    disk->sector[track][head][sector].actual_size = HU_SECTOR_BYTES;
                }
            }
        }

        // FAT の設定
        {
            unsigned char *data = disk->sector[HU_FAT_TRACK][HU_FAT_HEAD][HU_FAT_SECTOR].data;
            memset(&data[0], 0x00, HU_SECTOR_BYTES);
            memset(&data[HU_CLUSTER_SIZE], 0x8f, 0x30 * sizeof (unsigned char));
            data[0] = 0x01;
            data[1] = 0x8f;
        }
    }

}

// ディスクにファイルを追加する
//
static void add_file(struct d88_disk *disk, const char *input_path)
{
    // ファイルサイズの取得
    struct stat input_stat;
    if (stat(input_path, &input_stat) != 0) {
        fprintf(stderr, "error: add_file() - %s file not stated.\n", input_path);
        exit(1);
    }
    int input_bytes = input_stat.st_size;

    // ファイル名の取得
    const char *input_filename = NULL;
    {
        int i = strlen(input_path);
        while (i > 0 && input_path[i - 1] != '/' && input_path[i - 1] != '\\') {
            --i;
        }
        input_filename = &input_path[i];
    }

    // 拡張子の取得
    const char *input_extension = NULL;
    {
        int i = strlen(input_filename);
        while (i > 0 && input_filename[i - 1] != '.') {
            --i;
        }
        if (i > 0) {

        }
        input_extension = &input_filename[i];
    }

    // ファイルを開く
    FILE *input_file = fopen(input_path, "rb");
    if (input_file == NULL) {
        fprintf(stderr, "error: add_file() - %s file not opened.\n", input_path);
        exit(1);
    }

    // 空のディレクトリの取得
    struct hu_directory *directory = get_free_directory(disk);
    if (directory == NULL) {
        fprintf(stderr, "error: add_file() - directory is not free.\n");
        exit(1);
    }

    // ディレクトリの設定
    {
        directory->attribute = HU_DIRECTORY_ATTRIBUTE_BIN;
        {
            int i = 0;
            while (i < HU_DIRECTORY_FILE_NAME_LENGTH && input_filename[i] != '\0' && input_filename[i] != '.') {
                directory->file_name[i] = input_filename[i];
                ++i;
            }
            while (i < HU_DIRECTORY_FILE_NAME_LENGTH) {
                directory->file_name[i] = ' ';
                ++i;
            }
        }
        {
            int i = 0;
            if (input_extension != NULL) {
                while (i < HU_DIRECTORY_FILE_EXTENSION_LENGTH && input_extension[i] != '\0') {
                    directory->file_extension[i] = input_extension[i];
                    ++i;
                }
            }
            while (i < HU_DIRECTORY_FILE_EXTENSION_LENGTH) {
                directory->file_extension[i] = ' ';
                ++i;
            }
        }
        directory->passcode = ' ';
        directory->size = input_bytes;
        directory->load_address = 0x0000;
        directory->excute_address = 0x0000;
        {
            time_t date_time = time(NULL);
            struct tm *date_tm = localtime(&date_time);
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_YEAR] = get_bcd(date_tm->tm_year % 100);
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_MONTH_WEEK] = (date_tm->tm_mon + 1) * 0x10 + date_tm->tm_wday;
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_DAY] = get_bcd(date_tm->tm_mday);
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_HOURS] = get_bcd(date_tm->tm_hour);
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_MINUTES] = get_bcd(date_tm->tm_min);
            directory->modified_data[HU_DIRECTORY_MODIFIED_DATE_SECONDS] = 0x00;    // 必ず 0 にする
        }
        directory->start_cluster = 0;
    }

    // ファイルをクラスタに読み込む
    int cluster_last = -1;
    while (input_bytes > 0) {

        // 空のクラスタの取得
        int cluster = get_free_cluster(disk);
        if (cluster < 0) {
            fprintf(stderr, "error: add_file() - cluster is not free.\n");
            exit(1);
        }

        // 開始クラスタの設定
        if (directory->start_cluster == 0) {
            directory->start_cluster = cluster;
        }

        // FAT の更新
        disk->sector[HU_FAT_TRACK][HU_FAT_HEAD][HU_FAT_SECTOR].data[cluster] = cluster;
        if (cluster_last >= 0) {
            disk->sector[HU_FAT_TRACK][HU_FAT_HEAD][HU_FAT_SECTOR].data[cluster_last] = cluster;
        }

        // クラスタの先頭セクタの取得
        struct d88_sector *sector = disk->sector[cluster / HU_HEAD_SIZE][cluster % HU_HEAD_SIZE];
        
        // 1 クラスタの読み込み
        int cluster_bytes = input_bytes >= HU_SECTOR_SIZE * HU_SECTOR_BYTES ? HU_SECTOR_SIZE * HU_SECTOR_BYTES : input_bytes;
        input_bytes = input_bytes - cluster_bytes;

        // セクタへの読み込み
        int sector_size = 0;
        while (cluster_bytes > 0) {

            // 1 セクタの読み込み
            int sector_bytes = cluster_bytes >= HU_SECTOR_BYTES ? HU_SECTOR_BYTES : cluster_bytes;
            cluster_bytes = cluster_bytes - sector_bytes;

            // ファイルの読み込み
            size_t read_count = fread(sector->data, sector_bytes, 1, input_file);
            if (read_count != 1) {
                fprintf(stderr, "error: add_file() - %s file is not read.\n", input_path);
                exit(1);
            }

            // 次のセクタへ
            ++sector;
            ++sector_size;
        }

        // 最後のクラスタの FAT の設定
        if (input_bytes == 0) {
            disk->sector[HU_FAT_TRACK][HU_FAT_HEAD][HU_FAT_SECTOR].data[cluster] = 0x80 | (sector_size - 1);
        }

        // 直前のクラスタの設定
        cluster_last = cluster;
    }

    // ファイルを閉じる
    fclose(input_file);
}

// ブートセクタを設定する
//
static void set_boot(struct d88_disk *disk, const char *label)
{
    // .Sys ファイルの検索
    struct hu_directory *sys = NULL;
    {
        int sector = HU_DIRECTORY_SECTOR;
        int offset = 0;
        int fat = 0;
        struct hu_directory *directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
        while (fat < HU_FAT_SIZE && directory->attribute != 0xff) {
            if (directory->file_extension[0] == 'S' && directory->file_extension[1] == 'y' && directory->file_extension[2] == 's') {
                sys = directory;
            }
            offset = offset + sizeof (struct hu_directory);
            if (offset >= HU_SECTOR_BYTES) {
                ++sector;
                offset = 0;
            }
            directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
            ++fat;
        }
    }
    if (sys != NULL) {

        // ブートセクタの取得
        struct hu_boot *boot = (struct hu_boot *)disk->sector[HU_BOOT_TRACK][HU_BOOT_HEAD][HU_BOOT_SECTOR].data;

        // ブートセクタの設定
        boot->boot_flag = HU_BOOT_FLAG_BOOTABLE;
        if (label != NULL) {
            memset(boot->startup_label, ' ', HU_BOOT_STARTUP_LABEL_LENGTH);
            memcpy(boot->startup_label, label, strlen(label));
        } else {
            memcpy(boot->startup_label, sys->file_name, HU_BOOT_STARTUP_LABEL_LENGTH);
        }
        boot->file_extension[0] = 'S';
        boot->file_extension[1] = 'y';
        boot->file_extension[2] = 's';
        boot->file_extension[3] = ' ';
        boot->size = sys->size;
        boot->load_address = 0x0000;
        boot->excute_address = 0x0000;
        memcpy(boot->modified_data, sys->modified_data, HU_BOOT_MODIFIED_DATE_BYTES);
        boot->start_sector = sys->start_cluster * HU_SECTOR_SIZE;
    }
}

// 空のディレクトリを取得する
//
static hu_directory *get_free_directory(struct d88_disk *disk)
{
    int sector = HU_DIRECTORY_SECTOR;
    int offset = 0;
    int fat = 0;
    struct hu_directory *directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
    while (fat < HU_FAT_SIZE && directory->attribute != 0xff) {
        offset = offset + sizeof (struct hu_directory);
        if (offset >= HU_SECTOR_BYTES) {
            ++sector;
            offset = 0;
        }
        directory = (struct hu_directory *)&disk->sector[HU_DIRECTORY_TRACK][HU_DIRECTORY_HEAD][sector].data[offset];
        ++fat;
    }
    return fat < HU_FAT_SIZE ? directory : NULL;
}

// 空のクラスタを取得する
//
static int get_free_cluster(struct d88_disk *disk)
{
    unsigned char *data = disk->sector[HU_FAT_TRACK][HU_FAT_HEAD][HU_FAT_SECTOR].data;
    int cluster = 0;
    while (cluster < HU_FAT_SIZE && data[cluster] != 0x00) {
        ++cluster;
    }
    return cluster < HU_FAT_SIZE ? cluster : -1;
}


// 1 byte 数値を BCD に変換する
//
static unsigned char get_bcd(unsigned char decimal)
{
    return ((decimal / 10) * 0x10) + (decimal % 10);
}

// 1 セクタのデータをダンプする
//
static void dump_sector(struct d88_disk *disk, int track, int head, int sector, const char *name)
{
    printf("%s T%02d:H:%02d:S%02d\n", name, track, head, sector);
    for (int row = 0; row < 16; row++) {
        unsigned int address = (unsigned int)((unsigned long)&disk->sector[track][head][sector].data[row * 16] - (unsigned long)disk);
        printf("%08x ", address);
        for (int column = 0; column < 16; column++) {
            unsigned char data = disk->sector[track][head][sector].data[row * 16 + column];
            printf("%02x ", data);
        }
        for (int column = 0; column < 16; column++) {
            unsigned char data = disk->sector[track][head][sector].data[row * 16 + column];
            if (data < 0x20 || data >= 0x80) {
                printf(".");
            } else {
                printf("%c", data);
            }
        }
        printf("\n");
    }
}
