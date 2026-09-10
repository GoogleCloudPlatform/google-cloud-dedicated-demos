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
resource "google_compute_network" "vpc_default" {
  name                    = var.vpc
  project                 = data.google_project.this.project_id
  auto_create_subnetworks = false
  depends_on              = [time_sleep.wait_for_service_enablement] # S'assure que l'API est activée avant de créer le VPC
}

resource "google_compute_subnetwork" "subnet_u_france_east1" {
  name          = "${var.vpc}-subnet"
  project       = data.google_project.this.project_id
  region        = var.region
  network       = google_compute_network.vpc_default.self_link
  ip_cidr_range = "10.128.0.0/20"

  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = "10.130.0.0/18"
  }
  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = "10.134.0.0/20"
  }
}

resource "google_compute_subnetwork" "proxy_only_subnet" {
  name          = "${var.vpc}-proxy-subnet"
  project       = data.google_project.this.project_id
  region        = var.region
  network       = google_compute_network.vpc_default.self_link
  ip_cidr_range = "10.129.0.0/20"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}


resource "google_compute_router" "nat_router" {
  name    = "${var.vpc}-router"
  project = data.google_project.this.project_id
  region  = var.region
  network = google_compute_network.vpc_default.name
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "${var.vpc}-nat"
  project                            = data.google_project.this.project_id
  region                             = var.region
  router                             = google_compute_router.nat_router.name
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet_u_france_east1.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  nat_ip_allocate_option = "AUTO_ONLY"
}
