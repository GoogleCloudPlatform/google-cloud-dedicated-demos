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
# Cloud Storage bucket for Mimir metrics storage with Sovereign security hardening
resource "google_storage_bucket" "monitoring_storage_bucket" {
  count                       = local.config.enable_storage_bucket == true? 1 : 0
  name                        = local.config.storage_bucket_name
  location                    = data.google_client_config.default.region
  project                     = data.google_client_config.default.project
  uniform_bucket_level_access = true
  labels                      = local.common_labels
  force_destroy               = true

  # Automatically abort incomplete multipart uploads after 7 days to optimize storage costs
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

}
