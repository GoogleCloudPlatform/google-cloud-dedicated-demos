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
  description = "The GCP project ID"
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "local_subnet_cidr" {
  type = string
}

variable "remote_subnet_cidr" {
  type = string
}

variable "local_asn" {
  type = number
}

variable "remote_asn" {
  type = number
}

variable "shared_ike_key" {
  type = string
}

variable "vm_machine_type" {
  type = string
}

variable "vm_image" {
  type = string
}

variable "bgp_cr_interface_0_ip" {
  type = string
}

variable "bgp_peer_interface_0_ip" {
  type = string
}

variable "bgp_cr_interface_1_ip" {
  type = string
}

variable "bgp_peer_interface_1_ip" {
  type = string
}

variable "remote_vpn_interface_0_ip" {
  type = string
}

variable "remote_vpn_interface_1_ip" {
  type = string
}
variable "allowed_ssh_source_ip" {
  type        = string
  description = "Allowed IP address for external SSH access"
  default     = ""
}

variable "secondary_ip_ranges" {
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = [
    {
      range_name    = "pods"
      ip_cidr_range = "10.101.0.0/16"
    },
    {
      range_name    = "services"
      ip_cidr_range = "10.102.0.0/20"
    }
  ]
  description = "Optional secondary IP ranges for the subnet (used by GKE)"
}

variable "create_test_vm" {
  description = "Whether to create a test VM in the network"
  type        = bool
  default     = false
}

variable "is_gcp" {
  type        = bool
  description = "Whether this network is deployed in standard GCP (True) or GCD (False)"
  default     = true
}

variable "google_apis_psc_ip" {
  type        = string
  description = "The static IP to reserve for Google APIs PSC endpoint in GCP (must be outside any configured subnet ranges)"
}
