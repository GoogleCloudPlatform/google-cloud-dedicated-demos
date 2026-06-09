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
  description = "The GCP project ID."
  value       = var.project_id
}

output "region" {
  description = "The region where resources were deployed."
  value       = var.region
}

output "universe_api_domain" {
  description = "The configured Sovereign Universe API domain."
  value       = var.universe_api_domain
}

output "project_number" {
  description = "Project number."
  value       = data.google_project.project.number
}

output "tax_office_cluster_name" {
  description = "The name of the deployed GKE cluster."
  value       = google_container_cluster.tax_office_cluster.name
}

output "tax_office_bucket_name" {
  description = "The name of the GCS bucket holding tax data."
  value       = google_storage_bucket.tax_data_bucket.name
}

output "app_repository_id" {
  description = "The ID of the Artifact Registry repository."
  value       = google_artifact_registry_repository.docker_registry.repository_id
}

output "dataset_id" {
  value = var.dataset_id
}

output "tax_table_id" {
  value = var.tax_table_id
}

output "policy_table_id" {
  value = var.policy_table_id
}

output "policy_embeddings_table_id" {
  value = var.policy_embeddings_table_id
}


resource "local_file" "helm_secrets" {
  filename        = "${path.module}/../k8s/helm/deployment-secrets.yaml"
  file_permission = "0600"
  content = yamlencode({
    taxApp = {
      flaskSecretKey = random_password.flask_secret_key.result
      demoPassword   = var.demo_password
      demoUsername   = var.demo_username
    }
    jupyter = {
      rawPassword    = var.demo_password
    }
    vllm = {
      huggingFaceToken = var.hugging_face_token
    }
  })
}
