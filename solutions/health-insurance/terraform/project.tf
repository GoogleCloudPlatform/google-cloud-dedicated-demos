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
resource "google_project_service" "apis" {
  for_each = var.thp_apis

  project            = data.google_project.this.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "time_sleep" "wait_for_service_enablement" {
  #depends_on      = [google_project_service.apis, google_project_service.compute_api, google_project_service.container_api]
  depends_on      = [google_project_service.apis]
  create_duration = "180s"
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}
