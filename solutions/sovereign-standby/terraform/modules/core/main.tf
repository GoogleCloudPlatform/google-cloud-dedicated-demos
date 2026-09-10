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
module "auth" {
  count  = lookup(var.config, "enable_auth", false) ? 1 : 0
  source = "../auth"

  prefix                = var.config.general.prefix
  universe_domain       = var.config.general.universe_domain
  org_id                = var.config.general.org_id
  pool_id               = try(var.config.auth.pool_id, "")
  provider_id           = try(var.config.auth.provider_id, "")
  federated_user_email  = try(var.config.auth.federated_user_email, "")
  idp_metadata_xml_file = try(var.config.auth.idp_metadata_xml_file, "")
}

module "network" {
  count  = var.config.enable_network ? 1 : 0
  source = "../network"

  prefix                    = var.config.general.prefix
  project_id                = var.config.general.project_id
  region                    = var.config.network.region
  zone                      = var.config.network.zone
  local_subnet_cidr         = var.config.network.local_subnet_cidr
  remote_subnet_cidr        = var.config.network.remote_subnet_cidr
  local_asn                 = var.config.network.local_asn
  remote_asn                = var.config.network.remote_asn
  shared_ike_key            = var.config.network.shared_ike_key
  vm_machine_type           = var.config.network.vm_machine_type
  vm_image                  = var.config.network.vm_image
  bgp_cr_interface_0_ip     = var.config.network.bgp_cr_interface_0_ip
  bgp_peer_interface_0_ip   = var.config.network.bgp_peer_interface_0_ip
  bgp_cr_interface_1_ip     = var.config.network.bgp_cr_interface_1_ip
  bgp_peer_interface_1_ip   = var.config.network.bgp_peer_interface_1_ip
  remote_vpn_interface_0_ip = var.config.network.remote_vpn_interface_0_ip
  remote_vpn_interface_1_ip = var.config.network.remote_vpn_interface_1_ip
  allowed_ssh_source_ip     = var.config.network.allowed_ssh_source_ip
  create_test_vm            = var.config.network.create_test_vm
  secondary_ip_ranges       = var.config.network.secondary_ip_ranges
  is_gcp                    = var.config.general.is_gcp
  google_apis_psc_ip        = var.config.network.google_apis_psc_ip
}


module "sts" {
  count  = lookup(var.config, "enable_sts", false) ? 1 : 0
  source = "../sts"

  prefix                   = var.config.general.prefix
  enable_sts_control_plane = lookup(var.config, "enable_sts", false) && var.config.general.is_gcp
  enable_sts_data_plane    = lookup(var.config, "enable_sts", false) && !var.config.general.is_gcp
  project_id               = var.config.general.project_id
  gcp_project_id           = try(var.config.gcs.gcp_project_id, "")
  zone                     = var.config.network.zone
  subnet_id                = length(module.network) > 0 ? module.network[0].subnet_id : ""
  vm_machine_type          = var.config.network.vm_machine_type
  vm_image                 = var.config.network.vm_image
  sts_agent_vm_name        = try(var.config.gcs.sts_agent_vm_name, "sts-agent-vm")
  source_bucket_name       = try(var.config.gcs.source_bucket_name, "")
  dest_bucket_name         = try(var.config.gcs.dest_bucket_name, "")
  dest_bucket_location     = try(var.config.gcs.dest_bucket_location, "")
  agent_pool_name          = try(var.config.gcs.agent_pool_name, "")
  transfer_job_name        = try(var.config.gcs.transfer_job_name, "")
}

module "gke" {
  count  = var.config.enable_app ? 1 : 0
  source = "../gke"

  prefix       = var.config.general.prefix
  project_id   = var.config.general.project_id
  region       = var.config.network.region
  network_name = module.network[0].network_name
  subnet_name  = module.network[0].subnet_id
  is_gcp       = var.config.general.is_gcp

  cluster_name = try(var.config.gke.cluster_name, "federation-gke-cluster")
}

module "postgresql" {
  count  = var.config.enable_cloudsql ? 1 : 0
  source = "../postgresql"

  prefix              = var.config.general.prefix
  project_id          = var.config.general.project_id
  region              = var.config.network.region
  db_tier             = try(var.config.cloudsql_db.db_tier, null)
  subnet_name         = module.network[0].subnet_name
  subnet_id           = module.network[0].subnet_id
  network_name        = module.network[0].network_name
  psc_ip              = try(var.config.cloudsql_db.psc_ip, null)
  admin_password      = try(var.config.cloudsql_db.admin_password, null)
  repl_password       = try(var.config.cloudsql_db.repl_password, null)
  db_name             = try(var.config.cloudsql_db.db_name, null)
  db_user             = try(var.config.cloudsql_db.db_user, null)
  enable_psc_outbound = var.config.enable_psc_outbound
}

module "monitoring" {
  count  = var.config.enable_monitoring ? 1 : 0
  source = "../monitoring"

  prefix     = var.config.general.prefix
  project_id = var.config.general.project_id
}
