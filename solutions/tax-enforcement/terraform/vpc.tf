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
resource "google_compute_network" "tax_office_network" {
  project                 = var.project_id
  name                    = local.vpc_name
  auto_create_subnetworks = false
  depends_on              = [time_sleep.wait_for_service_enablement]
}

resource "google_compute_subnetwork" "tax_office_node_subnet" {
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.tax_office_network.self_link
  name          = local.subnet_name
  ip_cidr_range = var.gke_node_cidr
}

resource "google_compute_subnetwork" "proxy_only_subnet" {
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.tax_office_network.self_link
  name          = "${local.resource_prefix}-proxy-subnet"
  ip_cidr_range = var.proxy_only_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_router" "tax_office_router" {
  project = var.project_id
  name    = local.router_name
  network = google_compute_network.tax_office_network.name
  region  = var.region
}

resource "google_compute_router_nat" "tax_office_nat" {
  project                            = var.project_id
  name                               = local.nat_name
  router                             = google_compute_router.tax_office_router.name
  region                             = google_compute_router.tax_office_router.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.tax_office_node_subnet.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  nat_ip_allocate_option = "AUTO_ONLY"
}
