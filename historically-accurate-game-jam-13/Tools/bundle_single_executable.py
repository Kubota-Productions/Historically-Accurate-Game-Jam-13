#!/usr/bin/env python3
"""Bundle a Godot export directory (executable + FMOD shared libraries) into a true standalone single executable."""

from __future__ import annotations

import argparse
import hashlib
import os
import pathlib
import shutil
import stat
import struct
import subprocess
import sys
import tempfile

MAGIC = 0x4A474148  # 'HAGJ' in little-endian

STUB_C_SOURCE = r"""
#define _FILE_OFFSET_BITS 64
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define HAGJ_MAGIC 0x4A474148U

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <direct.h>
#include <io.h>

static void ensure_parent_dirs_w(const wchar_t *file_path) {
    wchar_t buf[32768];
    wcsncpy(buf, file_path, 32767);
    buf[32767] = L'\0';
    for (wchar_t *p = buf; *p; ++p) {
        if (*p == L'/' || *p == L'\\') {
            wchar_t saved = *p;
            *p = L'\0';
            if (wcslen(buf) > 0 && buf[wcslen(buf) - 1] != L':') {
                CreateDirectoryW(buf, NULL);
            }
            *p = saved;
        }
    }
}

static const wchar_t *skip_program_name_w(const wchar_t *cmdline) {
    const wchar_t *p = cmdline;
    while (*p == L' ' || *p == L'\t') ++p;
    if (*p == L'"') {
        ++p;
        while (*p && *p != L'"') ++p;
        if (*p == L'"') ++p;
    } else {
        while (*p && *p != L' ' && *p != L'\t') ++p;
    }
    return p;
}

int main(void) {
    wchar_t self_path[32768];
    DWORD len = GetModuleFileNameW(NULL, self_path, 32768);
    if (len == 0 || len >= 32768) return 101;

    FILE *fp = _wfopen(self_path, L"rb");
    if (!fp) return 102;

    if (_fseeki64(fp, -20, SEEK_END) != 0) { fclose(fp); return 103; }
    uint64_t payload_offset = 0;
    uint64_t payload_hash = 0;
    uint32_t magic = 0;
    if (fread(&payload_offset, 8, 1, fp) != 1 ||
        fread(&payload_hash, 8, 1, fp) != 1 ||
        fread(&magic, 4, 1, fp) != 1 ||
        magic != HAGJ_MAGIC) {
        fclose(fp);
        return 104;
    }

    if (_fseeki64(fp, (__int64)payload_offset, SEEK_SET) != 0) { fclose(fp); return 105; }

    uint32_t entry_len = 0;
    if (fread(&entry_len, 4, 1, fp) != 1 || entry_len == 0 || entry_len > 4096) { fclose(fp); return 106; }
    char *entry_utf8 = (char *)calloc(entry_len + 1, 1);
    if (fread(entry_utf8, 1, entry_len, fp) != entry_len) { fclose(fp); return 107; }

    uint32_t file_count = 0;
    if (fread(&file_count, 4, 1, fp) != 1) { fclose(fp); return 108; }

    wchar_t temp_base[32768];
    DWORD tlen = GetTempPathW(32768, temp_base);
    if (tlen == 0 || tlen >= 32768) { fclose(fp); return 109; }

    wchar_t extract_dir[32768];
    _snwprintf(extract_dir, 32767, L"%shagj13_%016llx", temp_base, (unsigned long long)payload_hash);
    extract_dir[32767] = L'\0';

    wchar_t ready_marker[32768];
    _snwprintf(ready_marker, 32767, L"%s\\.ready", extract_dir);
    ready_marker[32767] = L'\0';

    if (GetFileAttributesW(ready_marker) == INVALID_FILE_ATTRIBUTES) {
        CreateDirectoryW(extract_dir, NULL);
        const size_t chunk_sz = 1024 * 1024;
        uint8_t *buf = (uint8_t *)malloc(chunk_sz);
        if (!buf) { fclose(fp); return 110; }

        for (uint32_t i = 0; i < file_count; ++i) {
            uint8_t kind = 0;
            uint32_t path_len = 0;
            uint64_t data_len = 0;
            if (fread(&kind, 1, 1, fp) != 1 ||
                fread(&path_len, 4, 1, fp) != 1 ||
                path_len == 0 || path_len > 4096) {
                free(buf); fclose(fp); return 111;
            }
            char *rel_utf8 = (char *)calloc(path_len + 1, 1);
            if (fread(rel_utf8, 1, path_len, fp) != path_len ||
                fread(&data_len, 8, 1, fp) != 1) {
                free(rel_utf8); free(buf); fclose(fp); return 112;
            }

            wchar_t rel_w[4096];
            MultiByteToWideChar(CP_UTF8, 0, rel_utf8, -1, rel_w, 4096);
            free(rel_utf8);
            for (wchar_t *p = rel_w; *p; ++p) {
                if (*p == L'/') *p = L'\\';
            }

            wchar_t dest_path[32768];
            _snwprintf(dest_path, 32767, L"%s\\%s", extract_dir, rel_w);
            dest_path[32767] = L'\0';
            ensure_parent_dirs_w(dest_path);

            FILE *out = _wfopen(dest_path, L"wb");
            if (!out) { free(buf); fclose(fp); return 113; }
            uint64_t remaining = data_len;
            while (remaining > 0) {
                size_t to_read = remaining > chunk_sz ? chunk_sz : (size_t)remaining;
                if (fread(buf, 1, to_read, fp) != to_read) {
                    fclose(out); free(buf); fclose(fp); return 114;
                }
                if (fwrite(buf, 1, to_read, out) != to_read) {
                    fclose(out); free(buf); fclose(fp); return 115;
                }
                remaining -= to_read;
            }
            fclose(out);
        }
        free(buf);

        FILE *rf = _wfopen(ready_marker, L"wb");
        if (rf) {
            fwrite("ok", 1, 2, rf);
            fclose(rf);
        }
    }
    fclose(fp);

    wchar_t entry_w[4096];
    MultiByteToWideChar(CP_UTF8, 0, entry_utf8, -1, entry_w, 4096);
    free(entry_utf8);
    for (wchar_t *p = entry_w; *p; ++p) {
        if (*p == L'/') *p = L'\\';
    }

    wchar_t target_exe[32768];
    _snwprintf(target_exe, 32767, L"%s\\%s", extract_dir, entry_w);
    target_exe[32767] = L'\0';

    SetDllDirectoryW(extract_dir);
    wchar_t *old_path = (wchar_t *)calloc(65536, sizeof(wchar_t));
    if (old_path) {
        GetEnvironmentVariableW(L"PATH", old_path, 65535);
        wchar_t *new_path = (wchar_t *)calloc(98304, sizeof(wchar_t));
        if (new_path) {
            _snwprintf(new_path, 98303, L"%s;%s", extract_dir, old_path);
            SetEnvironmentVariableW(L"PATH", new_path);
            free(new_path);
        }
        free(old_path);
    }

    const wchar_t *tail = skip_program_name_w(GetCommandLineW());
    size_t cmd_cap = wcslen(target_exe) + wcslen(tail) + 16;
    wchar_t *cmdline = (wchar_t *)calloc(cmd_cap, sizeof(wchar_t));
    _snwprintf(cmdline, cmd_cap - 1, L"\"%s\"%s", target_exe, tail);

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(target_exe, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        free(cmdline);
        return 116;
    }
    free(cmdline);

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 0;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)exit_code;
}

#else /* POSIX (Linux & macOS) */
#include <errno.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <mach-o/ldsyms.h>
#endif

static void ensure_parent_dirs(const char *file_path) {
    char buf[4096];
    strncpy(buf, file_path, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    for (char *p = buf + 1; *p; ++p) {
        if (*p == '/') {
            *p = '\0';
            mkdir(buf, 0755);
            *p = '/';
        }
    }
}

static FILE *open_self_payload(uint64_t *out_offset, uint64_t *out_hash) {
#ifdef __APPLE__
    unsigned long sect_size = 0;
    const uint8_t *sect_data = getsectiondata(&_mh_execute_header, "__DATA", "__hagj13", &sect_size);
    if (sect_data && sect_size >= 20) {
        uint64_t payload_offset = 0;
        uint64_t payload_hash = 0;
        uint32_t magic = 0;
        memcpy(&payload_offset, sect_data + sect_size - 20, 8);
        memcpy(&payload_hash, sect_data + sect_size - 12, 8);
        memcpy(&magic, sect_data + sect_size - 4, 4);
        if (magic == HAGJ_MAGIC) {
            *out_offset = payload_offset;
            *out_hash = payload_hash;
            return fmemopen((void *)sect_data, sect_size, "rb");
        }
    }
#endif

    char self_path[4096];
    memset(self_path, 0, sizeof(self_path));
#ifdef __APPLE__
    uint32_t sz = sizeof(self_path);
    if (_NSGetExecutablePath(self_path, &sz) != 0) return NULL;
#else
    ssize_t r = readlink("/proc/self/exe", self_path, sizeof(self_path) - 1);
    if (r <= 0) return NULL;
    self_path[r] = '\0';
#endif

    FILE *fp = fopen(self_path, "rb");
    if (!fp) return NULL;
    if (fseeko(fp, -20, SEEK_END) != 0) { fclose(fp); return NULL; }

    uint64_t payload_offset = 0;
    uint64_t payload_hash = 0;
    uint32_t magic = 0;
    if (fread(&payload_offset, 8, 1, fp) != 1 ||
        fread(&payload_hash, 8, 1, fp) != 1 ||
        fread(&magic, 4, 1, fp) != 1 ||
        magic != HAGJ_MAGIC) {
        fclose(fp);
        return NULL;
    }
    *out_offset = payload_offset;
    *out_hash = payload_hash;
    return fp;
}

int main(int argc, char **argv) {
    uint64_t payload_offset = 0;
    uint64_t payload_hash = 0;
    FILE *fp = open_self_payload(&payload_offset, &payload_hash);
    if (!fp) {
        fprintf(stderr, "Failed to open embedded game payload.\n");
        return 101;
    }

    if (fseeko(fp, (off_t)payload_offset, SEEK_SET) != 0) { fclose(fp); return 102; }

    uint32_t entry_len = 0;
    if (fread(&entry_len, 4, 1, fp) != 1 || entry_len == 0 || entry_len > 4096) { fclose(fp); return 103; }
    char *entry_rel = (char *)calloc(entry_len + 1, 1);
    if (fread(entry_rel, 1, entry_len, fp) != entry_len) { fclose(fp); return 104; }

    uint32_t file_count = 0;
    if (fread(&file_count, 4, 1, fp) != 1) { fclose(fp); return 105; }

    const char *base_tmp = getenv("TMPDIR");
    if (!base_tmp || !base_tmp[0]) base_tmp = getenv("XDG_CACHE_HOME");
    if (!base_tmp || !base_tmp[0]) base_tmp = "/tmp";

    char extract_dir[4096];
    size_t blen = strlen(base_tmp);
    while (blen > 1 && base_tmp[blen - 1] == '/') --blen;
    snprintf(extract_dir, sizeof(extract_dir), "%.*s/hagj13_%016llx", (int)blen, base_tmp, (unsigned long long)payload_hash);

    char ready_marker[4096];
    snprintf(ready_marker, sizeof(ready_marker), "%s/.ready", extract_dir);

    struct stat st;
    if (stat(ready_marker, &st) != 0) {
        mkdir(extract_dir, 0755);
        const size_t chunk_sz = 1024 * 1024;
        uint8_t *buf = (uint8_t *)malloc(chunk_sz);
        if (!buf) { fclose(fp); return 106; }

        for (uint32_t i = 0; i < file_count; ++i) {
            uint8_t kind = 0;
            uint32_t path_len = 0;
            uint64_t data_len = 0;
            if (fread(&kind, 1, 1, fp) != 1 ||
                fread(&path_len, 4, 1, fp) != 1 ||
                path_len == 0 || path_len > 4096) {
                free(buf); fclose(fp); return 107;
            }
            char *rel_path = (char *)calloc(path_len + 1, 1);
            if (fread(rel_path, 1, path_len, fp) != path_len ||
                fread(&data_len, 8, 1, fp) != 1) {
                free(rel_path); free(buf); fclose(fp); return 108;
            }

            char dest_path[4096];
            snprintf(dest_path, sizeof(dest_path), "%s/%s", extract_dir, rel_path);
            free(rel_path);
            ensure_parent_dirs(dest_path);

            if (kind == 1) {
                char *link_target = (char *)calloc((size_t)data_len + 1, 1);
                if (fread(link_target, 1, (size_t)data_len, fp) != (size_t)data_len) {
                    free(link_target); free(buf); fclose(fp); return 109;
                }
                unlink(dest_path);
                symlink(link_target, dest_path);
                free(link_target);
            } else {
                unlink(dest_path);
                FILE *out = fopen(dest_path, "wb");
                if (!out) { free(buf); fclose(fp); return 110; }
                uint64_t remaining = data_len;
                while (remaining > 0) {
                    size_t to_read = remaining > chunk_sz ? chunk_sz : (size_t)remaining;
                    if (fread(buf, 1, to_read, fp) != to_read) {
                        fclose(out); free(buf); fclose(fp); return 111;
                    }
                    if (fwrite(buf, 1, to_read, out) != to_read) {
                        fclose(out); free(buf); fclose(fp); return 112;
                    }
                    remaining -= to_read;
                }
                fclose(out);
                chmod(dest_path, (kind == 2) ? 0755 : 0644);
            }
        }
        free(buf);

        char target_exe_tmp[4096];
        snprintf(target_exe_tmp, sizeof(target_exe_tmp), "%s/%s", extract_dir, entry_rel);
        chmod(target_exe_tmp, 0755);

#ifdef __APPLE__
        /* Ensure extracted .app bundle has clean ad-hoc signature on Apple Silicon */
        char *app_pos = strstr(entry_rel, ".app/");
        if (app_pos) {
            size_t app_len = (size_t)(app_pos - entry_rel) + 4;
            char cmd[8192];
            snprintf(cmd, sizeof(cmd), "xattr -cr \"%s/%.*s\" 2>/dev/null; codesign --force --deep --sign - \"%s/%.*s\" >/dev/null 2>&1",
                     extract_dir, (int)app_len, entry_rel, extract_dir, (int)app_len, entry_rel);
            system(cmd);
        }
#endif

        FILE *rf = fopen(ready_marker, "wb");
        if (rf) {
            fwrite("ok", 1, 2, rf);
            fclose(rf);
        }
    }
    fclose(fp);

    char target_exe[4096];
    snprintf(target_exe, sizeof(target_exe), "%s/%s", extract_dir, entry_rel);
    free(entry_rel);

    const char *old_ld = getenv("LD_LIBRARY_PATH");
    char new_ld[8192];
    if (old_ld && old_ld[0]) {
        snprintf(new_ld, sizeof(new_ld), "%s:%s", extract_dir, old_ld);
    } else {
        snprintf(new_ld, sizeof(new_ld), "%s", extract_dir);
    }
    setenv("LD_LIBRARY_PATH", new_ld, 1);

    char **new_argv = (char **)calloc((size_t)argc + 2, sizeof(char *));
    new_argv[0] = target_exe;
    for (int i = 1; i < argc; ++i) {
        new_argv[i] = argv[i];
    }
    new_argv[argc] = NULL;

    execv(target_exe, new_argv);
    perror("execv failed");
    return 127;
}
#endif
"""


def build_payload(input_dir: pathlib.Path, entry_rel: str) -> tuple[bytes, int]:
    """Serialize all files in input_dir into a single payload blob + 64-bit hash."""
    entry_rel_norm = entry_rel.replace("\\", "/").lstrip("/")
    entry_path = input_dir / entry_rel_norm
    if not entry_path.exists():
        raise FileNotFoundError(f"Entry executable '{entry_rel_norm}' not found inside '{input_dir}'")

    items: list[tuple[int, str, bytes]] = []
    hasher = hashlib.sha256()
    hasher.update(entry_rel_norm.encode("utf-8"))

    for path in sorted(input_dir.rglob("*")):
        rel = path.relative_to(input_dir).as_posix()
        if path.is_symlink():
            target = os.readlink(path)
            data = target.encode("utf-8")
            items.append((1, rel, data))
            hasher.update(rel.encode("utf-8"))
            hasher.update(data)
        elif path.is_file():
            if path.suffix.lower() in {".tmp", ".log", ".pdb"} or path.name == ".gdignore":
                continue
            data = path.read_bytes()
            is_exec = (
                rel == entry_rel_norm
                or path.suffix.lower() in {".exe", ".dll", ".so", ".dylib", ".x86_64", ".arm64"}
                or ".so." in path.name
                or "/MacOS/" in f"/{rel}"
                or ".framework/" in f"/{rel}"
                or bool(path.stat().st_mode & stat.S_IXUSR)
            )
            kind = 2 if is_exec else 0
            items.append((kind, rel, data))
            hasher.update(rel.encode("utf-8"))
            hasher.update(struct.pack("<Q", len(data)))
            # Hash first/last 64KB + size for fast deterministic content addressing
            hasher.update(data[:65536])
            if len(data) > 65536:
                hasher.update(data[-65536:])

    payload_hash = struct.unpack("<Q", hasher.digest()[:8])[0]

    chunks: list[bytes] = []
    entry_bytes = entry_rel_norm.encode("utf-8")
    chunks.append(struct.pack("<I", len(entry_bytes)))
    chunks.append(entry_bytes)
    chunks.append(struct.pack("<I", len(items)))

    for kind, rel, data in items:
        rel_bytes = rel.encode("utf-8")
        chunks.append(struct.pack("<BI", kind, len(rel_bytes)))
        chunks.append(rel_bytes)
        chunks.append(struct.pack("<Q", len(data)))
        chunks.append(data)

    return b"".join(chunks), payload_hash


def compile_and_bundle(
    input_dir: pathlib.Path,
    entry_rel: str,
    output_path: pathlib.Path,
    platform_name: str,
) -> None:
    payload, payload_hash = build_payload(input_dir, entry_rel)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = pathlib.Path(tmp)
        stub_c = tmp_dir / "stub.c"
        stub_c.write_text(STUB_C_SOURCE, encoding="utf-8")

        if platform_name == "macos":
            payload_file = tmp_dir / "payload.bin"
            trailer = struct.pack("<QQI", 0, payload_hash, MAGIC)
            payload_file.write_bytes(payload + trailer)

            compiler = shutil.which("clang") or shutil.which("gcc")
            if not compiler:
                raise RuntimeError("No C compiler (clang/gcc) found on macOS runner")

            # Try universal binary first, fall back to native host architecture
            universal_cmd = [
                compiler,
                "-O2",
                "-arch",
                "x86_64",
                "-arch",
                "arm64",
                str(stub_c),
                f"-Wl,-sectcreate,__DATA,__hagj13,{payload_file}",
                "-o",
                str(output_path),
            ]
            res = subprocess.run(universal_cmd, capture_output=True, text=True)
            if res.returncode != 0:
                native_cmd = [
                    compiler,
                    "-O2",
                    str(stub_c),
                    f"-Wl,-sectcreate,__DATA,__hagj13,{payload_file}",
                    "-o",
                    str(output_path),
                ]
                subprocess.run(native_cmd, check=True)

            output_path.chmod(0o755)
            if shutil.which("codesign"):
                subprocess.run(["codesign", "--force", "--sign", "-", str(output_path)], check=False)
        else:
            stub_bin = tmp_dir / ("stub.exe" if platform_name == "windows" else "stub")
            compiler = shutil.which("gcc") or shutil.which("clang")
            if not compiler:
                raise RuntimeError(f"No C compiler (gcc/clang) found for platform {platform_name}")

            cmd = [compiler, "-O2", "-s", str(stub_c), "-o", str(stub_bin)]
            if platform_name == "windows":
                cmd.append("-mwindows")
            subprocess.run(cmd, check=True)

            stub_bytes = stub_bin.read_bytes()
            payload_offset = len(stub_bytes)
            trailer = struct.pack("<QQI", payload_offset, payload_hash, MAGIC)

            with output_path.open("wb") as out_f:
                out_f.write(stub_bytes)
                out_f.write(payload)
                out_f.write(trailer)

            if platform_name != "windows":
                output_path.chmod(0o755)

    total_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"Successfully bundled standalone single executable: {output_path} ({total_mb:.2f} MB, hash={payload_hash:016x})")


def detect_host_platform() -> str:
    if sys.platform.startswith("win"):
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    return "linux"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", required=True, type=pathlib.Path, help="Directory containing exported executable and companion libraries")
    parser.add_argument("--entry", required=True, help="Relative path inside --input-dir to the main executable")
    parser.add_argument("--output", required=True, type=pathlib.Path, help="Output path for the standalone single executable")
    parser.add_argument("--platform", choices=["windows", "linux", "macos"], default=detect_host_platform(), help="Target platform")
    args = parser.parse_args()

    compile_and_bundle(
        input_dir=args.input_dir.resolve(),
        entry_rel=args.entry,
        output_path=args.output.resolve(),
        platform_name=args.platform,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
