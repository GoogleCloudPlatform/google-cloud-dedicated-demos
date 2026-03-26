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
# --- 1. Core Configuration ---

variable "project_id" {
  description = "The GCP project where the resources will be created."
  type        = string

  validation {
    condition     = var.project_id != ""
    error_message = "'project_id' was not set, please set the value in the terraform.tfvars file"
  }
}

variable "region" {
  description = "Region for resources to be created"
  type        = string

  validation {
    condition     = var.region != ""
    error_message = "'region' was not set, please set the value in the terraform.tfvars file"
  }
}

variable "universe_domain" {
  description = "Sovereign Universe (e.g., 'eu0.cloud' for sovereign environments)"
  type        = string
  default     = null
}

variable "project_services" {
  description = "Service APIs to enable on the project."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "dns.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
}

# --- 2. Application & Naming Configuration ---

variable "resource_prefix" {
  description = "A short prefix used for naming all major resources (e.g., 'tax-office')"
  type        = string
  default     = "tax-office"
}

variable "app_name" {
  description = "The name of application used for Artifact Registry repository ID."
  type        = string
  default     = "tax-office-app"
}

# --- 3. GKE & Workload Identity Configuration ---

variable "node_sa_id" {
  description = "The account ID for the GKE node Service Account."
  type        = string
  default     = "tax-office-node"
}

variable "node_sa_display_name" {
  description = "The display name for the GKE node Service Account."
  type        = string
  default     = "Tax Office Node SA"
}

variable "gke_node_cidr" {
  description = "CIDR range for the GKE node subnetwork."
  type        = string
  default     = "10.128.0.0/20"
}

# --- 4. Data & Storage Configuration ---

variable "data_bucket_name" {
  description = "The unique name of bucket which will hold tax data."
  type        = string
  default     = "tax-office-data2"
}

variable "data_file_location" {
  description = "Local path to the file to upload to GCS."
  type        = string
  default     = "./assets/tax_office_data.csv"
}

# --- 5. BigQuery Configuration ---

variable "dataset_id" {
  description = "Big Query Dataset id for tax data."
  type        = string
  default     = "tax_office_dataset"
}

variable "tax_table_id" {
  description = "Big Query table id for tax data."
  type        = string
  default     = "tax_data_table"
}

variable "policy_table_id" {
  description = "Big Query table id for policy data."
  type        = string
  default     = "policies"
}

variable "policy_embeddings_table_id" {
  description = "Big Query table id for policy embeddings data."
  type        = string
  default     = "policy_embeddings"
}
