#!/usr/bin/env python3
"""Run: python3 tests/verify_stream.py /absolute/path/to/zip_stream

The executable is built from tests/zip_stream.c and SaoqiangWCAssetsZIP.c.
Fixtures and output live in a temporary directory and are removed afterwards.
Only Python's standard library is required; file formats are synthetic bytes.
"""
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib

CHUNK = 65536
LARGE_BLOCK = bytes(range(256)) * 256


def fixture_names():
    names = [
        f"icons/group{i % 17:02d}/item{i:04d}.{'svg' if i % 2 else 'png'}"
        for i in range(1600)
    ]
    return names + ["气泡/彩色气泡@3x.png", "empty/zero.bin", "large/payload.bin"]


def write_large(path):
    with path.open("wb") as stream:
        for _ in range(32):
            stream.write(LARGE_BLOCK)


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK), b""):
            result.update(chunk)
    return result.digest()


def create_fixtures(root):
    names = fixture_names()
    for i, name in enumerate(names):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if i < 1600:
            payload = (
                f'<svg xmlns="http://www.w3.org/2000/svg"><text>{i}</text></svg>'.encode()
                if i % 2 else b"\x89PNG\r\n\x1a\n" + struct.pack("<I", i) + bytes(range(256)) * (1 + i % 9)
            )
            path.write_bytes(payload)
        elif i == 1600:
            path.write_bytes(b"\x00\xff\x01\x00" + "彩色气泡 🎨".encode("utf-8"))
        elif i == 1601:
            path.touch()
        else:
            write_large(path)
    (root / "sentinel.txt").write_bytes(b"KEEP-ME\n")
    (root / "output-link.zip").symlink_to("sentinel.txt")
    (root / "source-link.bin").symlink_to(names[0])
    (root / "source-directory").mkdir()
    os.mkfifo(root / "source-fifo")
    for filename, size in (("oversize.bin", 64 * 1024 * 1024 + 1), ("limit64.bin", 64 * 1024 * 1024)):
        with (root / filename).open("wb") as stream:
            stream.truncate(size)  # Sparse files; the C test rejects these before copying.
    for filename in ("mutable-size.bin", "mutable-time.bin", "mutable-inode.bin", "replacement.bin"):
        write_large(root / filename)
    original = (root / "mutable-inode.bin").stat()
    os.utime(root / "replacement.bin", ns=(original.st_atime_ns, original.st_mtime_ns))
    return names, {name: digest(root / name) for name in names}


def verify_archive(output, root, names, original_hashes):
    with zipfile.ZipFile(output) as archive, output.open("rb") as raw:
        assert archive.namelist() == names, "entry order or exact UTF-8 path changed"
        assert len(archive.infolist()) == 1603
        for entry in archive.infolist():
            assert entry.compress_type == zipfile.ZIP_STORED
            assert entry.flag_bits & 0x800, "missing UTF-8 flag"
            assert entry.flag_bits & 0x008, "missing data-descriptor flag"
            assert not entry.flag_bits & 0x001, "unexpected encryption"
            assert entry.file_size == entry.compress_size
            raw.seek(entry.header_offset)
            header = struct.unpack("<IHHHHHIIIHH", raw.read(30))
            assert header[0] == 0x04034B50 and header[2] == entry.flag_bits
            assert raw.read(header[9]) == entry.filename.encode("utf-8")
            raw.seek(header[10] + entry.file_size, os.SEEK_CUR)
            descriptor = struct.unpack("<IIII", raw.read(16))
            assert descriptor == (0x08074B50, entry.CRC, entry.file_size, entry.file_size)
            crc = length = 0
            with archive.open(entry) as actual, (root / entry.filename).open("rb") as expected:
                while True:
                    chunk = actual.read(CHUNK)
                    assert chunk == expected.read(CHUNK), entry.filename
                    if not chunk:
                        break
                    length += len(chunk)
                    crc = zlib.crc32(chunk, crc)
            assert length == entry.file_size
            assert crc & 0xFFFFFFFF == entry.CRC
            assert digest(root / entry.filename) == original_hashes[entry.filename], "source modified"
        assert archive.getinfo("empty/zero.bin").file_size == 0
        assert archive.getinfo("large/payload.bin").file_size == 2 * 1024 * 1024
    with zipfile.ZipFile(root / "empty.zip") as empty:
        assert empty.namelist() == []
        assert empty.testzip() is None
    assert (root / "sentinel.txt").read_bytes() == b"KEEP-ME\n"
    assert (root / "output-link.zip").is_symlink()
    assert not (root / "negative.zip").exists()


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    executable = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="saoqiang-zip-stream-") as temporary:
        root = Path(temporary)
        names, hashes = create_fixtures(root)
        output = root / "stream.zip"
        subprocess.run([str(executable), str(root), str(output)], check=True, timeout=120, cwd=root)
        verify_archive(output, root, names, hashes)
    print("Python independent-reader verification: 1603 names, CRCs, payloads, UTF-8, empty files, "
          "2 MiB streaming and source preservation passed")


if __name__ == "__main__":
    main()
