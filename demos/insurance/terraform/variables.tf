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
variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "universe_domain" {
  type        = string
  description = "GCP Universe Domain"
  default     = "apis-berlin-build0.goog"
}

variable "region" {
  type        = string
  description = "region to use"
  default     = "u-germany-northeast1"
}

variable "claims_document_bucket_name" {
  type        = string
  description = "Bucket for claims document"
}

variable "jupyter_password" {
  type        = string
  description = "Plain text password for the Jupyter Notebook user."
  sensitive   = true
}

variable "hugging_face_token" {
  type        = string
  description = "Hugging Face User Access Token (Read permission) to download gated models"
  sensitive   = true
}


# Optional configurations with safe default values
variable "vpc" {
  type        = string
  description = "VPC name"
  default     = "insurance-demo-vpc"
}

variable "gke_name" {
  type        = string
  description = "GKE name"
  default     = "insurance-demo-cluster"
}


variable "thp_apis" {
  type        = set(string)
  description = "List of APIs to enable for realize this configuration"
  default = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com"
  ]
}

variable "sql_instance_name" {
  type        = string
  description = "Name of SQL Instance"
  default     = "insurance-demo-sql"
}

variable "database_version_sql" {
  type        = string
  description = "Database version for SQL Instance"
  default     = "POSTGRES_15"
}

variable "sql_instance_resources" {
  type        = string
  description = "Machine configuration and performance about SQL Instance"
  default     = "db-perf-optimized-C-4"
}

variable "database_name" {
  type        = string
  description = "Name of database for testing configuration"
  default     = "insurance_demo_claims"
}

variable "psc_endpoint_name" {
  type        = string
  description = "Name of PSC endpoint"
  default     = "insurance-demo-psc-endpoint"
}


variable "dns_managed_zone_name" {
  type        = string
  description = "Name of DNS Managed zone"
  default     = "insurance-demo-dns-zone"
}

variable "psc_dns_name" {
  type        = string
  description = "Name for dns name in managed zone"
  default     = "u-germany-northeast1.sql.goog."
}

variable "artifact_repository_id" {
  type        = string
  description = "ID for Artifact Registry Docker repository"
  default     = "insurance-demo-repo"
}

variable "app_login_user" {
  type        = string
  description = "Username for accessing the Web Showroom Dashboard"
}

variable "app_login_password" {
  type        = string
  description = "Password for accessing the Web Showroom Dashboard"
  sensitive   = true
}
