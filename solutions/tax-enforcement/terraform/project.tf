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
resource "google_project_service" "apis_to_enable" {
  project                    = var.project_id
  for_each                   = toset(var.project_services)
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "time_sleep" "wait_for_service_enablement" {
  # Wait for APIs to be enabled before creating dependencies like Service Accounts
  depends_on      = [google_project_service.apis_to_enable]
  create_duration = "180s"
}

resource "random_password" "flask_secret_key" {
  length  = 32
  special = true
}
