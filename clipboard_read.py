#!/usr/bin/env python3
"""Read a Wayland text clipboard offer with a byte limit and a deadline.

Qt 6.12 TextField can pull an unbounded clipboard payload into omarchy-shell.
The preset-name field pastes only through this helper.
"""
import json
import os
import selectors
import signal
import subprocess
import sys
import time


def read_bounded(command, limit, timeout=1.0):
    if not 0 < limit <= 1024:
        return ""
    deadline = time.monotonic() + timeout
    try:
        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return ""
    data = bytearray()
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    return ""
                chunk = os.read(proc.stdout.fileno(), min(4096, limit + 1 - len(data)))
                if not chunk:
                    return data.decode("utf-8", errors="replace")
                data.extend(chunk)
                if len(data) > limit:
                    return ""
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()


def main(argv):
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    if len(argv) < 3:
        sys.exit(1)
    try:
        limit = int(argv[1])
    except ValueError:
        sys.exit(1)
    if not 0 < limit <= 1024:
        sys.exit(1)
    command = ["wl-paste", "--no-newline", "--type", "text"]
    if argv[2] == "primary":
        command.append("--primary")
    elif argv[2] != "clipboard":
        sys.exit(1)
    print(json.dumps(read_bounded(command, limit)))


if __name__ == "__main__":
    main(sys.argv)
