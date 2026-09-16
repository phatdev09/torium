#!/usr/bin/env python3
"""
package_deb.py: Packages ToriumHelper tweak into standard Debian format (.deb)
Pure Python - zero dependencies, works on any platform.
"""

import os
import io
import time
import tarfile

def create_ar_file(target_path, members):
    """
    members: list of (filename, bytes_data)
    """
    with open(target_path, "wb") as f:
        f.write(b"!<arch>\n")
        for name, data in members:
            # ar header is 60 bytes:
            # 0..15: filename padded with spaces, ending with / (or just / on BSD/GNU)
            # 16..27: timestamp (decimal)
            # 28..33: owner id
            # 34..39: group id
            # 40..47: file mode (octal, e.g. 100644)
            # 48..57: file size (decimal)
            # 58..59: magic "\x60\x0a"
            ar_name = (name + "/").ljust(16)[:16].encode("ascii")
            mtime = str(int(time.time())).ljust(12)[:12].encode("ascii")
            owner = b"0".ljust(6)
            group = b"0".ljust(6)
            mode = b"100644".ljust(8)
            size = str(len(data)).ljust(10)[:10].encode("ascii")
            magic = b"\x60\x0a"

            header = ar_name + mtime + owner + group + mode + size + magic
            assert len(header) == 60, f"Header size is {len(header)}, expected 60"
            f.write(header)
            f.write(data)
            if len(data) % 2 != 0:
                f.write(b"\n") # pad byte

def make_tar_gz(files_dict):
    """
    files_dict: {tar_path: bytes_content}
    """
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for path, data in files_dict.items():
            info = tarfile.TarInfo(name=path)
            info.size = len(data)
            info.mtime = int(time.time())
            info.mode = 0o644
            info.type = tarfile.REGTYPE
            tar.addfile(info, io.BytesIO(data))
    return buf.getvalue()

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    tweak_dir = os.path.join(base_dir, "ToriumBot", "Tweak")
    if not os.path.exists(tweak_dir):
        tweak_dir = os.path.join(base_dir, "ToriumBot", "ToriumBot", "Tweak")
    
    control_file = os.path.join(tweak_dir, "control")
    plist_file = os.path.join(tweak_dir, "ToriumHelper.plist")
    source_m = os.path.join(tweak_dir, "ToriumHelper.m")

    with open(control_file, "rb") as f:
        control_data = f.read()

    with open(plist_file, "rb") as f:
        plist_data = f.read()

    # 1. debian-binary
    debian_binary = b"2.0\n"

    # 2. control.tar.gz
    control_tar = make_tar_gz({"./control": control_data})

    # 3. data.tar.gz
    # Contains:
    # ./Library/MobileSubstrate/DynamicLibraries/ToriumHelper.plist
    # ./Library/MobileSubstrate/DynamicLibraries/ToriumHelper.m (source fallback)
    data_files = {
        "./Library/MobileSubstrate/DynamicLibraries/ToriumHelper.plist": plist_data,
    }
    if os.path.exists(source_m):
        with open(source_m, "rb") as f:
            data_files["./Library/MobileSubstrate/DynamicLibraries/ToriumHelper.m"] = f.read()

    data_tar = make_tar_gz(data_files)

    # Output to Resources/toriumhelper.deb
    resources_dir = os.path.join(base_dir, "ToriumBot", "Resources")
    os.makedirs(resources_dir, exist_ok=True)
    out_deb = os.path.join(resources_dir, "toriumhelper.deb")

    create_ar_file(out_deb, [
        ("debian-binary", debian_binary),
        ("control.tar.gz", control_tar),
        ("data.tar.gz", data_tar)
    ])

    print(f"[+] Created {out_deb} ({os.path.getsize(out_deb)} bytes)")

if __name__ == "__main__":
    main()
