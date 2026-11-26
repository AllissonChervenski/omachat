#!/usr/bin/python3
"""Read at most 32 KiB of primary text in 600 ms."""
import json
import os
import selectors
import subprocess
import time
p = subprocess.Popen(['wl-paste', '--primary', '--no-newline'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
s = selectors.DefaultSelector()
s.register(p.stdout, selectors.EVENT_READ)
result = bytearray()
deadline = time.monotonic() + .6
try:
    while time.monotonic() < deadline:
        if not s.select(max(0, deadline-time.monotonic())):
            break
        chunk = os.read(p.stdout.fileno(), min(4096, 32769-len(result)))
        if not chunk:
            if result and len(result) <= 32768:
                print(json.dumps({'text': result.decode('utf-8', errors='replace')}))
            break
        result.extend(chunk)
        if len(result) > 32768:
            break
finally:
    s.close()
    if p.poll() is None:
        p.kill()
    p.wait()
