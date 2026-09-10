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
# -----------------------------------------------------------------------------
# CRÉATION DU COMPTE DE SERVICE
# -----------------------------------------------------------------------------
resource "google_service_account" "jupyter_sa" {
  project      = data.google_project.this.project_id
  account_id   = "jupyterhub-demo"
  display_name = "jupyterhub-demo"
  description  = "Jupyterhub service account"
  depends_on   = [time_sleep.wait_for_service_enablement]
}

# -----------------------------------------------------------------------------
# ATTRIBUTION DES ROLES POUR LE SA
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "bigquery_editor_binding" {
  project = data.google_project.this.id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "bigquery_jobuser_binding" {
  project = data.google_project.this.id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "bigquery_readsessionuser_binding" {
  project = data.google_project.this.id
  role    = "roles/bigquery.readSessionUser"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "workloadidentityuser_binding" {
  project = data.google_project.this.id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "bucket_access" {
  project = data.google_project.this.id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "sql_instance_user" {
  project = data.google_project.this.id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "sql_client" {
  project = data.google_project.this.id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

resource "google_project_iam_member" "artifact_registry_reader" {
  project = data.google_project.this.id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.jupyter_sa.email}"
}

# -----------------------------------------------------------------------------
# BINDING WORKLOAD IDENTITY
# -----------------------------------------------------------------------------

resource "google_service_account_iam_member" "insurance_demo_ksa_workload_identity" {
  service_account_id = google_service_account.jupyter_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wif_name_for_universe}.svc.id.goog[insurance-ns/insurance-demo-ksa]"
  depends_on         = [google_container_cluster.demo-cluster]
}

resource "google_service_account_iam_member" "insurance_jupyter_ksa_workload_identity" {
  service_account_id = google_service_account.jupyter_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wif_name_for_universe}.svc.id.goog[insurance-ns/insurance-demo-jupyter-ksa]"
  depends_on         = [google_container_cluster.demo-cluster]
}
