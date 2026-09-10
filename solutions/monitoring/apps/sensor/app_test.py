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
import unittest
import os
from unittest.mock import patch
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import InMemoryMetricReader

from app import sensor

class TestSensorApp(unittest.TestCase):

    @patch.dict(os.environ, {"PROMETHEUS_PORT": "8000"})
    def setUp(self):
        self.reader = InMemoryMetricReader()
        self.provider = MeterProvider(metric_readers=[self.reader])

        self.meter = self.provider.get_meter("sensor.meter.test")
        self.test_counter = self.meter.create_counter("sensor_alerts_test")

    def _get_points(self, name):
        data = self.reader.get_metrics_data()
        return next((m.data.data_points for rm in data.resource_metrics
                     for sm in rm.scope_metrics for m in sm.metrics if m.name == name), []) if data else []

    def test_sensor_increments_counter(self):
        sensor(self.test_counter, "critical")
        points = self._get_points("sensor_alerts_test")

        self.assertEqual(len(points), 1)
        self.assertEqual(points[0].value, 1)

        self.assertEqual(points[0].attributes, {"severity": "critical", "alert_id": "PULL_001"})

    def test_sensor_multiple_severities(self):
        sensor(self.test_counter, "critical")
        sensor(self.test_counter, "warning")
        sensor(self.test_counter, "critical")

        points = self._get_points("sensor_alerts_test")
        self.assertEqual(len(points), 2)

        stats = {p.attributes["severity"]: p.value for p in points}
        self.assertEqual(stats.get("critical"), 2)
        self.assertEqual(stats.get("warning"), 1)

if __name__ == '__main__':
    unittest.main()
