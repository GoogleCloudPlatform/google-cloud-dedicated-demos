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

variable "enable_sts_control_plane" {
  type        = bool
  description = "Enable creation of STS Control Plane resources in Universe A (GCP)"
  default     = false
}

variable "enable_sts_data_plane" {
  type        = bool
  description = "Enable creation of STS Data Plane resources in Universe B (GCD)"
  default     = false
}

variable "project_id" {
  type        = string
  description = "Project ID of the target deployment environment"
}

variable "gcp_project_id" {
  type        = string
  description = "Project ID of Universe A (GCP) used for metadata query in GCD agent"
  default     = ""
}


variable "zone" {
  type        = string
  description = "Zone for compute instance placement"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID of the target VPC network to attach VM instance"
  default     = ""
}

variable "vm_machine_type" {
  type        = string
  description = "Machine type for the STS agent VM instance"
  default     = "c3-standard-4"
}

variable "vm_image" {
  type        = string
  description = "OS Image for the VM instance"
  default     = "eu0-system:debian-cloud/debian-13"
}

variable "sts_agent_vm_name" {
  type        = string
  description = "Name for the STS agent VM instance"
  default     = "sts-agent-vm"
}

variable "source_bucket_name" {
  type        = string
  description = "Name of the GCS source bucket created in Universe A (GCP)"
  default     = ""
}

variable "dest_bucket_name" {
  type        = string
  description = "Name of the destination GCS bucket in Universe B (GCD)"
}

variable "dest_bucket_location" {
  type        = string
  description = "Location for the destination GCS bucket"
}

variable "agent_pool_name" {
  type        = string
  description = "Name of the Storage Transfer Service Agent Pool"
}

variable "transfer_job_name" {
  type        = string
  description = "Name of the Storage Transfer Job"
}
