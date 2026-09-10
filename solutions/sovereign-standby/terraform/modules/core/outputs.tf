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
output "local_vpn_interface_0_ip" {
  description = "The first IP address of the newly created HA VPN Gateway. Put this in the 'remote_vpn_interface_0_ip' field in the OTHER environment's YAML."
  value       = length(module.network) > 0 ? module.network[0].local_vpn_interface_0_ip : null
}

output "local_vpn_interface_1_ip" {
  description = "The second IP address of the newly created HA VPN Gateway. Put this in the 'remote_vpn_interface_1_ip' field in the OTHER environment's YAML."
  value       = length(module.network) > 0 ? module.network[0].local_vpn_interface_1_ip : null
}

output "test_vm_internal_ip" {
  description = "The internal IP address of the test VM created in this project."
  value       = length(module.network) > 0 ? module.network[0].test_vm_internal_ip : null
}



output "gke_sa_email" {
  description = "GKE Google Service Account Email for Workload Identity annotation"
  value       = length(module.gke) > 0 ? module.gke[0].service_account_email : null
}

output "gke_cluster_name" {
  description = "Full name of the GKE cluster"
  value       = length(module.gke) > 0 ? module.gke[0].cluster_name : null
}

output "dashboard_id" {
  description = "Monitoring dashboard ID"
  value       = length(module.monitoring) > 0 ? module.monitoring[0].dashboard_id : null
}

output "source_bucket_name" {
  description = "Source bucket name on GCP"
  value       = length(module.sts) > 0 ? module.sts[0].source_bucket_name : null
}

output "transfer_job_name" {
  description = "The name of the created transfer job"
  value       = length(module.sts) > 0 ? module.sts[0].transfer_job_name : null
}

output "dest_bucket_name" {
  description = "The name of the created destination bucket"
  value       = length(module.sts) > 0 ? module.sts[0].dest_bucket_name : null
}
