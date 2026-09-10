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
variable "prefix" {
  type        = string
  default     = ""
  description = "Prefix for resource names"
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
}


variable "db_tier" {
  description = "Cloud SQL postgres DB tier"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "psc_ip" {
  description = "The IP address of PSC for DB instance"
  type        = string
  default     = ""
}

variable "admin_password" {
  description = "The password for the default postgres admin user"
  type        = string
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "repl_password" {
  description = "The password for the replication/application user (repl_user)"
  type        = string
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "db_name" {
  description = "The name of the application database to create"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "db_user" {
  description = "The name of the application database user to create"
  type        = string
}



variable "enable_psc_outbound" {
  description = "Enable PSC Outbound Network Attachment for database replication"
  type        = bool
  default     = false
}
