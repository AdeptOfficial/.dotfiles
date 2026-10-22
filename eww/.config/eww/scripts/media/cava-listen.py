#!/usr/bin/env python3
"""Own CAVA's lifecycle and forward only complete, valid frames to EWW."""
import signal
import subprocess
import tempfile
import time

CONFIG = '''[general]
framerate = 30
bars = 52
sensitivity = 120
[input]
method = pulse
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
'''


def stop(*_):
    raise SystemExit(0)


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with tempfile.NamedTemporaryFile(mode='w', suffix='.conf') as config:
        config.write(CONFIG)
        config.flush()
        while True:
            child = subprocess.Popen(['cava', '-p', config.name], stdout=subprocess.PIPE,
                                     text=True, encoding='utf-8')
            try:
                for line in child.stdout:
                    values = line.strip().strip(';').split(';')
                    if len(values) == 52 and all(v in '01234567' and len(v) == 1 for v in values):
                        print(''.join('▁▂▃▄▅▆▇█'[int(v)] for v in values), flush=True)
            except BrokenPipeError:
                return
            finally:
                child.terminate()
                try:
                    child.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
                child.stdout.close()
            time.sleep(1)


if __name__ == '__main__':
    main()
