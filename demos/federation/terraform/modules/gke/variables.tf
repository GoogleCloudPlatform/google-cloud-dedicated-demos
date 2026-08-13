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
  type        = string
  description = "The project ID to deploy the GKE cluster in"
}

variable "region" {
  type        = string
  description = "The region to deploy the GKE cluster in"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the subnet"
}

variable "cluster_name" {
  type        = string
  default     = "federation-gke-cluster"
  description = "The name of the GKE cluster"
}

variable "cluster_secondary_range_name" {
  type        = string
  default     = "pods"
  description = "The name of the secondary range for Pods"
}

variable "services_secondary_range_name" {
  type        = string
  default     = "services"
  description = "The name of the secondary range for Services"
}

variable "is_gcp" {
  type        = bool
  default     = true
  description = "Flag indicating whether target is GCP (true) or GCD (false)"
}
