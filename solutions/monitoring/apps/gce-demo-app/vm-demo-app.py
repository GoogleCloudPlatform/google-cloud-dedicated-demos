#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#!/usr/bin/env python3
import time
import json
import datetime

def main():
    print("Starting standalone GCE VM stdout log generator...")
    count = 1
    while True:
        log_entry = {
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "severity": "INFO",
            "event_id": f"VM_STDOUT_{count:04d}",
            "message": f"Simulated user CLI/application transaction writing to stdout on GCE VM (event #{count})"
        }
        # Print directly to stdout (unbuffered) so systemd-journald captures into /var/log/syslog
        print(json.dumps(log_entry), flush=True)
        count += 1
        time.sleep(10)

if __name__ == '__main__':
    main()
