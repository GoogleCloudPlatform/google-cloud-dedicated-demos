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
# Custom VPC network for monitoring stack
resource "google_compute_network" "monitoring_vpc" {
  count                   = local.config.enable_gke == true ? 1 : 0
  name                    = local.config.vpc_name
  project                 = data.google_client_config.default.project
  auto_create_subnetworks = false
}

# Primary subnetwork with Private Google Access enabled for secure API communication
resource "google_compute_subnetwork" "monitoring_subnet" {
  count                    = local.config.enable_gke == true ? 1 : 0
  name                     = local.config.subnet_name
  project                  = data.google_client_config.default.project
  region                   = data.google_client_config.default.region
  network                  = length(google_compute_network.monitoring_vpc) > 0 ? google_compute_network.monitoring_vpc[0].name : local.config.vpc_name
  ip_cidr_range            = "10.128.0.0/24"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = "10.130.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = "10.131.0.0/20"
  }
}

resource "google_compute_subnetwork" "monitoring_proxy_subnet" {
  count         = local.config.enable_gke == true ? 1 : 0
  name          = local.config.proxy_subnet_name
  project       = data.google_client_config.default.project
  region        = data.google_client_config.default.region
  network       = length(google_compute_network.monitoring_vpc) > 0 ? google_compute_network.monitoring_vpc[0].name : local.config.vpc_name
  ip_cidr_range = "10.129.0.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_router" "monitoring_router" {
  count   = local.config.enable_gke == true ? 1 : 0
  name    = local.config.router_name
  project = data.google_client_config.default.project
  region  = data.google_client_config.default.region
  network = length(google_compute_network.monitoring_vpc) > 0 ? google_compute_network.monitoring_vpc[0].name : local.config.vpc_name
}

# This is needed as helm needs to communicate to internet to fetch
# components like grafana, open telemetry, mimir.
resource "google_compute_router_nat" "monitoring_nat_router" {
  count                              = local.config.enable_gke == true ? 1 : 0
  name                               = local.config.nat_name
  project                            = data.google_client_config.default.project
  region                             = data.google_client_config.default.region
  router                             = length(google_compute_router.monitoring_router) > 0 ? google_compute_router.monitoring_router[0].name : local.config.router_name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = length(google_compute_subnetwork.monitoring_subnet) > 0 ? google_compute_subnetwork.monitoring_subnet[0].id : local.config.subnet_name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
