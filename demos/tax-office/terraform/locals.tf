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
locals {
  resource_prefix      = var.resource_prefix
  vpc_name             = local.resource_prefix
  subnet_name          = "${local.resource_prefix}-subnet"
  router_name          = "${local.resource_prefix}-router"
  nat_name             = "${local.resource_prefix}-nat"
  cluster_name         = "${local.resource_prefix}-cluster"
  artifact_registry_id = "${var.app_name}-registry"

  # Split project_id (e.g., "eu0:abc-test-env") into parts for wif name: abc-test-env.eu0
  project_id_parts      = split(":", var.project_id)
  project_prefix        = element(local.project_id_parts, 0)
  project_name_id       = element(local.project_id_parts, 1)
  wif_name_for_universe = "${local.project_name_id}.${local.project_prefix}"

  # Constructed Workload Identity Pool ID for GKE and IAM configurations
  wif_pool_id = "${local.wif_name_for_universe}.svc.id.goog"

  # Standardized KSA member strings for IAM role binding.
  project_number     = data.google_project.project.number
  jupyter_ksa_member = "principal://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${local.wif_pool_id}/subject/ns/${local.resource_prefix}-ns/sa/jupyter-notebook-ksa"
  app_ksa_member     = "principal://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${local.wif_pool_id}/subject/ns/${local.resource_prefix}-ns/sa/app-ksa"

  # Splits the local path by the directory separator '/' and takes the last element (the file name).
  # e.g., "./assets/tax_office_data.csv" -> "tax_office_data.csv"
  data_file_name = element(split("/", var.data_file_location), length(split("/", var.data_file_location)) - 1)

  bigquery_app_roles = toset([
    "roles/bigquery.jobUser",
    "roles/bigquery.dataViewer",
    "roles/storage.objectViewer",
    "roles/bigquery.dataEditor"
  ])

  # Jupyter roles
  jupyter_roles = local.bigquery_app_roles

  # App roles
  app_roles = local.bigquery_app_roles
}
