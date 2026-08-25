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
output "project_id" {
  value       = data.google_client_config.default.project
  description = "The Google Cloud project ID where the monitoring infrastructure is deployed."
}

output "region" {
  value       = data.google_client_config.default.region
  description = "The Google Cloud region hosting the GKE cluster and metrics storage bucket."
}

output "universe_api_domain" {
  value       = local.config.universe_api_domain
  description = "The target API domain for the Google Cloud universe environment."
}

output "k8s_namespace" {
  value       = local.config.k8s_namespace
  description = "The name of the cluster namespace."
}

output "cluster" {
  value       = length(google_container_cluster.monitoring_cluster) > 0 ? google_container_cluster.monitoring_cluster[0].name : local.config.gke_name
  description = "The name of the GKE cluster hosting Grafana, Mimir, Loki and OpenTelemetry collector."
}

output "storage_bucket" {
  value       = length(google_storage_bucket.monitoring_storage_bucket) > 0 ? google_storage_bucket.monitoring_storage_bucket[0].name : local.config.storage_bucket_name
  description = "The name of the hardened Cloud Storage bucket storing Mimir long-term time-series metrics."
}

output "artifact_registry" {
  value       = length(google_artifact_registry_repository.monitoring_registry) > 0 ? google_artifact_registry_repository.monitoring_registry[0].repository_id : local.config.artifact_registry
  description = "The ID of the Artifact Registry repository."
}

output "artifact_registry_uri" {
  value       = length(google_artifact_registry_repository.monitoring_registry) > 0 ? google_artifact_registry_repository.monitoring_registry[0].registry_uri : local.config.artifact_registry_uri
  description = "The URI of the Artifact Registry repository."
}

output "vpc" {
  value       = length(google_compute_network.monitoring_vpc) > 0 ? google_compute_network.monitoring_vpc[0].name : local.config.vpc_name
  description = "The VPC name used by the demo."
}

output "grafana_sa_email" {
  value       = google_service_account.grafana_sa.email
  description = "The Google service account email bound via Workload Identity for Grafana dashboard operations."
}

output "mimir_sa_email" {
  value       = length(google_service_account.mimir_storage_sa) > 0 ? google_service_account.mimir_storage_sa[0].email : "${local.config.mimir_sa}@${local.project_name_id}.${local.project_prefix}.iam.gserviceaccount.com"
  description = "The Google service account email bound via Workload Identity for Mimir metrics storage access."
}

output "otel_sa_email" {
  value       = google_service_account.otel_collector.email
  description = "The Google service account email bound via Workload Identity for OpenTelemetry metric and log ingestion."
}

output "grafana_admin_user" {
  description = "The grafana admin user."
  value       = local.config.grafana_admin_user
}

output "grafana_admin_password" {
  description = "The grafana admin password."
  value       = local.config.grafana_admin_password
  sensitive   = true
}

output "grafana_client_id" {
  value       = local.config.grafana_client_id
  description = "The client ID used for OAUTH authentication."
  sensitive   = true
}

output "grafana_client_secret" {
  value       = local.config.grafana_client_secret
  description = "The client Secret used for OAUTH authentication."
  sensitive   = true
}

output "grafana_oauth_provider_url" {
  value       = local.config.grafana_oauth_provider_url
  description = "The provider url used for OAUTH authentication."
}

output "grafana_disable_login_form" {
  value       = local.config.grafana_disable_login_form
  description = "Disable login form."
}

output "grafana_enable_oauth_login" {
  value       = local.config.grafana_enable_oauth_Login
  description = "Enable or Disable oauth login."
}

output "gce_logging_vm_name" {
  description = "Name of the standalone logging GCE VM"
  value       = try(google_compute_instance.logging_demo_vm[0].name, "")
}
