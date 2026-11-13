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
"""Gunicorn settings for serving the dashboard in production containers.

Never serve traffic with the Flask development server: its interactive debugger
allows remote code execution. Threads keep each worker answering health probes
while requests wait on the LLM service. The timeout leaves headroom for slow
worker startup under the pod CPU limit. Set PORT, WEB_CONCURRENCY,
GUNICORN_THREADS, or GUNICORN_TIMEOUT to override the defaults.
"""

import os

bind = f'0.0.0.0:{os.environ.get("PORT", "5001")}'
workers = int(os.environ.get('WEB_CONCURRENCY', '1'))
threads = int(os.environ.get('GUNICORN_THREADS', '8'))
timeout = int(os.environ.get('GUNICORN_TIMEOUT', '120'))
# Disable the unused gunicornc control socket (appuser has no writable home).
control_socket_disable = True
