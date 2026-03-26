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
resource "google_storage_bucket" "tax_data_bucket" {
  name                        = var.data_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  depends_on                  = [time_sleep.wait_for_service_enablement]
}

resource "google_storage_bucket_object" "tax_data_object" {
  name   = local.data_file_name
  bucket = google_storage_bucket.tax_data_bucket.name
  source = var.data_file_location
}
