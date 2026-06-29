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
resource "google_bigquery_dataset" "insurance_ds" {
  dataset_id                 = "next_demo_health_insurance_ds"
  location                   = var.region
  project                    = data.google_project.this.project_id
  delete_contents_on_destroy = true
  depends_on                 = [time_sleep.wait_for_service_enablement]
}

resource "google_bigquery_job" "dwh_init" {
  job_id   = "dwh_init_job_${formatdate("YYYYMMDDhhmmss", timestamp())}"
  location = var.region
  project  = data.google_project.this.project_id

  query {
    query          = file("${path.module}/../schema/bigquery_dwh_schema.sql")
    use_legacy_sql = false
  }
  depends_on = [google_bigquery_dataset.insurance_ds]
}
