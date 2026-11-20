#import <Foundation/Foundation.h>
#import <string.h>

// ASCII-only string helpers for the per-image-load hot path. The predicates in
// SaoqiangWCAssetsStore.m / SaoqiangWCAssetsInspector.m run for every hooked
// image load, so they must not allocate NSString objects. Byte comparison is
// equivalent for the ASCII needles used here; bytes >= 0x80 are copied verbatim
// so a UTF-8 name is never split by lowercasing.
// A compile-time constant so callers can declare plain stack buffers.
enum { SQNameCapacity = 720 };

NS_INLINE size_t SQNameLowerCopy(const char *source, size_t length, char *destination) {
    for (size_t i = 0; i < length; ++i) {
        unsigned char c = (unsigned char)source[i];
        destination[i] = (c >= 'A' && c <= 'Z') ? (char)(c + 32) : (char)c;
    }
    destination[length] = 0; return length;
}
NS_INLINE BOOL SQNameContains(const char *text, size_t length, const char *needle) {
    size_t n = strlen(needle); if (!n || n > length) return NO;
    for (size_t i = 0; i + n <= length; ++i) if (!memcmp(text + i, needle, n)) return YES;
    return NO;
}
NS_INLINE BOOL SQNameHasPrefix(const char *text, size_t length, const char *prefix) {
    size_t n = strlen(prefix); return n <= length && !memcmp(text, prefix, n);
}
NS_INLINE BOOL SQNameHasSuffix(const char *text, size_t length, const char *suffix) {
    size_t n = strlen(suffix); return n <= length && !memcmp(text + length - n, suffix, n);
}
// Last path component only; trailing separators are ignored like -lastPathComponent.
NS_INLINE const char *SQNameLastComponent(const char *path, size_t length, size_t *outLength) {
    while (length && path[length - 1] == '/') --length;
    size_t start = length;
    while (start && path[start - 1] != '/') --start;
    *outLength = length - start; return path + start;
}
// Length of the extension after the last dot, 0 when there is no usable one.
NS_INLINE size_t SQNameExtensionLength(const char *text, size_t length) {
    for (size_t i = length; i > 0; --i) if (text[i - 1] == '.') return length - i;
    return 0;
}
NS_INLINE BOOL SQNameHasImageExtension(const char *text, size_t length) {
    size_t n = SQNameExtensionLength(text, length);
    if (!n) return NO;
    const char *ext = text + length - n;
    return (n == 3 && (!memcmp(ext, "png", 3) || !memcmp(ext, "svg", 3) || !memcmp(ext, "jpg", 3))) ||
           (n == 4 && !memcmp(ext, "jpeg", 4));
}
NS_INLINE size_t SQNameStripSuffixes(const char *text, size_t length, char *destination) {
    static const char *const suffixes[] = {"@3x", "@2x", "~iphone", "~ipad"};
    size_t written = 0;
    for (size_t i = 0; i < length;) {
        size_t matched = 0;
        for (size_t s = 0; s < sizeof(suffixes) / sizeof(*suffixes); ++s) {
            size_t n = strlen(suffixes[s]);
            if (i + n <= length && !memcmp(text + i, suffixes[s], n)) { matched = n; break; }
        }
        if (matched) { i += matched; continue; }
        destination[written++] = text[i++];
    }
    destination[written] = 0; return written;
}
NS_INLINE BOOL SQNameBubblePrefix(const char *text, size_t length) {
    static const char *const prefixes[] = {
        "chatroom_bubble_", "chatting_bg_", "chatting_bkg_", "chatbubble_",
        "message_bubble_", "sendertextnodebkg", "receivertextnodebkg"
    };
    for (size_t i = 0; i < sizeof(prefixes) / sizeof(*prefixes); ++i)
        if (SQNameHasPrefix(text, length, prefixes[i])) return YES;
    return NO;
}
NS_INLINE BOOL SQNameExcluded(const char *text, size_t length) {
    static const char *const parts[] = {
        "avatar", "headimg", "defaulthead", "portrait", "thumbnail", "expression",
        "sticker", "wallpaper", "snapshot", "screenshot", "unnamed"
    };
    for (size_t i = 0; i < sizeof(parts) / sizeof(*parts); ++i)
        if (SQNameContains(text, length, parts[i])) return YES;
    return NO;
}
// Class names appear once per visited view; avoid -NSStringFromClass allocations.
NS_INLINE BOOL SQNameClassExcluded(const char *className, const char *const *parts) {
    if (!className) return NO;
    char buffer[160]; size_t length = strlen(className);
    if (length >= sizeof(buffer)) return NO;
    SQNameLowerCopy(className, length, buffer);
    for (size_t i = 0; parts[i]; ++i) if (SQNameContains(buffer, length, parts[i])) return YES;
    return NO;
}
