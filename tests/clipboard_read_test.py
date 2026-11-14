#!/usr/bin/env python3
"""Byte-limit and deadline checks for the preset-name paste helper."""
import importlib.util
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("clipboard_read", root / "clipboard_read.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def check(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)


def python_write(script):
    return [sys.executable, "-c", script]


check(helper.read_bounded(python_write("import sys; sys.stdout.write('Halo')"), 64) == "Halo",
      "short payload is returned")
check(helper.read_bounded(python_write("import sys; sys.stdout.write('x' * 200)"), 10) == "",
      "oversize payload is dropped")
check(helper.read_bounded(python_write("import time, sys; time.sleep(3); sys.stdout.write('late')"), 64, timeout=0.2) == "",
      "slow payload is dropped")
check(helper.read_bounded(python_write("import sys; sys.stdout.write('ok')"), 0) == "",
      "invalid limit is refused")

missing = subprocess.run([sys.executable, str(root / "clipboard_read.py")], capture_output=True, text=True)
check(missing.returncode == 1, "missing argv exits 1")
bad_limit = subprocess.run([sys.executable, str(root / "clipboard_read.py"), "0", "clipboard"], capture_output=True, text=True)
check(bad_limit.returncode == 1, "zero limit exits 1")
bad_source = subprocess.run([sys.executable, str(root / "clipboard_read.py"), "40", "other"], capture_output=True, text=True)
check(bad_source.returncode == 1, "unknown source exits 1")

print("PASS: clipboard helper drops oversize and slow payloads, and rejects invalid invocation.")
