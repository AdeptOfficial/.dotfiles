#!/usr/bin/env python3
"""Translate this controller's five-slider MessagePack frames for stock deej.

Hardware: CH340, 115200 baud, fixmap of slider1..slider5 -> uint ADC values.
No firmware changes. A PTY exposes stock deej's pipe-separated serial format.
"""
import os
from pathlib import Path
import pty
import signal
import subprocess
import time
import tty

import serial

MARKER = b"\x85\xa7slider1"


def frames(buffer):
    """Consume complete, validated frames; retain partial input between reads."""
    while True:
        start = buffer.find(MARKER)
        if start < 0:
            if len(buffer) >= len(MARKER):
                del buffer[:-(len(MARKER) - 1)]
            return
        del buffer[:start]
        pos = 1
        values = []
        try:
            for i in range(1, 6):
                key = b"\xa7slider" + str(i).encode()
                if len(buffer) < pos + len(key) + 1:
                    return
                if buffer[pos:pos + len(key)] != key:
                    raise ValueError("unexpected key")
                pos += len(key)
                tag = buffer[pos]
                pos += 1
                if tag < 128:
                    value = tag
                elif tag in (0xcc, 0xcd):
                    size = 1 if tag == 0xcc else 2
                    if len(buffer) < pos + size:
                        return
                    value = int.from_bytes(buffer[pos:pos + size], "big")
                    pos += size
                else:
                    raise ValueError("unexpected value type")
                if not 0 <= value <= 1023:
                    raise ValueError("ADC value out of range")
                values.append(value)
        except ValueError:
            del buffer[0]
            continue
        del buffer[:pos]
        yield values


def main():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "deej"
    runtime.mkdir(mode=0o700, exist_ok=True)
    link = runtime / "serial"
    master, slave = pty.openpty()
    tty.setraw(slave)
    link.unlink(missing_ok=True)
    link.symlink_to(os.ttyname(slave))
    child = None

    def stop(*_):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        child = subprocess.Popen(
            [str(Path.home() / ".local/bin/deej")],
            cwd=Path.home() / ".config/deej",
        )
        device = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0"
        while child.poll() is None:
            try:
                with serial.Serial(device, 115200, timeout=0.2, exclusive=True) as port:
                    print("Controller connected at 115200 baud", flush=True)
                    buffer = bytearray()
                    first = True
                    while child.poll() is None:
                        buffer.extend(port.read(256))
                        for values in frames(buffer):
                            os.write(master, ("|".join(map(str, values)) + "\r\n").encode())
                            if first:
                                print("Valid five-slider frame forwarded:", values, flush=True)
                                first = False
            except (serial.SerialException, OSError) as exc:
                print("Waiting for controller:", exc, flush=True)
                time.sleep(2)
        raise SystemExit(child.returncode)
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        link.unlink(missing_ok=True)
        os.close(master)
        os.close(slave)


if __name__ == "__main__":
    main()
