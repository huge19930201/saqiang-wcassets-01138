#ifndef SAOQIANG_WCASSETS_ZIP_H
#define SAOQIANG_WCASSETS_ZIP_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Pointers must remain valid for the synchronous call. UTF-8 relative names only. */
typedef struct {
    const char *name;
    const void *data;
    size_t size;
} SaoqiangWCAssetsZIPEntry;
/* Creates a new ZIP32 (stored method, UTF-8), returning 0 on success.
   Refuses overwrite and path traversal; partial output is removed on failure. */
int SaoqiangWCAssetsWriteZIP(const char *path, const SaoqiangWCAssetsZIPEntry *entries,
                           size_t count, char *error, size_t errorCapacity);
/* Streaming entry: neither names, paths nor source contents may be changed by
   the caller until the synchronous call returns. Empty regular files are valid. */
typedef struct {
    const char *name;
    const char *path;
} SaoqiangWCAssetsZIPFile;
#define SAOQIANG_WCASSETS_ZIP_MAX_FILES 20000u
#define SAOQIANG_WCASSETS_ZIP_MAX_FILE_SIZE (64u * 1024u * 1024u)
#define SAOQIANG_WCASSETS_ZIP_MAX_TOTAL_SIZE (1024u * 1024u * 1024u)
/* ZIP32, stored, UTF-8, with data descriptors; at most 64 KiB of payload is
   buffered. Limits above apply to this file API only (total is source bytes).
   Validates all names and opens/stats all sources before creating output.
   Rejects unsafe/malformed UTF-8 names, ASCII case-insensitive duplicates and
   file/directory conflicts; Unicode bytes are preserved without normalization
   or non-ASCII case folding. O_NOFOLLOW rejects final-component symlinks.
   Sources must be regular files and retain device/inode/size/mtime/ctime,
   including nanoseconds, from preflight through the end of their read.
   cancelled may be NULL; otherwise nonzero cancels. It is called during
   preflight, before each read (including retries), and during finalization.
   Returns 0 on success, -1 on error/cancellation. Never overwrites output;
   removes only output created by this call on failure. error may be NULL. */
int SaoqiangWCAssetsWriteZIPFiles(const char *output, const SaoqiangWCAssetsZIPFile *files,
                                size_t count, int (*cancelled)(void *), void *context,
                                char *error, size_t errorCapacity);
#ifdef __cplusplus
}
#endif
#endif
