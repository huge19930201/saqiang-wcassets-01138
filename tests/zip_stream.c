#if defined(__APPLE__) && !defined(_DARWIN_C_SOURCE)
#define _DARWIN_C_SOURCE 1
#endif
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#include "SaoqiangWCAssetsZIP.h"
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define FIXTURE_COUNT 1603u
#define CHECK(test) do { if (!(test)) { \
    fprintf(stderr, "line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static char *join(const char *root, const char *name) {
    size_t length = strlen(root) + strlen(name) + 2;
    char *path = malloc(length);
    CHECK(path != NULL);
    CHECK(snprintf(path, length, "%s/%s", root, name) > 0);
    return path;
}
static int exists(const char *path) {
    struct stat value;
    if (!lstat(path, &value)) return 1;
    CHECK(errno == ENOENT);
    return 0;
}
static void expect_failure(const char *output, const SaoqiangWCAssetsZIPFile *files,
                           size_t count, int (*cancelled)(void *), void *context,
                           const char *reason) {
    char error[256] = {0};
    CHECK(!exists(output));
    CHECK(SaoqiangWCAssetsWriteZIPFiles(output, files, count, cancelled, context,
                                      error, sizeof(error)) != 0);
    CHECK(error[0] != 0);
    if (reason && !strstr(error, reason)) {
        fprintf(stderr, "expected '%s', got '%s'\n", reason, error);
        exit(1);
    }
    CHECK(!exists(output));
}
static int cancel_immediately(void *context) {
    unsigned *calls = context;
    ++*calls;
    return 1;
}

typedef struct {
    const char *output;
    const char *source;
    const char *replacement;
    int mode; /* 0: cancel, 1: size, 2: nanosecond mtime, 3: replace before reopen */
    unsigned calls, triggered;
    off_t partialSize;
} Callback;

static int during_export(void *context) {
    Callback *state = context;
    struct stat output;
    ++state->calls;
    if (state->triggered || stat(state->output, &output)) return 0;
    if (state->mode != 3 && output.st_size < 65536) return 0;
    state->triggered = 1;
    state->partialSize = output.st_size;
    if (!state->mode) return 1;
    if (state->mode == 3) {
        CHECK(rename(state->replacement, state->source) == 0);
        return 0;
    }
    int fd = open(state->source, O_WRONLY);
    CHECK(fd >= 0);
    if (state->mode == 1) {
        CHECK(ftruncate(fd, 7) == 0);
    } else {
        struct stat before;
        struct timespec times[2];
        CHECK(fstat(fd, &before) == 0);
#if defined(__APPLE__)
        times[0] = before.st_atimespec;
        times[1] = before.st_mtimespec;
#else
        times[0] = before.st_atim;
        times[1] = before.st_mtim;
#endif
        /* Change only the sub-second part; a seconds-only comparison misses it. */
        times[1].tv_nsec = times[1].tv_nsec < 500000000L ? 800000000L : 100000000L;
        CHECK(futimens(fd, times) == 0);
    }
    CHECK(close(fd) == 0);
    return 0;
}

static void check_sentinel(const char *path) {
    char bytes[16] = {0};
    FILE *f = fopen(path, "rb");
    CHECK(f != NULL);
    CHECK(fread(bytes, 1, sizeof(bytes), f) == 8);
    CHECK(!memcmp(bytes, "KEEP-ME\n", 8));
    CHECK(fclose(f) == 0);
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s FIXTURE_DIRECTORY OUTPUT_ZIP\n", argv[0]);
        return 2;
    }
    const char *root = argv[1], *output = argv[2];
    char error[256];
    SaoqiangWCAssetsZIPFile *files = calloc(FIXTURE_COUNT, sizeof(*files));
    CHECK(files != NULL);
    for (size_t i = 0; i < FIXTURE_COUNT; ++i) {
        char name[128];
        if (i < 1600) {
            CHECK(snprintf(name, sizeof(name), "icons/group%02u/item%04u.%s",
                           (unsigned)(i % 17), (unsigned)i, i % 2 ? "svg" : "png") > 0);
        } else {
            const char *special[] = {"气泡/彩色气泡@3x.png", "empty/zero.bin", "large/payload.bin"};
            CHECK(snprintf(name, sizeof(name), "%s", special[i - 1600]) > 0);
        }
        files[i].name = strdup(name);
        CHECK(files[i].name != NULL);
        files[i].path = join(root, name);
    }
    CHECK(!exists(output));
    if (SaoqiangWCAssetsWriteZIPFiles(output, files, FIXTURE_COUNT, NULL, NULL,
                                    error, sizeof(error))) {
        fprintf(stderr, "write failed: %s\n", error);
        return 1;
    }
    CHECK(error[0] == 0);
    CHECK(SaoqiangWCAssetsWriteZIPFiles(output, files, FIXTURE_COUNT, NULL, NULL,
                                      error, sizeof(error)) != 0);
    CHECK(strstr(error, "must not exist") != NULL);

    char *negative = join(root, "negative.zip");
    char *sentinel = join(root, "sentinel.txt");
    check_sentinel(sentinel);
    CHECK(SaoqiangWCAssetsWriteZIPFiles(sentinel, files, 1, NULL, NULL,
                                      error, sizeof(error)) != 0);
    check_sentinel(sentinel);
    char *outputLink = join(root, "output-link.zip");
    CHECK(SaoqiangWCAssetsWriteZIPFiles(outputLink, files, 1, NULL, NULL,
                                      error, sizeof(error)) != 0);
    struct stat linkInfo;
    CHECK(lstat(outputLink, &linkInfo) == 0 && S_ISLNK(linkInfo.st_mode));
    check_sentinel(sentinel);

    const char *bad[] = {"../escape", "/absolute", "a/../../x", "a//x", "./x",
        "a/./b", "a\\b", "C:x", "a/", "", "a\nfile", "\xc0\xaf", "\xed\xa0\x80", "\xf4\x90\x80\x80"};
    for (size_t i = 0; i < sizeof(bad) / sizeof(bad[0]); ++i) {
        SaoqiangWCAssetsZIPFile file = {bad[i], files[0].path};
        expect_failure(negative, &file, 1, NULL, NULL, NULL);
    }
    SaoqiangWCAssetsZIPFile duplicates[] = {{"icons/A.png", files[0].path}, {"icons/A.png", files[1].path}};
    expect_failure(negative, duplicates, 2, NULL, NULL, "conflicting");
    duplicates[1].name = "ICONS/a.PNG";
    expect_failure(negative, duplicates, 2, NULL, NULL, "conflicting");
    SaoqiangWCAssetsZIPFile hierarchy[] = {{"a", files[0].path}, {"a-else", files[0].path}, {"A/b", files[0].path}};
    expect_failure(negative, hierarchy, 3, NULL, NULL, "conflicting");
    expect_failure(negative, NULL, 1, NULL, NULL, NULL);
    expect_failure(negative, files, SAOQIANG_WCASSETS_ZIP_MAX_FILES + 1u, NULL, NULL, "limit");
    SaoqiangWCAssetsZIPFile invalid = {NULL, files[0].path};
    expect_failure(negative, &invalid, 1, NULL, NULL, NULL);
    invalid.name = "valid"; invalid.path = NULL;
    expect_failure(negative, &invalid, 1, NULL, NULL, NULL);

    const char *rejectedSources[] = {"missing.bin", "source-link.bin", "source-directory", "source-fifo", "oversize.bin"};
    for (size_t i = 0; i < sizeof(rejectedSources) / sizeof(rejectedSources[0]); ++i) {
        char *path = join(root, rejectedSources[i]);
        SaoqiangWCAssetsZIPFile file = {"valid.bin", path};
        expect_failure(negative, &file, 1, NULL, NULL, NULL);
        free(path);
    }
    char *missing = join(root, "missing.bin");
    SaoqiangWCAssetsZIPFile missingLast[] = {files[0], {"missing.bin", missing}};
    expect_failure(negative, missingLast, 2, NULL, NULL, "source");
    free(missing);

    char *limitPath = join(root, "limit64.bin");
    SaoqiangWCAssetsZIPFile tooMuch[17];
    char limitNames[17][24];
    for (size_t i = 0; i < 17; ++i) {
        CHECK(snprintf(limitNames[i], sizeof(limitNames[i]), "limit%02u.bin", (unsigned)i) > 0);
        tooMuch[i] = (SaoqiangWCAssetsZIPFile){limitNames[i], limitPath};
    }
    expect_failure(negative, tooMuch, 17, NULL, NULL, "total size");
    free(limitPath);

    unsigned calls = 0;
    expect_failure(negative, files, 1, cancel_immediately, &calls, "cancelled");
    CHECK(calls == 1);
    Callback cancel = {negative, files[1602].path, NULL, 0, 0, 0, 0};
    expect_failure(negative, files + 1602, 1, during_export, &cancel, "cancelled");
    CHECK(cancel.triggered && cancel.partialSize >= 65536 && cancel.calls > 1);

    const char *mutableNames[] = {"mutable-size.bin", "mutable-time.bin", "mutable-inode.bin"};
    char *replacement = join(root, "replacement.bin");
    for (size_t i = 0; i < 3; ++i) {
        char *path = join(root, mutableNames[i]);
        SaoqiangWCAssetsZIPFile file = {"mutable.bin", path};
        Callback mutation = {negative, path, replacement, (int)i + 1, 0, 0, 0};
        expect_failure(negative, &file, 1, during_export, &mutation, "changed");
        CHECK(mutation.triggered);
        free(path);
    }
    free(replacement);

    char *empty = join(root, "empty.zip");
    CHECK(SaoqiangWCAssetsWriteZIPFiles(empty, NULL, 0, NULL, NULL, error, sizeof(error)) == 0);
    CHECK(error[0] == 0);
    char tinyError[1] = {'x'};
    CHECK(SaoqiangWCAssetsWriteZIPFiles(negative, NULL, 1, NULL, NULL, tinyError, sizeof(tinyError)) != 0);
    CHECK(tinyError[0] == 0);
    CHECK(SaoqiangWCAssetsWriteZIPFiles(negative, NULL, 1, NULL, NULL, NULL, 0) != 0);
    CHECK(!exists(negative));
    for (size_t i = 0; i < FIXTURE_COUNT; ++i) {
        free((void *)files[i].name);
        free((void *)files[i].path);
    }
    free(files); free(negative); free(sentinel); free(outputLink); free(empty);
    puts("stream ZIP: 1603 files, overwrite, validation, limits, cancellation and source changes passed");
    return 0;
}
