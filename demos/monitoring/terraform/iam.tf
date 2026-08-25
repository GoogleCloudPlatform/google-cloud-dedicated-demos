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
# Grafana
resource "google_service_account" "grafana_sa" {
  project      = data.google_client_config.default.project
  account_id   = local.config.grafana_sa
  display_name = "Grafana SA"
}

resource "google_project_iam_member" "grafana_viewer" {
  project = data.google_client_config.default.project
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_service_account_iam_member" "grafana_ksa_workload_identity" {
  service_account_id = google_service_account.grafana_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wif_name_for_universe}.svc.id.goog[${local.config.k8s_namespace}/grafana-ksa]"
}

# Mimir
resource "google_service_account" "mimir_storage_sa" {
  count        = local.config.enable_storage_bucket == true ? 1 : 0
  project      = data.google_client_config.default.project
  account_id   = local.config.mimir_sa
  display_name = "Mimir Storage SA"
}

resource "google_project_iam_member" "mimir_storage_access" {
  count   = local.config.enable_storage_bucket == true ? 1 : 0
  project = data.google_client_config.default.project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.mimir_storage_sa[0].email}"
}

resource "google_storage_bucket_iam_member" "mimir_bucket_access" {
  count  = local.config.enable_storage_bucket == true ? 1 : 0
  bucket = google_storage_bucket.monitoring_storage_bucket[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.mimir_storage_sa[0].email}"
}

resource "google_service_account_iam_member" "mimir_storage_ksa_workload_identity" {
  count              = local.config.enable_storage_bucket == true ? 1 : 0
  service_account_id = google_service_account.mimir_storage_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wif_name_for_universe}.svc.id.goog[${local.config.k8s_namespace}/mimir-ksa]"
}

# OpenTelemetry
resource "google_service_account" "otel_collector" {
  project      = data.google_client_config.default.project
  account_id   = local.config.otel_sa
  display_name = "OTEL Collector"
}

resource "google_project_iam_member" "otel" {
  project = data.google_client_config.default.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

resource "google_project_iam_member" "otel_logging" {
  project = data.google_client_config.default.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

resource "google_service_account_iam_member" "otel_ksa_workload_identity" {
  service_account_id = google_service_account.otel_collector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wif_name_for_universe}.svc.id.goog[${local.config.k8s_namespace}/otel-ksa]"
}

# MonitoringNode (GKE)
resource "google_service_account" "monitoring_node_sa" {
  count        = local.config.enable_gke == true ? 1 : 0
  project      = data.google_client_config.default.project
  account_id   = local.config.monitoring_node_sa
  display_name = "Monitoring GKE Node SA"
}

resource "google_project_iam_member" "artifact_registry_reader" {
  count   = local.config.enable_gke == true ? 1 : 0
  project = data.google_client_config.default.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.monitoring_node_sa[0].email}"
}

# Project default SA
resource "google_project_iam_member" "compute_default_artifact_registry_reader" {
  project = data.google_client_config.default.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.default.number}-compute@developer.${local.project_prefix}-system.iam.gserviceaccount.com"
}

# Standalone GCE VM Logging Service Account
resource "google_service_account" "logging_vm_sa" {
  count        = local.config.gce_enabled ? 1 : 0
  project      = data.google_client_config.default.project
  account_id   = local.config.logging_vm_sa
  display_name = "GCE VM Logging Service Account for OTel & Fluent Bit"
}

resource "google_project_iam_member" "logging_vm_sa_log_writer" {
  count   = local.config.gce_enabled ? 1 : 0
  project = data.google_client_config.default.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.logging_vm_sa[0].email}"
}
