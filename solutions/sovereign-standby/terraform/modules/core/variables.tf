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
variable "config" {
  description = "Configuration map parsed from defaults.yaml for a specific universe environment"
  type        = any

  validation {
    condition     = !var.config.enable_cloudsql || var.config.enable_network
    error_message = "The network must be enabled (enable_network = true) if CloudSQL is enabled (enable_cloudsql = true)."
  }

  validation {
    condition     = !var.config.enable_app || var.config.enable_network
    error_message = "The network must be enabled (enable_network = true) if App is enabled (enable_app = true)."
  }
}
