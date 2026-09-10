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
import os
import random
import ssl
import threading
import time
from http.server import HTTPServer
from opentelemetry import metrics
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.metrics import MeterProvider
from prometheus_client import MetricsHandler


def sensor(counter, severity):
    """
    Business logic for recording the metric.
    Increments the counter by 1 and attaches attributes (labels) to it locally.
    """
    counter.add(1, {"severity": severity, "alert_id": "PULL_001"})


def start_server(port, cert_file=None, key_file=None, ca_file=None, client_auth=False):
    """
    Starts HTTP or HTTPS server for Prometheus scraping.
    """
    server = HTTPServer(("0.0.0.0", port), MetricsHandler)
    if cert_file and key_file and os.path.exists(cert_file) and os.path.exists(key_file):
        print(f"Enabling TLS for metrics server on port {port}")
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(certfile=cert_file, keyfile=key_file)
        if ca_file and os.path.exists(ca_file):
            ssl_context.load_verify_locations(cafile=ca_file)
            if client_auth:
                ssl_context.verify_mode = ssl.CERT_REQUIRED
                print("mTLS client authentication required")
            else:
                ssl_context.verify_mode = ssl.CERT_OPTIONAL
        server.socket = ssl_context.wrap_socket(server.socket, server_side=True)
    else:
        print(f"Starting plain HTTP metrics server on port {port}")

    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    return server


def main():
    # 1. Server Configuration (PULL MODEL)
    PORT = int(os.environ.get("PROMETHEUS_PORT", "8000"))
    CERT_FILE = os.environ.get("SENSOR_SSL_CERT_FILE", "/etc/ssl/certs/sovereign/tls.crt")
    KEY_FILE = os.environ.get("SENSOR_SSL_KEY_FILE", "/etc/ssl/certs/sovereign/tls.key")
    CA_FILE = os.environ.get("SENSOR_SSL_CA_FILE", "/etc/ssl/certs/sovereign/ca.crt")
    CLIENT_AUTH = os.environ.get("SENSOR_CLIENT_AUTH", "true").lower() in ("true", "1", "yes")

    # 2. Pull-Based Metric Reader & Provider
    reader = PrometheusMetricReader()
    provider = MeterProvider(metric_readers=[reader])
    metrics.set_meter_provider(provider)

    # 3. Start HTTPS / HTTP Metrics Server
    start_server(
        port=PORT,
        cert_file=CERT_FILE,
        key_file=KEY_FILE,
        ca_file=CA_FILE,
        client_auth=CLIENT_AUTH,
    )

    # 4. Get a Meter & Create Counter
    meter = metrics.get_meter("sensor.meter")
    sensor_counter = meter.create_counter(
        name="sensor_alerts",
        description="Count of sensor pull alerts",
        unit="1",
    )

    print(f"Exposing metrics on port {PORT}/metrics (TLS={os.path.exists(CERT_FILE)})")

    # 5. Main Application Sensor Loop
    while True:
        severity = random.choice(["warning", "critical"])
        sensor(sensor_counter, severity)
        print(f"Recorded {severity} alert")
        time.sleep(5)


if __name__ == "__main__":
    main()
