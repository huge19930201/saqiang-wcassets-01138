#if defined(__APPLE__) && !defined(_DARWIN_C_SOURCE)
#define _DARWIN_C_SOURCE 1
#endif
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#include "SaoqiangWCAssetsZIP.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>

static int SaoqiangWCAssetsZIPBytes(FILE *f, const void *p, size_t n) {
    return !n || fwrite(p, 1, n, f) == n;
}
static int SaoqiangWCAssetsZIP16(FILE *f, uint16_t x) {
    unsigned char b[2] = {(unsigned char)x, (unsigned char)(x >> 8)};
    return SaoqiangWCAssetsZIPBytes(f, b, 2);
}
static int SaoqiangWCAssetsZIP32(FILE *f, uint32_t x) {
    return SaoqiangWCAssetsZIP16(f, (uint16_t)x) && SaoqiangWCAssetsZIP16(f, (uint16_t)(x >> 16));
}
static uint32_t SaoqiangWCAssetsZIPCRC(const void *data, size_t n) {
    const unsigned char *p = data; uint32_t crc = 0xffffffffu;
    for (size_t i = 0; i < n; ++i) {
        crc ^= p[i];
        for (unsigned j = 0; j < 8; ++j) crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}
static int SaoqiangWCAssetsZIPName(const char *s) {
    if (!s || !*s || *s == '/' || strlen(s) > UINT16_MAX) return 0;
    const char *part = s;
    for (const char *p = s; ; ++p) {
        unsigned char c = (unsigned char)*p;
        if (c && (c < 32 || c == 127 || c == '\\' || c == ':')) return 0;
        if (!c || c == '/') {
            size_t n = (size_t)(p - part);
            if (!n || (n == 1 && part[0] == '.') || (n == 2 && part[0] == '.' && part[1] == '.')) return 0;
            if (!c) break;
            part = p + 1;
        }
    }
    return 1;
}
int SaoqiangWCAssetsWriteZIP(const char *path, const SaoqiangWCAssetsZIPEntry *entries,
                           size_t count, char *error, size_t errorCapacity) {
    const char *message = "invalid ZIP input"; FILE *f = NULL;
    uint32_t *offsets = NULL, *crcs = NULL;
    if (error && errorCapacity) error[0] = 0;
    if (!path || (count && !entries) || count > UINT16_MAX) goto failed;
    uint64_t total = 22;
    for (size_t i = 0; i < count; ++i) {
        const SaoqiangWCAssetsZIPEntry *e = entries + i;
        if (!SaoqiangWCAssetsZIPName(e->name) || e->size > UINT32_MAX || (e->size && !e->data)) goto failed;
        total += 76u + 2u * strlen(e->name) + e->size;
        if (total >= UINT32_MAX) { message = "ZIP32 size limit exceeded"; goto failed; }
        for (size_t j = 0; j < i; ++j) if (!strcmp(e->name, entries[j].name)) { message = "duplicate ZIP path"; goto failed; }
    }
    offsets = calloc(count ? count : 1, sizeof(*offsets)); crcs = calloc(count ? count : 1, sizeof(*crcs));
    if (!offsets || !crcs) { message = "allocation failed"; goto failed; }
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) { message = "cannot create ZIP (output must not exist)"; goto failed; }
    f = fdopen(fd, "wb");
    if (!f) { close(fd); unlink(path); message = "cannot open ZIP stream"; goto failed; }
    uint32_t at = 0;
    for (size_t i = 0; i < count; ++i) {
        const SaoqiangWCAssetsZIPEntry *e = entries + i;
        uint16_t length = (uint16_t)strlen(e->name); uint32_t size = (uint32_t)e->size;
        offsets[i] = at; crcs[i] = SaoqiangWCAssetsZIPCRC(e->data, e->size);
        if (!(SaoqiangWCAssetsZIP32(f, 0x04034b50) && SaoqiangWCAssetsZIP16(f, 20) &&
            SaoqiangWCAssetsZIP16(f, 0x0800) && SaoqiangWCAssetsZIP16(f, 0) &&
            SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0x21) &&
            SaoqiangWCAssetsZIP32(f, crcs[i]) && SaoqiangWCAssetsZIP32(f, size) && SaoqiangWCAssetsZIP32(f, size) &&
            SaoqiangWCAssetsZIP16(f, length) && SaoqiangWCAssetsZIP16(f, 0) &&
            SaoqiangWCAssetsZIPBytes(f, e->name, length) && SaoqiangWCAssetsZIPBytes(f, e->data, e->size))) goto io_failed;
        at += 30u + length + size;
    }
    uint32_t central = at;
    for (size_t i = 0; i < count; ++i) {
        const SaoqiangWCAssetsZIPEntry *e = entries + i; uint16_t length = (uint16_t)strlen(e->name); uint32_t size = (uint32_t)e->size;
        if (!(SaoqiangWCAssetsZIP32(f, 0x02014b50) && SaoqiangWCAssetsZIP16(f, 20) && SaoqiangWCAssetsZIP16(f, 20) &&
            SaoqiangWCAssetsZIP16(f, 0x0800) && SaoqiangWCAssetsZIP16(f, 0) &&
            SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0x21) && SaoqiangWCAssetsZIP32(f, crcs[i]) &&
            SaoqiangWCAssetsZIP32(f, size) && SaoqiangWCAssetsZIP32(f, size) && SaoqiangWCAssetsZIP16(f, length) &&
            SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) &&
            SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP32(f, 0) && SaoqiangWCAssetsZIP32(f, offsets[i]) &&
            SaoqiangWCAssetsZIPBytes(f, e->name, length))) goto io_failed;
        at += 46u + length;
    }
    if (!(SaoqiangWCAssetsZIP32(f, 0x06054b50) && SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIP16(f, (uint16_t)count) && SaoqiangWCAssetsZIP16(f, (uint16_t)count) &&
        SaoqiangWCAssetsZIP32(f, at - central) && SaoqiangWCAssetsZIP32(f, central) && SaoqiangWCAssetsZIP16(f, 0))) goto io_failed;
    if (fclose(f)) { f = NULL; unlink(path); message = "closing ZIP failed"; goto failed; }
    free(offsets); free(crcs); return 0;
io_failed:
    message = "ZIP write failed"; fclose(f); f = NULL; unlink(path);
failed:
    free(offsets); free(crcs);
    if (error && errorCapacity) snprintf(error, errorCapacity, "%s", message);
    return -1;
}

/* File-backed writer. Keep the memory-entry ABI and behavior above intact. */
typedef struct {
    struct stat snapshot;
    uint32_t size, crc, offset;
    uint16_t nameLength;
} SaoqiangWCAssetsZIPFileInfo;

static int SaoqiangWCAssetsZIPUTF8(const char *name) {
    const unsigned char *p = (const unsigned char *)name;
    while (*p) {
        uint32_t value = *p++, minimum;
        unsigned remaining;
        if (value < 0x80) continue;
        if (value >= 0xc2 && value <= 0xdf) { remaining = 1; minimum = 0x80; value &= 0x1f; }
        else if (value >= 0xe0 && value <= 0xef) { remaining = 2; minimum = 0x800; value &= 0x0f; }
        else if (value >= 0xf0 && value <= 0xf4) { remaining = 3; minimum = 0x10000; value &= 0x07; }
        else return 0;
        while (remaining--) {
            if ((*p & 0xc0) != 0x80) return 0;
            value = (value << 6) | (*p++ & 0x3f);
        }
        if (value < minimum || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) return 0;
    }
    return 1;
}
static unsigned char SaoqiangWCAssetsZIPFold(unsigned char c) {
    return c >= 'A' && c <= 'Z' ? (unsigned char)(c + ('a' - 'A')) : c;
}
static int SaoqiangWCAssetsZIPFileOrder(const void *a, const void *b) {
    const SaoqiangWCAssetsZIPFile *left = *(const SaoqiangWCAssetsZIPFile *const *)a;
    const SaoqiangWCAssetsZIPFile *right = *(const SaoqiangWCAssetsZIPFile *const *)b;
    const unsigned char *p = (const unsigned char *)left->name;
    const unsigned char *q = (const unsigned char *)right->name;
    for (;;) {
        unsigned x = SaoqiangWCAssetsZIPFold(*p++), y = SaoqiangWCAssetsZIPFold(*q++);
        /* Put slash before other characters so a file and its children are adjacent. */
        if (x == '/') x = 1;
        if (y == '/') y = 1;
        if (x != y) return x < y ? -1 : 1;
        if (!x) return 0;
    }
}
static int SaoqiangWCAssetsZIPFileConflict(const char *a, const char *b) {
    while (*a && *b && SaoqiangWCAssetsZIPFold((unsigned char)*a) ==
           SaoqiangWCAssetsZIPFold((unsigned char)*b)) { ++a; ++b; }
    return !*a && (!*b || *b == '/');
}
static int SaoqiangWCAssetsZIPSameFile(const struct stat *a, const struct stat *b) {
    if (!S_ISREG(b->st_mode) || a->st_dev != b->st_dev || a->st_ino != b->st_ino || a->st_size != b->st_size) return 0;
#if defined(__APPLE__)
    return a->st_mtimespec.tv_sec == b->st_mtimespec.tv_sec && a->st_mtimespec.tv_nsec == b->st_mtimespec.tv_nsec &&
           a->st_ctimespec.tv_sec == b->st_ctimespec.tv_sec && a->st_ctimespec.tv_nsec == b->st_ctimespec.tv_nsec;
#else
    return a->st_mtim.tv_sec == b->st_mtim.tv_sec && a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
           a->st_ctim.tv_sec == b->st_ctim.tv_sec && a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
#endif
}
static int SaoqiangWCAssetsZIPSource(const char *path) {
    /* O_NONBLOCK makes rejection of a FIFO immediate instead of waiting for a writer. */
    return open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
}
static int SaoqiangWCAssetsZIPLocal(FILE *f, const char *name, uint16_t length) {
    return SaoqiangWCAssetsZIP32(f, 0x04034b50) && SaoqiangWCAssetsZIP16(f, 20) &&
        SaoqiangWCAssetsZIP16(f, 0x0808) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0x21) &&
        SaoqiangWCAssetsZIP32(f, 0) && SaoqiangWCAssetsZIP32(f, 0) && SaoqiangWCAssetsZIP32(f, 0) &&
        SaoqiangWCAssetsZIP16(f, length) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIPBytes(f, name, length);
}
static int SaoqiangWCAssetsZIPCentral(FILE *f, const char *name, const SaoqiangWCAssetsZIPFileInfo *info) {
    return SaoqiangWCAssetsZIP32(f, 0x02014b50) && SaoqiangWCAssetsZIP16(f, 20) && SaoqiangWCAssetsZIP16(f, 20) &&
        SaoqiangWCAssetsZIP16(f, 0x0808) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0x21) && SaoqiangWCAssetsZIP32(f, info->crc) &&
        SaoqiangWCAssetsZIP32(f, info->size) && SaoqiangWCAssetsZIP32(f, info->size) &&
        SaoqiangWCAssetsZIP16(f, info->nameLength) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) &&
        SaoqiangWCAssetsZIP32(f, 0) && SaoqiangWCAssetsZIP32(f, info->offset) &&
        SaoqiangWCAssetsZIPBytes(f, name, info->nameLength);
}
static int SaoqiangWCAssetsZIPCancelled(int (*cancelled)(void *), void *context) {
    return cancelled && cancelled(context);
}
int SaoqiangWCAssetsWriteZIPFiles(const char *output, const SaoqiangWCAssetsZIPFile *files,
                                size_t count, int (*cancelled)(void *), void *context,
                                char *error, size_t errorCapacity) {
    const char *message = "invalid ZIP input";
    SaoqiangWCAssetsZIPFileInfo *info = NULL;
    const SaoqiangWCAssetsZIPFile **sorted = NULL;
    FILE *f = NULL;
    int source = -1, created = 0, haveIdentity = 0;
    struct stat outputIdentity;
    uint64_t total = 0, archiveSize = 22;
    uint32_t at = 0, table[256];
    unsigned char buffer[64u * 1024u];
    if (error && errorCapacity) error[0] = 0;
    if (!output || !*output || (count && !files)) goto failed;
    if (count > SAOQIANG_WCASSETS_ZIP_MAX_FILES) { message = "ZIP entry limit exceeded"; goto failed; }
    if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
    info = calloc(count ? count : 1, sizeof(*info));
    sorted = calloc(count ? count : 1, sizeof(*sorted));
    if (!info || !sorted) { message = "allocation failed"; goto failed; }
    for (size_t i = 0; i < count; ++i) {
        if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
        if (!SaoqiangWCAssetsZIPName(files[i].name) || !SaoqiangWCAssetsZIPUTF8(files[i].name) ||
            !files[i].path || !*files[i].path) goto failed;
        info[i].nameLength = (uint16_t)strlen(files[i].name);
        sorted[i] = files + i;
    }
    qsort(sorted, count, sizeof(*sorted), SaoqiangWCAssetsZIPFileOrder);
    for (size_t i = 1; i < count; ++i) {
        if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
        if (SaoqiangWCAssetsZIPFileConflict(sorted[i - 1]->name, sorted[i]->name)) {
            message = "duplicate or conflicting ZIP path"; goto failed;
        }
    }
    free(sorted); sorted = NULL;
    for (size_t i = 0; i < count; ++i) {
        if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
        source = SaoqiangWCAssetsZIPSource(files[i].path);
        if (source < 0) { message = "cannot open ZIP source"; goto failed; }
        if (fstat(source, &info[i].snapshot) || !S_ISREG(info[i].snapshot.st_mode) || info[i].snapshot.st_size < 0) {
            message = "ZIP source must be a regular file"; goto failed;
        }
        if ((uint64_t)info[i].snapshot.st_size > SAOQIANG_WCASSETS_ZIP_MAX_FILE_SIZE) {
            message = "ZIP source size limit exceeded"; goto failed;
        }
        info[i].size = (uint32_t)info[i].snapshot.st_size;
        total += info[i].size;
        archiveSize += 92u + 2u * info[i].nameLength + (uint64_t)info[i].size;
        if (total > SAOQIANG_WCASSETS_ZIP_MAX_TOTAL_SIZE || archiveSize >= UINT32_MAX) {
            message = "ZIP total size limit exceeded"; goto failed;
        }
        int status = close(source); source = -1;
        if (status) { message = "closing ZIP source failed"; goto failed; }
    }
    if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
    int fd = open(output, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0) { message = "cannot create ZIP (output must not exist)"; goto failed; }
    created = 1;
    if (fstat(fd, &outputIdentity)) { close(fd); message = "cannot stat ZIP output"; goto failed; }
    haveIdentity = 1;
    f = fdopen(fd, "wb");
    if (!f) { close(fd); message = "cannot open ZIP stream"; goto failed; }
    for (unsigned i = 0; i < 256; ++i) {
        uint32_t crc = i;
        for (unsigned j = 0; j < 8; ++j) crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
        table[i] = crc;
    }
    for (size_t i = 0; i < count; ++i) {
        struct stat current;
        if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
        source = SaoqiangWCAssetsZIPSource(files[i].path);
        if (source < 0) { message = "cannot reopen ZIP source"; goto failed; }
        if (fstat(source, &current) || !SaoqiangWCAssetsZIPSameFile(&info[i].snapshot, &current)) goto changed;
        info[i].offset = at;
        if (!SaoqiangWCAssetsZIPLocal(f, files[i].name, info[i].nameLength)) goto io_failed;
        uint32_t remaining = info[i].size, crc = 0xffffffffu;
        while (remaining) {
            size_t amount = remaining < sizeof(buffer) ? remaining : sizeof(buffer);
            if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
            ssize_t n = read(source, buffer, amount);
            if (n < 0) {
                if (errno == EINTR) continue;
                message = "ZIP source read failed"; goto failed;
            }
            if (!n) goto changed;
            for (size_t j = 0; j < (size_t)n; ++j) crc = table[(crc ^ buffer[j]) & 0xffu] ^ (crc >> 8);
            if (!SaoqiangWCAssetsZIPBytes(f, buffer, (size_t)n)) goto io_failed;
            remaining -= (uint32_t)n;
        }
        /* Also detect growth, including empty files, without reading unbounded data. */
        for (;;) {
            if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
            ssize_t n = read(source, buffer, 1);
            if (n < 0 && errno == EINTR) continue;
            if (n < 0) { message = "ZIP source read failed"; goto failed; }
            if (n || fstat(source, &current) || !SaoqiangWCAssetsZIPSameFile(&info[i].snapshot, &current)) goto changed;
            break;
        }
        int status = close(source); source = -1;
        if (status) { message = "closing ZIP source failed"; goto failed; }
        info[i].crc = ~crc;
        if (!(SaoqiangWCAssetsZIP32(f, 0x08074b50) && SaoqiangWCAssetsZIP32(f, info[i].crc) &&
              SaoqiangWCAssetsZIP32(f, info[i].size) && SaoqiangWCAssetsZIP32(f, info[i].size))) goto io_failed;
        at += 46u + info[i].nameLength + info[i].size;
    }
    uint32_t central = at;
    for (size_t i = 0; i < count; ++i) {
        if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
        if (!SaoqiangWCAssetsZIPCentral(f, files[i].name, info + i)) goto io_failed;
        at += 46u + info[i].nameLength;
    }
    if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
    if (!(SaoqiangWCAssetsZIP32(f, 0x06054b50) && SaoqiangWCAssetsZIP16(f, 0) && SaoqiangWCAssetsZIP16(f, 0) &&
          SaoqiangWCAssetsZIP16(f, (uint16_t)count) && SaoqiangWCAssetsZIP16(f, (uint16_t)count) &&
          SaoqiangWCAssetsZIP32(f, at - central) && SaoqiangWCAssetsZIP32(f, central) && SaoqiangWCAssetsZIP16(f, 0))) goto io_failed;
    int status = fclose(f); f = NULL;
    if (status) { message = "closing ZIP failed"; goto failed; }
    if (SaoqiangWCAssetsZIPCancelled(cancelled, context)) goto cancel;
    free(info);
    return 0;
changed:
    message = "ZIP source changed during export"; goto failed;
cancel:
    message = "ZIP export cancelled"; goto failed;
io_failed:
    message = "ZIP write failed";
failed:
    if (source >= 0) close(source);
    if (f) fclose(f);
    if (created) {
        struct stat current;
        /* Do not remove a different file substituted at output during a callback. */
        if (!haveIdentity || (!lstat(output, &current) && current.st_dev == outputIdentity.st_dev &&
                             current.st_ino == outputIdentity.st_ino)) unlink(output);
    }
    free(sorted); free(info);
    if (error && errorCapacity) snprintf(error, errorCapacity, "%s", message);
    return -1;
}
