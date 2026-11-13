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
"""Tests for the Gunicorn production server settings."""

import os
import pathlib
import runpy
import unittest
from unittest import mock

_CONFIG_PATH = str(pathlib.Path(__file__).with_name('gunicorn.conf.py'))


class GunicornConfTest(unittest.TestCase):
  """Tests for gunicorn.conf.py."""

  @mock.patch.dict(os.environ, clear=True)
  def test_defaults_serve_container_port(self):
    # Act
    config = runpy.run_path(_CONFIG_PATH)
    # Assert
    self.assertEqual(config['bind'], '0.0.0.0:5001')
    self.assertEqual(config['workers'], 1)
    self.assertEqual(config['threads'], 8)
    self.assertEqual(config['timeout'], 120)

  @mock.patch.dict(
    os.environ,
    {
      'PORT': '8080',
      'WEB_CONCURRENCY': '2',
      'GUNICORN_THREADS': '4',
      'GUNICORN_TIMEOUT': '60',
    },
    clear=True,
  )
  def test_environment_overrides_defaults(self):
    # Act
    config = runpy.run_path(_CONFIG_PATH)
    # Assert
    self.assertEqual(config['bind'], '0.0.0.0:8080')
    self.assertEqual(config['workers'], 2)
    self.assertEqual(config['threads'], 4)
    self.assertEqual(config['timeout'], 60)
