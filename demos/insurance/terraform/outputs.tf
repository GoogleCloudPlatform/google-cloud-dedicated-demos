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
  value       = data.google_project.this.project_id
  description = "GCP Project ID"
}

output "region" {
  value       = var.region
  description = "GCP Region"
}

output "universe_domain" {
  value       = var.universe_domain
  description = "GCP Universe Domain"
}

output "sql_instance_name" {
  value       = google_sql_database_instance.sql.name
  description = "Cloud SQL Instance Name"
}

output "claims_database_name" {
  value       = google_sql_database.sql_db.name
  description = "Cloud SQL Database Name"
}

output "claims_document_bucket" {
  value       = google_storage_bucket.claim_documents_bucket.name
  description = "GCS Bucket for Claim Documents"
}

output "sql_dns_name" {
  value       = google_sql_database_instance.sql.dns_name
  description = "Internal DNS name allocated for Cloud SQL instance"
}


output "gke_cluster_name" {
  value       = google_container_cluster.demo-cluster.name
  description = "GKE Cluster Name"
}

output "docker_registry_host" {
  value       = local.registry_host
  description = "Fully qualified Docker registry hostname"
}

output "docker_repo_prefix" {
  value       = local.docker_repo_prefix
  description = "Base image repository URL prefix"
}

output "gcp_service_account_email" {
  value       = google_service_account.jupyter_sa.email
  description = "Service account email for Jupyter/App Workload Identity"
}

output "model_host" {
  value       = local.model_host
  description = "Base endpoint URL for LLM API"
}

output "artifact_repository_id" {
  value       = var.artifact_repository_id
  description = "ID for Artifact Registry Docker repository"
}

resource "local_file" "secrets" {
  filename        = "${path.module}/../k8s/helm/deployment-secrets.yaml"
  file_permission = "0600"
  content         = yamlencode({
    global = {
      iamDatabaseUser = google_sql_user.iam_service_account_user.name
    }
    insuranceApp = {
      dbPassword    = random_password.db_password.result
      loginUser     = var.app_login_user
      loginPassword = var.app_login_password
    }
    vllm = {
      huggingFaceToken = var.hugging_face_token
    }
    jupyter = {
      rawPassword = var.jupyter_password
    }
  })
}
