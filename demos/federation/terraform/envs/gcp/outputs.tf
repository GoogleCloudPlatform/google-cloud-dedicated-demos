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
  value = module.core.local_vpn_interface_0_ip
}

output "local_vpn_interface_1_ip" {
  value = module.core.local_vpn_interface_1_ip
}

output "test_vm_internal_ip" {
  value = module.core.test_vm_internal_ip
}



output "db_host" {
  description = "PSC IP of the database"
  value       = try(local.config.cloudsql_db.psc_ip, null)
}

output "db_port" {
  description = "Database port"
  value       = 5432
}

output "db_name" {
  description = "Database name"
  value       = try(local.config.cloudsql_db.db_name, null)
}

output "db_user" {
  description = "Database user"
  value       = try(local.config.cloudsql_db.db_user, null)
}

output "db_password" {
  description = "Database password"
  value       = try(local.config.cloudsql_db.repl_password, null)
  sensitive   = true
}

output "gke_sa_email" {
  description = "GKE Service Account Email for Workload Identity annotation"
  value       = module.core.gke_sa_email
}

output "gke_cluster_name" {
  description = "Full name of the GKE cluster"
  value       = module.core.gke_cluster_name
}

output "prefix" {
  description = "Resource prefix"
  value       = local.config.general.prefix
}

output "project_id" {
  description = "Project ID"
  value       = local.config.general.project_id
}

output "region" {
  description = "Region"
  value       = local.config.network.region
}

output "zone" {
  description = "Zone"
  value       = local.config.network.zone
}

output "dashboard_id" {
  description = "Monitoring dashboard ID"
  value       = module.core.dashboard_id
}

output "db_admin_password" {
  description = "Database admin password"
  value       = try(local.config.cloudsql_db.admin_password, null)
  sensitive   = true
}

output "source_bucket_name" {
  description = "Source bucket name on GCP"
  value       = module.core.source_bucket_name
  sensitive   = true
}

output "transfer_job_name" {
  description = "The name of the created transfer job"
  value       = module.core.transfer_job_name
  sensitive   = true
}
