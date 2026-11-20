// Declaraciones mínimas de libarchive.
//
// macOS incluye libarchive (/usr/lib/libarchive.2.dylib) pero el SDK no trae
// sus cabeceras, así que declaramos aquí solo las funciones que usamos.
// Firmas tomadas de archive.h / archive_entry.h (libarchive 3.x, API estable).

#ifndef ARCHIVE_PREVIEW_SHIM_H
#define ARCHIVE_PREVIEW_SHIM_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <time.h>

struct archive;
struct archive_entry;

#define ARCHIVE_EOF      1
#define ARCHIVE_OK       0
#define ARCHIVE_RETRY  (-10)
#define ARCHIVE_WARN   (-20)
#define ARCHIVE_FAILED (-25)
#define ARCHIVE_FATAL  (-30)

#define AE_IFMT   ((mode_t)0170000)
#define AE_IFREG  ((mode_t)0100000)
#define AE_IFLNK  ((mode_t)0120000)
#define AE_IFDIR  ((mode_t)0040000)

struct archive *archive_read_new(void);
int archive_read_free(struct archive *);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_support_format_raw(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
ssize_t archive_read_data(struct archive *, void *buffer, size_t size);
int archive_read_has_encrypted_entries(struct archive *);

int archive_errno(struct archive *);
const char *archive_error_string(struct archive *);
const char *archive_format_name(struct archive *);
int archive_filter_count(struct archive *);
const char *archive_filter_name(struct archive *, int index);

const char *archive_entry_pathname(struct archive_entry *);
const char *archive_entry_pathname_utf8(struct archive_entry *);
const char *archive_entry_symlink_utf8(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
int archive_entry_size_is_set(struct archive_entry *);
time_t archive_entry_mtime(struct archive_entry *);
int archive_entry_mtime_is_set(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
int archive_entry_is_encrypted(struct archive_entry *);

#endif
