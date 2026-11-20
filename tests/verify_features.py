"""Verify raw original exports against provider/key oracles saved before export."""
import base64
import binascii
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import unicodedata
import zlib


CASES = {
    "missing-raw", "invalid-raw", "unsupported-format", "basename-case-collision",
    "basename-unicode-collision", "incompatible-index", "empty-index", "metadata-only",
    "theme-change", "keyset-change", "raw-bytes-change", "cancel", "bubblebox-disabled",
}
AVAILABLE_CASES = {
    "missing-raw", "invalid-raw", "unsupported-format", "basename-case-collision",
    "basename-unicode-collision", "incompatible-index", "bubblebox-disabled",
}
INCOMPLETE_CASES = {"missing-raw", "incompatible-index"}
PROVIDER_CASES = {
    "no-version-or-UUID-lock", "file-url-identity", "selected-info-path-fallback",
    "invalid-path-rejected", "missing-selected-path", "incompatible-ABI-not-called",
    "exception-contained", "missing-provider", "point-mode-and-entry-removed",
}
INFO_FILES = {"_export-info/manifest.json", "_export-info/issues.txt"}
# Written only when the provider hands over its whole pack as NSData, which the
# loader fixtures do and the container-less regression cases do not. The export
# declares the size it wrote, so this is checked rather than assumed.
CONTAINER_HEAD = "_export-info/container-head.bin"
# Written only when the pack's own file table could be read back by a plausible
# name and looked like text. Same rule as the head dump: the export declares the
# size it wrote, so presence and size are checked rather than assumed.
PACK_INDEX = "_export-info/pack-index.bin"
COUNT_FIELDS = (
    "expected", "written", "processed", "failed", "missing", "unsupported",
    "conflicts", "itemsVerified", "bytes",
)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def load_json(path):
    require(path.is_file() and not path.is_symlink(), f"missing/unsafe JSON: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def fold(name):
    return unicodedata.normalize("NFC", name).casefold()


def counts(summary, label, *, available, complete):
    require(isinstance(summary, dict), f"{label}: missing summary")
    for field in COUNT_FIELDS:
        value = summary.get(field)
        require(type(value) is int and value >= 0, f"{label}: invalid {field}: {value!r}")
    for field in ("available", "complete", "cancelled"):
        require(type(summary.get(field)) is bool, f"{label}: {field} must be boolean")
    require(summary["available"] is available, f"{label}: incorrect availability")
    require(summary["complete"] is complete, f"{label}: incorrect completeness")
    require(not summary.get("busy", False), f"{label}: worker still busy")
    require(summary["written"] <= summary["processed"] <= summary["expected"], f"{label}: inconsistent progress")
    require(summary["itemsVerified"] <= summary["written"], f"{label}: impossible verification count")
    if available:
        require(summary["written"] > 0 and summary["itemsVerified"] == summary["written"], f"{label}: available bytes not re-verified")
    if complete:
        require(summary["expected"] == summary["written"] == summary["processed"], f"{label}: incomplete enumeration")
        require(summary["failed"] == summary["missing"] == 0, f"{label}: completed with missing bytes")
        require(summary.get("expectedKnown") is True, f"{label}: completed with an unknown index")


def oracle_items(items, label):
    require(isinstance(items, list), f"{label}: oracle must be a list")
    result = {}
    for item in items:
        require(isinstance(item, dict), f"{label}: malformed oracle record")
        provider, key = item.get("provider"), item.get("key")
        require(provider in {"ThemeBox", "BubbleBox"} and isinstance(key, str) and key, f"{label}: invalid provider/key")
        identity = (provider, key)
        require(identity not in result and item.get("identity") == provider + "|" + key, f"{label}: duplicate/changed identity: {identity}")
        try:
            data = base64.b64decode(item["base64"], validate=True)
        except (ValueError, TypeError, KeyError, binascii.Error) as error:
            raise AssertionError(f"{label}: invalid independent bytes: {identity}") from error
        require(data, f"{label}: empty independent original: {identity}")
        basename = key.rsplit("/", 1)[-1]
        kind = ("png" if data.startswith(b"\x89PNG\r\n\x1a\n") else
                "gif" if data.startswith((b"GIF87a", b"GIF89a")) else
                "svg" if b"<svg" in data else "bin")
        name = basename if PurePosixPath(basename).suffix else basename + "." + kind
        require(item.get("name") == name and item.get("originalName") == basename and item.get("detected") == kind, f"{label}: independent original name changed: {identity}")
        result[identity] = (item, data)
    return result


def verify_folder(folder, expected, summary, label):
    require(folder.is_dir() and not folder.is_symlink(), f"{label}: no available directory")
    files, directories = set(), set()
    for path in folder.rglob("*"):
        require(not path.is_symlink(), f"{label}: symlink: {path}")
        relative = path.relative_to(folder).as_posix()
        if path.is_dir():
            directories.add(relative)
        else:
            require(path.is_file(), f"{label}: special export entry: {relative}")
            files.add(relative)
    manifest = load_json(folder / "_export-info/manifest.json")
    # A delivered directory cannot be cancelled. The report is serialized before
    # SQFinish adds its cancellation flag to the public completion summary.
    manifest_summary = dict(manifest, cancelled=manifest.get("cancelled", False))
    counts(manifest_summary, label + " manifest", available=True, complete=summary["complete"])
    for field in COUNT_FIELDS + ("available", "complete", "cancelled"):
        require(manifest_summary[field] == summary[field], f"{label}: manifest/completion {field} differs")
    issues = folder / "_export-info/issues.txt"
    require(issues.is_file() and not issues.is_symlink(), f"{label}: missing human diagnostic")
    text = issues.read_text(encoding="utf-8")
    require("\x00" not in text, f"{label}: binary issue report")
    if any(summary[field] for field in ("failed", "missing", "unsupported", "conflicts")) or not summary["complete"]:
        require(text.strip(), f"{label}: warnings have no human diagnostic")
    entries = manifest.get("items")
    require(isinstance(entries, list) and len(entries) == len(expected), f"{label}: omitted manifest entries")
    groups = Counter(fold(item["name"]) for item, _ in expected.values())
    seen, seen_files, used_dirs = set(), set(), {"_export-info"}
    roots, duplicates = Counter(), Counter()
    duplicate_numbers = set()
    for entry in entries:
        require(isinstance(entry, dict), f"{label}: malformed manifest entry")
        identity = (entry.get("provider"), entry.get("key"))
        require(identity in expected and identity not in seen, f"{label}: duplicate/foreign provider+key: {identity}")
        original, data = expected[identity]
        filename = entry.get("file")
        require(isinstance(filename, str) and filename, f"{label}: missing output filename")
        path = PurePosixPath(filename)
        require(not path.is_absolute() and path.as_posix() == filename and ".." not in path.parts and "\\" not in filename, f"{label}: unsafe filename: {filename}")
        require(entry.get("name") == original["name"] and path.name == original["name"], f"{label}: original basename/extension/case changed: {identity}")
        group = fold(original["name"])
        if len(path.parts) == 1:
            roots[group] += 1
        else:
            require(len(path.parts) == 3 and path.parts[0] == "_duplicates" and re.fullmatch(r"[0-9]{6}", path.parts[1]) and int(path.parts[1]) > 0, f"{label}: invalid duplicate layout: {filename}")
            require(groups[group] > 1, f"{label}: unique original needlessly moved: {identity}")
            require(path.parts[1] not in duplicate_numbers, f"{label}: duplicate folder reused")
            duplicate_numbers.add(path.parts[1])
            duplicates[group] += 1
            used_dirs.update({"_duplicates", "/".join(path.parts[:2])})
        require(fold(filename) not in seen_files, f"{label}: destinations still collide: {filename}")
        require(entry.get("original") is True and entry.get("snapshot") is False, f"{label}: resource is not original")
        require((folder / filename).read_bytes() == data, f"{label}: source bytes/provider differ: {identity}")
        require(type(entry.get("bytes")) is int and entry["bytes"] == len(data), f"{label}: wrong byte count: {identity}")
        require(entry.get("sha256") == hashlib.sha256(data).hexdigest(), f"{label}: wrong hash: {identity}")
        seen.add(identity)
        seen_files.add(fold(filename))
    # Manifest supplies a location only. Independent names and collision groups
    # decide the permitted layout; a self-consistent wrong layout must still fail.
    require(seen == set(expected), f"{label}: missing provider/key identities")
    for group, size in groups.items():
        require(roots[group] == 1 and duplicates[group] == size - 1, f"{label}: collision group lost root/originals: {group}")
    require(duplicate_numbers == {f"{i:06d}" for i in range(1, sum(duplicates.values()) + 1)}, f"{label}: non-sequential duplicate folders")
    expected_files = {entry["file"] for entry in entries} | INFO_FILES
    # The pack head dump is optional, so it is checked against what the export
    # says it wrote instead of being folded into INFO_FILES unconditionally.
    head_bytes = summary.get("containerHeadBytes", 0)
    require(type(head_bytes) is int and head_bytes >= 0, f"{label}: invalid containerHeadBytes")
    if head_bytes:
        expected_files.add(CONTAINER_HEAD)
    index_bytes = summary.get("packIndexBytes", 0)
    require(type(index_bytes) is int and index_bytes >= 0, f"{label}: invalid packIndexBytes")
    if index_bytes:
        expected_files.add(PACK_INDEX)
    # Apple filesystems may return a canonically equivalent Unicode spelling
    # during enumeration. Preserve case and all original manifest names, while
    # comparing filesystem paths in NFC; separate collision folders must remain.
    canonical_files = {unicodedata.normalize("NFC", name) for name in files}
    canonical_expected = {unicodedata.normalize("NFC", name) for name in expected_files}
    require(len(files) == len(expected_files) == len(canonical_files) == len(canonical_expected), f"{label}: lost/aliased filesystem entries")
    require(canonical_files == canonical_expected, f"{label}: missing/extra files: {canonical_files ^ canonical_expected}")
    head = folder / CONTAINER_HEAD
    if head_bytes:
        require(head.is_file() and not head.is_symlink() and head.stat().st_size == head_bytes, f"{label}: pack head dump missing or wrong size")
    else:
        require(not head.exists(), f"{label}: pack head dump written without being declared")
    pack_index = folder / PACK_INDEX
    if index_bytes:
        require(pack_index.is_file() and not pack_index.is_symlink() and pack_index.stat().st_size == index_bytes, f"{label}: pack index dump missing or wrong size")
        payload = pack_index.read_bytes()
        require(payload[:1] in (b"{", b"[", b"<") or payload.startswith(b"bplist00") or b"\x00" not in payload, f"{label}: pack index dump is not a table")
    else:
        require(not pack_index.exists(), f"{label}: pack index dump written without being declared")
    canonical_dirs = {unicodedata.normalize("NFC", name) for name in directories}
    require(len(canonical_dirs) == len(directories) and canonical_dirs == {unicodedata.normalize("NFC", name) for name in used_dirs}, f"{label}: unexpected grouping directories: {directories ^ used_dirs}")
    require(summary["written"] == summary["itemsVerified"] == len(expected), f"{label}: not all available originals verified")
    require(summary["bytes"] == sum(len(data) for _, data in expected.values()), f"{label}: resource byte total wrong")
    require(summary["conflicts"] == sum(size - 1 for size in groups.values()), f"{label}: resolved collision count wrong")
    return manifest


def validate_png(data, label):
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), f"{label}: not PNG")
    position, pixels, dimensions = 8, bytearray(), None
    while position < len(data):
        length = struct.unpack_from(">I", data, position)[0]
        kind = data[position + 4:position + 8]
        payload = data[position + 8:position + 8 + length]
        crc = struct.unpack_from(">I", data, position + 8 + length)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, f"{label}: invalid PNG CRC")
        if kind == b"IHDR":
            dimensions = struct.unpack_from(">II", payload)
        if kind == b"IDAT":
            pixels.extend(payload)
        position += length + 12
        if kind == b"IEND":
            break
    require(dimensions == (1, 1) and position == len(data) and zlib.decompress(pixels), f"{label}: PNG is not a tiny real original")


def verify(root):
    require((root / "features-done.txt").read_text(encoding="utf-8").strip() == "done", "feature checks did not finish")
    require(not (root / "capture-failed.txt").exists(), "native fixture reported failure")
    provider = load_json(root / "provider-checks.json")
    require(provider.get("status") == "passed" and provider.get("assertions", 0) >= 20, "provider identity checks failed")
    require(set(provider.get("cases", [])) == PROVIDER_CASES, "provider coverage changed")
    source = load_json(root / "expected-source.json")
    require(source.get("schema") == 2 and source.get("expected") == 1717, "invalid independent source schema/count")
    for field, value in {"themeBoxCount": 1714, "bubbleBoxCount": 3, "baseCount": 1706, "gifCount": 2, "indexCount": 1710}.items():
        require(source.get(field) == value, f"source fixture changed: {field}")
    require(source.get("diskOriginals") is False and source.get("themeBoxLoadBubble") is False and source.get("bubbleBoxEnabled") is True, "active source/display-state coverage changed")
    require(set(source.get("sources", [])) == {"themeFiles", "_fileIndex", "themeFileMap", "diyFileMap", "ThemeBox.bubbleFiles", "BubbleBox.bubbleFiles", "BubbleBox.bubbleFileMap"}, "loader union source missing")
    expected = oracle_items(source.get("items"), "happy oracle")
    require(len(expected) == 1717 and Counter(identity[0] for identity in expected) == {"ThemeBox": 1714, "BubbleBox": 3}, "combined source identities changed")
    theme = {key: value for (provider, key), value in expected.items() if provider == "ThemeBox"}
    gif_items = [(key, value[1]) for key, value in theme.items() if value[0]["detected"] == "gif"]
    require(len(gif_items) == 2, "two real GIF originals missing")
    for key, data in gif_items:
        require(struct.unpack_from("<HH", data, 6) == (1, 1) and data.endswith(b";"), f"{key}: invalid 1-pixel GIF")
    pngs = [data for item, data in theme.values() if item["detected"] == "png"]
    require(len(pngs) == 3, "known original PNG coverage changed")
    for data in pngs:
        validate_png(data, "happy PNG")
    aliases = source.get("caseAliases")
    require(isinstance(aliases, list) and len(aliases) == 6, "six case-only alias pairs missing")
    alias_keys = set()
    for pair in aliases:
        require(isinstance(pair, list) and len(pair) == 2 and all(key in theme for key in pair), "invalid case alias pair")
        first, second = pair
        require(first != second and theme[first][0]["name"] != theme[second][0]["name"] and fold(theme[first][0]["name"]) == fold(theme[second][0]["name"]), "pair is not a case-only basename collision")
        require(theme[first][1] != theme[second][1], "alias byte identity test is vacuous")
        alias_keys.add(second)
    require(len(alias_keys) == 6 and len(theme) - len(alias_keys) - len(gif_items) == 1706, "1714/1706 diagnostic reproduction changed")
    overlap = source.get("overlapKey")
    require(overlap == "loadedTheme/PNG/ChatRoom_Bubble_HB_Sender_Handled@2x.png", "shared exact provider key changed")
    require(expected[("ThemeBox", overlap)][1] != expected[("BubbleBox", overlap)][1], "providers must expose different bytes for identical key")
    require(("ThemeBox", source.get("loadedBubbleKey")) in expected, "ThemeBox loaded bubble disappeared with loadBubble=NO")
    require(any(not PurePosixPath(key).suffix for key in theme), "extensionless source coverage missing")
    summary = load_json(root / "theme-full-result.json")
    counts(summary, "happy completion", available=True, complete=True)
    require(summary["expected"] == summary["written"] == 1717 and summary["conflicts"] == 7 and not summary["cancelled"], "happy originals/collisions changed")
    verify_folder(root / "test-theme-folder", expected, summary, "happy")

    regression = load_json(root / "failures.json")
    require(regression.get("status") == "passed" and isinstance(regression.get("cases"), list), "regression cases did not finish")
    records = {record["case"]: record for record in regression["cases"]}
    require(len(records) == len(regression["cases"]) and set(records) == CASES, "13-case coverage changed")
    folders = root / "case-folders"
    require(folders.is_dir() and not folders.is_symlink(), "case directories were not copied by ui-smoke")
    require({path.name for path in folders.iterdir()} == AVAILABLE_CASES, "wrong available case folders")
    for name, record in records.items():
        available = name in AVAILABLE_CASES
        complete = available and name not in INCOMPLETE_CASES
        result = record.get("summary")
        counts(result, name, available=available, complete=complete)
        require(record.get("directoryReturned") is available, f"{name}: incorrect directory result")
        require(isinstance(record.get("error"), str) and (not record["error"] if available else bool(record["error"].strip())), f"{name}: incorrect completion error")
        require(result["cancelled"] is (name == "cancel"), f"{name}: incorrect cancellation state")
        case_expected = oracle_items(record.get("oracle"), name)
        if available:
            verify_folder(folders / name, case_expected, result, name)
            require(result["failed"] == 0, f"{name}: saved originals counted as failures")
            for item, _ in case_expected.values():
                value = record.get("reads", {}).get(item["identity"])
                require(type(value) is int and value >= 2, f"{name}: original reread skipped after warning/missing/index issue")
        if name.endswith("change"):
            require(record.get("mutationApplied") is True and record.get("rawCalls", 0) > 0, f"{name}: mutation did not run")
        if name == "raw-bytes-change":
            require(record.get("rawCalls", 0) >= 2, "changed original bytes not re-fetched")
        if name == "missing-raw":
            require(len(case_expected) == result["written"] == result["missing"] == 1 and result["expected"] == result["processed"] == 2, "mixed missing raw availability/counts wrong")
        elif name == "invalid-raw":
            require(len(case_expected) == result["written"] == 4 and result["unsupported"] >= 2, "non-image originals/extensions were dropped")
            require({item["name"] for item, _ in case_expected.values()} == {"broken.PNG", "no-extension.bin", "png-without-ext.png", "actualPNG.SvG"}, "original extension/case/detected fallback changed")
        elif name == "unsupported-format":
            require(len(case_expected) == result["written"] == 1 and result["unsupported"] >= 1, "KTX original was dropped")
            require(next(iter(case_expected.values()))[1].startswith(b"\xabKTX 11\xbb\r\n\x1a\n"), "KTX fixture magic invalid")
        elif name.startswith("basename-"):
            require(len(case_expected) == result["written"] == 2 and result["conflicts"] == 1, f"{name}: collision was not resolved")
        elif name == "incompatible-index":
            require(result.get("expectedKnown") is False and result["written"] == 1, "unknown index discarded available file or claimed complete")
        elif name == "bubblebox-disabled":
            require(record.get("bubbleRawCalls") == record.get("bubbleSourceCalls") == 0 and len(case_expected) == result["expected"] == 1 and all(identity[0] == "ThemeBox" for identity in case_expected), "disabled BubbleBox enumerated/exported")
    print("NATIVE_FEATURE_CHECK_PASSED: 1714 ThemeBox + 3 independent BubbleBox exact originals; 2 GIF, 7 resolved collisions; flat names/provider-key byte oracle; 13 availability/cancellation/source regressions")


if __name__ == "__main__":
    require(len(sys.argv) == 2, "usage: verify_features.py <copied Documents artifacts>")
    verify(Path(sys.argv[1]))
