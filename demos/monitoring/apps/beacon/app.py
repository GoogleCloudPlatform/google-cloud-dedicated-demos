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
# app.py
import time
import random
import os
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter

def emit_beacon(counter, severity):
    """
    Business logic for emitting the metric.
    Increments the counter by 1 and attaches attributes (labels) to it.
    """
    counter.add(1, {"severity": severity, "alert_id": "PUSH_001"})

def main():
    # 1. Endpoint Configuration
    # Get the OTLP Collector endpoint from environment variables, defaulting to local HTTP receiver
    COLLECTOR_ENDPOINT = os.environ.get("OTEL_COLLECTOR_ENDPOINT", "http://0.0.0.0:4318/v1/metrics")
    CA_CERT_FILE = os.environ.get("OTEL_EXPORTER_OTLP_CERTIFICATE", os.environ.get("SSL_CERT_FILE", None))
    CLIENT_CERT_FILE = os.environ.get("OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE", None)
    CLIENT_KEY_FILE = os.environ.get("OTEL_EXPORTER_OTLP_CLIENT_KEY", None)

    # 2. Exporter Setup
    # Initialize the OTLP Exporter using HTTP/HTTPS protocol with optional TLS / mTLS
    exporter_kwargs = {"endpoint": COLLECTOR_ENDPOINT}
    if CA_CERT_FILE and os.path.exists(CA_CERT_FILE):
        exporter_kwargs["certificate_file"] = CA_CERT_FILE
    if CLIENT_CERT_FILE and os.path.exists(CLIENT_CERT_FILE):
        exporter_kwargs["client_certificate_file"] = CLIENT_CERT_FILE
    if CLIENT_KEY_FILE and os.path.exists(CLIENT_KEY_FILE):
        exporter_kwargs["client_key_file"] = CLIENT_KEY_FILE

    exporter = OTLPMetricExporter(**exporter_kwargs)

    # 3. Metric Reader Configuration
    # Wrap the exporter in a Periodic reader which flushes metrics to the collector every 5 seconds (5000ms)
    reader = PeriodicExportingMetricReader(exporter, export_interval_millis=5000)

    # 4. Meter Provider Initialization
    # The MeterProvider links the SDK's internal metric collection to the exporting pipeline (reader)
    provider = MeterProvider(metric_readers=[reader])
    # 5. Global Registration
    # Set this provider as the global meter provider for the application
    metrics.set_meter_provider(provider)

    # 6. Get a Meter
    # Retrieve a named meter (scope) to create instrumentation instruments
    meter = metrics.get_meter("beacon.meter")

    # 7. Create a Metric Instrument
    # Create a Counter to record cumulative values (events that only go up)
    beacon_counter = meter.create_counter(
        name="beacon_push_alerts",
        description="Count of beacon push alerts",
        unit="1"
    )

    print(f"Pushing metrics to {COLLECTOR_ENDPOINT}")

    # 8. Main Application Push Loop
    while True:
        severity = random.choice(['warning', 'critical'])
        emit_beacon(beacon_counter, severity)
        print(f"Sent {severity} alert via OTLP")
        time.sleep(5)

if __name__ == '__main__':
    main()
