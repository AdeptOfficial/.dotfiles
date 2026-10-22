from datetime import datetime
import signal
import time

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

while True:
    print(datetime.now().strftime("%H:%M:%S.%f")[:-3], flush=True)
    time.sleep(0.05)
