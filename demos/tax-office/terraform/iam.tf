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
resource "google_service_account" "tax_office_node_sa" {
  project      = var.project_id
  account_id   = var.node_sa_id
  display_name = var.node_sa_display_name
  depends_on   = [time_sleep.wait_for_service_enablement]
}

# Grant GKE Node Service Account permission to read Artifact Registry images
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.tax_office_node_sa.email}"
}

# IAM bindings for the Jupyter KSA
resource "google_project_iam_member" "jupyter_ksa_roles" {
  for_each = local.jupyter_roles

  project = var.project_id
  role    = each.value
  member  = local.jupyter_ksa_member

  depends_on = [google_container_cluster.tax_office_cluster]
}

# IAM bindings for the Application KSA
resource "google_project_iam_member" "app_ksa_roles" {
  for_each = local.app_roles

  project = var.project_id
  role    = each.value
  member  = local.app_ksa_member

  depends_on = [google_container_cluster.tax_office_cluster]
}
